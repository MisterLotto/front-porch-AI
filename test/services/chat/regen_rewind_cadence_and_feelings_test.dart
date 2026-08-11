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

// Regenerating a group turn must put back EVERYTHING that turn changed.
//
// Every realism value the engine tracks is a scalar, and scalars are snapshotted
// into each message's `realism_state` and rewound when you regenerate. Two are
// not scalars — they ride the per-member _groupRealism map:
//
//   * the hidden inter-character feelings ("how does Aerin feel about Bo")
//   * the short-term bond-decay cadence ('turnsSinceDecayCheck')
//
// Neither was ever captured, so the regen revert could not put them back. The
// hidden feelings are re-scored after EVERY generation from a keyword sweep over
// the freshly written reply, so each press of Regenerate stacked another ±2/±4
// on top of the last press — permanently, one-way, invisible, with no path back.
// Twenty presses and a pair of characters had quietly moved from neutral to
// "warm and friendly toward", which then rides into every generation prompt.
//
// The cadence had the matching hole: every press burned another turn of it, and
// every tenth press spent a −1 bond that was never refunded.
//
// A decoy made this hard to see. ChatService carried `_moodDecayCounter`, which
// WAS captured, WAS persisted to the sessions table and WAS restored on regen —
// and which no decay logic ever read. The counter that actually gates decay is
// the one covered here. The revert only looked like it rewound the cadence.
//
// These tests drive the REAL production pair (captureCadenceAndFeelings /
// restoreFromMessageState) against live in-memory maps, so a field that capture
// writes and restore forgets — or vice versa — reddens CI.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/relationship_service.dart';

/// A RelationshipService wired to live maps, exactly as ChatService wires it:
/// the group scalars, the inter-character feelings map, and the generic
/// per-speaker counter store all round-trip through real storage.
class _Harness {
  _Harness({this.isGroup = true, this.trackInter = true});

  final bool isGroup;
  final bool trackInter;
  final String speaker = 'aerin';

  final aff = <String, int>{};
  final inter = <String, Map<String, int>>{};
  final counters = <String, Map<String, int>>{};

  /// What the last generated reply "said" — the keyword sweep reads this.
  String recentExchange = '';

  late final RelationshipService svc = RelationshipService(
    onNotify: () {},
    onSaveChat: () async {},
    getIsGroupActive: () => isGroup,
    getObserverMode: () => false,
    getGroupCharacterCount: () => 2,
    getShouldTrackInterCharacterRelationships: () => isGroup && trackInter,
    getCurrentSpeakerIdForRealism: () => isGroup ? speaker : '',
    getCurrentGroupMemberIds: () => const {'aerin', 'bo'},
    getOtherGroupMemberIds: (self) =>
        ['aerin', 'bo'].where((id) => id != self).toList(),
    getOtherGroupMemberIdToLowerName: (self) =>
        {for (final id in ['aerin', 'bo']) if (id != self) id: id},
    getRecentExchangeLowerText: () => recentExchange,
    getMessageCount: () => 8,
    getIsGroupRealismActive: () => isGroup,
    getGroupAffectionScore: (id, {int defaultValue = 0}) =>
        aff[id] ?? defaultValue,
    setGroupAffectionScore: (id, v) => aff[id] = v,
    getGroupLongTermScore: (id, {int defaultValue = 0}) => defaultValue,
    setGroupLongTermScore: (_, _) {},
    getGroupTrustLevel: (id, {int defaultValue = 0}) => defaultValue,
    setGroupTrustLevel: (_, _) {},
    getGroupFixation: (id, {String defaultValue = ''}) => defaultValue,
    setGroupFixation: (_, _) {},
    getGroupFixationLifespan: (id, {int defaultValue = 0}) => defaultValue,
    setGroupFixationLifespan: (_, _) {},
    getGroupRelationshipTier: (id, {int defaultValue = 0}) => defaultValue,
    setGroupRelationshipTier: (_, _) {},
    getGroupLongTermTier: (id, {int defaultValue = 0}) => defaultValue,
    setGroupLongTermTier: (_, _) {},
    getGroupSpatialStance: (id, {String defaultValue = ''}) => defaultValue,
    setGroupSpatialStance: (_, _) {},
    getGroupInterCharacterRelationships: (id) => inter[id] ?? const {},
    setGroupInterCharacterRelationships: (id, rels) =>
        inter[id] = Map<String, int>.from(rels),
    getGroupCounter: (id, key, {int defaultValue = 0}) =>
        counters[id]?[key] ?? defaultValue,
    setGroupCounter: (id, key, v) =>
        (counters[id] ??= <String, int>{})[key] = v,
  );

