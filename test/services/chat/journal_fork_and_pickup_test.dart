// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// Fable mediums: fork must copy diary embeddings (cosine resurface), and
// pickup must retire every owner's placement card in the session (Bob
// picking up Alice's keys).

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/chat/journal_physics.dart';
import 'package:front_porch_ai/services/chat/journal_store.dart';

void main() {
  late AppDatabase db;
  late JournalStore store;

  setUp(() {
    db = AppDatabase.forTesting(sameIsolate: true);
    store = JournalStore(getDb: () => db);
  });
  tearDown(() async => db.close());

  test('copySessionTo keeps embedding + accessCount', () async {
    final blob = Uint8List.fromList([1, 2, 3, 4]);
    await store.addCard(
      sessionId: 'parent',
      characterId: 'alice',
      content: 'I set the keys down.',
      category: 'item',
      kind: 'item',
      extraMetadata: {'item': 'car keys'},
      sourcePositions: const [2],
      maxCards: 200,
    );
    final parent = (await store.cardsFor('parent', 'alice')).single;
    await db.updateJournalCard(
      parent.id,
      JournalMemoriesCompanion(
        embedding: Value(blob),
        dimensions: const Value(4),
        accessCount: const Value(7),
      ),
    );

    await store.copySessionTo('parent', 'fork', cursor: 10);
    final copied = (await store.cardsFor('fork', 'alice')).single;
    expect(copied.embedding, blob);
    expect(copied.dimensions, 4);
    expect(copied.accessCount, 7);
    expect(copied.content, parent.content);
  });

  test('retireItemCardsInSession clears every owner of that item', () async {
    await store.addCard(
      sessionId: 's1',
      characterId: 'alice',
      content: 'I set the keys down on the table.',
      category: 'item',
      kind: 'item',
      extraMetadata: {'item': 'car keys'},
      maxCards: 200,
    );
    await store.addCard(
      sessionId: 's1',
      characterId: 'bob',
      content: 'I left the keys by the door.',
      category: 'item',
      kind: 'item',
      extraMetadata: {'item': 'car keys'},
      maxCards: 200,
    );
    await store.addCard(
      sessionId: 's1',
      characterId: 'alice',
      content: 'A rainy afternoon.',
      category: 'moment',
      maxCards: 200,
    );

    final n = await store.retireItemCardsInSession('s1', 'car keys');
    expect(n, 2);
    final alice = await store.cardsFor('s1', 'alice');
    expect(alice.single.content, 'A rainy afternoon.');
    expect(await store.cardsFor('s1', 'bob'), isEmpty);
    expect(JournalPhysics.isItemCard(alice.single), isFalse);
  });

  test('copySessionTo skips cards that cite past the fork', () async {
    await store.addCard(
      sessionId: 'parent',
      characterId: 'alice',
      content: 'before',
      category: 'moment',
      sourcePositions: const [1],
      maxCards: 200,
    );
    await store.addCard(
      sessionId: 'parent',
      characterId: 'alice',
      content: 'after',
      category: 'moment',
      sourcePositions: const [8],
      maxCards: 200,
    );
    await store.copySessionTo('parent', 'fork', cursor: 5);
    final copied = await store.cardsFor('fork', 'alice');
    expect(copied.map((c) => c.content), ['before']);
  });
}
