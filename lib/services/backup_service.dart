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

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:front_porch_ai/database/database.dart';

/// Creates timestamped backups of the SQLite database.
/// Auto-backup runs every 10 minutes and is always on.
/// Keeps the most recent [maxBackups] copies and prunes older ones.
class BackupService {
  static const int maxBackups = 10;
  static const Duration _autoBackupInterval = Duration(minutes: 10);
  static const String _backupDir = 'backups';
  static Timer? _autoBackupTimer;

  /// Start the automatic backup timer (every 10 minutes).
  /// Safe to call multiple times — will not create duplicate timers.
  static void startAutoBackup() {
    if (_autoBackupTimer != null) return;
    debugPrint('[Backup] Auto-backup started (every ${_autoBackupInterval.inMinutes} minutes)');
    _autoBackupTimer = Timer.periodic(_autoBackupInterval, (_) async {
      try {
        await createBackup();
        await pruneBackups();
      } catch (e) {
        debugPrint('[Backup] Auto-backup failed: $e');
      }
    });
  }

  /// Stop the automatic backup timer.
  static void stopAutoBackup() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;
  }

  /// Get the backup directory path (creates it if needed).
  static Future<Directory> _getBackupDir() async {
    final dbPath = AppDatabase.dbFilePath;
    if (dbPath == null) throw StateError('Database path not initialized');
    final parentDir = path.dirname(dbPath); // .../KoboldManager/
    final backupDir = Directory(path.join(parentDir, _backupDir));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Copy the current DB to a timestamped backup file.
  /// Returns the backup path, or null if the DB doesn't exist.
  static Future<String?> createBackup() async {
    final dbPath = AppDatabase.dbFilePath;
    if (dbPath == null) return null;

    final dbFile = File(dbPath);
    if (!await dbFile.exists()) return null;

    // Checkpoint WAL so the .db file is self-contained
    try {
      final db = await AppDatabase.instance();
      await db.checkpoint();
    } catch (e) {
      debugPrint('[Backup] WAL checkpoint failed: $e');
    }

    final backupDir = await _getBackupDir();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final backupPath = path.join(backupDir.path, 'front_porch_$timestamp.db');

    await dbFile.copy(backupPath);
    debugPrint('[Backup] Created backup: $backupPath');
    return backupPath;
  }

  /// List available backups (newest first).
  static Future<List<File>> listBackups() async {
    try {
      final backupDir = await _getBackupDir();
      final files = <File>[];
      await for (final entity in backupDir.list()) {
        if (entity is File && entity.path.endsWith('.db')) {
          files.add(entity);
        }
      }
      // Sort by modified time, newest first
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      return files;
    } catch (_) {
      return [];
    }
  }

  /// Restore a specific backup (replaces the live DB).
  /// The caller MUST close and reopen the database after calling this.
  static Future<void> restoreBackup(String backupPath) async {
    final dbPath = AppDatabase.dbFilePath;
    if (dbPath == null) throw StateError('Database path not initialized');

    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw FileSystemException('Backup file not found', backupPath);
    }

    // Close the live DB
    await AppDatabase.closeAndReset();

    // Replace with backup
    await backupFile.copy(dbPath);
    // Remove stale WAL/SHM
    try { await File('$dbPath-wal').delete(); } catch (_) {}
    try { await File('$dbPath-shm').delete(); } catch (_) {}

    debugPrint('[Backup] Restored backup from: $backupPath');
  }

  /// Delete backups older than the most recent [maxBackups].
  static Future<void> pruneBackups() async {
    final backups = await listBackups();
    if (backups.length <= maxBackups) return;

    for (var i = maxBackups; i < backups.length; i++) {
      try {
        await backups[i].delete();
        debugPrint('[Backup] Pruned old backup: ${backups[i].path}');
      } catch (e) {
        debugPrint('[Backup] Failed to prune: $e');
      }
    }
  }

  /// Delete ALL backups. Used during major schema upgrades (e.g. 0.9.0
  /// reunification) to prevent restoring old-schema backups that would corrupt
  /// the database.
  static Future<void> purgeAllBackups() async {
    final backups = await listBackups();
    for (final backup in backups) {
      try {
        await backup.delete();
        debugPrint('[Backup] Purged old backup: ${backup.path}');
      } catch (e) {
        debugPrint('[Backup] Failed to purge: $e');
      }
    }
    debugPrint('[Backup] Purged ${backups.length} old backups');
  }
}
