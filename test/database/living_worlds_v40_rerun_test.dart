// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The v39→v40 Living Worlds migration must never run its one-shot data
// mutations twice.
//
// Drift rewrites user_version whenever the version it opens with differs from
// the file's — INCLUDING when an OLDER binary opens a NEWER database (a
// version rollback, or the Windows beta+nightly pair that share one data
// folder). The old binary's onUpgrade does nothing (every `from < N` is
// false), but it stamps the file back down to its own schemaVersion. The next
// launch of the newer binary therefore re-enters the ladder at `from = 39`.
//
// The v40 block's `UPDATE worlds SET inject_description = 0` has no WHERE
// clause, so that second pass silently switched OFF description injection for
// every world the user had turned ON — their places just stopped appearing in
// the prompt, with nothing to see and nothing to blame. The ladder's
// neighbours (v37, v38, v41…) already carry this exact guard; v40's data
// mutation did not.
//
// This test replays the real ladder against a database that already has the
// v40 columns, which is precisely the post-rollback state.

import 'package:drift/drift.dart' show Migrator, Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(sameIsolate: true));
  tearDown(() async => db.close());

  Future<int> injectFlag(String id) async {
    final row = await db
        .customSelect(
          'SELECT inject_description FROM worlds WHERE id = ?',
          variables: [Variable(id)],
        )
        .getSingle();
    return row.read<int>('inject_description');
  }

  /// Replays the upgrade ladder from v39 the way a re-stamped database does.
  Future<void> rerunLadderFrom39() async {
    await db.migration.onUpgrade(Migrator(db), 39, db.schemaVersion);
  }

  test('a re-run of the v40 step keeps the user\'s injectDescription', () async {
    // Two worlds, both with the toggle ON — the state of any world created
    // after the real migration, plus any the user switched back on.
    await db.customStatement(
      "INSERT INTO worlds (id, name, description, inject_description) "
      "VALUES ('w1', 'Harborview', 'A salt-bleached fishing town.', 1)",
    );
    await db.customStatement(
      "INSERT INTO worlds (id, name, description, inject_description) "
      "VALUES ('w2', 'The Longhouse', 'Smoke and old wood.', 1)",
    );

    await rerunLadderFrom39();

    expect(
      await injectFlag('w1'),
      1,
      reason: 'the columns already existed, so this pass is a re-entry after a '
          'rollback — the value is the user\'s setting, not the migration\'s',
    );
    expect(await injectFlag('w2'), 1);
  });

  test('the REAL first pass still migrates (the gate is not a mute)', () async {
    // Put the table back into its v39 shape: no inject_description, no
    // format_version. This is the state of every database the migration was
    // written for, and the pass that ADDs the columns is the one allowed to
    // rewrite them.
    await db.customStatement('ALTER TABLE worlds DROP COLUMN inject_description');
    await db.customStatement('ALTER TABLE worlds DROP COLUMN format_version');
    await db.customStatement(
      "INSERT INTO worlds (id, name, description) "
      "VALUES ('w-old', 'Harborview', 'A label, not a description.')",
    );
    await db.customStatement(
      "INSERT INTO groups (id, name, character_ids, world_ids) "
      "VALUES ('g-old', 'The Crew', '[]', '[\"Harborview\"]')",
    );

    await rerunLadderFrom39();

    expect(
      await injectFlag('w-old'),
      0,
      reason: 'worlds that predate Living Worlds carried label-style '
          'descriptions — the genuine upgrade must still switch them off',
    );
    final group = await db
        .customSelect("SELECT world_ids FROM groups WHERE id = 'g-old'")
        .getSingle();
    expect(
      group.read<String>('world_ids'),
      '["w-old"]',
      reason: 'the genuine upgrade must still rewrite group world names to ids',
    );
  });

  test('a re-run does not rewrite group world links', () async {
    // After the real migration these are already UUIDs. A second pass drops
    // any that no longer resolve (a world the user has since deleted), which
    // is silent data loss the pre-migration backup can no longer undo.
    await db.customStatement(
      "INSERT INTO worlds (id, name, description) "
      "VALUES ('w-live', 'Harborview', '')",
    );
    await db.customStatement(
      "INSERT INTO groups (id, name, character_ids, world_ids) "
      "VALUES ('g1', 'The Crew', '[]', '[\"w-live\",\"w-gone\"]')",
    );

    await rerunLadderFrom39();

    final row = await db
        .customSelect("SELECT world_ids FROM groups WHERE id = 'g1'")
        .getSingle();
    expect(
      row.read<String>('world_ids'),
      '["w-live","w-gone"]',
      reason: 'the one-shot name→UUID rewrite must not fire again',
    );
  });
}
