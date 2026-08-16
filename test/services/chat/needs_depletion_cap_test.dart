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

// "SUDDEN LOSS OF LIKE 35-40 POINTS IN A SINGLE TURN" — the needs feedback loop.
//
// Reported by a user, verbatim: "There's issue when the need starts to
// influence the response, then next turn the response further boosts the need
// gravity... which result in sudden loss of like 35-40 points of hunger, energy
// or bladder in single turn and... obvious results. Sometimes several of them
// affected."
//
// THE LOOP. The needs eval is handed the character's OWN REPLY and asked what
// the scene did to her needs. But that reply was written FROM the needs — the
// state block gives the model lines like "Sharp, gnawing hunger cramps;
// light-headed and shaky, thoughts drifting uncontrollably to food". The model
// writes her clutching her stomach; the eval reads that and scores it as
// BECOMING hungrier. Describing a state was counted as changing it, so the
// lower the need went, the more vivid the prose, and the bigger the next hit.
//
// CLAUDE.md already forbids precisely this for the Realism Engine — "the eval
// scores the USER's message, never the character's own reply", because
// otherwise "rerolling a line would reroll their feelings". The rule had never
// been applied to Needs.
//
// THE ARITHMETIC MATCHED THE REPORT EXACTLY:
//     eval delta, clamped at -30      up to -30
//     decay (bladder 6 / hunger 4)         -3..-6
//     cross-boost modifiers (x1.25-1.4)  up to  -8 total
//     ------------------------------------------------
//     worst single turn                       ~ -38
// The -30 was itself the previous patch. It bounded the damage at exactly the
// number being complained about, which is why this kept feeling like whack-a-
// mole: the rule lived at the CALL SITES (twice, byte-identical, and missing
// entirely from a third applier) instead of on the data.
//
// THE FIX, per the maintainer's ruling: DECAY OWNS DEPLETION. One exchange may
// take only a small extra bite, and the bound is applied ONCE, in the evaluator,
// by a single helper both eval paths share — because the whack-a-mole was that
// the rule lived at the call sites (twice byte-identical, missing from a third).
//
// PER-NEED, not one flat number: "I want variability but not wide swings", and
// "drinking a soda would cause bladder to drop… more than on a standard turn."
// So every cap is at least 2x that need's decay rate — a described event always
// visibly beats ambient drift — while nothing comes near the reported 35-40.
// Restoration is deliberately NOT bounded: eating a meal really does fill you in
// one go, and the prompt spends a paragraph fighting models that lowball that.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/needs_simulation.dart';

