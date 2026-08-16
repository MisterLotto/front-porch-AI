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

// CONVERTING A 1:1 INTO A GROUP MUST CARRY THE HOST'S DIARY, NOT JUST HER
// RINGS AND QUESTS.
//
// The fork mints a brand-new session and a brand-new member instance id for
// the host, so every per-owner store has to be re-keyed onto (newSession,
// memberId). `_carryHostStateIntoForkedGroup` did that for Growth Rings,
// objectives and RAG embeddings — and skipped the Journal, whose cards are
// keyed by exactly the same pair. The host therefore walked into the group
// with an empty diary: every memory card, item placement and promise from the
// 1:1 was unreachable, and it could never rebuild because the fork also
// carries the recap cursor past the copied history.
//
// Proven to fail: delete the journal carry loop in
// chat_service_cast.dart and the second expectation goes red (0 cards).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/utils/utils.dart';

/// ONE root for the whole file: the fork writes group members through
/// `AppDatabase.instance()` (the process singleton) while reading them back
/// through the repository it was handed, so the two have to be the same
/// database — which means the same documents directory every time it is asked.
final Directory _root = Directory.systemTemp.createTempSync('fpai_forkjournal_');

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return _root.path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  late AppDatabase db;
  late StorageService storage;
  late ChatService chat;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'update_auto_check': false});
    // Deliberately the singleton, not forTesting(): _createGroupMember inserts
    // through AppDatabase.instance(), and a second in-memory database would
    // leave the new group with no members at all — the carry would then be
    // skipped for the honest reason "host member not found" and the test would
    // prove nothing.
    db = await AppDatabase.instance();
    storage = StorageService();
    chat =
        ChatService(
            KoboldService(storage),
            UserPersonaService(db),
            storage,
            WorldRepository(storage, db),
          )
          ..setDatabase(db)
          ..setCharacterRepository(CharacterRepository(db, storage));
    await storage.initialized;
  });

  tearDown(() async {
    chat.dispose();
    // The singleton database is shared with any later test in this file; the
    // temp root goes away with the process.
  });

  CharacterCard card(String name, String id) => CharacterCard(
    name: name,
    description: 'Exists only inside the fork-journal test.',
    firstMessage: 'The screen door bangs shut behind you.',
  )..dbId = id;

  test('forking a 1:1 into a group carries the host journal onto the member',
      () async {
    final host = card('Nia', 'char-journal-host');
    await chat.setActiveCharacter(host);
    final soloSessionId = chat.currentSessionId;
    expect(soloSessionId, isNotNull);

    await chat.journalStore.addCard(
      sessionId: soloSessionId!,
      characterId: host.stableGroupId,
      content: 'I set my car keys down — on the hallway table.',
      category: 'item',
      kind: 'item',
      maxCards: 40,
    );
    await chat.journalStore.addCard(
      sessionId: soloSessionId,
      characterId: host.stableGroupId,
      content: 'He remembered my sister\'s name without being told.',
      category: 'moment',
      emotionLabel: 'touched',
      pinned: true,
      maxCards: 40,
    );

    final group = await chat.forkToGroupChat(
      [card('Marisol', 'char-journal-arrival')],
      GroupChatRepository(storage, db),
    );
    expect(group, isNotNull, reason: 'the conversion itself must succeed');

    final newSessionId = chat.currentSessionId;
    expect(
      newSessionId,
      isNot(soloSessionId),
      reason: 'the fork mints a new session — that is why re-keying is needed',
    );

    final hostMember = chat.groupCharacters.firstWhere((c) => c.name == 'Nia');
    final carried = await chat.journalStore.cardsFor(
      newSessionId!,
      hostMember.stableGroupId,
    );

    expect(
      carried,
      hasLength(2),
      reason:
          'THE BUG: rings, quests and RAG were re-keyed onto the host member '
          'but the diary was left behind in the old session, so the host '
          'opened the very same conversation with no memories at all',
    );
    expect(
      carried.map((c) => c.content),
      containsAll(<String>[
        'I set my car keys down — on the hallway table.',
        'He remembered my sister\'s name without being told.',
      ]),
    );
    // The carry is a COPY, not a move: the preserved 1:1 stays the revert
    // snapshot, so its diary must still be intact.
    expect(
      await chat.journalStore.cardsFor(soloSessionId, host.stableGroupId),
      hasLength(2),
    );
    // Physics/lineage fields ride along — a pinned memory must not silently
    // become droppable in the group.
    expect(carried.where((c) => c.pinned), hasLength(1));
    expect(
      carried.firstWhere((c) => c.pinned).emotionLabel,
      'touched',
    );
  });
}
