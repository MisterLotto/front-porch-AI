// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One-shot data migrations invoked from the ladder (v3 UUID rewrite, v40
// Living Worlds).

part of 'database.dart';

/// One-shot data migrations invoked from the ladder (v3 UUID rewrite, v40 Living Worlds).
extension _AppDatabaseDataMigrations on AppDatabase {
  /// Living Worlds schema + name→UUID backfill (phase 0) and biome span
  /// table (phase 1).
  ///
  /// **Re-run policy:** schema pieces (ALTER + CREATE IF NOT EXISTS) are
  /// tolerant of a second pass. The destructive **data mutations are gated on
  /// `columnsAddedNow`** — i.e. they fire only on the pass that actually
  /// introduced the v40 columns. The ladder's `if (from < 40)` is NOT enough
  /// on its own: drift rewrites user_version even when an OLDER binary opens a
  /// newer DB (rollback / dual-run — see the same note on the v37 step), so
  /// this whole method can legally re-enter with `from = 39` against a
  /// database that was migrated months ago. Without the gate: (1)
  /// `inject_description = 0` clobbers every world's user toggle, silently
  /// dropping place descriptions out of the prompt; (2) `groups.world_ids` is
  /// rewritten in place and drops refs that no longer resolve (original name
  /// lists live only in the pre-migration backup — not preserved in the live
  /// DB for re-run inspection); (3) the chat_worlds seed resurrects world
  /// links the user had since removed.
  Future<void> _migrateLivingWorldsV40() async {
    try {
      await _createPreRepairBackup();
    } catch (e) {
      debugPrint('[DB] v40: pre-migration backup skipped: $e');
    }

    // worlds columns (re-runnable). A successful ALTER is the ONLY honest
    // signal that this pass is the real 39→40 upgrade: once the column exists,
    // its value is the user's, not the migration's, and must not be rewritten.
    var columnsAddedNow = false;
    for (final def in [
      'cover_image TEXT',
      'format_version INTEGER NOT NULL DEFAULT 1',
      'source_id TEXT',
      'linked_character_id TEXT',
      'biome_id TEXT',
      'biome_json TEXT',
      'inject_description INTEGER NOT NULL DEFAULT 1',
    ]) {
      final col = def.split(' ').first;
      try {
        await customStatement('ALTER TABLE worlds ADD COLUMN $def');
        debugPrint('[DB] v40: added worlds.$col');
        if (col == 'inject_description') columnsAddedNow = true;
      } catch (_) {
        // already present (re-run / dual-version)
      }
    }

    await customStatement('''
      CREATE TABLE IF NOT EXISTS chat_worlds (
        id TEXT NOT NULL PRIMARY KEY,
        chat_id TEXT NOT NULL,
        world_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_chat_worlds_chat ON chat_worlds(chat_id)',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS chat_biome_spans (
        id TEXT NOT NULL PRIMARY KEY,
        chat_id TEXT NOT NULL,
        effective_from_day INTEGER NOT NULL,
        biome_json TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_chat_biome_spans_chat '
      'ON chat_biome_spans(chat_id)',
    );

    // Migrated library worlds: descriptions were labels → don't inject.
    // Unconditional UPDATE, so it may ONLY run on the pass that created the
    // column — on a re-entry these are the user's own toggles.
    if (columnsAddedNow) {
      try {
        await customStatement(
          'UPDATE worlds SET inject_description = 0, format_version = 1',
        );
      } catch (e) {
        debugPrint('[DB] v40: inject_description defaulting failed: $e');
      }
    }

    // Backfill linked_character_id from linked_character_name.
    try {
      final worlds = await customSelect(
        'SELECT id, linked_character_name FROM worlds '
        'WHERE linked_character_name IS NOT NULL AND linked_character_name != \'\' '
        'AND (linked_character_id IS NULL OR linked_character_id = \'\')',
      ).get();
      for (final row in worlds) {
        final wId = row.data['id'] as String?;
        final cName = row.data['linked_character_name'] as String?;
        if (wId == null || cName == null) continue;
        final chars = await customSelect(
          'SELECT id FROM characters WHERE name = ? AND deleted_at IS NULL LIMIT 1',
          variables: [Variable(cName)],
        ).get();
        if (chars.isEmpty) continue;
        final cId = chars.first.data['id'] as String?;
        if (cId == null) continue;
        await customStatement(
          'UPDATE worlds SET linked_character_id = ? WHERE id = ?',
          [cId, wId],
        );
      }
    } catch (e) {
      debugPrint('[DB] v40: linked_character_id backfill failed: $e');
    }

    // Name→UUID for groups.world_ids + seed chat_worlds for existing sessions.
    // Rewrites groups.world_ids in place — pre-migration name lists survive
    // only in the forced backup file, not as a re-runnable live snapshot. On a
    // re-entry the refs are already UUIDs, so a second pass can only drop the
    // ones that stopped resolving and re-seed chat links the user removed.
    if (!columnsAddedNow) {
      debugPrint(
        '[DB] v40: worlds columns already present — skipping the one-shot '
        'data migration (re-run after a version rollback)',
      );
      return;
    }
    try {
      final worldRows = await customSelect(
        'SELECT id, name FROM worlds WHERE deleted_at IS NULL',
      ).get();
      final nameToId = <String, String>{};
      final validIds = <String>{};
      for (final r in worldRows) {
        final id = r.data['id']?.toString();
        final name = r.data['name']?.toString();
        if (id == null) continue;
        validIds.add(id);
        if (name != null) nameToId[name] = id;
      }

      final groups = await customSelect(
        'SELECT id, world_ids FROM groups WHERE deleted_at IS NULL',
      ).get();
      var unresolvedTotal = 0;
      var groupsRewritten = 0;
      var chatLinks = 0;

      for (final g in groups) {
        final gId = g.data['id']?.toString();
        if (gId == null) continue;
        final raw = g.data['world_ids']?.toString() ?? '[]';
        List<String> refs = const [];
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            refs = [
              for (final e in decoded)
                if (e != null && e.toString().isNotEmpty) e.toString(),
            ];
          }
        } catch (_) {
          refs = const [];
        }
        final unresolved = <String>[];
        final ids = <String>[];
        final seen = <String>{};
        for (final ref in refs) {
          final id = validIds.contains(ref) ? ref : nameToId[ref];
          if (id == null) {
            unresolved.add(ref);
            continue;
          }
          if (seen.add(id)) ids.add(id);
        }
        unresolvedTotal += unresolved.length;
        if (unresolved.isNotEmpty) {
          debugPrint(
            '[DB] v40: group $gId dropped unresolved world refs: $unresolved',
          );
        }
        final encoded = jsonEncode(ids);
        if (encoded != raw) {
          await customStatement(
            'UPDATE groups SET world_ids = ? WHERE id = ?',
            [encoded, gId],
          );
          groupsRewritten++;
        }

        // Sessions for this group → chat_worlds. Skip when the pair already
        // exists (PK is only link id, so INSERT OR IGNORE alone would
        // duplicate on a second pass).
        final sessions = await customSelect(
          'SELECT id FROM sessions WHERE group_id = ? AND deleted_at IS NULL',
          variables: [Variable(gId)],
        ).get();
        for (final s in sessions) {
          final sid = s.data['id']?.toString();
          if (sid == null) continue;
          var order = 0;
          for (final wid in ids) {
            try {
              final exists = await customSelect(
                'SELECT 1 AS o FROM chat_worlds '
                'WHERE chat_id = ? AND world_id = ? LIMIT 1',
                variables: [Variable(sid), Variable(wid)],
              ).get();
              if (exists.isNotEmpty) {
                order++;
                continue;
              }
              await customStatement(
                'INSERT INTO chat_worlds '
                '(id, chat_id, world_id, sort_order, created_at) '
                'VALUES (?, ?, ?, ?, ?)',
                [
                  _uuid.v4(),
                  sid,
                  wid,
                  order++,
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
                ],
              );
              chatLinks++;
            } catch (e) {
              debugPrint('[DB] v40: chat_worlds insert failed: $e');
            }
          }
        }
      }
      debugPrint(
        '[DB] v40 Living Worlds: groups rewritten=$groupsRewritten, '
        'chat_world links=$chatLinks, unresolved refs=$unresolvedTotal '
        '(original name lists only in pre-migration backup)',
      );
    } catch (e, st) {
      debugPrint('[DB] v40: world ref backfill failed: $e\n$st');
    }
  }

  /// Migrate all int-keyed tables to UUID text PKs.
  /// Creates new tables, copies data with generated UUIDs, drops old, renames.
  Future<void> _migrateToUuids() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // ── Folders ──────────────────────────────────────────────────
    await customStatement(
      'CREATE TABLE folders_new ('
      'id TEXT NOT NULL, name TEXT NOT NULL, parent_id TEXT, '
      'updated_at INTEGER NOT NULL DEFAULT $now, '
      'deleted_at INTEGER, PRIMARY KEY (id))',
    );
    // Build oldId→uuid map
    final oldFolders = await customSelect(
      'SELECT id, name, parent_id FROM folders',
    ).get();
    final folderIdMap = <int, String>{}; // old int → new uuid
    for (final row in oldFolders) {
      final oldId = row.read<int>('id');
      folderIdMap[oldId] = _uuid.v4();
    }
    for (final row in oldFolders) {
      final oldId = row.read<int>('id');
      final newId = folderIdMap[oldId]!;
      final oldParent = row.readNullable<int>('parent_id');
      final newParent = oldParent != null ? folderIdMap[oldParent] : null;
      await customInsert(
        'INSERT INTO folders_new (id, name, parent_id, updated_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable(newId),
          Variable(row.read<String>('name')),
          Variable(newParent),
          Variable(now),
        ],
      );
    }
    await customStatement('DROP TABLE folders');
    await customStatement('ALTER TABLE folders_new RENAME TO folders');

    // ── Characters ───────────────────────────────────────────────
    await customStatement(
      'CREATE TABLE characters_new ('
      'id TEXT NOT NULL, name TEXT NOT NULL, '
      'description TEXT NOT NULL DEFAULT \'\', personality TEXT NOT NULL DEFAULT \'\', '
      'scenario TEXT NOT NULL DEFAULT \'\', first_message TEXT NOT NULL DEFAULT \'\', '
      'mes_example TEXT NOT NULL DEFAULT \'\', system_prompt TEXT NOT NULL DEFAULT \'\', '
      'post_history_instructions TEXT NOT NULL DEFAULT \'\', '
      'alternate_greetings TEXT NOT NULL DEFAULT \'[]\', '
      'tags TEXT NOT NULL DEFAULT \'[]\', '
      'image_path TEXT, tts_voice TEXT, folder_id TEXT, '
      'lorebook TEXT, world_names TEXT NOT NULL DEFAULT \'[]\', '
      'created_at INTEGER NOT NULL DEFAULT $now, '
      'updated_at INTEGER NOT NULL DEFAULT $now, '
      'deleted_at INTEGER, PRIMARY KEY (id))',
    );
    final oldChars = await customSelect('SELECT * FROM characters').get();
    final charIdMap = <int, String>{}; // old int → new uuid
    for (final row in oldChars) {
      final oldId = row.read<int>('id');
      charIdMap[oldId] = _uuid.v4();
    }
    for (final row in oldChars) {
      final oldId = row.read<int>('id');
      final newId = charIdMap[oldId]!;
      final oldFolderId = row.readNullable<int>('folder_id');
      final newFolderId = oldFolderId != null ? folderIdMap[oldFolderId] : null;
      await customInsert(
        'INSERT INTO characters_new (id, name, description, personality, scenario, '
        'first_message, mes_example, system_prompt, post_history_instructions, '
        'alternate_greetings, tags, image_path, tts_voice, folder_id, '
        'lorebook, world_names, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(newId),
          Variable(row.read<String>('name')),
          Variable(row.read<String>('description')),
          Variable(row.read<String>('personality')),
          Variable(row.read<String>('scenario')),
          Variable(row.read<String>('first_message')),
          Variable(row.read<String>('mes_example')),
          Variable(row.read<String>('system_prompt')),
          Variable(row.read<String>('post_history_instructions')),
          Variable(row.read<String>('alternate_greetings')),
          Variable(row.read<String>('tags')),
          Variable(row.readNullable<String>('image_path')),
          Variable(row.readNullable<String>('tts_voice')),
          Variable(newFolderId),
          Variable(row.readNullable<String>('lorebook')),
          Variable(row.read<String>('world_names')),
          Variable(row.read<int>('created_at')),
          Variable(row.read<int>('updated_at')),
        ],
      );
    }
    await customStatement('DROP TABLE characters');
    await customStatement('ALTER TABLE characters_new RENAME TO characters');

    // ── Sessions (already text PK, just remap characterId int→text, add deletedAt) ──
    await customStatement(
      'CREATE TABLE sessions_new ('
      'id TEXT NOT NULL, character_id TEXT, group_id TEXT, '
      'name TEXT, description TEXT, '
      'author_note TEXT NOT NULL DEFAULT \'\', '
      'author_note_depth INTEGER NOT NULL DEFAULT 4, '
      'parent_session TEXT, fork_index INTEGER, '
      'created_at INTEGER NOT NULL DEFAULT $now, '
      'updated_at INTEGER NOT NULL DEFAULT $now, '
      'deleted_at INTEGER, PRIMARY KEY (id))',
    );
    final oldSessions = await customSelect('SELECT * FROM sessions').get();
    for (final row in oldSessions) {
      final oldCharId = row.readNullable<int>('character_id');
      final newCharId = oldCharId != null ? charIdMap[oldCharId] : null;
      await customInsert(
        'INSERT INTO sessions_new (id, character_id, group_id, name, description, '
        'author_note, author_note_depth, parent_session, fork_index, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(row.read<String>('id')),
          Variable(newCharId),
          Variable(row.readNullable<String>('group_id')),
          Variable(row.readNullable<String>('name')),
          Variable(row.readNullable<String>('description')),
          Variable(row.read<String>('author_note')),
          Variable(row.read<int>('author_note_depth')),
          Variable(row.readNullable<String>('parent_session')),
          Variable(row.readNullable<int>('fork_index')),
          Variable(row.read<int>('created_at')),
          Variable(row.read<int>('updated_at')),
        ],
      );
    }
    await customStatement('DROP TABLE sessions');
    await customStatement('ALTER TABLE sessions_new RENAME TO sessions');

    // ── Messages (int PK → text UUID, add updatedAt/deletedAt) ──
    await customStatement(
      'CREATE TABLE messages_new ('
      'id TEXT NOT NULL, session_id TEXT NOT NULL, '
      'position INTEGER NOT NULL, sender TEXT NOT NULL, '
      'is_user INTEGER NOT NULL, character_id TEXT, '
      'swipes TEXT NOT NULL DEFAULT \'[]\', '
      'swipe_index INTEGER NOT NULL DEFAULT 0, '
      'swipe_durations TEXT NOT NULL DEFAULT \'[]\', '
      'updated_at INTEGER NOT NULL DEFAULT $now, '
      'deleted_at INTEGER, PRIMARY KEY (id))',
    );
    final oldMsgs = await customSelect('SELECT * FROM messages').get();
    for (final row in oldMsgs) {
      await customInsert(
        'INSERT INTO messages_new (id, session_id, position, sender, is_user, '
        'character_id, swipes, swipe_index, swipe_durations, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(_uuid.v4()), // generate UUID for each message
          Variable(row.read<String>('session_id')),
          Variable(row.read<int>('position')),
          Variable(row.read<String>('sender')),
          Variable(row.read<bool>('is_user') ? 1 : 0),
          Variable(row.readNullable<String>('character_id')),
          Variable(row.read<String>('swipes')),
          Variable(row.read<int>('swipe_index')),
          Variable(row.read<String>('swipe_durations')),
          Variable(now),
        ],
      );
    }
    await customStatement('DROP TABLE messages');
    await customStatement('ALTER TABLE messages_new RENAME TO messages');

    // ── Groups (already text PK, just add updatedAt/deletedAt) ──
    await customStatement(
      'ALTER TABLE groups ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $now',
    );
    await customStatement('ALTER TABLE groups ADD COLUMN deleted_at INTEGER');

    // ── Personas (already text PK, just add updatedAt/deletedAt) ──
    await customStatement(
      'ALTER TABLE personas ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $now',
    );
    await customStatement('ALTER TABLE personas ADD COLUMN deleted_at INTEGER');

    // ── Worlds (int PK → text UUID, add updatedAt/deletedAt) ──
    await customStatement(
      'CREATE TABLE worlds_new ('
      'id TEXT NOT NULL, name TEXT NOT NULL UNIQUE, '
      'description TEXT NOT NULL DEFAULT \'\', '
      'lorebook TEXT, linked_character_name TEXT, '
      'updated_at INTEGER NOT NULL DEFAULT $now, '
      'deleted_at INTEGER, PRIMARY KEY (id))',
    );
    final oldWorlds = await customSelect('SELECT * FROM worlds').get();
    for (final row in oldWorlds) {
      await customInsert(
        'INSERT INTO worlds_new (id, name, description, lorebook, linked_character_name, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(_uuid.v4()),
          Variable(row.read<String>('name')),
          Variable(row.read<String>('description')),
          Variable(row.readNullable<String>('lorebook')),
          Variable(row.readNullable<String>('linked_character_name')),
          Variable(now),
        ],
      );
    }
    await customStatement('DROP TABLE worlds');
    await customStatement('ALTER TABLE worlds_new RENAME TO worlds');
  }
}
