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

// "She has a candy bar in her pocket and she is starving — does she eat it?"
//
// Both facts already reached the model. The needs fragment said her thoughts
// keep returning to when the next meal might come; four lines later the
// inventory fragment said she is carrying a candy bar. Nothing joined them, so
// whether she ate it was entirely down to how good the model was: a frontier
// model usually noticed, a smaller local one narrated the hunger and walked
// past the food in her own pocket, or set off to cook something.
//
// One sentence in the composer joins them. It is the ONLY place Pockets and
// Needs meet, and it meets them where they were already sitting side by side —
// so neither engine reads the other's state, no needs code learns the word
// "inventory", and no LLM call is added.
//
// The gate is the interesting part and is what these tests are mostly about:
// the line must be absent whenever it would have nothing to point at, because
// an instruction to "use what you have" is noise when she has nothing, and a
// lie when nothing is wrong with her.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/prompt_injection.dart';

/// The sentence under test, as the composer emits it.
const _join = 'they would reach for it before looking elsewhere';

void main() {
  final alice = CharacterCard(name: 'Alice');

  /// Builds the real composer with only the two fragments that matter alive.
  /// Everything else contributes '' — the weather/ambition/preferences
  /// precedent already used by the composer tests next door.
  RealismStateInjection composer({
    required bool needsOn,
    required bool realismOn,
    Map<String, int>? needsVector,
    Pockets? pockets,
  }) {
    final sim = NeedsSimulation(
      onNotify: () {},
      onSaveChat: () async {},
      getTimeOfDay: () => 'morning',
      getRealismEnabled: () => realismOn,
      getObserverMode: () => true,
      getCurrentSpeakerIdForRealism: () => '',
      getIsGroupNonObserverMode: () => false,
      getGroupNeeds: (_) => const {},
      setGroupNeeds: (_, _) {},
      getEnjoysLowHygiene: () => false,
      getNeedsSimEnabled: () => needsOn,
    );
    if (needsVector != null) {
      sim.restoreFromSnapshot({'vector': needsVector});
    }

    return RealismStateInjection(
      relationshipInjection: RelationshipInjection(
        relationshipService: RelationshipService(
        onNotify: () {},
        onSaveChat: () async {},
        getIsGroupActive: () => false,
        getObserverMode: () => true,
        getGroupCharacterCount: () => 0,
        getShouldTrackInterCharacterRelationships: () => false,
        getCurrentSpeakerIdForRealism: () => '',
        getCurrentGroupMemberIds: () => const {},
        getOtherGroupMemberIds: (_) => const [],
        getOtherGroupMemberIdToLowerName: (_) => const {},
        getRecentExchangeLowerText: () => '',
        getMessageCount: () => 0,
        getIsGroupRealismActive: () => false,
        getGroupAffectionScore: (id, {defaultValue = 0}) => defaultValue,
        getGroupRelationshipTier: (id, {defaultValue = 0}) => defaultValue,
        setGroupRelationshipTier: (id, v) {},
        getGroupLongTermTier: (id, {defaultValue = 0}) => defaultValue,
        setGroupLongTermTier: (id, v) {},
        getGroupSpatialStance: (id, {defaultValue = ''}) => defaultValue,
        setGroupSpatialStance: (id, v) {},
        getGroupInterCharacterRelationships: (id) => const {},
        setGroupInterCharacterRelationships: (id, m) {},
        setGroupAffectionScore: (id, v) {},
        getGroupLongTermScore: (id, {defaultValue = 0}) => defaultValue,
        setGroupLongTermScore: (id, v) {},
        getGroupTrustLevel: (id, {defaultValue = 0}) => defaultValue,
        setGroupTrustLevel: (id, v) {},
        getGroupFixation: (id, {defaultValue = ''}) => defaultValue,
        setGroupFixation: (id, v) {},
        getGroupFixationLifespan: (id, {defaultValue = 0}) => defaultValue,
        setGroupFixationLifespan: (id, v) {},
      ),
        getRealismEnabled: () => false,
        getIsGroupNonObserverMode: () => false,
        getCurrentSpeakerIdForRealism: () => '',
        getGroupCharacters: () => const [],
        getActiveCharacter: () => alice,
        getShouldTrackInterCharacterRelationships: () => false,
        getGroupInt: (id, key, {defaultValue = 0}) => defaultValue,
        getCharacterIdFromCard: (c) => c.name,
        getInterCharacterRelationships: (_) => const {},
      ),
      emotionInjection: EmotionInjection(
        getRealismEnabled: () => false,
        getCharacterEmotion: () => '',
        getEmotionIntensity: () => '',
      ),
      timeInjection: TimeInjection(
        timeService: TimeService(
          onNotify: () {},
          onSaveChat: () async {},
          onSetPendingRealismMetadata: (_, _) {},
          onPatchLastMessageRealismState: (_, _, _) {},
        ),
      ),
      weatherInjection: WeatherInjection(
        getWeather: () => null,
        getPreviousSegment: () => null,
        getUpcoming: () => null,
      ),
      ambitionInjection: AmbitionInjection(
        ambitionService: AmbitionService(
          journalStore: JournalStore(getDb: () => null),
          growthStore: GrowthStore(getDb: () => null),
          fireEval: (_) async => null,
          getMaxCards: () => 30,
        ),
        getSessionId: () => null,
        getActiveCharacter: () => alice,
        getIsGroupNonObserverMode: () => false,
        getCurrentSpeakerIdForRealism: () => '',
        getGroupCharacters: () => const [],
        getCharacterIdFromCard: (c) => c.name,
      ),
      preferencesInjection: PreferencesInjection(
        getActiveCharacter: () => alice,
        getIsGroupNonObserverMode: () => false,
        getCurrentSpeakerIdForRealism: () => '',
        getGroupCharacters: () => const [],
        getCharacterIdFromCard: (c) => c.name,
        getNsfwEnabled: () => false,
      ),
      inventoryInjection: InventoryInjection(
        getActiveCharacter: () => alice,
        getIsGroupNonObserverMode: () => false,
        getCurrentSpeakerIdForRealism: () => '',
        getGroupCharacters: () => const [],
        getCharacterIdFromCard: (c) => c.name,
        getPockets: (_) => pockets,
      ),
      promiseDebtInjection: PromiseDebtInjection(
        promiseDebtService: PromiseDebtService(
          journalStore: JournalStore(getDb: () => null),
          fireEval: (_) async => null,
          getMaxCards: () => 30,
          applyTrustDelta: (_) {},
          applyBondDelta: (_) {},
        ),
        getSessionId: () => null,
        getActiveCharacter: () => alice,
        getIsGroupNonObserverMode: () => false,
        getCurrentSpeakerIdForRealism: () => '',
        getGroupCharacters: () => const [],
        getCharacterIdFromCard: (c) => c.name,
        getUserName: () => 'You',
      ),
      behavioralInjection: BehavioralInjection(
        relationshipService: RelationshipService(
        onNotify: () {},
        onSaveChat: () async {},
        getIsGroupActive: () => false,
        getObserverMode: () => true,
        getGroupCharacterCount: () => 0,
        getShouldTrackInterCharacterRelationships: () => false,
        getCurrentSpeakerIdForRealism: () => '',
        getCurrentGroupMemberIds: () => const {},
        getOtherGroupMemberIds: (_) => const [],
        getOtherGroupMemberIdToLowerName: (_) => const {},
        getRecentExchangeLowerText: () => '',
        getMessageCount: () => 0,
        getIsGroupRealismActive: () => false,
        getGroupAffectionScore: (id, {defaultValue = 0}) => defaultValue,
        getGroupRelationshipTier: (id, {defaultValue = 0}) => defaultValue,
        setGroupRelationshipTier: (id, v) {},
        getGroupLongTermTier: (id, {defaultValue = 0}) => defaultValue,
        setGroupLongTermTier: (id, v) {},
        getGroupSpatialStance: (id, {defaultValue = ''}) => defaultValue,
        setGroupSpatialStance: (id, v) {},
        getGroupInterCharacterRelationships: (id) => const {},
        setGroupInterCharacterRelationships: (id, m) {},
        setGroupAffectionScore: (id, v) {},
        getGroupLongTermScore: (id, {defaultValue = 0}) => defaultValue,
        setGroupLongTermScore: (id, v) {},
        getGroupTrustLevel: (id, {defaultValue = 0}) => defaultValue,
        setGroupTrustLevel: (id, v) {},
        getGroupFixation: (id, {defaultValue = ''}) => defaultValue,
        setGroupFixation: (id, v) {},
        getGroupFixationLifespan: (id, {defaultValue = 0}) => defaultValue,
        setGroupFixationLifespan: (id, v) {},
      ),
        getRealismEnabled: () => false,
      ),
      nsfwInjection: NsfwInjection(
        nsfwService: NsfwService(
          getGroupInt: (id, key, {defaultValue = 0}) => defaultValue,
          getGroupValue: (id, key) => null,
          setGroupValue: (id, key, v) {},
        ),
        getRealismEnabled: () => false,
        getActiveCharacter: () => alice,
        getIsGroupNonObserverMode: () => false,
        getCurrentSpeakerIdForRealism: () => '',
        getGroupCharacters: () => const [],
        getCharacterIdFromCard: (c) => c.name,
      ),
      needsInjection: NeedsInjection(
        needsSimulation: sim,
        getNeedsSimEnabled: () => needsOn,
        getRealismEnabled: () => realismOn,
        getIsGroupNonObserverMode: () => false,
        getCurrentSpeakerIdForRealism: () => '',
        getGroupCharacters: () => const [],
        getEnjoysLowHygiene: () => false,
        getGroupNeeds: (_) => const {},
        getCharacterIdFromCard: (c) => c.name,
      ),
      getRealismEnabled: () => realismOn,
      getClockRunningOverride: () => false,
      getIsGroupNonObserverMode: () => false,
      getCurrentSpeakerIdForRealism: () => '',
      getGroupCharacters: () => const [],
      getActiveCharacter: () => alice,
      getCharacterIdFromCard: (c) => c.name,
    );
  }

  /// Starving — well below the step-4 threshold the needs fragment prints at.
  const starving = {'hunger': 5};
  Pockets candyBar() => Pockets(carrying: [const PocketItem('candy bar')]);

  group('the case that prompted this', () {
    test('starving AND carrying food: she is told to reach for it', () {
      final block = composer(
        needsOn: true,
        realismOn: true,
        needsVector: starving,
        pockets: candyBar(),
      ).buildRealismStateInjection();

      expect(block, contains('Hunger:'), reason: 'the need must be biting');
      expect(block, contains('candy bar'), reason: 'and she must have it');
      expect(block, contains(_join));
    });

    test('she knows what she has BEFORE she is told she is hungry', () {
      // The ordering question, and it is not cosmetic. What she is carrying is
      // standing knowledge; a need is something that arrives. Nobody discovers
      // the contents of their own pocket at the moment they get hungry.
      //
      // Told the other way round — which is how this shipped first — the model
      // met a vivid, directive hunger line and only learned about the candy bar
      // three fragments later, past ambitions and preferences, by which point a
      // small local model had usually already sent her to the kitchen. A
      // frontier model connects them either way; the weak ones are exactly who
      // this pairing exists for.
      final block = composer(
        needsOn: true,
        realismOn: true,
        needsVector: starving,
        pockets: candyBar(),
      ).buildRealismStateInjection();

      expect(
        block.indexOf('candy bar'),
        lessThan(block.indexOf('Hunger:')),
        reason: 'possessions are standing fact and must precede the state they '
            'might answer',
      );
    });

    test('the line comes AFTER what she has, so "that" has an antecedent', () {
      final block = composer(
        needsOn: true,
        realismOn: true,
        needsVector: starving,
        pockets: candyBar(),
      ).buildRealismStateInjection();

      expect(
        block.indexOf('candy bar'),
        lessThan(block.indexOf(_join)),
        reason: 'an instruction that refers back to a list has to follow it',
      );
    });

    test('it does not silence the hunger, only the overlooking', () {
      // The failure mode worth guarding: a join line that reads as "solve it"
      // could have the model skip straight to eating and never show the state.
      final block = composer(
        needsOn: true,
        realismOn: true,
        needsVector: starving,
        pockets: candyBar(),
      ).buildRealismStateInjection();

      // The hunger line must still be there, in full prose, next to the join.
      final hunger = block
          .split('\n')
          .firstWhere((l) => l.startsWith('Hunger:'), orElse: () => '');
      expect(
        hunger.length,
        greaterThan(40),
        reason: 'she still SHOWS the hunger — the join adds an option, it does '
            'not replace the state with an instruction to fix it',
      );
      expect(
        block.indexOf(hunger),
        lessThan(block.indexOf(_join)),
      );
      expect(
        block,
        contains('never quote meters'),
        reason: 'the words-only contract still governs the whole block',
      );
    });
  });

  group('absent whenever it would have nothing to point at', () {
    test('nothing in her pockets — no line', () {
      final block = composer(
        needsOn: true,
        realismOn: true,
        needsVector: starving,
        pockets: null,
      ).buildRealismStateInjection();

      expect(block, contains('Hunger:'));
      expect(
        block,
        isNot(contains(_join)),
        reason: '"use what you have" is noise when she has nothing',
      );
    });

    test('an empty record counts as nothing', () {
      final block = composer(
        needsOn: true,
        realismOn: true,
        needsVector: starving,
        pockets: Pockets(),
      ).buildRealismStateInjection();

      expect(block, isNot(contains(_join)));
    });

    test('Pockets switched off — no line, even while starving', () {
      // pocketsFor returns null with the switch down, which is exactly what
      // this models. The join must follow the feature, not outlive it.
      final block = composer(
        needsOn: true,
        realismOn: true,
        needsVector: starving,
        pockets: null,
      ).buildRealismStateInjection();

      expect(block, isNot(contains(_join)));
    });

    test('needs off — no line, even with a full pocket', () {
      final block = composer(
        needsOn: false,
        realismOn: true,
        needsVector: starving,
        pockets: candyBar(),
      ).buildRealismStateInjection();

      expect(block, contains('candy bar'), reason: 'Pockets stands alone');
      expect(
        block,
        isNot(contains(_join)),
        reason: 'with no needs tracked there is nothing for an item to ease',
      );
    });

    test('realism off takes needs with it, so no line', () {
      final block = composer(
        needsOn: true,
        realismOn: false,
        needsVector: starving,
        pockets: candyBar(),
      ).buildRealismStateInjection();

      expect(block, contains('candy bar'));
      expect(block, isNot(contains(_join)));
    });

    test('needs on but nothing biting — no line', () {
      // Sated needs are silent, so the needs fragment is empty and there is
      // nothing an item could help with.
      final block = composer(
        needsOn: true,
        realismOn: true,
        needsVector: const {'hunger': 95},
        pockets: candyBar(),
      ).buildRealismStateInjection();

      expect(block, isNot(contains('Hunger:')));
      expect(block, isNot(contains(_join)));
    });
  });

  group('it names no need and no item, on purpose', () {
    test('the sentence carries no food vocabulary', () {
      final block = composer(
        needsOn: true,
        realismOn: true,
        needsVector: starving,
        pockets: candyBar(),
      ).buildRealismStateInjection();

      final line = block
          .split('\n')
          .firstWhere((l) => l.contains(_join));

      for (final word in ['food', 'eat', 'hunger', 'candy', 'meal']) {
        expect(
          line.toLowerCase(),
          isNot(contains(word)),
          reason: 'a pantry vocabulary here would only ever serve hunger; the '
              'same instinct covers a coat in the cold and a bottle when '
              'thirsty, so the model judges relevance',
        );
      }
    });

    test('it fires for a need that has nothing to do with food', () {
      final block = composer(
        needsOn: true,
        realismOn: true,
        needsVector: const {'comfort': 5},
        pockets: Pockets(worn: [const PocketItem('heavy coat')]),
      ).buildRealismStateInjection();

      expect(block, contains(_join));
    });
  });
}
