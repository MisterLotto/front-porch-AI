// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Sync-meta, purge, character, and avatar queries.

part of 'database.dart';

/// Sync-meta, purge, character, and avatar queries.
extension AppDatabaseLibraryQueries on AppDatabase {
  // ── Sync Meta Queries ────────────────────────────────────────────────

  /// Get the current sync version (0 if no row exists yet).
  Future<int> getSyncVersion() async {
    try {
      final rows = await customSelect(
        'SELECT version FROM sync_meta WHERE id = 1',
      ).get();
      return rows.isNotEmpty ? rows.first.read<int>('version') : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Increment the sync version counter. Call after every meaningful write.
  Future<void> bumpSyncVersion() async {
    await customUpdate(
      'UPDATE sync_meta SET version = version + 1, '
      'last_modified_at = ? WHERE id = 1',
      variables: [Variable(DateTime.now().millisecondsSinceEpoch ~/ 1000)],
      updates: {syncMeta},
    );
  }

  /// Hard-delete all soft-deleted rows from every table and VACUUM the database
  /// to reclaim disk space. Without this, deleted messages accumulate and bloat
  /// the DB (e.g. 59k deleted messages = 300+ MB of wasted space).
  ///
  /// [skipTables] — optional set of table names (lowercase, e.g. {'characters','groups'})
  ///                whose soft-deleted rows should be left behind. Used before cloud
  ///                sync so that recent character/group deletion flags survive long
  ///                enough for the DB file + merge to propagate them to other devices.
  Future<int> purgeDeletedRows({Set<String> skipTables = const {}}) async {
    int total = 0;
    for (final table in [
      'messages',
      'sessions',
      'characters',
      'groups',
      'folders',
      'personas',
      'worlds',
    ]) {
      if (skipTables.contains(table)) {
        debugPrint(
          '[DB] Skipping purge of soft-deleted rows in $table (deletion signal protection for cloud sync)',
        );
        continue;
      }
      final count = await customUpdate(
        'DELETE FROM $table WHERE deleted_at IS NOT NULL',
        updates: {},
      );
      if (count > 0) {
        debugPrint('[DB] Purged $count deleted rows from $table');
        total += count;
      }
    }
    if (total > 0) {
      debugPrint('[DB] Purged $total deleted rows total — running VACUUM');
      await customStatement('VACUUM');
      debugPrint('[DB] VACUUM complete');
    }
    return total;
  }

  // ── Character Queries ───────────────────────────────────────────────

  Future<List<Character>> getAllCharacters() =>
      (select(characters)..where((c) => c.deletedAt.isNull())).get();

  Stream<List<Character>> watchAllCharacters() =>
      (select(characters)..where((c) => c.deletedAt.isNull())).watch();

  Future<Character> getCharacterById(String id) =>
      (select(characters)..where((c) => c.id.equals(id))).getSingle();

  Future<Character?> getCharacterByImagePath(String path) async {
    // getSingleOrNull() THROWS when two rows share an imagePath — possible for
    // legacy data, and it aborted the whole JSON migration and wedged the app
    // on the migration overlay. Tolerate duplicates, but pick DETERMINISTICALLY
    // (oldest createdAt, then id) rather than a plan-dependent "first" row, so
    // a duplicate never links chat sessions to a random twin across runs.
    final rows =
        await (select(characters)
              ..where((c) => c.imagePath.equals(path) & c.deletedAt.isNull())
              ..orderBy([
                (c) => OrderingTerm(expression: c.createdAt),
                (c) => OrderingTerm(expression: c.id),
              ])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertCharacter(CharactersCompanion character) async {
    // Ensure UUID is set
    if (!character.id.present) {
      character = character.copyWith(id: Value(_uuid.v4()));
    }
    final result = await into(characters).insert(character);
    await bumpSyncVersion();
    return result;
  }

  // insertCharacterReturningId lives on AppDatabase itself, not here — see
  // the doc comment on that method in database.dart for why.

  Future<bool> updateCharacter(CharactersCompanion character) async {
    // IMPORTANT: Use .write() not .replace() — .replace() overwrites the entire
    // row, wiping any fields not explicitly set (Value.absent → null/default).
    // .write() only updates fields where Value.present is true.
    final rows = await (update(
      characters,
    )..where((c) => c.id.equals(character.id.value))).write(character);
    await bumpSyncVersion();
    return rows > 0;
  }

  /// Update ONLY the imagePath for a character (preserves all other data).
  Future<void> updateCharacterImagePath(String id, String newPath) async {
    await (update(characters)..where((c) => c.id.equals(id))).write(
      CharactersCompanion(imagePath: Value(newPath)),
    );
    await bumpSyncVersion();
  }

  Future<int> deleteCharacterById(String id) async {
    // Hard delete: also cascade to sessions and their messages
    final charSessions = await (select(
      sessions,
    )..where((s) => s.characterId.equals(id))).get();
    for (final s in charSessions) {
      await (delete(messages)..where((m) => m.sessionId.equals(s.id))).go();
    }
    await (delete(sessions)..where((s) => s.characterId.equals(id))).go();
    final count = await (delete(
      characters,
    )..where((c) => c.id.equals(id))).go();
    await bumpSyncVersion();
    return count;
  }

  /// Soft-delete a character (sets deletedAt + updatedAt on the row) while
  /// performing the same hard cascade delete of its dependent sessions and
  /// messages. The soft-deleted row remains in the table (with the flag) so
  /// that cloud DB sync + DatabaseMergeService can propagate the deletion
  /// to other devices and prevent resurrection.
  ///
  /// This is the method that should be called from user-facing delete paths
  /// (repositories) when cloud sync is active. The hard `deleteCharacterById`
  /// is retained for internal purge/migration use.
  Future<int> softDeleteCharacterById(String id) async {
    // Hard cascade the child data (sessions + messages). These are not
    // independently surfaced in the UI and do not need soft-delete flags
    // for the character deletion propagation use case.
    final charSessions = await (select(
      sessions,
    )..where((s) => s.characterId.equals(id))).get();
    for (final s in charSessions) {
      await (delete(messages)..where((m) => m.sessionId.equals(s.id))).go();
    }
    await (delete(sessions)..where((s) => s.characterId.equals(id))).go();

    // Soft-delete the primary character row so the flag travels with the DB.
    final now = DateTime.now();
    final count = await (update(characters)..where((c) => c.id.equals(id)))
        .write(
          CharactersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
    await bumpSyncVersion();
    return count;
  }

  // ── Avatar Queries ──────────────────────────────────────────────────

  /// Get all avatar images for a character.
  Future<List<AvatarImage>> getAvatarImagesByCharacterId(
    String characterId,
  ) async {
    return (select(avatarImages)
          ..where((a) => a.characterId.equals(characterId))
          ..orderBy([(a) => OrderingTerm.asc(a.displayOrder)]))
        .get();
  }

  /// Every character's avatars in ONE query, grouped by character id.
  ///
  /// Loading the library used to call [getAvatarImagesByCharacterId] once per
  /// character — an N+1 where each query is also a round trip to the database
  /// isolate (`NativeDatabase.createInBackground`), so the cost is per-call
  /// overhead more than SQL. One grouped query measured ~4x faster and, more
  /// importantly, stops scaling with the size of the library.
  Future<Map<String, List<AvatarImage>>> getAvatarImagesGroupedByCharacter()
  async {
    final rows =
        await (select(avatarImages)..orderBy([
          (a) => OrderingTerm.asc(a.characterId),
          (a) => OrderingTerm.asc(a.displayOrder),
        ])).get();
    final grouped = <String, List<AvatarImage>>{};
    for (final row in rows) {
      (grouped[row.characterId] ??= <AvatarImage>[]).add(row);
    }
    return grouped;
  }

  /// Get a single avatar by ID.
  Future<AvatarImage?> getAvatarById(String id) async {
    return (select(
      avatarImages,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  /// Count avatars for a character (to determine next display order).
  Future<int> countAvatarsForCharacter(String characterId) async {
    final result = await (select(
      avatarImages,
    )..where((a) => a.characterId.equals(characterId))).get();
    return result.length;
  }

  /// Insert an avatar image record.
  Future<void> insertAvatar(AvatarImagesCompanion avatar) async {
    await into(avatarImages).insert(avatar);
    await bumpSyncVersion();
  }

  /// Delete an avatar image record.
  Future<int> deleteAvatar(String id) async {
    final count = await (delete(
      avatarImages,
    )..where((a) => a.id.equals(id))).go();
    await bumpSyncVersion();
    return count;
  }

  /// Update the prime avatar index for a character.
  Future<void> updatePrimeAvatarIndex(
    String characterId,
    int primeIndex,
  ) async {
    await (update(characters)..where((c) => c.id.equals(characterId))).write(
      CharactersCompanion(primeAvatarIndex: Value(primeIndex)),
    );
    await bumpSyncVersion();
  }

  /// Update the label for an avatar image.
  Future<void> updateAvatarLabel(String avatarId, String label) async {
    await (update(avatarImages)..where((a) => a.id.equals(avatarId))).write(
      AvatarImagesCompanion(label: Value(label)),
    );
    await bumpSyncVersion();
  }
}
