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

// Phase 2 test gate, items 2 and 3 of the Realism engine audit.
//
// ITEM 2 — the clamps. Bond is ±300 and trust is ±100, and those bounds are
// load-bearing: the tier ladder, the progress bars and the group blob all
// assume them. But the only place they were asserted was the card-SEED path.
// On the DELTA path — the one that actually runs every turn — the largest
// value any test used was +120 from a base of 40, so the clamp constants could
// have been changed to anything larger and the suite would have stayed green.
//
// ITEM 3 — the per-speaker round trip, at the leaf. In a group every member's
// relationship state is swapped in and out of one shared set of scalars on
// every turn. If a field is written by save and not read by load (or vice
// versa) one character silently inherits another's feelings. Covers the eight
// fields saveRelationshipScalarsToGroup actually writes — the three scores, the
// two fixation fields, spatial stance and both tiers. The bond-decay counter it
// also writes through setGroupCounter is not covered here. The existing
// realism_parity_test hand-rolls its own load/save pair rather than driving the
// real ones, so it cannot catch a field that the real methods forget.
//
// The ChatService-level dance (_loadGroupRealismIntoScalars /
// _saveScalarsIntoGroupRealism) is private to a part-file library and needs a
// separate widget-level test; this covers the RelationshipService half, which
// is where most of the per-speaker fields live.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/relationship_service.dart';

/// Builds a RelationshipService wired to live in-memory maps, so the group
/// getters and setters genuinely round-trip the way ChatService's do.
RelationshipService _svc({
  bool isGroup = true,
  Map<String, int>? affection,
  Map<String, int>? longTerm,
  Map<String, int>? trust,
  Map<String, String>? fixation,
  Map<String, int>? fixLifespan,
  Map<String, int>? relTier,
  Map<String, int>? longTier,
  Map<String, String>? spatial,
}) {
  final gAff = affection ?? <String, int>{};
  final gLT = longTerm ?? <String, int>{};
  final gTrust = trust ?? <String, int>{};
  final gFix = fixation ?? <String, String>{};
  final gFixLife = fixLifespan ?? <String, int>{};
  final gRTier = relTier ?? <String, int>{};
  final gLTTier = longTier ?? <String, int>{};
  final gSpat = spatial ?? <String, String>{};
  final gInter = <String, Map<String, int>>{};

  return RelationshipService(
    onNotify: () {},
    onSaveChat: () async {},
    getIsGroupActive: () => isGroup,
    getObserverMode: () => false,
    getGroupCharacterCount: () => 2,
    getShouldTrackInterCharacterRelationships: () => false,
    getCurrentSpeakerIdForRealism: () => '',
    getCurrentGroupMemberIds: () => const {},
    getOtherGroupMemberIds: (_) => const [],
    getOtherGroupMemberIdToLowerName: (_) => const {},
    getRecentExchangeLowerText: () => '',
    getMessageCount: () => 0,
    getIsGroupRealismActive: () => isGroup,
    getGroupAffectionScore: (id, {int defaultValue = 0}) =>
        gAff[id] ?? defaultValue,
    setGroupAffectionScore: (id, v) => gAff[id] = v,
    getGroupLongTermScore: (id, {int defaultValue = 0}) =>
        gLT[id] ?? defaultValue,
    setGroupLongTermScore: (id, v) => gLT[id] = v,
    getGroupTrustLevel: (id, {int defaultValue = 0}) =>
        gTrust[id] ?? defaultValue,
    setGroupTrustLevel: (id, v) => gTrust[id] = v,
    getGroupFixation: (id, {String defaultValue = ''}) =>
        gFix[id] ?? defaultValue,
    setGroupFixation: (id, v) => gFix[id] = v,
    getGroupFixationLifespan: (id, {int defaultValue = 0}) =>
        gFixLife[id] ?? defaultValue,
    setGroupFixationLifespan: (id, v) => gFixLife[id] = v,
    getGroupRelationshipTier: (id, {int defaultValue = 0}) =>
        gRTier[id] ?? defaultValue,
    setGroupRelationshipTier: (id, v) => gRTier[id] = v,
    getGroupLongTermTier: (id, {int defaultValue = 0}) =>
        gLTTier[id] ?? defaultValue,
    setGroupLongTermTier: (id, v) => gLTTier[id] = v,
    getGroupSpatialStance: (id, {String defaultValue = ''}) =>
        gSpat[id] ?? defaultValue,
    setGroupSpatialStance: (id, v) => gSpat[id] = v,
    getGroupInterCharacterRelationships: (id) => gInter[id] ?? const {},
    setGroupInterCharacterRelationships: (id, rels) =>
        gInter[id] = Map<String, int>.from(rels),
  );
}

