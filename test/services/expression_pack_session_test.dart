// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/expression_pack_service.dart';
import 'package:front_porch_ai/services/image_prompt/expression_prompts.dart';

void main() {
  group('ExpressionPackSession', () {
    test('run() drives all slots pending → done with per-slot derived seeds '
        'and emotion-first prompts', () async {
      final seeds = <int>[];
      final prompts = <String>[];
      final negatives = <String>[];
      Future<Uint8List?> gen({
        required String prompt,
        required String negativePrompt,
        required int seed,
      }) async {
        seeds.add(seed);
        prompts.add(prompt);
        negatives.add(negativePrompt);
        return Uint8List.fromList([seeds.length]);
      }

      final session = ExpressionPackSession(
        emotions: const ['joy', 'anger', 'neutral'],
        basePrompt: 'a portrait of luna',
        negativePrompt: 'np',
        generate: gen,
      );

      expect(session.slots, hasLength(3));
      expect(session.pendingCount, 3);
      expect(session.seed, greaterThanOrEqualTo(0));

      await session.run();

      expect(session.isRunning, isFalse);
      expect(session.doneCount, 3);
      expect(session.pendingCount, 0);
      for (final slot in session.slots) {
        expect(slot.state, ExpressionSlotState.done);
        expect(slot.bytes, isNotNull);
        expect(slot.keep, isTrue);
        expect(slot.error, isNull);
      }
      expect(seeds, hasLength(3));
      // Identity rides the img2img base — seeds must DIFFER per slot (a
      // shared seed at low CFG produced near-identical images), derived
      // deterministically from the session seed.
      expect(seeds.toSet(), hasLength(3), reason: 'per-slot noise');
      for (var i = 0; i < 3; i++) {
        expect(seeds[i], (session.seed + i) & 0x7fffffff);
      }
      // Emotion leads the prompt: front tokens carry the most weight.
      expect(prompts[0], '${kExpressionModifiers['joy']}, a portrait of luna');
      expect(prompts[2], startsWith(kExpressionModifiers['neutral']!));
      // Per-emotion counter-cues ride the negative prompt (free rider: CFG-1
      // models ignore negatives; classic CFG backends get real steering).
      expect(negatives[0], 'np, ${kExpressionNegatives['joy']}');
      expect(negatives[1], 'np, ${kExpressionNegatives['anger']}');
    });

    test('explicit constructor seed is honored', () async {
      final seeds = <int>[];
      final session = ExpressionPackSession(
        emotions: const ['joy'],
        basePrompt: 'p',
        negativePrompt: 'np',
        seed: 42,
        generate: ({required String prompt, required String negativePrompt, required int seed}) async {
          seeds.add(seed);
          return Uint8List.fromList([1]);
        },
      );
      expect(session.seed, 42);
      await session.run();
      expect(seeds, [42]);
    });

    test('null generator result → slot failed with error', () async {
      final session = ExpressionPackSession(
        emotions: const ['joy'],
        basePrompt: 'p',
        negativePrompt: 'np',
        generate: ({required String prompt, required String negativePrompt, required int seed}) async => null,
      );
      await session.run();
      final slot = session.slots.single;
      expect(slot.state, ExpressionSlotState.failed);
      expect(slot.error, isNotNull);
      expect(session.doneCount, 0);
      expect(session.keptCount, 0);
    });

    test('throwing generator → failed, run continues to later slots', () async {
      Future<Uint8List?> gen({
        required String prompt,
        required String negativePrompt,
        required int seed,
      }) async {
        if (prompt.contains(kExpressionModifiers['anger']!)) {
          throw Exception('boom');
        }
        return Uint8List.fromList([1]);
      }

      final session = ExpressionPackSession(
        emotions: const ['joy', 'anger', 'neutral'],
        basePrompt: 'p',
        negativePrompt: 'np',
        generate: gen,
      );
      await session.run();
      expect(session.slots[0].state, ExpressionSlotState.done);
      expect(session.slots[1].state, ExpressionSlotState.failed);
      expect(session.slots[1].error, contains('boom'));
      expect(session.slots[2].state, ExpressionSlotState.done);
      expect(session.doneCount, 2);
    });

    test('cancel() between slots leaves remainder pending; run() resumes', () async {
      late ExpressionPackSession session;
      var calls = 0;
      Future<Uint8List?> gen({
        required String prompt,
        required String negativePrompt,
        required int seed,
      }) async {
        calls++;
        if (calls == 2) session.cancel();
        return Uint8List.fromList([calls]);
      }

      session = ExpressionPackSession(
        emotions: const ['joy', 'anger', 'fear', 'sadness'],
        basePrompt: 'p',
        negativePrompt: 'np',
        generate: gen,
      );
      await session.run();
      // The in-flight (2nd) slot finishes; the rest stay pending.
      expect(session.isRunning, isFalse);
      expect(session.doneCount, 2);
      expect(session.pendingCount, 2);
      expect(session.slots[2].state, ExpressionSlotState.pending);
      expect(session.slots[3].state, ExpressionSlotState.pending);

      await session.run(); // resume path
      expect(session.doneCount, 4);
      expect(session.pendingCount, 0);
      expect(calls, 4);
    });

    test('reroll() uses a fresh seed and only touches that slot', () async {
      final seeds = <int>[];
      var counter = 0;
      Future<Uint8List?> gen({
        required String prompt,
        required String negativePrompt,
        required int seed,
      }) async {
        seeds.add(seed);
        counter++;
        return Uint8List.fromList([counter]);
      }

      final session = ExpressionPackSession(
        emotions: const ['joy', 'anger'],
        basePrompt: 'p',
        negativePrompt: 'np',
        generate: gen,
      );
      await session.run();
      final joyBytes = session.slots[0].bytes;
      final angerBytes = session.slots[1].bytes;

      await session.reroll(1);
      expect(seeds, hasLength(3));
      expect(seeds[2], isNot(session.seed), reason: 'reroll needs fresh seed');
      expect(session.seed, seeds[0], reason: 'session seed must not change');
      expect(session.slots[0].bytes, same(joyBytes));
      expect(session.slots[1].bytes, isNot(same(angerBytes)));
      expect(session.slots[1].state, ExpressionSlotState.done);
    });

    test(
      'reroll() marks the session running for its duration — generations '
      'serialize (single-GPU backends) and the UI can disable other buttons',
      () async {
        final gate = Completer<void>();
        var calls = 0;
        final session = ExpressionPackSession(
          emotions: const ['joy', 'anger'],
          basePrompt: 'p',
          negativePrompt: 'np',
          generate: ({required String prompt, required String negativePrompt, required int seed}) async {
            calls++;
            // Only the reroll (3rd call) blocks; the initial run flows through.
            if (calls > 2) await gate.future;
            return Uint8List.fromList([calls]);
          },
        );
        await session.run();
        expect(session.doneCount, 2);

        final rerolling = session.reroll(0); // blocks on the gate
        expect(session.isRunning, isTrue);
        await session.reroll(1); // must no-op while the reroll is in flight
        expect(calls, 3, reason: 'no concurrent second generation');
        gate.complete();
        await rerolling;
        expect(session.isRunning, isFalse);
      },
    );

    test('reroll() retries failed slots', () async {
      var failNext = true;
      final session = ExpressionPackSession(
        emotions: const ['joy'],
        basePrompt: 'p',
        negativePrompt: 'np',
        generate: ({required String prompt, required String negativePrompt, required int seed}) async {
          if (failNext) {
            failNext = false;
            return null;
          }
          return Uint8List.fromList([7]);
        },
      );
      await session.run();
      expect(session.slots[0].state, ExpressionSlotState.failed);
      await session.reroll(0);
      expect(session.slots[0].state, ExpressionSlotState.done);
      expect(session.slots[0].error, isNull);
      expect(session.doneCount, 1);
    });

    test('reroll() and run() are no-ops while running; bad index is safe', () async {
      final gate = Completer<void>();
      var calls = 0;
      final session = ExpressionPackSession(
        emotions: const ['joy', 'anger'],
        basePrompt: 'p',
        negativePrompt: 'np',
        generate: ({required String prompt, required String negativePrompt, required int seed}) async {
          calls++;
          await gate.future;
          return Uint8List.fromList([calls]);
        },
      );
      final running = session.run();
      expect(session.isRunning, isTrue);
      expect(calls, 1);

      await session.run(); // reentrancy guard: no-op
      expect(calls, 1);

      await session.reroll(1); // no-op while running
      expect(calls, 1);
      expect(session.slots[1].state, ExpressionSlotState.pending);

      gate.complete();
      await running;
      expect(session.doneCount, 2);
      expect(calls, 2);

      await session.reroll(99); // out of range: no-op, no throw
      await session.reroll(-1);
      expect(calls, 2);
    });

    test('setKeep flips keep and keptCount/doneCount track it', () async {
      final session = ExpressionPackSession(
        emotions: const ['joy', 'anger'],
        basePrompt: 'p',
        negativePrompt: 'np',
        generate: ({required String prompt, required String negativePrompt, required int seed}) async =>
            Uint8List.fromList([1]),
      );
      await session.run();
      expect(session.doneCount, 2);
      expect(session.keptCount, 2);
      session.setKeep(0, false);
      expect(session.slots[0].keep, isFalse);
      expect(session.keptCount, 1);
      expect(session.doneCount, 2);
      session.setKeep(0, true);
      expect(session.keptCount, 2);
      session.setKeep(99, true); // out of range: safe no-op
    });

    test('dispose mid-generation is safe (no post-dispose mutation)', () async {
      final gate = Completer<void>();
      final session = ExpressionPackSession(
        emotions: const ['joy'],
        basePrompt: 'p',
        negativePrompt: 'np',
        generate: ({required String prompt, required String negativePrompt, required int seed}) async {
          await gate.future;
          return Uint8List.fromList([1]);
        },
      );
      final running = session.run();
      session.dispose();
      gate.complete();
      // Must complete without throwing — notifying a disposed ChangeNotifier
      // would assert in debug mode, so this proves the disposed bail-out.
      await running;
    });
  });
}
