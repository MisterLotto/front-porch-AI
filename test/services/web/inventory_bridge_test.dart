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

// `FrontPorchExtensions.inventory` across the web bridge.
//
// THE BUG. `inventory` was missing from `frontPorchFromFields`' constructor
// call entirely, so it silently took its `const {}` default on every save that
// went through the web facade. The update path passes the existing extensions
// as `base:` precisely so a partial edit cannot wipe unrelated state — every
// other field honours that; this one ignored it.
//
// The visible result: open a character on your phone, change the description,
// save, and whatever starting Pockets & Wardrobe its author had written was
// gone. Nothing on screen mentioned inventory, so there was no reason to
// suspect the edit had touched it, and no way to get it back short of
// re-downloading the card.
//
// This is the same class of bug the ambitions list had (see
// test/models/preferences_round_trip_test.dart, "an older web client that omits
// the keys keeps the base values"), which is why the cases below mirror it.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/web/util/util.dart';

void main() {
  /// A card whose author set up starting pockets, plus one unrelated field so
  /// the tests can tell "nothing was carried" from "only inventory was lost".
  FrontPorchExtensions seeded() => FrontPorchExtensions(
    ambitions: ['open her own bakery'],
    inventory: {
      'worn': [
        {'name': 'flour-dusted apron', 'state': 'well-worn'},
      ],
      'carrying': ['shop keys', 'a notebook'],
    },
  );

  group('a web save must not empty her pockets', () {
    test('a payload that never mentions inventory keeps the base', () {
      // The exact shape of the bug: the React editor has no inventory control,
      // so this — a save with the key entirely absent — is EVERY web edit
      // today, not an edge case.
      final back = frontPorchFromFields(const {
        'description': 'edited from a phone',
      }, base: seeded());

      expect(
        back.inventory,
        isNotEmpty,
        reason: 'the base had starting pockets and the payload said nothing '
            'about them, so there was nothing to clear them with',
      );
      expect((back.inventory['carrying'] as List), contains('shop keys'));
      expect(
        back.ambitions,
        ['open her own bakery'],
        reason: 'the neighbouring list must survive too — if this also broke, '
            'the failure is the base itself, not inventory',
      );
    });

    test('an empty payload keeps it', () {
      expect(frontPorchFromFields(const {}, base: seeded()).inventory, {
        'worn': [
          {'name': 'flour-dusted apron', 'state': 'well-worn'},
        ],
        'carrying': ['shop keys', 'a notebook'],
      });
    });

    test('with no base at all it is simply empty, never null', () {
      expect(frontPorchFromFields(const {}).inventory, isEmpty);
    });
  });

  group('it survives the full round trip', () {
    test('extensions -> json -> extensions keeps items and their condition', () {
      final back = frontPorchFromFields(frontPorchToJson(seeded()));

      final worn = (back.inventory['worn'] as List).single as Map;
      expect(worn['name'], 'flour-dusted apron');
      expect(
        worn['state'],
        'well-worn',
        reason: 'the condition is half of what Pockets tracks — an apron that '
            'comes back from a save freshly laundered is a silent rewrite of '
            "the author's card",
      );
      expect((back.inventory['carrying'] as List), hasLength(2));
    });

    test('toJson actually emits the key', () {
      // Without this the round-trip above could pass purely on the base
      // fallback, proving nothing about the outbound half.
      expect(frontPorchToJson(seeded()).containsKey('inventory'), isTrue);
    });

    test('a client that sends a real inventory overwrites the base', () {
      final back = frontPorchFromFields({
        'inventory': {
          'carrying': ['a bus ticket'],
        },
      }, base: seeded());

      expect((back.inventory['carrying'] as List), ['a bus ticket']);
      expect(
        back.inventory.containsKey('worn'),
        isFalse,
        reason: 'a sent record replaces wholesale rather than merging — the '
            'same as every other field on this bridge, and what an authoring '
            'UI that can REMOVE an item requires',
      );
    });
  });

  group('a malformed payload falls back instead of throwing', () {
    test('junk in the inventory slot keeps the base', () {
      for (final junk in <Object>['apron', 7, <String>[]]) {
        final back = frontPorchFromFields({'inventory': junk}, base: seeded());
        expect(
          back.inventory,
          isNotEmpty,
          reason: 'junk: $junk — a hand-edited or older client must not be '
              "able to clear an author's work by sending nonsense",
        );
      }
    });

    test('an explicit empty map does clear it', () {
      // Distinct from junk on purpose: {} is a well-formed record that says
      // "she starts with nothing", and an authoring UI needs to be able to say
      // that. Only unparseable values fall back.
      expect(
        frontPorchFromFields(const {'inventory': {}}, base: seeded()).inventory,
        isEmpty,
      );
    });

    test('entries of the wrong shape survive as-is for Pockets to sort out', () {
      // The cast is deliberately shallow, matching CharacterCard.fromJson.
      // Pockets.fromJson is the one consumer and already tolerates both entry
      // shapes; a second, stricter validator here would mean two readers of one
      // field disagreeing about what is valid.
      final back = frontPorchFromFields(const {
        'inventory': {
          'carrying': [
            42,
            {'name': 'keys'},
          ],
        },
      });
      expect(() => back.inventory, returnsNormally);
      expect((back.inventory['carrying'] as List), hasLength(2));
    });
  });
}
