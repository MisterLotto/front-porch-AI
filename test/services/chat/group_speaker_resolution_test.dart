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

// Phase 2 test gate, item 5: identifying WHICH group member a historical
// message belongs to.
//
// Regenerating, swiping or deleting a message in a group rewinds that
// character's realism state. Get the character wrong and you write one member's
// bond, trust and needs onto another — silently, with no error, and the wrong
// numbers then persist.
//
// All three reprocess sites resolved the speaker by display name with
// `orElse: () => _groupCharacters.first`. The generation path bans exactly that
// fallback, in as many words: "duplicate display names would persist the
// critical scalar save to the wrong member's _groupRealism entry." Reprocess
// kept it, and the audit found nine call sites through those paths with no test
// coverage at all.
//
// The resolution rule is now: trust the character id stamped on the message
// when it was generated; fall back to the display name only when exactly one
// member matches; otherwise refuse and skip.
//
// These tests call the PRODUCTION function directly. An earlier draft of this
// file re-implemented the rule as a local copy, which is the same flaw the
// audit found in realism_parity_test: a test that owns its own copy of the
// logic passes happily while production drifts away from it. The rule was
// extracted to one pure public function so there is nothing to drift from.
//
// SCOPE: this pins the RULE. It does not pin the WIRING — that the three
// reprocess call sites actually skip when the rule returns null. Driving those
// needs a live ChatService with a seeded group, which is a heavier harness than
// this file carries. The rule was the part that was wrong; the call sites are
// three lines each and were changed together.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/services/chat/group_speaker_resolution.dart';
import 'package:front_porch_ai/utils/character_id.dart';

CharacterCard _member(String name, String image) =>
    CharacterCard(name: name)..imagePath = '/library/$image.png';

ChatMessage _from(String sender, {String? characterId}) => ChatMessage(
  text: 'something they said',
  isUser: false,
  sender: sender,
  characterId: characterId,
);

void main() {
  group('resolving which group member a message belongs to', () {
    test('two members sharing a display name resolve by stamped id', () {
      // THE CASE THE BAN EXISTS FOR. Both are called "Alex"; only the id
      // separates them. Under the old fallback this always picked the first,
      // so regenerating the second Alex's line rewound the first Alex.
      final alexA = _member('Alex', 'Alex_1111');
      final alexB = _member('Alex', 'Alex_2222');
      final cast = [alexA, alexB];

      final fromB = _from('Alex', characterId: alexB.stableGroupId);
      expect(
        resolveGroupSpeakerForMessage(cast, fromB)?.stableGroupId,
        alexB.stableGroupId,
        reason: 'the stamped id is the only thing that tells the two apart',
      );

      final fromA = _from('Alex', characterId: alexA.stableGroupId);
      expect(resolveGroupSpeakerForMessage(cast, fromA)?.stableGroupId, alexA.stableGroupId);
    });

    test('duplicate names with NO stamped id refuse rather than guess', () {
      // An older message from before the stamp existed. Two members match the
      // name, so there is genuinely no way to tell. Returning the first would
      // be a coin flip that silently corrupts one of them.
      final cast = [_member('Alex', 'Alex_1111'), _member('Alex', 'Alex_2222')];
      expect(
        resolveGroupSpeakerForMessage(cast, _from('Alex')),
        isNull,
        reason: 'refusing is the only safe answer; the caller must skip',
      );
    });

    test('a sender who is no longer in the cast refuses', () {
      // Someone left the group, or was renamed. The old code handed this to
      // whoever was first in the list.
      final cast = [_member('Aerin', 'Aerin_1'), _member('Bo', 'Bo_2')];
      expect(resolveGroupSpeakerForMessage(cast, _from('Departed')), isNull);
      expect(
        resolveGroupSpeakerForMessage(cast, _from('Departed', characterId: 'Ghost_9')),
        isNull,
        reason: 'a stamped id that matches nobody must not fall through to '
            'the name, and must not fall through to the first member',
      );
    });

    test('the stamped id wins even when a DIFFERENT member matches the name',
        () {
      // A member was renamed to a name another member used to have. The name
      // now points at the wrong person; the id still points at the right one.
      final aerin = _member('Aerin', 'Aerin_1');
      final renamed = _member('Aerin', 'Bo_2'); // was Bo, now also called Aerin
      final cast = [aerin, renamed];

      final msg = _from('Aerin', characterId: renamed.stableGroupId);
      expect(
        resolveGroupSpeakerForMessage(cast, msg)?.stableGroupId,
        renamed.stableGroupId,
        reason: 'identity is the id, not the label on it',
      );
    });

    test('an ORPHANED stamp falls through to a unique name, on purpose', () {
      // A member removed and re-added keeps their name but gets a new stable
      // id, so their old messages carry a stamp that matches nobody. Refusing
      // here would make regenerating those lines silently do nothing. This is
      // a deliberate choice, not an oversight — pinned so it cannot be
      // "tidied" into a refusal without someone noticing.
      final cast = [_member('Aerin', 'Aerin_NEW'), _member('Bo', 'Bo_2')];
      final oldMsg = _from('Aerin', characterId: 'Aerin_OLD_DELETED');
      expect(resolveGroupSpeakerForMessage(cast, oldMsg)?.name, 'Aerin');
    });

    test('an orphaned stamp does NOT fall through to an ambiguous name', () {
      // The safety property that makes the fallthrough acceptable: it still
      // refuses whenever the name cannot single out one member.
      final cast = [_member('Alex', 'Alex_1'), _member('Alex', 'Alex_2')];
      expect(
        resolveGroupSpeakerForMessage(cast, _from('Alex', characterId: 'Gone')),
        isNull,
      );
    });

    test('a unique name still resolves when there is no stamped id', () {
      // The common case for messages written before the stamp. Unambiguous, so
      // the name is trustworthy.
      final cast = [_member('Aerin', 'Aerin_1'), _member('Bo', 'Bo_2')];
      expect(resolveGroupSpeakerForMessage(cast, _from('Bo'))?.name, 'Bo');
    });

    test('an empty cast refuses instead of throwing', () {
      expect(resolveGroupSpeakerForMessage(const [], _from('Anyone')), isNull);
    });

    test('an empty stamped id falls back to the name rather than matching '
        'a member whose id is also empty', () {
      final cast = [_member('Aerin', 'Aerin_1'), _member('Bo', 'Bo_2')];
      expect(resolveGroupSpeakerForMessage(cast, _from('Bo', characterId: ''))?.name, 'Bo');
    });
  });
}
