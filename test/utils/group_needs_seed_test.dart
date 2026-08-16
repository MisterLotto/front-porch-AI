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

// A group member's default needs seed must use the engine's key set.
//
// It did not. It wrote 'thirst' and 'rest' — which exist nowhere else in the
// codebase — and omitted 'energy', 'fun' and 'comfort', which are real. So a
// new group member started with two needs the simulation ignores and three
// silently filled from defaults, and the per-member baseline sliders in the
// group creator, which write into this shape, could not reach half the needs.
//
// It shipped because nothing compared the two lists.
//
// The seed stays a literal — utils must not import services/chat, and pulling
// the engine in there to fix a data bug would invert the layer direction. So
// THIS FILE is the enforcement: it compares the seed against the engine key set
// AND values, and reddens CI if either side moves without the other.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/needs_simulation.dart';
import 'package:front_porch_ai/utils/group_realism_blobs.dart';

void main() {
  group('the default group-member needs seed', () {
    Map<String, dynamic> needsOfSeed() {
      final needs = defaultGroupMemberRealismSeed()['needs'];
      expect(
        needs,
        isA<Map>(),
        reason: 'the seed must carry a needs map at all — its mere presence is '
            'what two places use to infer that Needs is enabled for the group',
      );
      return Map<String, dynamic>.from(needs as Map);
    }

    test('uses exactly the engine key set — no extras, none missing', () {
      final seeded = needsOfSeed().keys.toSet();
      final engine = NeedsSimulation.needKeys.toSet();

      expect(
        seeded.difference(engine),
        isEmpty,
        reason: 'keys the engine has never heard of. The seed used to carry '
            '"thirst" and "rest", which are simply ignored',
      );
      expect(
        engine.difference(seeded),
        isEmpty,
        reason: 'real needs missing from the seed. "energy", "fun" and '
            '"comfort" used to be absent, so they fell back to defaults while '
            'the group wizard offered no way to set them',
      );
    });

    test('every value matches the engine default for that need', () {
      final seeded = needsOfSeed();
      for (final key in NeedsSimulation.needKeys) {
        expect(
          seeded[key],
          NeedsSimulation.needDefaults[key],
          reason: 'a seeded group member and one that falls back to defaults '
              'must start in the same place; "$key" disagrees',
        );
      }
    });

    test('values are in the range the simulation accepts', () {
      for (final entry in needsOfSeed().entries) {
        expect(entry.value, isA<int>(), reason: '${entry.key} must be an int');
        expect(
          entry.value as int,
          inInclusiveRange(0, 100),
          reason: '${entry.key} is outside the 0-100 needs scale',
        );
      }
    });

    test('two callers do not share one needs map', () {
      // Mutates the map the seed ACTUALLY returns, not a copy of it. An earlier
      // version of this test copied first and mutated the copy, so it could
      // never fail — the exact kind of test this whole exercise exists to stop
      // shipping.
      final first =
          defaultGroupMemberRealismSeed()['needs'] as Map<String, dynamic>;
      first['hunger'] = 1;

      final second =
          defaultGroupMemberRealismSeed()['needs'] as Map<String, dynamic>;
      expect(
        second['hunger'],
        isNot(1),
        reason: 'the second caller received the first caller\'s mutation — '
            'group members would share one needs vector, so feeding one would '
            'feed them all',
      );
    });
  });
}
