// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// Database Cleanup used to treat every group RAG corpus (`group_<id>`) and
// every working memory_sources list (image-basename IDs) as dead:
// Scan lied, Clean wiped. Same class as the shipped 68/68 1:1 wipe.
// These tests insert a live group archive row AND a basename source list.

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/database/database_cleanup.dart';
import 'package:front_porch_ai/utils/utils.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(sameIsolate: true));
  tearDown(() async => db.close());

  Future<void> addGroupRag({
    required String groupId,
    required String sessionId,
  }) async {
    await db.into(db.groups).insert(
          GroupsCompanion.insert(id: groupId, name: 'Porch Duo'),
        );
    await db.insertSession(
      SessionsCompanion.insert(id: sessionId, groupId: Value(groupId)),
    );
    await db.insertEmbedding(
      MessageEmbeddingsCompanion(
        id: const Value('emb-group'),
        sessionId: Value(sessionId),
        characterId: Value('group_$groupId'),
        positionStart: const Value(0),
        positionEnd: const Value(1),
        content: const Value('group memory'),
        embedding: Value(Uint8List(4)),
        dimensions: const Value(1),
      ),
    );
  }

  test('a group RAG row keyed group_<id> is NOT an orphan', () async {
    await addGroupRag(groupId: 'g1', sessionId: 's-g1');
    final report = await DatabaseCleanup.checkOrphans(db);
    expect(
      report.orphanCounts['message_embeddings'],
      0,
      reason: 'live group archive must never look orphaned',
    );
  });

  test('cleanup keeps the group archive and removes only a truly dead row',
      () async {
    await addGroupRag(groupId: 'g1', sessionId: 's-g1');
    await db.insertEmbedding(
      MessageEmbeddingsCompanion(
        id: const Value('emb-dead'),
        sessionId: const Value('s-g1'),
        characterId: const Value('group_deleted-group'),
        positionStart: const Value(2),
        positionEnd: const Value(3),
        content: const Value('dead group'),
        embedding: Value(Uint8List(4)),
        dimensions: const Value(1),
      ),
    );

    final result = await DatabaseCleanup.cleanOrphans(db);
    expect(result.removedCounts['message_embeddings'], 1);
    final left = await db.select(db.messageEmbeddings).get();
    expect(left.map((e) => e.characterId), ['group_g1']);
  });

  test('memory_sources keyed by image basename is NOT broken', () async {
    await db.into(db.characters).insert(
          CharactersCompanion.insert(
            id: 'uuid-aerin',
            name: 'Aerin',
            imagePath: const Value('/library/Aerin_1782587668376.png'),
          ),
        );
    await db.into(db.characters).insert(
          CharactersCompanion.insert(
            id: 'uuid-reader',
            name: 'Reader',
            imagePath: const Value('/library/Reader_1.png'),
            memorySources: Value(
              jsonEncode(['Aerin_1782587668376']),
            ),
          ),
        );

    final report = await DatabaseCleanup.checkOrphans(db);
    expect(
      report.brokenRefCounts['memory_sources'],
      0,
      reason: 'the picker stores stableGroupId, not the UUID',
    );
    expect(
      stableGroupIdFrom('/library/Aerin_1782587668376.png', 'Aerin'),
      'Aerin_1782587668376',
    );
  });

  test('cleanup does not empty a live basename memory_sources list', () async {
    await db.into(db.characters).insert(
          CharactersCompanion.insert(
            id: 'uuid-aerin',
            name: 'Aerin',
            imagePath: const Value('/library/Aerin_1782587668376.png'),
          ),
        );
    await db.into(db.characters).insert(
          CharactersCompanion.insert(
            id: 'uuid-reader',
            name: 'Reader',
            imagePath: const Value('/library/Reader_1.png'),
            memorySources: Value(
              jsonEncode(['Aerin_1782587668376', 'Gone_999']),
            ),
          ),
        );

    final result = await DatabaseCleanup.cleanOrphans(db);
    expect(result.fixedRefCounts['memory_sources'], 1);
    final row = await db.customSelect(
      "SELECT memory_sources FROM characters WHERE id = 'uuid-reader'",
    ).getSingle();
    expect(
      jsonDecode(row.data['memory_sources'] as String),
      ['Aerin_1782587668376'],
    );
  });
}
