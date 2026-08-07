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

// Ambitions steer objectives (maintainer ruling 2026-08-07): Ambition (the
// mountain) -> Objectives (the switchbacks) -> Tasks (the steps). The
// proposal eval is shown the character's ambitions and asked for the next
// believable step up one of them, and it reports WHICH one it served so the
// answer can be stored on the objective.
//
// The failure mode that makes this worth guarding is quiet and total: the
// prompt numbers a roster, the parse turns a number back into an ambition,
// and if those two ever disagree about which ambitions are in the list — or
// what order they are in — then "2" means one goal on the way out and a
// different goal on the way back. Nothing throws. The user just sees a chip
// claiming their quest serves a goal it has nothing to do with.
//
// So most of this file pins that the numbering and its inverse read the same
// list, including at the edges (achieved ambitions dropped, out-of-range,
// junk).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/realism_prompt_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bakery = 'open her own bakery';
  const sister = 'reconcile with her sister';
  const done = 'learn to drive';

  List<({String text, int progress})> roster() => const [
    (text: bakery, progress: 30),
    (text: sister, progress: 0),
  ];

  String narrative(List<({String text, int progress})> ambitions) =>
      RealismPromptBuilder.narrativeEvalPrompt(
        charName: 'Jennifer',
        userName: 'Sam',
        dossier: '',
        recent: 'Sam: hello\nJennifer: hi',
        ambitions: ambitions,
      );

  String oneShot(List<({String text, int progress})> ambitions) =>
      RealismPromptBuilder.oneShotEvalPrompt(
        charName: 'Jennifer',
        userName: 'Sam',
        dossier: '',
        standing: '',
        recent: 'Sam: hello\nJennifer: hi',
        arousalEnabled: false,
        arousalLevel: 0,
        ambitions: ambitions,
      );

  group('the roster the model is shown', () {
    test('numbers the ambitions with their stage words', () {
      final p = narrative(roster());

      expect(p, contains('1. $bakery (gaining ground)'));
      expect(p, contains('2. $sister (just beginning)'));
      expect(
        p,
        contains('serves_ambition'),
        reason: 'the field has to be asked for, or nothing ever tags a quest',
      );
    });

    test('drops an ambition that is already achieved', () {
      final p = narrative(const [
        (text: done, progress: 100),
        (text: bakery, progress: 30),
      ]);

      expect(
        p,
        isNot(contains(done)),
        reason: 'a finished mountain has no next switchback; offering it just '
            'invites steps toward something already done',
      );
      expect(
        p,
        contains('1. $bakery'),
        reason: 'and the survivors renumber from 1 — which is exactly why the '
            'resolver must read the same filtered list',
      );
    });

    test('a character with no ambitions is charged nothing', () {
      final p = narrative(const []);

      expect(p, isNot(contains('serves_ambition')));
      expect(p, isNot(contains('Long-term ambitions')));
      expect(
        p,
        isNot(contains('PREFER a concrete next step')),
        reason: 'the whole steering block must vanish, not render empty — an '
            'ambition-less card has to cost what it did before this existed',
      );
    });

    test('so is one whose every ambition is achieved', () {
      expect(narrative(const [(text: done, progress: 100)]),
          isNot(contains('serves_ambition')));
    });
  });

  group('resolveServedAmbition is the exact inverse of that numbering', () {
    test('a number maps to the ambition the prompt gave it', () {
      expect(RealismPromptBuilder.resolveServedAmbition('1', roster()), bakery);
      expect(RealismPromptBuilder.resolveServedAmbition('2', roster()), sister);
    });

    test('it reads the SAME filtered list, so achieved ones shift indices', () {
      const withDone = [
        (text: done, progress: 100),
        (text: bakery, progress: 30),
      ];

      expect(
        RealismPromptBuilder.resolveServedAmbition('1', withDone),
        bakery,
        reason: 'the prompt numbered bakery as 1 because it dropped the '
            'achieved one; resolving against the unfiltered list would return '
            '"learn to drive" and tag the quest with a goal already finished',
      );
    });

    test('"none" and its variants mean no ambition', () {
      for (final raw in const ['none', 'NONE', ' None ', 'none of them']) {
        expect(
          RealismPromptBuilder.resolveServedAmbition(raw, roster()),
          isNull,
          reason: 'a situational quest is legal and must store NULL',
        );
      }
    });

    test('it is forgiving about how a local model phrases the number', () {
      for (final raw in const ['2', 'ambition 2', '2 — reconcile', '"2"']) {
        expect(
          RealismPromptBuilder.resolveServedAmbition(raw, roster()),
          sister,
          reason: 'local-model floor: the answer shape varies and a strict '
              'parse would silently drop every tag',
        );
      }
    });

    test('junk, absence and out-of-range all fall back to no ambition', () {
      expect(RealismPromptBuilder.resolveServedAmbition(null, roster()), isNull);
      expect(RealismPromptBuilder.resolveServedAmbition('', roster()), isNull);
      expect(
        RealismPromptBuilder.resolveServedAmbition('banana', roster()),
        isNull,
      );
      expect(
        RealismPromptBuilder.resolveServedAmbition('7', roster()),
        isNull,
        reason: 'an index past the end must not throw and must not wrap',
      );
      expect(
        RealismPromptBuilder.resolveServedAmbition('0', roster()),
        isNull,
        reason: 'the roster is 1-based; 0 is a model mistake, not item one',
      );
      expect(
        RealismPromptBuilder.resolveServedAmbition('1', const []),
        isNull,
        reason: 'no ambitions means nothing to resolve against',
      );
    });
  });

  group('one-shot and multi-call are told the same thing', () {
    // Strict parity: the one-shot path exists to save tokens, never to change
    // what the engine decides. If only one of the two prompts carried the
    // roster, a user switching modes would get differently-steered quests.
    test('both carry the roster and ask for serves_ambition', () {
      for (final p in [narrative(roster()), oneShot(roster())]) {
        expect(p, contains('1. $bakery (gaining ground)'));
        expect(p, contains('2. $sister (just beginning)'));
        expect(p, contains('serves_ambition'));
        expect(p, contains('PREFER a concrete next step'));
      }
    });

    test('and both omit all of it when there are no ambitions', () {
      for (final p in [narrative(const []), oneShot(const [])]) {
        expect(p, isNot(contains('serves_ambition')));
        expect(p, isNot(contains('Long-term ambitions')));
      }
    });

    test('the steering text itself is byte-identical between them', () {
      // Not merely "both mention it" — the rubric has to be the same rubric.
      const marker = 'PREFER a concrete next step';
      String steer(String p) =>
          p.substring(p.indexOf(marker), p.indexOf(marker) + 260);

      expect(steer(narrative(roster())), steer(oneShot(roster())));
    });
  });

  group('switching Ambitions off stops paying for the steering', () {
    // Structural, not behavioural: the gate lives in a chat_service part file
    // and needs a live ChatService to exercise. Read it as "the two gates
    // still say the same thing", not "the gate works".
    //
    // It is here because the whole feature-independence effort exists to stop
    // switched-off features from billing per turn, and this is a new per-turn
    // cost. The per-turn ambition INJECTION already learned this lesson and
    // carries the gate with a comment explaining it; the eval must not drift
    // from it, or turning Ambitions off would silence the display while the
    // eval kept steering quests toward a goal that can no longer move.
    /// The `getAmbitions:` lambda, whitespace-flattened so the formatter's
    /// line breaks cannot make this pass or fail.
    String evalGate() {
      final src = File(
        'lib/services/chat/chat_service_wiring_evals.dart',
      ).readAsStringSync();
      final start = src.indexOf('getAmbitions: () =>');
      return src
          .substring(start, src.indexOf('setObjective:', start))
          .replaceAll(RegExp(r'\s+'), ' ');
    }

    test('the eval roster is gated exactly as the injection is', () {
      final injection = File(
        'lib/services/chat/chat_service_wiring_injection.dart',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

      expect(
        injection,
        contains('realismSettings.ambitionsEnabled && objectivesActive'),
        reason: 'the injection gate is the precedent this one copies',
      );
      expect(
        evalGate(),
        contains('!_storageService.realismSettings.ambitionsEnabled'),
        reason: 'the Ambitions switch must reach getAmbitions, or an '
            'ambitions-off chat still pays per turn to be steered toward a '
            'goal that can no longer move',
      );
      expect(
        evalGate(),
        contains('!objectivesActive'),
        reason: 'and so must Objectives — completing a quest is the only '
            'thing that advances an ambition',
      );
    });
  });
}