void main() {
  group('clamp boundaries on the DELTA path (not just the seed path)', () {
    test('bond cannot be pushed past +300 or below -300', () {
      final up = _svc()..seedFromCardV2OrExt(
        shortTermBond: 0,
        longTermBond: 0,
        trustLevel: 0,
      );
      up.applyScoreDelta(9999);
      expect(up.affectionScore, 300, reason: 'bond ceiling is +300');

      final down = _svc()..seedFromCardV2OrExt(
        shortTermBond: 0,
        longTermBond: 0,
        trustLevel: 0,
      );
      down.applyScoreDelta(-9999);
      expect(down.affectionScore, -300, reason: 'bond floor is -300');
    });

    test('bond clamps from an already-high base, not just from zero', () {
      // The pre-existing coverage only ever added +120 to a base of 40, which
      // never reaches the bound. Starting near the ceiling is what actually
      // exercises it.
      final svc = _svc()..seedFromCardV2OrExt(
        shortTermBond: 295,
        longTermBond: 0,
        trustLevel: 0,
      );
      svc.applyScoreDelta(50);
      expect(svc.affectionScore, 300);
    });

    test('trust cannot be pushed past +100 or below -100', () {
      final up = _svc()..seedFromCardV2OrExt(
        shortTermBond: 0,
        longTermBond: 0,
        trustLevel: 0,
      );
      up.applyTrustDelta(9999);
      expect(up.trustLevel, 100, reason: 'trust ceiling is +100');

      final down = _svc()..seedFromCardV2OrExt(
        shortTermBond: 0,
        longTermBond: 0,
        trustLevel: 0,
      );
      down.applyTrustDelta(-9999);
      expect(down.trustLevel, -100, reason: 'trust floor is -100');
    });

    test('trust and bond do NOT share a scale', () {
      // Guards against a refactor that "unifies" the two clamps. A +200 trust
      // delta must stop at 100 even though the same delta on bond would not.
      final svc = _svc()..seedFromCardV2OrExt(
        shortTermBond: 0,
        longTermBond: 0,
        trustLevel: 0,
      );
      svc.applyScoreDelta(200);
      svc.applyTrustDelta(200);
      expect(svc.affectionScore, 200, reason: 'bond has room at 200');
      expect(svc.trustLevel, 100, reason: 'trust does not');
    });

    // Long-term bond has no public per-turn delta mutator (it grows inside the
    // relationship pass), so its bound is only reachable through the seed path.
    test('the seed path clamps to the same bounds', () {
      final svc = _svc()..seedFromCardV2OrExt(
        shortTermBond: 9999,
        longTermBond: -9999,
        trustLevel: 9999,
      );
      expect(svc.affectionScore, 300);
      expect(svc.longTermScore, -300);
      expect(svc.trustLevel, 100);
    });
  });

  group('per-speaker save/load round trip', () {
    test('every field written by save comes back through load', () {
      final svc = _svc();
      svc.loadScalars(
        affectionScore: 123,
        longTermScore: 45,
        trustLevel: -67,
        activeFixation: 'her laugh',
        fixationLifespan: 5,
        spatialStance: 'close',
      );

      svc.saveRelationshipScalarsToGroup('alice');

      // Wipe the working registers the way switching speakers does, and prove
      // the wipe is total before reloading. Without this, a load that simply
      // FAILS to overwrite an omitted field would look like a successful
      // round trip — the value would still be sitting there from before.
      svc.loadScalars(affectionScore: 0, longTermScore: 0, trustLevel: 0);
      expect(svc.affectionScore, 0);
      expect(svc.longTermScore, 0);
      expect(svc.trustLevel, 0);
      expect(svc.activeFixation, isEmpty);
      expect(svc.fixationLifespan, 0);
      expect(svc.spatialStance, isEmpty,
          reason: 'the omitted-field defaults must clear, or the round trip '
              'below proves nothing');

      svc.loadRelationshipScalarsForSpeaker('alice');

      expect(svc.affectionScore, 123);
      expect(svc.longTermScore, 45);
      expect(svc.trustLevel, -67);
      expect(svc.activeFixation, 'her laugh');
      expect(svc.fixationLifespan, 5);
      expect(svc.spatialStance, 'close');
      // The real save writes tiers too — 8 fields, not 6. Derived from the
      // scores, so a load that restored scores but not tiers would show the
      // right number under the wrong word.
      expect(svc.relationshipTier, RelationshipService.bondTierFor(123));
      expect(svc.longTermTier, RelationshipService.bondTierFor(45));
    });

    test('two members keep separate state — no bleed between speakers', () {
      final svc = _svc();

      // Every field differs between the two, so a single shared slot fails on
      // whichever one it clobbers — not just on bond.
      svc.loadScalars(
        affectionScore: 200,
        longTermScore: 150,
        trustLevel: 80,
        activeFixation: 'alice-thing',
        fixationLifespan: 7,
        spatialStance: 'close',
      );
      svc.saveRelationshipScalarsToGroup('alice');

      svc.loadScalars(
        affectionScore: -50,
        longTermScore: -20,
        trustLevel: -10,
        activeFixation: 'bob-thing',
        fixationLifespan: 2,
        spatialStance: 'distant',
      );
      svc.saveRelationshipScalarsToGroup('bob');

      Map<String, Object?> snapshot() => {
        'affection': svc.affectionScore,
        'longTerm': svc.longTermScore,
        'trust': svc.trustLevel,
        'fixation': svc.activeFixation,
        'lifespan': svc.fixationLifespan,
        'stance': svc.spatialStance,
      };

      const alice = {
        'affection': 200,
        'longTerm': 150,
        'trust': 80,
        'fixation': 'alice-thing',
        'lifespan': 7,
        'stance': 'close',
      };
      const bob = {
        'affection': -50,
        'longTerm': -20,
        'trust': -10,
        'fixation': 'bob-thing',
        'lifespan': 2,
        'stance': 'distant',
      };

      svc.loadRelationshipScalarsForSpeaker('alice');
      expect(snapshot(), alice);

      svc.loadRelationshipScalarsForSpeaker('bob');
      expect(snapshot(), bob);

      // And back again — loading bob must not have disturbed alice's slot.
      svc.loadRelationshipScalarsForSpeaker('alice');
      expect(snapshot(), alice,
          reason: 'alice must be untouched by bob having spoken');
    });

    test('a CLEARED fixation propagates — not just a set one', () {
      // Clears used to be skipped by a non-empty guard, so a fixation could
      // never be dropped once set. The save path is deliberately unconditional.
      final svc = _svc();
      svc.loadScalars(
        affectionScore: 10,
        longTermScore: 10,
        trustLevel: 10,
        activeFixation: 'something',
        spatialStance: 'close',
      );
      svc.saveRelationshipScalarsToGroup('alice');

      svc.loadScalars(
        affectionScore: 10,
        longTermScore: 10,
        trustLevel: 10,
      );
      svc.saveRelationshipScalarsToGroup('alice');

      svc.loadRelationshipScalarsForSpeaker('alice');
      expect(svc.activeFixation, isEmpty, reason: 'the clear must persist');
      expect(svc.spatialStance, isEmpty);
    });

    test('a member with no stored long-term falls back to their bond', () {
      // Matches how the engine seeds a member that predates the longTermScore
      // key, and is the same fallback getLongTermForGroupCharacter uses.
      final svc = _svc(affection: {'newbie': 88});
      svc.loadRelationshipScalarsForSpeaker('newbie');
      expect(svc.affectionScore, 88);
      expect(svc.longTermScore, 88);
    });
  });
}
