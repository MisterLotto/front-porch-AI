// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Regression tests for the identity space DatabaseCleanup reconciles against.
//
// The Database Cleanup dialog used to join `objectives.character_id` and
// `message_embeddings.character_id` straight against `characters.id`. Those
// columns hold the character's stableGroupId (the portable image-filename id),
// while `characters.id` is a UUID — so a filename was compared to a UUID,
// nothing ever matched, and EVERY row looked orphaned. Measured against a real
// library before the fix: 107 of 107 objectives and 68 of 68 RAG embeddings
// would have been deleted, silently, by a button labelled "clean up".
//
// These tests pin both halves: live rows survive, genuinely dead ones go.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/database/database_cleanup.dart';
import 'package:front_porch_ai/utils/utils.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(sameIsolate: true);
  });

  tearDown(() async {
    await db.close();
  });

  /// A library character whose stableGroupId is its image filename basename —
  /// exactly how the app writes them.
  Future<String> addCharacter({
    required String id,
    required String name,
    required String imagePath,
  }) async {
    await db
        .into(db.characters)
        .insert(
          CharactersCompanion.insert(
            id: id,
            name: name,
            imagePath: Value(imagePath),
          ),
        );
    return stableGroupIdFrom(imagePath, name);
  }

  Future<void> addObjective(String characterId, String goal) async {
    await db
        .into(db.objectives)
        .insert(
          ObjectivesCompanion.insert(
            id: 'obj_${goal.hashCode}',
            characterId: characterId,
            objective: goal,
          ),
        );
  }

  test('an objective keyed by stableGroupId is NOT reported as an orphan',
      () async {
    final sgid = await addCharacter(
      id: 'bbf6ed62-f64c-4b6e-a724-257cefca03b8',
      name: 'Aerin',
      imagePath: '/library/Aerin_1782587668376.png',
    );
    expect(
      sgid,
      'Aerin_1782587668376',
      reason: 'the id space under test is the image filename, not the UUID',
    );
    await addObjective(sgid, 'Share porch lemonade');

    final report = await DatabaseCleanup.checkOrphans(db);
    expect(
      report.orphanCounts['objectives'],
      0,
      reason: 'a live character\'s objective must never look orphaned',
    );
  });

  test('cleanup keeps that objective and removes only the truly dead one',
      () async {
    final sgid = await addCharacter(
      id: 'bbf6ed62-f64c-4b6e-a724-257cefca03b8',
      name: 'Aerin',
      imagePath: '/library/Aerin_1782587668376.png',
    );
    await addObjective(sgid, 'Share porch lemonade');
    await addObjective('Violet_1785491322208', 'Belongs to a deleted character');

    final result = await DatabaseCleanup.cleanOrphans(db);
    expect(result.removedCounts['objectives'], 1);

    final left = await db.select(db.objectives).get();
    expect(left.map((o) => o.characterId), [sgid]);
  });

  test('a character with no image falls back to its sanitized name', () async {
    expect(stableGroupIdFrom(null, 'Seraphine Vail'), 'Seraphine_Vail');
    expect(stableGroupIdFrom('', "M'Lady O'Hara"), 'MLady_OHara');
    expect(
      stableGroupIdFrom('/lib/Nora_1780304424982.png', 'ignored'),
      'Nora_1780304424982',
    );
  });

  test('a soft-deleted character\'s objectives ARE orphans', () async {
    final sgid = await addCharacter(
      id: 'dead-uuid',
      name: 'Violet',
      imagePath: '/library/Violet_1785491322208.png',
    );
    await addObjective(sgid, 'Left behind');
    await (db.update(db.characters)..where((c) => c.id.equals('dead-uuid')))
        .write(CharactersCompanion(deletedAt: Value(DateTime.now())));

    final report = await DatabaseCleanup.checkOrphans(db);
    expect(
      report.orphanCounts['objectives'],
      1,
      reason: 'cleanup must still do its actual job',
    );
  });
}
