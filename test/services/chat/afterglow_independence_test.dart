// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

// Afterglow depends on the Realism Engine. Full stop.
//
// THE BUG, as a user hit it: 18+ on, Realism Engine on, Afterglow on — and
// nothing ever happens. Arousal pins at 100 forever. The Porch Life row shows
// the switch live and ungreyed the whole time, because its one declared
// dependency is satisfied.
//
// The cooldown's only trigger is climax detection, and climax detection rode
// the needs-impact eval, which opens
//
//     if (!getNeedsSimEnabled() || !getRealismEnabled()) return;
//
// `CharacterCard.needsSimEnabled` DEFAULTS FALSE, so on most cards that eval
// never ran and Afterglow never started. A dependency nobody declared.
//
// TWO PROPERTIES ARE PINNED HERE, and the second exists because the first
// attempt at this fix got it wrong:
//
//   1. Climax does not route through Needs.
//   2. Climax runs POST-GENERATION. It reads the reply. An earlier draft moved
//      it onto the pre-generation arousal eval, which scores the USER's
//      message — it would have judged a reply that did not exist yet, lagged a
//      turn, re-fired on the same climax still in recent history, and put the
//      pre-gen judge in the business of scoring the character's own words,
//      which the settled rule forbids because a reroll would reroll it.
//      The full unit and golden suites were GREEN on that version. Nothing
//      tested when it ran. That is what the second group is for.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/climax_eval.dart';
import 'package:front_porch_ai/services/chat/realism_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the check asks one question, and asks it well', () {
    test('the prompt carries the criteria, not just the question', () {
      final p = ClimaxEval.buildPrompt(
        charName: 'Jennifer',
        reply: 'she shuddered and went limp',
        recentExchange: '',
        toolsMode: false,
      );

      expect(p, contains('CLIMAX DETECTION'));
      expect(
        p,
        contains('are NOT a climax'),
        reason: 'without explicit criteria a model — especially a reasoning '
            'one — almost never answers true, and the Lust bar stays pinned '
            'at the top forever',
      );
      expect(
        p,
        contains('she shuddered and went limp'),
        reason: 'it judges the REPLY; a prompt without the reply in it is '
            'judging nothing',
      );
    });

    test('both fields are required in the tool schema', () {
      final params =
          ClimaxEval.tools.single['function']['parameters']
              as Map<String, dynamic>;

      expect(
        params['required'],
        containsAll(['is_climax', 'refractory_turns']),
        reason: 'optional means never emitted — a model fills in what the '
            'schema demands and skips what it does not, which is how orgasm '
            'detection was silently off on every tools-capable backend once '
            'before',
      );
    });

    test('a true verdict yields the refractory, false yields nothing', () {
      expect(
        ClimaxEval.parseRefractory('{"is_climax":true,"refractory_turns":6}'),
        6,
      );
      expect(
        ClimaxEval.parseRefractory('{"is_climax":false,"refractory_turns":0}'),
        isNull,
      );
    });

    test('a loose backend still gets read correctly', () {
      expect(
        ClimaxEval.parseRefractory('{"is_climax":"true","refractory_turns":"4"}'),
        4,
        reason: 'quoted values are the local-model floor',
      );
      expect(
        ClimaxEval.parseRefractory('{"is_climax":true}'),
        5,
        reason: 'a missing refractory must not discard a climax that WAS '
            'reported — fall back to the middle of the range',
      );
      expect(
        ClimaxEval.parseRefractory('{"is_climax":true,"refractory_turns":99}'),
        10,
        reason: 'and it stays clamped',
      );
      expect(ClimaxEval.parseRefractory(null), isNull);
      expect(ClimaxEval.parseRefractory('nonsense'), isNull);
    });
  });

  group('it runs post-generation, on the reply', () {
    // Structural, and honestly labelled — proving this behaviourally needs a
    // live ChatService running a real turn. Read it as "it is wired to the
    // post-gen phase", not "it fires at the right moment".
    //
    // It exists because the first attempt at this fix put it on the pre-gen
    // path and every suite stayed green.
    String read(String name) =>
        File('lib/services/chat/$name').readAsStringSync();

    test('the pass is called from the post-generation phase', () {
      expect(
        read('chat_service_generation_postgen.dart'),
        contains('_runClimaxPass(finalResponse)'),
        reason: 'finalResponse is the reply that was just written — the only '
            'thing there is to judge',
      );
    });

    test('no pre-generation eval touches climax', () {
      // These four are the pre-gen judges. Climax appearing in any of them is
      // the exact regression this file was rewritten to catch.
      for (final f in const [
        'realism_prompt_builder.dart',
        'realism_evals.support.dart',
        'realism_evals.calls.dart',
        'realism_evals.one_shot.dart',
      ]) {
        expect(
          read(f),
          isNot(contains('is_climax')),
          reason: '$f runs BEFORE generation and scores the user\'s message; '
              'climax is about the character\'s own reply',
        );
      }
    });

    test('the realism tools no longer carry it either', () {
      for (final tool in [kEmotionalEvalTools, kOneShotEvalTools, kNeedsImpactEvalTools]) {
        final params =
            tool.single['function']['parameters'] as Map<String, dynamic>;
        expect((params['properties'] as Map).containsKey('is_climax'), isFalse);
      }
    });
  });

  group('nothing routes Afterglow through Needs', () {
    String read(String name) =>
        File('lib/services/chat/$name').readAsStringSync();

    test('the needs evaluator has no climax code left', () {
      final src = read('needs_impact_evaluator.dart');
      expect(src, isNot(contains('onClimax')));
      expect(src, isNot(contains('is_climax')));
      expect(src, isNot(contains('_readClimax')));
    });

    test('the needs prompt no longer asks about climax', () {
      expect(read('llm_eval_engine.dart'), isNot(contains('CLIMAX DETECTION')));
    });

    test('the gate is the engine and the Afterglow switch, and nothing else', () {
      final gate = read('chat_service_climax.dart');

      expect(gate, contains('_realismEnabled'));
      expect(gate, contains('nsfwCooldownEnabled'));
      expect(
        gate,
        isNot(contains('needsSimEnabled')),
        reason: 'this is the whole bug — a Needs check here brings back a '
            'dependency the UI never declared and the user cannot see',
      );
    });

    test('applyClimaxEffects has exactly one caller', () {
      // One trigger, one owner. Two is how these paths drift apart again.
      final hits = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) =>
                !f.path.endsWith('nsfw_service.dart') &&
                f.readAsStringSync().contains('.applyClimaxEffects('),
          )
          .toList();

      expect(hits, hasLength(1));
      expect(hits.single.path, contains('chat_service_climax.dart'));
    });
  });
}
