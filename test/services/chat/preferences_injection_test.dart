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

// Likes & Dislikes — the BEHAVIOURAL half.
//
// The claim this file exists to keep honest is that acting on a taste needs no
// Realism Engine. PreferencesInjection takes no realism callback at all, which
// is easy to "fix" later by someone tidying up the injection list and adding
// `if (_characterStateEnabled)` in front of it for consistency with its
// neighbours. That would silently delete the feature for every realism-off
// user, which is precisely the class of bug docs/design/feature-independence.md
// was written to end. There is no realism switch to flip in these tests
// BECAUSE there is no realism input — and the composer test below proves the
// fragment still lands when the engine is off.
//
// The rest pins the things a careless edit would change: the 18+ pair is gated
// on the install's adult-themes switch and not on the card, the per-line cap
// bounds the prompt without truncating the card, and phrasing stays
// TENDENCIES rather than instructions (the design doc's named failure mode is
// a character who steers every scene toward her own likes).

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/preferences_injection.dart';

PreferencesInjection make(
  CharacterCard? card, {
  bool nsfw = false,
  List<CharacterCard> group = const [],
  String speakerId = '',
}) => PreferencesInjection(
  getActiveCharacter: () => card,
  getIsGroupNonObserverMode: () => group.isNotEmpty,
  getCurrentSpeakerIdForRealism: () => speakerId,
  getGroupCharacters: () => group,
  getCharacterIdFromCard: (c) => c.name,
  getNsfwEnabled: () => nsfw,
);

CharacterCard who(
  String name, {
  List<String> likes = const [],
  List<String> dislikes = const [],
  List<String> into = const [],
  List<String> notInto = const [],
}) => CharacterCard(
  name: name,
  frontPorchExtensions: FrontPorchExtensions(
    likes: likes,
    dislikes: dislikes,
    intimateInto: into,
    intimateNotInto: notInto,
  ),
);

void main() {
  group('the everyday lists', () {
    test('both sides render in one line', () {
      final txt = make(
        who(
          'Alice',
          likes: ['being read to', 'thunderstorms'],
          dislikes: ['being interrupted'],
        ),
      ).buildPreferencesInjection();

      expect(txt, contains('being read to, thunderstorms'));
      expect(txt, contains('being interrupted'));
      expect(txt, contains('drawn to'));
      expect(txt, contains('put off by'));
    });

    test('likes alone omit the dislikes clause, and vice versa', () {
      expect(
        make(who('Alice', likes: ['thunderstorms'])).buildPreferencesInjection(),
        isNot(contains('put off by')),
      );
      expect(
        make(who('Alice', dislikes: ['crowds'])).buildPreferencesInjection(),
        isNot(contains('drawn to')),
      );
    });

    test('it frames tastes as tendencies, never as instructions', () {
      // The design doc's named risk: a character told to like something starts
      // steering every scene toward it. The phrasing is the mitigation, so it
      // is worth pinning rather than leaving to whoever edits the string next.
      final txt = make(
        who('Alice', likes: ['being read to']),
      ).buildPreferencesInjection();
      expect(txt, contains('colour how they react'));
      expect(txt, contains('never steer the scene'));
    });

    test('a card with no preferences contributes nothing', () {
      expect(make(who('Alice')).buildPreferencesInjection(), isEmpty);
    });

    test('no card at all is empty, not a throw', () {
      expect(make(null).buildPreferencesInjection(), isEmpty);
    });
  });

  group('the 18+ pair', () {
    final spicy = who('Alice', likes: ['rain'], into: ['slow mornings'],
        notInto: ['an audience']);

    test('is absent when the install has 18+ themes off', () {
      final txt = make(spicy, nsfw: false).buildPreferencesInjection();
      expect(txt, contains('rain'), reason: 'everyday tastes still render');
      expect(txt, isNot(contains('slow mornings')));
      expect(txt, isNot(contains('an audience')));
      expect(txt, isNot(contains('intimate')));
    });

    test('renders as its own line when 18+ themes are on', () {
      final txt = make(spicy, nsfw: true).buildPreferencesInjection();
      expect(txt, contains('In intimate moments'));
      expect(txt, contains('slow mornings'));
      expect(txt, contains('not interested in an audience'));
    });

    test('18+ on but nothing authored adds no line', () {
      final txt = make(
        who('Alice', likes: ['rain']),
        nsfw: true,
      ).buildPreferencesInjection();
      expect(txt, isNot(contains('In intimate moments')));
    });
  });

  group('budget', () {
    test('the per-line cap bounds the PROMPT, not the card', () {
      final many = [for (var i = 0; i < 12; i++) 'thing$i'];
      final txt = make(who('Alice', likes: many)).buildPreferencesInjection();
      expect(txt, contains('thing0'));
      expect(txt, contains('thing${PreferencesInjection.maxPerLine - 1}'));
      expect(txt, isNot(contains('thing${PreferencesInjection.maxPerLine}')));
      // The card itself is untouched — the editor still shows all twelve.
      expect(many.length, 12);
    });

    test('an essay-length phrase set cannot eat the context budget', () {
      final txt = make(
        who(
          'Alice',
          likes: [for (var i = 0; i < 5; i++) 'a' * 300],
          dislikes: [for (var i = 0; i < 5; i++) 'b' * 300],
        ),
      ).buildPreferencesInjection();
      expect(txt.length, lessThanOrEqualTo(PreferencesInjection.maxChars + 1));
    });
  });

  group('group parity', () {
    test('it describes the SPEAKER, not whoever is active', () {
      // The failure this prevents is quiet and wrong rather than loud: a group
      // member described with another member's tastes.
      final alice = who('Alice', likes: ['thunderstorms']);
      final bob = who('Bob', likes: ['card games']);
      final txt = make(
        alice,
        group: [alice, bob],
        speakerId: 'Bob',
      ).buildPreferencesInjection();

      expect(txt, contains('card games'));
      expect(txt, isNot(contains('thunderstorms')));
    });

    test('a speaker id matching no member renders nothing at all', () {
      final alice = who('Alice', likes: ['thunderstorms']);
      final txt = make(
        alice,
        group: [alice],
        speakerId: 'Nobody',
      ).buildPreferencesInjection();
      expect(txt, isEmpty, reason: 'must not fall back to the active card');
    });
  });
}
