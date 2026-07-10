// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tests for ExpressionPackQc (advisory Vision QC over a finished expression
// pack) and describePortrait — both driven through a fake VisionEvalFn so no
// LLM or HTTP is involved. Also covers the reroll-reset contract on
// ExpressionPackSession: a regenerated slot must drop its stale verdict.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/expression_pack_qc.dart';
import 'package:front_porch_ai/services/expression_pack_service.dart';

ExpressionSlot doneSlot(String emotion, List<int> bytes) {
  final slot = ExpressionSlot(emotion);
  slot.state = ExpressionSlotState.done;
  slot.bytes = Uint8List.fromList(bytes);
  return slot;
}

/// Fake VisionEvalFn that captures every call and pops canned replies.
class FakeEval {
  FakeEval(this.replies);

  final List<String?> replies;
  final prompts = <String>[];
  final images = <List<String>>[];

  Future<String?> call({
    required String prompt,
    required List<String> imagesB64,
  }) async {
    prompts.add(prompt);
    images.add(imagesB64);
    return replies.removeAt(0);
  }
}

void main() {
  const base = 'QkFTRQ==';

  group('ExpressionPackQc.run', () {
    test('stamps pass/fail/mixed verdicts; flaw rides note without flipping '
        'pass; prompts carry the emotion; images ride [base, slot] in order',
        () async {
      final slots = [
        doneSlot('happy', [1, 2]),
        doneSlot('angry', [3, 4]),
        doneSlot('sad', [5, 6]),
      ];
      final fake = FakeEval([
        '{"same_person": true, "expression_matches": true, "flaw": "none"}',
        'Sure! {"same_person": false, "expression_matches": true, '
            '"flaw": "warped face"}',
        '{"same_person": true, "expression_matches": true, '
            '"flaw": "extra finger"}',
      ]);
      final qc = ExpressionPackQc(
        slots: slots,
        baseImageB64: base,
        fire: fake.call,
      );

      await qc.run();

      expect(slots[0].qc!.pass, isTrue);
      expect(slots[0].qc!.note, '');
      expect(slots[1].qc!.pass, isFalse);
      expect(slots[1].qc!.samePerson, isFalse);
      expect(slots[1].qc!.note, 'warped face');
      // A real flaw does NOT flip pass by itself — both booleans were true.
      expect(slots[2].qc!.pass, isTrue);
      expect(slots[2].qc!.note, 'extra finger');

      expect(qc.checkedCount, 3);
      expect(qc.totalToCheck, 3);
      expect(qc.flaggedCount, 1);
      expect(qc.unparsedCount, 0);
      expect(qc.isRunning, isFalse);

      expect(fake.prompts[0], contains('«happy»'));
      expect(fake.prompts[1], contains('«angry»'));
      expect(fake.prompts[2], contains('«sad»'));
      for (var i = 0; i < slots.length; i++) {
        expect(fake.images[i], [base, base64Encode(slots[i].bytes!)]);
      }
    });

    test('only done slots with bytes are checked', () async {
      final pending = ExpressionSlot('happy'); // stays pending
      final failed = ExpressionSlot('angry')
        ..state = ExpressionSlotState.failed;
      final done = doneSlot('sad', [7]);
      final fake = FakeEval([
        '{"same_person": true, "expression_matches": true, "flaw": "none"}',
      ]);
      final qc = ExpressionPackQc(
        slots: [pending, failed, done],
        baseImageB64: base,
        fire: fake.call,
      );

      await qc.run();

      expect(fake.prompts, hasLength(1));
      expect(qc.totalToCheck, 1);
      expect(pending.qc, isNull);
      expect(failed.qc, isNull);
      expect(done.qc, isNotNull);
    });

    test('unparseable and null replies leave qc null and count as unparsed',
        () async {
      final slots = [doneSlot('happy', [1]), doneSlot('angry', [2])];
      final fake = FakeEval(['they look pretty similar to me!', null]);
      final qc = ExpressionPackQc(
        slots: slots,
        baseImageB64: base,
        fire: fake.call,
      );

      await qc.run();

      expect(slots[0].qc, isNull);
      expect(slots[1].qc, isNull);
      expect(qc.unparsedCount, 2);
      expect(qc.checkedCount, 2);
      expect(qc.flaggedCount, 0);
    });

    test('cancel between slots leaves the rest unchecked', () async {
      final slots = [doneSlot('happy', [1]), doneSlot('angry', [2])];
      late ExpressionPackQc qc;
      var calls = 0;
      Future<String?> fire({
        required String prompt,
        required List<String> imagesB64,
      }) async {
        calls++;
        qc.cancel(); // requested mid-flight → consulted between slots
        return '{"same_person": true, "expression_matches": true, '
            '"flaw": "none"}';
      }

      qc = ExpressionPackQc(slots: slots, baseImageB64: base, fire: fire);
      await qc.run();

      expect(calls, 1);
      expect(slots[0].qc, isNotNull); // in-flight slot still finished
      expect(slots[1].qc, isNull);
      expect(qc.checkedCount, 1);
      expect(qc.isRunning, isFalse);
    });

    test('run() is reentrancy-guarded (second call is a no-op)', () async {
      final slots = [doneSlot('happy', [1])];
      final gate = Completer<void>();
      var calls = 0;
      Future<String?> fire({
        required String prompt,
        required List<String> imagesB64,
      }) async {
        calls++;
        await gate.future;
        return '{"same_person": true, "expression_matches": true, '
            '"flaw": "none"}';
      }

      final qc = ExpressionPackQc(
        slots: slots,
        baseImageB64: base,
        fire: fire,
      );
      final first = qc.run();
      expect(qc.isRunning, isTrue);
      final second = qc.run(); // must not start a second pass
      gate.complete();
      await first;
      await second;

      expect(calls, 1);
    });

    test(
      'a slot re-rolled while its check is in flight never receives the '
      'stale verdict (bytes identity guard)',
      () async {
        final slots = [doneSlot('happy', [1]), doneSlot('angry', [2])];
        Future<String?> fire({
          required String prompt,
          required List<String> imagesB64,
        }) async {
          if (prompt.contains('happy')) {
            // Simulate a re-roll landing while this check was in flight.
            slots[0].bytes = Uint8List.fromList([9, 9]);
            slots[0].qc = null;
          }
          return '{"same_person": false, "expression_matches": false, '
              '"flaw": "none"}';
        }

        final qc = ExpressionPackQc(
          slots: slots,
          baseImageB64: base,
          fire: fire,
        );
        await qc.run();

        expect(slots[0].qc, isNull, reason: 'stale verdict must not stamp');
        expect(slots[1].qc, isNotNull, reason: 'unaffected slot still checked');
        expect(qc.checkedCount, 2);
        expect(qc.unparsedCount, 0, reason: 'skipped ≠ unparsed');
      },
    );

    test('dispose mid-run bails out without stamping or notifying', () async {
      final slots = [doneSlot('happy', [1])];
      late ExpressionPackQc qc;
      Future<String?> fire({
        required String prompt,
        required List<String> imagesB64,
      }) async {
        qc.dispose(); // dialog closed while the eval was in flight
        return '{"same_person": true, "expression_matches": true, '
            '"flaw": "none"}';
      }

      qc = ExpressionPackQc(slots: slots, baseImageB64: base, fire: fire);
      await qc.run(); // must not throw (notifyListeners after dispose)

      expect(slots[0].qc, isNull);
      expect(qc.checkedCount, 0);
    });
  });

  group('reroll resets stale verdicts (ExpressionPackSession)', () {
    test('a regenerated slot drops its qc', () async {
      final session = ExpressionPackSession(
        emotions: const ['happy'],
        basePrompt: 'portrait',
        generate: ({required String prompt, required int seed}) async =>
            Uint8List.fromList([9]),
      );
      await session.run();
      expect(session.slots[0].state, ExpressionSlotState.done);

      session.slots[0].qc = const PackQcVerdict(
        samePerson: true,
        expressionMatches: true,
      );
      await session.reroll(0);

      expect(session.slots[0].state, ExpressionSlotState.done);
      expect(session.slots[0].qc, isNull);
    });
  });

  group('describePortrait', () {
    test('happy path returns the trimmed tags', () async {
      final fake = FakeEval(['  red hair, green eyes, freckles  ']);
      final tags = await describePortrait(imageB64: base, fire: fake.call);

      expect(tags, 'red hair, green eyes, freckles');
      expect(fake.images.single, [base]);
      expect(fake.prompts.single, contains('comma-separated'));
    });

    test('empty or null replies return null', () async {
      expect(
        await describePortrait(imageB64: base, fire: FakeEval(['   ']).call),
        isNull,
      );
      expect(
        await describePortrait(imageB64: base, fire: FakeEval([null]).call),
        isNull,
      );
    });

    test('overlong replies are truncated at a tag boundary', () async {
      final rambling = List.generate(120, (i) => 'tag number $i').join(', ');
      final fake = FakeEval([rambling]);
      final tags = await describePortrait(imageB64: base, fire: fake.call);

      expect(tags, isNotNull);
      expect(tags!.length, lessThanOrEqualTo(600));
      expect(tags.endsWith(','), isFalse);
      expect(rambling.startsWith(tags), isTrue);
    });
  });
}
