// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Deleting a character must delete the character's chats AND everything that
// hangs off them.
//
// Both character delete paths used to remove only `sessions` + `messages`,
// while the per-chat delete (deleteSessionById, audit P2.19) cascades eight
// tables. So "delete this character" left journal cards, growth rings, RAG
// embeddings, objectives, world links and biome spans behind forever — and an
// orphaned embedding is NOT inert: it carries its own verbatim copy of the
// conversation text, and MemoryService deliberately does not session-scope a
// character the user listed as an explicit cross-character memory source. The
// deleted character's chats therefore kept getting injected into someone
// else's prompt.
//
// These tests pin the cascade for both the hard and the soft delete path.

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(sameIsolate: true));
  tearDown(() async => db.close());

  /// A character with one chat and one row in every table that chat owns.
  /// [charId] is the characters.id UUID; [embedId] is the stableGroupId the
  /// derived tables key on (they are deliberately different keys).
  Future<void> seed({
    required String charId,
    required String sessionId,
    required String embedId,
  }) async {
    await db
        .into(db.characters)
        .insert(
          CharactersCompanion.insert(
            id: charId,
            name: charId,
            imagePath: Value('/tmp/$embedId.png'),
          ),
        );
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            id: sessionId,
            characterId: Value(charId),
          ),
        );
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'msg-$sessionId',
            sessionId: sessionId,
            position: 0,
            sender: charId,
            isUser: false,
          ),
        );
    await db
        .into(db.journalMemories)
        .insert(
          JournalMemoriesCompanion.insert(
            id: 'jrnl-$sessionId',
            sessionId: sessionId,
            characterId: embedId,
            content: 'I remember what we did.',
          ),
        );
    await db
        .into(db.growthRings)
        .insert(
          GrowthRingsCompanion.insert(
            id: 'ring-$sessionId',
            sessionId: sessionId,
            characterId: embedId,
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
            characterId: Value(embedId),
            positionStart: 0,
            positionEnd: 1,
            // The row carries the conversation text itself — this is what
            // survived the message delete and kept reaching other prompts.
            content: 'the deleted conversation, verbatim',
            embedding: Uint8List.fromList(const [1, 2, 3, 4]),
            dimensions: 1,
          ),
        );
    await db
        .into(db.objectives)
        .insert(
          ObjectivesCompanion.insert(
            id: 'obj-$sessionId',
            characterId: embedId,
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
    await db
        .into(db.chatBiomeSpans)
        .insert(
          ChatBiomeSpansCompanion.insert(
            id: 'span-$sessionId',
            chatId: sessionId,
            effectiveFromDay: 1,
            biomeJson: '{}',
          ),
        );
    await db
        .into(db.avatarImages)
        .insert(
          AvatarImagesCompanion.insert(
            id: 'av-$charId',
            characterId: charId, // avatars key on the UUID, not stableGroupId
            filename: 'look.png',
          ),
        );
  }

  Future<Map<String, int>> leftovers(String sessionId, String charId) async {
    Future<int> count(String sql) async =>
        (await db.customSelect(sql).getSingle()).read<int>('c');
    return {
      'sessions': await count(
        "SELECT COUNT(*) AS c FROM sessions WHERE id = '$sessionId'",
      ),
      'messages': await count(
        "SELECT COUNT(*) AS c FROM messages WHERE session_id = '$sessionId'",
      ),
      'journal_memories': await count(
        "SELECT COUNT(*) AS c FROM journal_memories "
        "WHERE session_id = '$sessionId'",
      ),
      'growth_rings': await count(
        "SELECT COUNT(*) AS c FROM growth_rings WHERE session_id = '$sessionId'",
      ),
      'growth_state': await count(
        "SELECT COUNT(*) AS c FROM growth_state WHERE session_id = '$sessionId'",
      ),
      'message_embeddings': await count(
        "SELECT COUNT(*) AS c FROM message_embeddings "
        "WHERE session_id = '$sessionId'",
      ),
      'objectives': await count(
        "SELECT COUNT(*) AS c FROM objectives WHERE chat_id = '$sessionId'",
      ),
      'chat_worlds': await count(
        "SELECT COUNT(*) AS c FROM chat_worlds WHERE chat_id = '$sessionId'",
      ),
      'chat_biome_spans': await count(
        "SELECT COUNT(*) AS c FROM chat_biome_spans "
        "WHERE chat_id = '$sessionId'",
      ),
      'avatar_images': await count(
        "SELECT COUNT(*) AS c FROM avatar_images WHERE character_id = '$charId'",
      ),
    };
  }

  test('soft-deleting a character cascades every per-chat table', () async {
    await seed(charId: 'uuid-a', sessionId: 'sess-a', embedId: 'Anna_1');

    await db.softDeleteCharacterById('uuid-a');

    expect(
      await leftovers('sess-a', 'uuid-a'),
      {
        'sessions': 0,
        'messages': 0,
        'journal_memories': 0,
        'growth_rings': 0,
        'growth_state': 0,
        'message_embeddings': 0,
        'objectives': 0,
        'chat_worlds': 0,
        'chat_biome_spans': 0,
        'avatar_images': 0,
      },
      reason: 'a leftover message_embeddings row still holds the deleted '
          "chat's text and is still retrievable by any character that lists "
          'this one as a memory source',
    );

    // The character row itself stays, flagged — that is the point of the soft
    // delete (the flag has to travel with the DB so a merge cannot resurrect).
    final flagged = await db
        .customSelect("SELECT deleted_at FROM characters WHERE id = 'uuid-a'")
        .getSingle();
    expect(flagged.data['deleted_at'], isNotNull);
  });

  test('hard-deleting a character cascades the same tables', () async {
    await seed(charId: 'uuid-b', sessionId: 'sess-b', embedId: 'Bea_1');

    await db.deleteCharacterById('uuid-b');

    expect(
      (await leftovers('sess-b', 'uuid-b')).values.toSet(),
      {0},
      reason: 'the hard path must not leave a different set of orphans behind '
          'than the soft path',
    );
    final rows = await db
        .customSelect("SELECT COUNT(*) AS c FROM characters WHERE id = 'uuid-b'")
        .getSingle();
    expect(rows.read<int>('c'), 0);
  });

  test('another character\'s chat data is untouched', () async {
    await seed(charId: 'uuid-c', sessionId: 'sess-c', embedId: 'Cal_1');
    await seed(charId: 'uuid-d', sessionId: 'sess-d', embedId: 'Dee_1');

    await db.softDeleteCharacterById('uuid-c');

    expect(
      (await leftovers('sess-d', 'uuid-d')).values.toSet(),
      {1},
      reason: 'the cascade is scoped to the deleted character\'s own chats',
    );
  });
}
