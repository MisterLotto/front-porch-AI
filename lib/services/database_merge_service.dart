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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:front_porch_ai/database/database.dart';

/// Row-level merge service for cloud sync.
///
/// Instead of replacing the entire database file, this service opens both
/// the local DB and a downloaded remote DB, then merges row-by-row using
/// UUID primary keys and `updatedAt` timestamps for conflict resolution.
///
/// Merge order respects FK dependencies:
///   Folders → Characters → Groups → Personas → Worlds → Sessions → Messages
class DatabaseMergeService {
  /// Merge a remote database file into the local database.
  ///
  /// [remoteTempPath] is the path to the downloaded remote DB file.
  /// Returns true if any changes were made to the local DB.
  static Future<bool> mergeRemoteIntoLocal(
    AppDatabase localDb,
    String remoteTempPath,
  ) async {
    final tempFile = File(remoteTempPath);
    if (!await tempFile.exists()) return false;

    // Open the remote DB as a raw NativeDatabase (no migrations)
    final remoteDb = NativeDatabase(tempFile);
    await remoteDb.ensureOpen(_MergeDbUser());

    bool anyChanges = false;

    try {
      // Merge in FK-dependency order
      anyChanges |= await _mergeFolders(localDb, remoteDb);
      anyChanges |= await _mergeCharacters(localDb, remoteDb);
      anyChanges |= await _mergeGroups(localDb, remoteDb);
      anyChanges |= await _mergePersonas(localDb, remoteDb);
      anyChanges |= await _mergeWorlds(localDb, remoteDb);
      anyChanges |= await _mergeSessions(localDb, remoteDb);
      anyChanges |= await _mergeMessages(localDb, remoteDb);

      if (anyChanges) {
        // Bump the sync version so the next sync knows we have changes
        await localDb.bumpSyncVersion();
        debugPrint('[Merge] Merge complete — local DB updated');
      } else {
        debugPrint('[Merge] Merge complete — no changes needed');
      }
    } catch (e) {
      debugPrint('[Merge] Error during merge: $e');
      rethrow;
    } finally {
      await remoteDb.close();
    }

    return anyChanges;
  }

  // ── Generic merge helper ──────────────────────────────────────────

  /// Generic merge for a table. Reads all rows from both local and remote,
  /// compares by UUID, and applies inserts/updates based on updatedAt.
  ///
  /// [tableName] — SQL table name
  /// [localDb] — the live AppDatabase for executing writes
  /// [remoteDb] — the raw remote NativeDatabase for reads
  /// [idColumn] — the name of the UUID primary key column (usually 'id')
  /// [updatedAtColumn] — column name for updatedAt timestamp
  /// [deletedAtColumn] — column name for deletedAt timestamp (soft delete)
  /// [buildInsert] — given a remote row map, return the SQL INSERT statement
  static Future<bool> _mergeTable({
    required String tableName,
    required AppDatabase localDb,
    required QueryExecutor remoteDb,
    String idColumn = 'id',
    String updatedAtColumn = 'updated_at',
    String deletedAtColumn = 'deleted_at',
  }) async {
    bool changed = false;

    // Read all rows from remote
    List<Map<String, Object?>> remoteRows;
    try {
      final result = await remoteDb.runSelect('SELECT * FROM $tableName', []);
      remoteRows = result;
    } catch (e) {
      debugPrint('[Merge] Could not read remote table $tableName: $e');
      return false;
    }

    if (remoteRows.isEmpty) return false;

    // Read all rows from local, keyed by ID
    final localResult = await localDb.customSelect('SELECT * FROM $tableName').get();
    final localById = <String, QueryRow>{};
    for (final row in localResult) {
      // Use .toString() because SQLite may return numeric-looking text as int
      final id = row.data[idColumn]?.toString() ?? '';
      localById[id] = row;
    }

    for (final remoteRow in remoteRows) {
      final remoteId = remoteRow[idColumn]?.toString() ?? '';
      final remoteUpdatedAt = remoteRow[updatedAtColumn] as int? ?? 0;
      final remoteDeletedAt = remoteRow[deletedAtColumn] as int?;

      final localRow = localById[remoteId];

      if (localRow == null) {
        // Row exists only in remote → INSERT into local
        await _insertRow(localDb, tableName, remoteRow);
        changed = true;
        debugPrint('[Merge] INSERT $tableName $remoteId');
      } else {
        // Row exists in both → compare updatedAt
        final localUpdatedAt = localRow.data[updatedAtColumn] as int? ?? 0;
        final localDeletedAt = localRow.data[deletedAtColumn] as int?;

        if (remoteUpdatedAt > localUpdatedAt) {
          // Remote is newer → UPDATE local
          await _updateRow(localDb, tableName, idColumn, remoteId, remoteRow);
          changed = true;
          debugPrint('[Merge] UPDATE $tableName $remoteId (remote ${remoteUpdatedAt} > local ${localUpdatedAt})');
        } else if (remoteDeletedAt != null && localDeletedAt == null && remoteUpdatedAt >= localUpdatedAt) {
          // Remote was deleted, local wasn't, and remote is at least as new → soft delete local
          await localDb.customUpdate(
            'UPDATE $tableName SET $deletedAtColumn = ?, $updatedAtColumn = ? WHERE $idColumn = ?',
            variables: [Variable(remoteDeletedAt), Variable(remoteUpdatedAt), Variable(remoteId)],
            updates: {},
          );
          changed = true;
          debugPrint('[Merge] SOFT-DELETE $tableName $remoteId');
        }
      }
    }

    return changed;
  }