  int get cadence => counters[speaker]?['turnsSinceDecayCheck'] ?? 0;
  Map<String, int> get feelings => inter[speaker] ?? const {};
}

void main() {
  group('a group regen puts back the two registers that are not scalars', () {
    test('the hidden feelings return to what they were before the turn', () {
      final h = _Harness()..inter['aerin'] = {'bo': 0};

      // The turn is stamped. This is the snapshot regen will rewind to.
      final stamped = h.svc.captureCadenceAndFeelings();

      // The reply lands and the post-generation keyword sweep scores it.
      h.recentExchange = 'bo is a wonderful friend and i adore them';
      h.svc.updateInterCharacterFeelingsFromRecentExchange('aerin');
      expect(
        h.feelings['bo'],
        4,
        reason: 'precondition: the sweep must actually have moved something, '
            'otherwise this test proves nothing about putting it back',
      );

      // Regenerate: the revert replays the stamped state for THIS member.
      h.svc.restoreFromMessageState(stamped, groupSpeakerId: 'aerin');

      expect(
        h.feelings['bo'],
        0,
        reason: 'the rejected turn\'s feeling change survived the regen. Press '
            'Regenerate twenty times and these two characters drift from '
            'strangers to friends with nothing the user did causing it',
      );
    });

    test('twenty regens leave no trace, instead of twenty steps of drift', () {
      // The compounding property is the whole point: it is not one wrong value,
      // it is a ratchet. Each press must start from the same baseline.
      final h = _Harness()..inter['aerin'] = {'bo': 0};
      final stamped = h.svc.captureCadenceAndFeelings();

      for (var i = 0; i < 20; i++) {
        h.recentExchange = 'bo said something nice and good';
        h.svc.updateInterCharacterFeelingsFromRecentExchange('aerin');
        h.svc.restoreFromMessageState(stamped, groupSpeakerId: 'aerin');
      }

      expect(
        h.feelings['bo'],
        0,
        reason: 'unrewound, twenty presses at +2 each would sit at +40 — past '
            'the +25 band, so the generation prompt would have started '
            'calling them "warm and friendly toward" each other',
      );
    });

    test(
      'regen overlays rejected-turn feelings AND cadence (P1.10 + twin)',
      () {
        // Mirrors ChatService regen: restore previousMessageState first, then
        // patch both out-of-band keys from lastMsg.realism_state. A test that
        // only asserts "second restore wins" is true by construction — this
        // one requires BOTH keys from the rejected stamp, and fails if either
        // is omitted from the patch (the second-look cadence gap).
        final h = _Harness()..inter['aerin'] = {'bo': 8};
        (h.counters['aerin'] ??= {})['turnsSinceDecayCheck'] = 9;

        // Older same-speaker stamp (previousMessageState) — wrong feelings
        // and a cadence that already advanced past the boundary.
        h.svc.restoreFromMessageState(
          {
            'interCharacterRelationships': {'bo': 0},
            'turnsSinceDecayCheck': 10,
          },
          groupSpeakerId: 'aerin',
        );
        expect(h.feelings['bo'], 0);
        expect(h.cadence, 10);

        // Rejected turn's own pre-gen realism_state (the overlay ChatService
        // now applies for both keys).
        final rejectedPatch = <String, dynamic>{
          'interCharacterRelationships': {'bo': 4},
          'turnsSinceDecayCheck': 7,
        };
        h.svc.restoreFromMessageState(
          rejectedPatch,
          groupSpeakerId: 'aerin',
        );
        expect(
          h.feelings['bo'],
          4,
          reason: 'rejected pre-gen feelings are the regen baseline',
        );
        expect(
          h.cadence,
          7,
          reason: 'cadence twin must come from the same rejected stamp — '
              'else two regens near the decay boundary disagree',
        );

        // Guard would stay green if we only patched feelings: re-assert that
        // leaving cadence out of the patch would leave the stale 10.
        h.svc.restoreFromMessageState(
          {
            'interCharacterRelationships': {'bo': 0},
            'turnsSinceDecayCheck': 10,
          },
          groupSpeakerId: 'aerin',
        );
        h.svc.restoreFromMessageState(
          {
            'interCharacterRelationships': {'bo': 4},
            // deliberately NO turnsSinceDecayCheck — the old P1.10-only patch
          },
          groupSpeakerId: 'aerin',
        );
        expect(
          h.cadence,
          10,
          reason: 'proves the twin is independent: feelings-only patch '
              'does not rewind cadence (so ChatService must pass both)',
        );
      },
    );

    test('the decay cadence is rewound too, so no regen burns a free turn', () {
      final h = _Harness()..aff['aerin'] = 50;
      (h.counters['aerin'] ??= {})['turnsSinceDecayCheck'] = 7;

      final stamped = h.svc.captureCadenceAndFeelings();
      expect(stamped['turnsSinceDecayCheck'], 7);

      h.svc.applyShortTermDecay(); // the turn happens
      expect(h.cadence, 8, reason: 'precondition: the turn advanced it');

      h.svc.restoreFromMessageState(stamped, groupSpeakerId: 'aerin');
      expect(
        h.cadence,
        7,
        reason: 'each regen used to advance the cadence permanently, so every '
            'tenth press silently spent a -1 bond that was never refunded',
      );
    });

    test('rewinding one member does not touch another member', () {
      // The wrong-member hazard: these maps are per-character, and writing the
      // rewind to the wrong key corrupts a character nobody was regenerating.
      final h = _Harness()
        ..inter['aerin'] = {'bo': 0}
        ..inter['bo'] = {'aerin': 30};
      final stamped = h.svc.captureCadenceAndFeelings(); // speaker is aerin

      h.recentExchange = 'bo is awful and rude';
      h.svc.updateInterCharacterFeelingsFromRecentExchange('aerin');
      h.svc.restoreFromMessageState(stamped, groupSpeakerId: 'aerin');

      expect(h.inter['bo']?['aerin'], 30, reason: 'Bo was never regenerated');
    });
  });

  group('the restore refuses rather than guesses', () {
    test('a group restore with no speaker id changes nothing', () {
      // Only the regen revert knows which member is being undone. Every other
      // caller of restoreFromMessageState passes no id — and in a group those
      // must leave these two registers alone rather than write the 1:1 scalar
      // (a silent no-op) or pick a member (silent corruption).
      final h = _Harness()..inter['aerin'] = {'bo': 12};
      (h.counters['aerin'] ??= {})['turnsSinceDecayCheck'] = 3;

      h.svc.restoreFromMessageState({
        'turnsSinceDecayCheck': 99,
        'interCharacterRelationships': {'bo': -99},
      });

      expect(h.feelings['bo'], 12);
      expect(h.cadence, 3);
    });

    test('a message stamped before these keys existed restores nothing', () {
      // Every message already in every user's database predates this snapshot.
      // Reading one must be a no-op, not a crash and not a reset to zero.
      final h = _Harness()..inter['aerin'] = {'bo': 12};
      (h.counters['aerin'] ??= {})['turnsSinceDecayCheck'] = 3;

      h.svc.restoreFromMessageState({
        'affectionScore': 40,
        'trustLevel': 10,
      }, groupSpeakerId: 'aerin');

      expect(h.feelings['bo'], 12);
      expect(h.cadence, 3);
      expect(h.svc.affectionScore, 40, reason: 'the scalars still restore');
    });
  });

  group('1:1 shares the mechanism rather than owning a parallel one', () {
    test('the cadence rewinds through the scalar, with no group map', () {
      final h = _Harness(isGroup: false);
      for (var i = 0; i < 4; i++) {
        h.svc.applyShortTermDecay();
      }

      final stamped = h.svc.captureCadenceAndFeelings();
      expect(stamped['turnsSinceDecayCheck'], 4);

      h.svc.applyShortTermDecay();
      expect(h.svc.captureCadenceAndFeelings()['turnsSinceDecayCheck'], 5);

      h.svc.restoreFromMessageState(stamped);
      expect(
        h.svc.captureCadenceAndFeelings()['turnsSinceDecayCheck'],
        4,
        reason: '1:1 regen never rewound this either — it restored '
            '_moodDecayCounter, which nothing read',
      );
    });

    test('a 1:1 snapshot carries no inter-character key at all', () {
      // 1:1 has no other characters, so the key must be absent rather than an
      // empty map: realism_state is written to every message of every chat.
      final h = _Harness(isGroup: false);
      expect(
        h.svc.captureCadenceAndFeelings().containsKey(
          'interCharacterRelationships',
        ),
        isFalse,
      );
    });

    test('a group larger than the tracking cap carries no key either', () {
      // Inter-character tracking is capped at 4 members; above it the map is
      // never populated, so the snapshot must not invent one.
      final h = _Harness(trackInter: false)..inter['aerin'] = {'bo': 5};
      expect(
        h.svc.captureCadenceAndFeelings().containsKey(
          'interCharacterRelationships',
        ),
        isFalse,
      );
    });
  });
}