void main() {
  NeedsSimulation simAt({int strength = 1}) => NeedsSimulation(
    onNotify: () {},
    onSaveChat: () async {},
    getTimeOfDay: () => 'evening',
    getRealismEnabled: () => true,
    getObserverMode: () => false,
    getCurrentSpeakerIdForRealism: () => '',
    getIsGroupNonObserverMode: () => false,
    getGroupNeeds: (_) => const {},
    setGroupNeeds: (_, _) {},
    getEnjoysLowHygiene: () => false,
    getNeedsSimEnabled: () => true,
    getNeedsSimStrength: () => strength,
  );

  group('the reported cliff cannot happen', () {
    test('no need can fall anywhere near the reported 35-40 at 1x', () {
      final s = simAt();
      for (final k in NeedsSimulation.needKeys) {
        expect(
          s.sceneDepletionCapFor(k),
          lessThanOrEqualTo(18),
          reason: 'THE BUG: a single exchange used to be allowed -30, which '
              'with decay and the cross-boost modifiers reached the reported '
              '35-40',
        );
      }
    });

    test('even at 5x nothing reaches the old fixed -30', () {
      final s = simAt(strength: 5);
      for (final k in NeedsSimulation.needKeys) {
        expect(
          s.sceneDepletionCapFor(k),
          lessThan(30),
          reason: 'nobody may end up WORSE off than before this change — a '
              'multiplicative scale would have put hygiene at 45',
        );
      }
    });
  });

  group('variability: a described EVENT beats a standard turn', () {
    test('every need — an event can always outpace ambient drift', () {
      // THE RULE, asserted rather than left in a comment. Maintainer: "I would
      // like needs to be variable still. For example drinking a soda would
      // cause bladder to drop… more than on a standard turn."
      //
      // A first draft set bladder's cap to 6 — exactly its decay rate — which
      // would have made drinking a soda indistinguishable from nothing
      // happening. That is the flatness this guard exists to prevent.
      final s = simAt();
      for (final k in NeedsSimulation.needKeys) {
        expect(
          s.sceneDepletionCapFor(k),
          greaterThanOrEqualTo(NeedsSimulation.needDecay[k]! * 2),
          reason: '$k: a narrated event must be able to cost at least twice '
              'what a turn of doing nothing costs, or the scene does not read '
              'as having happened',
        );
      }
    });

    test('the soda case specifically', () {
      // Bladder decays 6/turn. A described drink has to land clearly harder
      // than that, and 18 is about three turns of normal build.
      final s = simAt();
      expect(s.sceneDepletionCapFor('bladder'), 18);
      expect(
        s.sceneDepletionCapFor('bladder'),
        greaterThan(NeedsSimulation.needDecay['bladder']! * 2),
      );
    });

    test('the caps are not one flat number', () {
      // Every scene nudging everything by the same amount is not variability,
      // it is noise at a fixed amplitude.
      final s = simAt();
      final caps = {
        for (final k in NeedsSimulation.needKeys) s.sceneDepletionCapFor(k),
      };
      expect(caps.length, greaterThan(2));
    });

    test('every need has a deliberate number, none fall through', () {
      for (final k in NeedsSimulation.needKeys) {
        expect(NeedsSimulation.sceneDepletionAt1x.containsKey(k), isTrue,
            reason: '$k would silently take the cautious fallback');
      }
    });
  });

  group('the caps follow the strength slider', () {
    test('every notch does something', () {
      final caps = [
        for (var st = 1; st <= 5; st++) simAt(strength: st).sceneDepletionCapFor('energy'),
      ];
      expect(caps, [12, 14, 16, 18, 20]);
    });

    test('an absent strength callback means 1x, not a crash', () {
      final s = NeedsSimulation(
        onNotify: () {},
        onSaveChat: () async {},
        getTimeOfDay: () => 'evening',
        getRealismEnabled: () => true,
        getObserverMode: () => false,
        getCurrentSpeakerIdForRealism: () => '',
        getIsGroupNonObserverMode: () => false,
        getGroupNeeds: (_) => const {},
        setGroupNeeds: (_, _) {},
        getEnjoysLowHygiene: () => false,
        getNeedsSimEnabled: () => true,
      );
      expect(s.sceneDepletionCapFor('hunger'),
          NeedsSimulation.sceneDepletionAt1x['hunger']);
    });

    test('a nonsense strength is clamped rather than trusted', () {
      // needsSimStrength comes off a character card, which a stranger can
      // author and hand you through The Stoop.
      expect(simAt(strength: 99).sceneDepletionCapFor('hunger'), 20);
      expect(simAt(strength: -5).sceneDepletionCapFor('hunger'), 12);
    });

    test('an unknown need takes the cautious fallback', () {
      expect(simAt().sceneDepletionCapFor('nostalgia'),
          NeedsSimulation.sceneDepletionFallback);
    });
  });

  test('the simulation mutator itself stays unbounded', () {
    // The bound is a policy about what a MODEL may claim, applied in the
    // evaluator. applySceneImpact is a pure mutator: pushing the policy down
    // into it was tried first and bounded the whole vector, breaking two tests
    // that use it merely to ARRANGE a state. Kept honest here.
    final s = simAt();
    s.initializeFreshWithDefaults({
      for (final k in NeedsSimulation.needKeys) k: 60,
    });
    s.applySceneImpact(const NeedsImpact(deltas: {'hunger': -50}));
    expect(s.vector['hunger'], 10);
  });

  test('decay is untouched — it is what depletion is supposed to come from', () {
    final s = simAt();
    s.initializeFreshWithDefaults({
      for (final k in NeedsSimulation.needKeys) k: 60,
    });
    s.tickDecay();
    expect(s.vector['bladder'], 60 - NeedsSimulation.needDecay['bladder']!);
  });
}