  /// Insert a complete row into a table using raw SQL.
  static Future<void> _insertRow(
    AppDatabase db,
    String tableName,
    Map<String, Object?> row,
  ) async {
    final columns = row.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    final values = columns.map((c) => Variable(row[c])).toList();

    await db.customInsert(
      'INSERT OR IGNORE INTO $tableName (${columns.join(', ')}) VALUES ($placeholders)',
      variables: values,
    );
  }

  /// Update a complete row in a table using raw SQL.
  static Future<void> _updateRow(
    AppDatabase db,
    String tableName,
    String idColumn,
    String id,
    Map<String, Object?> row,
  ) async {
    final setClauses = row.keys
        .where((c) => c != idColumn)
        .map((c) => '$c = ?')
        .toList();
    final values = row.keys
        .where((c) => c != idColumn)
        .map((c) => Variable(row[c]))
        .toList();
    values.add(Variable(id));

    await db.customUpdate(
      'UPDATE $tableName SET ${setClauses.join(', ')} WHERE $idColumn = ?',
      variables: values,
      updates: {},
    );
  }

  // ── Per-table merge methods ───────────────────────────────────────

  static Future<bool> _mergeFolders(AppDatabase localDb, QueryExecutor remoteDb) {
    return _mergeTable(
      tableName: 'folders',
      localDb: localDb,
      remoteDb: remoteDb,
    );
  }

  static Future<bool> _mergeCharacters(AppDatabase localDb, QueryExecutor remoteDb) {
    return _mergeTable(
      tableName: 'characters',
      localDb: localDb,
      remoteDb: remoteDb,
    );
  }

  static Future<bool> _mergeGroups(AppDatabase localDb, QueryExecutor remoteDb) {
    return _mergeTable(
      tableName: 'groups',
      localDb: localDb,
      remoteDb: remoteDb,
    );
  }

  static Future<bool> _mergePersonas(AppDatabase localDb, QueryExecutor remoteDb) {
    return _mergeTable(
      tableName: 'personas',
      localDb: localDb,
      remoteDb: remoteDb,
    );
  }

  static Future<bool> _mergeWorlds(AppDatabase localDb, QueryExecutor remoteDb) {
    return _mergeTable(
      tableName: 'worlds',
      localDb: localDb,
      remoteDb: remoteDb,
    );
  }

  static Future<bool> _mergeSessions(AppDatabase localDb, QueryExecutor remoteDb) {
    return _mergeTable(
      tableName: 'sessions',
      localDb: localDb,
      remoteDb: remoteDb,
    );
  }

  static Future<bool> _mergeMessages(AppDatabase localDb, QueryExecutor remoteDb) {
    return _mergeTable(
      tableName: 'messages',
      localDb: localDb,
      remoteDb: remoteDb,
    );
  }
}

/// Minimal QueryExecutorUser for opening the remote DB without running migrations.
class _MergeDbUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 3;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {
    // No-op — we only read from this DB, no migrations should run
  }
}
