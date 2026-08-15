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

// A BACKGROUND PASS MAY ONLY CLAIM THE WINDOW IT ACTUALLY READ.
//
// Both periodic passes (Journal + Growth) are fired and forgotten from the
// post-generation phase, and `getMessages()` hands them ChatService's LIVE
// `_messages` list — the same object `sendMessage` appends to. Sending is
// gated on `_isGenerating` only, so a user CAN take a whole new turn while a
// pass is queued behind the main generation on a single-slot local backend.
//
// The window is snapshotted (`messages.sublist(start)`), but both passes used
// to set the cursor from `messages.length` AFTER their awaits — parking it
// past turns they never read. Nothing rewinds a pass cursor, so those
// exchanges were silently un-journaled / never grown, forever.
//
// Red-proved: restoring `messages.length` at either cursor site sends that
// pass's test to "expected 2, actual 4".

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

ChatMessage _msg(String sender, String text, {bool isUser = false}) =>
    ChatMessage(text: text, sender: sender, isUser: isUser);

void main() {
  final host = CharacterCard(
    name: 'Mira',
    description: 'The one keeping the diary.',
    personality: 'Wry, guarded, loyal.',
  );

  group('Journal pass cursor', () {
    late AppDatabase db;
    late JournalStore store;

    setUp(() async {
      db = AppDatabase.forTesting(sameIsolate: true);
      store = JournalStore(getDb: () => db);
      await db.insertSession(SessionsCompanion.insert(id: 's1'));
    });

    tearDown(() async {
      await db.close();
    });

    test('stops at the snapshot end when a turn lands during the pass', () async {
      // Two messages when the pass starts...
      final messages = <ChatMessage>[
        _msg('Sam', 'evening', isUser: true),
        _msg('Mira', 'evening yourself'),
      ];
      final cursors = <int>[];
      var running = false;

      final pass = JournalMaintenance(
        store: store,
        probe: ToolTransportProbe()..markXmlOnly('fake'),
        review: JournalReview(
          store: store,
          getSessionId: () => 's1',
          setRecap: (_) {},
          setCursor: cursors.add,
          onSaveChat: () async {},
          onNotify: () {},
          getMaxCards: () => 200,
        ),
        fireLLMEval: (p) async {
          // ...and the user takes another turn while the eval is in flight.
          messages
            ..add(_msg('Sam', 'one more thing', isUser: true))
            ..add(_msg('Mira', 'go on'));
          return '<recap>We talked on the porch.</recap>'
              '<memory action="add" category="moment" msgs="1">'
              'we said good evening</memory>';
        },
        fireToolEval: (p, t) async => null,
        stripThinkBlocks: (t) => t,
        getSessionId: () => 's1',
        getActiveCharacter: () => host,
        getActiveGroup: () => null,
        getGroupCharacters: () => const [],
        getCharacterIdFromCard: (c) => c.name.toLowerCase(),
        getMessages: () => messages,
        getUserName: () => 'Sam',
        getCursor: () => 0,
        setCursor: cursors.add,
        getRecap: () => '',
        setRecap: (_) {},
        getIsPassRunning: () => running,
        setIsPassRunning: (v) => running = v,
        getReviewFirst: () => false,
        getBackendIdentity: () => 'fake',
        getMaxCards: () => 200,
        onNotify: () {},
        onSaveChat: () async {},
        getCurrentStoryDay: () => 1,
        getCurrentStoryClockIso: () => '2026-06-30T09:00:00.000Z',
      );

      await pass.runMaintenancePass();

      expect(messages, hasLength(4));
      expect(
        cursors,
        [2],
        reason:
            'the pass read messages 0-1 only; claiming 4 would leave the new '
            'exchange permanently behind the cursor and un-journaled',
      );
    });
  });

  group('Growth pass cursor', () {
    late AppDatabase db;
    late GrowthStore store;

    setUp(() async {
      db = AppDatabase.forTesting(sameIsolate: true);
      store = GrowthStore(getDb: () => db);
      await db.insertSession(SessionsCompanion.insert(id: 's1'));
    });

    tearDown(() async {
      await db.close();
    });

    test('stops at the snapshot end when a turn lands during the pass', () async {
      final messages = <ChatMessage>[
        _msg('Sam', 'you seem steadier lately', isUser: true),
        _msg('Mira', 'I have been trying'),
      ];
      var running = false;

      final growth = GrowthService(
        store: store,
        review: GrowthReview(
          store: store,
          getSessionId: () => 's1',
          getIsGroup: () => false,
          onApplied: () async {},
          onNotify: () {},
        ),
        probe: ToolTransportProbe()..markXmlOnly('fake'),
        fireLLMEval: (p) async {
          messages
            ..add(_msg('Sam', 'and today?', isUser: true))
            ..add(_msg('Mira', 'steadier still'));
          return '<ring action="add" category="trait" msgs="1">'
              'She lets herself be believed.</ring>';
        },
        fireToolEval: (p, t) async => null,
        stripThinkBlocks: (t) => t,
        getBackendIdentity: () => 'fake',
        getSessionId: () => 's1',
        getActiveCharacter: () => host,
        getActiveGroup: () => null,
        getGroupCharacters: () => const [],
        getSceneGuestCards: () => const [],
        getCharacterIdFromCard: (c) => c.name.toLowerCase(),
        getMessages: () => messages,
        getUserName: () => 'Sam',
        getRecap: () => '',
        getJournalCards: (s, c) async => const [],
        getGrowthEnabled: () => true,
        getReviewFirst: () => false,
        getIsPassRunning: () => running,
        setIsPassRunning: (v) => running = v,
        refreshCache: () async {},
        onNotify: () {},
      );

      await growth.runGrowthPass();

      expect(messages, hasLength(4));
      expect(
        await store.cursorFor('s1'),
        2,
        reason:
            'a ring pass that read two messages may not claim four — the '
            'exchange taken mid-pass would never be evaluated for growth',
      );
    });
  });
}
