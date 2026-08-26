// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Deleting a group used to wipe sessions+messages only, then ask for the
// group's sessions (already gone), so journal/growth/embeddings/objectives/
// worlds never ran through deleteSessionById (audit P1).

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(sameIsolate: true));
  tearDown(() async => db.close());

  Future<void> seed({
    required String groupId,
    required String sessionId,
  }) async {
    await db.insertGroup(
      GroupsCompanion.insert(id: groupId, name: 'Porch Duo'),
    );
    await db.insertSession(
      SessionsCompanion.insert(id: sessionId, groupId: Value(groupId)),
    );
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'msg-$sessionId',
            sessionId: sessionId,
            position: 0,
            sender: 'Mara',
            isUser: false,
          ),
        );
    await db
        .into(db.journalMemories)
        .insert(
          JournalMemoriesCompanion.insert(
            id: 'jrnl-$sessionId',
            sessionId: sessionId,
            characterId: 'Mara_1',
            content: 'We sat on the porch.',
          ),
        );
    await db
        .into(db.growthRings)
        .insert(
          GrowthRingsCompanion.insert(
            id: 'ring-$sessionId',
            sessionId: sessionId,
            characterId: 'Mara_1',
            content: 'She trusts him now.',
          ),
        );
    await db
        .into(db.growthState)
        .insert(GrowthStateCompanion.insert(sessionId: sessionId));
    await db
        .into(db.messageEmbeddings)
        .insert(
          MessageEmbeddingsCompanion.insert(
            id: 'emb-$sessionId',
            sessionId: sessionId,
            characterId: const Value('Mara_1'),
            positionStart: 0,
            positionEnd: 1,
            content: 'the deleted group chat, verbatim',
            embedding: Uint8List.fromList(const [1, 2, 3, 4]),
            dimensions: 1,
          ),
        );
    await db
        .into(db.objectives)
        .insert(
          ObjectivesCompanion.insert(
            id: 'obj-$sessionId',
            characterId: 'Mara_1',
            chatId: Value(sessionId),
            objective: 'finish the quest',
          ),
        );
    await db
        .into(db.chatWorlds)
        .insert(
          ChatWorldsCompanion.insert(
            id: 'cw-$sessionId',
            chatId: sessionId,
            worldId: 'world-1',
          ),
        );
  }

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('c');

  test('hard-deleting a group cascades every per-chat table', () async {
    await seed(groupId: 'grp-a', sessionId: 'gsess-a');
    await db.deleteGroupById('grp-a');

    expect(
      await count("SELECT COUNT(*) AS c FROM sessions WHERE id = 'gsess-a'"),
      0,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS c FROM journal_memories WHERE session_id = 'gsess-a'",
      ),
      0,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS c FROM growth_rings WHERE session_id = 'gsess-a'",
      ),
      0,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS c FROM message_embeddings WHERE session_id = 'gsess-a'",
      ),
      0,
      reason: 'leftover embeddings still hold the deleted transcript',
    );
    expect(
      await count(
        "SELECT COUNT(*) AS c FROM objectives WHERE chat_id = 'gsess-a'",
      ),
      0,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS c FROM chat_worlds WHERE chat_id = 'gsess-a'",
      ),
      0,
    );
    expect(
      await count("SELECT COUNT(*) AS c FROM groups WHERE id = 'grp-a'"),
      0,
    );
  });

  test('soft-deleting a group cascades the same per-chat tables', () async {
    await seed(groupId: 'grp-b', sessionId: 'gsess-b');
    await db.softDeleteGroupById('grp-b');

    expect(
      await count(
        "SELECT COUNT(*) AS c FROM message_embeddings WHERE session_id = 'gsess-b'",
      ),
      0,
    );
    final flagged = await db
        .customSelect("SELECT deleted_at FROM groups WHERE id = 'grp-b'")
        .getSingle();
    expect(flagged.data['deleted_at'], isNotNull);
  });
}
