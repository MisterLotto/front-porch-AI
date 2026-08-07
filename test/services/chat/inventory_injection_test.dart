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

// The half of Pockets that makes the record worth keeping.
//
// An inventory nobody reads is a database. Injected, it is the difference
// between a character still holding the keys she picked up forty messages ago
// and one who is mysteriously empty-handed the moment the prose scrolled out of
// context — which is the entire problem the feature exists to solve.
//
// Two things are pinned here beyond "it renders". First, OFF MEANS OFF: with
// the switch down the caller hands back no record and the fragment must be
// absent, not stale — a frozen inventory line every turn would be worse than
// none, the same reasoning that governs the story-clock fragment. Second,
// GROUP PARITY: the fragment describes the SPEAKER. Getting that wrong is
// quiet and wrong rather than loud — one member narrated with another's
// possessions.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/pockets.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/inventory_injection.dart';

InventoryInjection make({
  CharacterCard? active,
  List<CharacterCard> group = const [],
  String speakerId = '',
  Map<String, Pockets> records = const {},
}) => InventoryInjection(
  getActiveCharacter: () => active,
  getIsGroupNonObserverMode: () => group.isNotEmpty,
  getCurrentSpeakerIdForRealism: () => speakerId,
  getGroupCharacters: () => group,
  getCharacterIdFromCard: (c) => c.name,
  getPockets: (id) => records[id],
);

void main() {
  final alice = CharacterCard(name: 'Alice');

  test('it names what she is wearing and carrying', () {
    final txt = make(
      active: alice,
      records: {
        'Alice': Pockets(
          worn: [const PocketItem('sundress')],
          carrying: [const PocketItem('car keys')],
        ),
      },
    ).buildInventoryInjection();

    expect(txt, contains('Alice is wearing sundress'));
    expect(txt, contains('carrying car keys'));
  });

  test('a condition rides along with its item', () {
    final txt = make(
      active: alice,
      records: {
        'Alice': Pockets(
          carrying: [const PocketItem('iron sword', state: 'notched')],
        ),
      },
    ).buildInventoryInjection();
    expect(txt, contains('iron sword (notched)'));
  });

  test('one empty list omits its clause rather than saying "nothing"', () {
    final worn = make(
      active: alice,
      records: {
        'Alice': Pockets(worn: [const PocketItem('coat')]),
      },
    ).buildInventoryInjection();
    expect(worn, contains('wearing coat'));
    expect(worn, isNot(contains('carrying')));
  });

  test('it states the fact instead of instructing the model', () {
    // "Keep this consistent" invites a model to narrate an inventory check.
    // Naming what she has lets it simply be true, which is the point.
    final txt = make(
      active: alice,
      records: {
        'Alice': Pockets(carrying: [const PocketItem('car keys')]),
      },
    ).buildInventoryInjection();
    expect(txt, isNot(contains('consistent')));
    expect(txt, isNot(contains('remember')));
    expect(txt, endsWith('.'));
  });

  group('off means off', () {
    test('no record at all means no fragment', () {
      // This is the shape the switch produces: the caller returns null when
      // Pockets is off, so the line is ABSENT rather than frozen at whatever
      // it last said.
      expect(make(active: alice).buildInventoryInjection(), isEmpty);
    });

    test('an empty record is silent too', () {
      final txt = make(
        active: alice,
        records: {'Alice': Pockets()},
      ).buildInventoryInjection();
      expect(txt, isEmpty);
    });

    test('no speaker at all is empty, not a throw', () {
      expect(make().buildInventoryInjection(), isEmpty);
    });
  });

  group('group parity', () {
    final bob = CharacterCard(name: 'Bob');

    test('it describes the SPEAKER, not whoever is active', () {
      final txt = make(
        active: alice,
        group: [alice, bob],
        speakerId: 'Bob',
        records: {
          'Alice': Pockets(carrying: [const PocketItem('car keys')]),
          'Bob': Pockets(carrying: [const PocketItem('a lantern')]),
        },
      ).buildInventoryInjection();

      expect(txt, contains('Bob is'));
      expect(txt, contains('a lantern'));
      expect(txt, isNot(contains('car keys')));
    });

    test('a member with no record of their own stays silent', () {
      final txt = make(
        active: alice,
        group: [alice, bob],
        speakerId: 'Bob',
        records: {
          'Alice': Pockets(carrying: [const PocketItem('car keys')]),
        },
      ).buildInventoryInjection();
      expect(txt, isEmpty, reason: 'must not borrow the other member\'s');
    });

    test('a speaker id matching no member renders nothing', () {
      final txt = make(
        active: alice,
        group: [alice],
        speakerId: 'Nobody',
        records: {
          'Alice': Pockets(carrying: [const PocketItem('car keys')]),
        },
      ).buildInventoryInjection();
      expect(txt, isEmpty);
    });
  });

  test('a cluttered scene cannot eat the context budget', () {
    final txt = make(
      active: alice,
      records: {
        'Alice': Pockets(
          worn: [for (var i = 0; i < 8; i++) PocketItem('w' * 55, state: 's' * 55)],
          carrying: [for (var i = 0; i < 8; i++) PocketItem('c' * 55)],
        ),
      },
    ).buildInventoryInjection();
    expect(txt.length, lessThanOrEqualTo(InventoryInjection.maxChars + 1));
  });
}
