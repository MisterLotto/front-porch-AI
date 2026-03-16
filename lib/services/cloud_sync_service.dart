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
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/database_merge_service.dart';
import 'package:front_porch_ai/services/cloud_providers/google_drive_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Information about a remote file.
class RemoteFileInfo {
  final String remotePath;
  final DateTime? lastModified;
  final int? size;

  RemoteFileInfo({required this.remotePath, this.lastModified, this.size});
}

/// Status of the sync operation.
enum SyncStatus { idle, syncing, error, success }

/// Abstract interface for cloud storage providers.
abstract class CloudStorageProvider {
  /// Connect using provider-specific credentials.
  Future<void> connect(Map<String, String> credentials);

  /// Disconnect and clean up.
  Future<void> disconnect();

  /// Whether the provider is currently connected.
  bool get isConnected;

  /// Display name for the provider.
  String get displayName;

  /// List files at the given remote path (recursive).
  Future<List<RemoteFileInfo>> listFiles(String remotePath);

  /// Upload a local file to the remote path.
  Future<void> uploadFile(String localPath, String remotePath);

  /// Download a remote file to local path.
  Future<void> downloadFile(String remotePath, String localPath);

  /// Ensure a remote directory exists.
  Future<void> ensureDir(String remotePath);

  /// Delete a remote file.
  Future<void> deleteFile(String remotePath);

  /// Delete a remote directory and all its contents.
  Future<void> deleteDirectory(String remotePath);
}

/// Orchestrates cloud sync with a pluggable provider.
class CloudSyncService extends ChangeNotifier {
  CloudStorageProvider? _provider;
  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncTime;
  int _syncedFiles = 0;
  int _totalFiles = 0;
  int _processedFiles = 0;

  SyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get syncedFiles => _syncedFiles;
  bool get isConnected => _provider?.isConnected ?? false;
  String? get providerName => _provider?.displayName;

  /// Progress from 0.0 to 1.0 during sync.
  double get progress => _totalFiles > 0 ? (_processedFiles / _totalFiles).clamp(0.0, 1.0) : 0.0;
  int get totalFiles => _totalFiles;
  int get processedFiles => _processedFiles;

  /// Set the active cloud storage provider.
  void setProvider(CloudStorageProvider? provider) {
    _provider = provider;
    notifyListeners();
  }

  /// Get the active cloud storage provider.
  CloudStorageProvider? get provider => _provider;

  /// Disconnect and clear the active provider.
  void clearProvider() {
    _provider = null;
    _status = SyncStatus.idle;
    notifyListeners();
  }

  /// Run a full bi-directional sync of characters and the database.
  Future<void> fullSync(String chatsDir, String charactersDir, {
    Set<String>? validCharIds,
    Set<String>? validGroupIds,
  }) async {
    if (_provider == null || !_provider!.isConnected) return;

    _status = SyncStatus.syncing;
    _lastError = null;
    _syncedFiles = 0;
    _totalFiles = 0;
    _processedFiles = 0;
    _dbWasDownloaded = false;
    notifyListeners();

    try {
      // One-time cloud data purge after 0.9.0 upgrade.
      // The old cloud DB is schema v1/v2/v3 with different UUIDs — merging
      // it would cause duplicates. Purge it and do a fresh upload.
      final prefs = await SharedPreferences.getInstance();
      final didPurge = !(prefs.getBool('cloud_purged_for_0.9.0') ?? false);
      if (didPurge) {
        debugPrint('[CloudSync] Purging stale cloud data for 0.9.0 fresh start');
        try {
          await purgeCloudData();
        } catch (e) {
          debugPrint('[CloudSync] Purge failed (non-fatal): $e');
        }
        await prefs.setBool('cloud_purged_for_0.9.0', true);
        debugPrint('[CloudSync] Cloud purge complete — uploading fresh data');
      }

      // Ensure remote directories exist
      await _provider!.ensureDir('/FrontPorchAI');
      await _provider!.ensureDir('/FrontPorchAI/characters');

      // Count total files for progress tracking
      _totalFiles = 1 + await _countSyncFiles( // +1 for DB file
        charactersDir, '/FrontPorchAI/characters', false, ['.png'],
      );
      notifyListeners();

      if (didPurge) {
        // After purge, skip normal _syncDatabase (version mismatches confuse it).
        // Just checkpoint and upload the local DB directly.
        final localPath = AppDatabase.dbFilePath;
        if (localPath != null) {
          final db = await AppDatabase.instance();
          await db.bumpSyncVersion();
          await db.checkpoint();
          await _provider!.uploadFile(localPath, '/FrontPorchAI/front_porch.db');
          _syncedFiles++;
          _processedFiles++;
          notifyListeners();
          debugPrint('[CloudSync] Fresh upload complete after purge');
        }
      } else {
        // Normal sync flow
        debugPrint('[CloudSync] Starting database sync...');
        await _syncDatabase();
        debugPrint('[CloudSync] Database sync complete.');
      }

      // Sync characters (bi-directional for PNGs)
      debugPrint('[CloudSync] Starting character file sync...');
      try {
        await _syncDirectory(
          localDir: charactersDir,
          remoteDir: '/FrontPorchAI/characters',
          extensions: ['.png'],
        );
        debugPrint('[CloudSync] Character file sync complete.');
      } catch (e) {
        debugPrint('[CloudSync] Character file sync error (non-fatal): $e');
      }

      _status = SyncStatus.success;
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      debugPrint('Cloud sync error: $e');
    }
    notifyListeners();
  }

  /// Sync the SQLite database file as a single unit.
  /// Strategy: compare local vs remote modified time, newer wins.
  bool _dbWasDownloaded = false;

  /// Whether the last sync downloaded a new database file.
  /// Callers should check this and reload repositories if true.
  bool get dbWasDownloaded => _dbWasDownloaded;

  /// Set when the remote DB has a NEWER schema version than local.
  /// Callers should show a dialog telling user to update and disable sync.
  bool _schemaMismatch = false;
  bool get schemaMismatch => _schemaMismatch;

  /// Set when a v2 DB was downloaded from the cloud and migrated to v3 locally.
  /// Callers should show a warning before uploading the upgraded DB back to cloud.
  bool _pendingSchemaUpgrade = false;
  bool get pendingSchemaUpgrade => _pendingSchemaUpgrade;

  int _remoteSchemaVersion = 0;
  int get remoteSchemaVersion => _remoteSchemaVersion;
  int _localSchemaVersion = 0;
  int get localSchemaVersion => _localSchemaVersion;

  /// Force-upload the local database to cloud, overwriting the remote copy.
  Future<void> forceUploadDatabase() async {
    if (_provider == null || !_provider!.isConnected) {
      debugPrint('[CloudSync] Force upload aborted — provider not connected');
      throw StateError('Cloud provider not connected. Connect first in Settings.');
    }
    final localPath = AppDatabase.dbFilePath;
    if (localPath == null) {
      debugPrint('[CloudSync] Force upload aborted — no local DB path');
      throw StateError('Database path not available');
    }

    // Bump sync version and checkpoint before upload
    final db = await AppDatabase.instance();
    await db.bumpSyncVersion();
    await db.checkpoint();

    const remotePath = '/FrontPorchAI/front_porch.db';
    await _provider!.uploadFile(localPath, remotePath);
    _pendingSchemaUpgrade = false;

    // Persist that we've uploaded this schema version so the upgrade
    // dialog doesn't reappear on next launch (Google Drive eventual
    // consistency may return the old file briefly).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cloud_schema_uploaded', db.schemaVersion);
    debugPrint('[CloudSync] Force-uploaded local database to cloud (schema v${db.schemaVersion})');
    notifyListeners();
  }

  /// Delete ALL data from the cloud (DB + characters).
  /// Used for disaster recovery when the cloud data is corrupted.
  Future<void> purgeCloudData() async {
    if (_provider == null || !_provider!.isConnected) {
      debugPrint('[CloudSync] Purge aborted — provider not connected');
      throw StateError('Cloud provider not connected. Connect first in Settings.');
    }

    try {
      await _provider!.deleteDirectory('/FrontPorchAI');
      // Clear any cached folder IDs — they all point to deleted folders now
      if (_provider is GoogleDriveProvider) {
        (_provider as GoogleDriveProvider).clearFolderCache();
      }
      debugPrint('[CloudSync] Purged all cloud data (/FrontPorchAI deleted)');
    } catch (e) {
      debugPrint('[CloudSync] Purge error: $e');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _syncDatabase() async {
    if (_provider == null || !_provider!.isConnected) return;

    final localPath = AppDatabase.dbFilePath;
    if (localPath == null) return;

    const remotePath = '/FrontPorchAI/front_porch.db';
    final localFile = File(localPath);

    // Checkpoint WAL so the .db file is self-contained for upload
    if (await localFile.exists()) {
      try {
        final db = await AppDatabase.instance();
        await db.checkpoint();
      } catch (e) {
        debugPrint('WAL checkpoint failed: $e');
      }
    }

    // Check remote
    RemoteFileInfo? remoteInfo;
    try {
      final remoteFiles = await _provider!.listFiles('/FrontPorchAI');
      remoteInfo = remoteFiles.where(
        (f) => path.basename(f.remotePath) == 'front_porch.db'
      ).firstOrNull;
    } catch (_) {}

    // Read local sync version
    int localVersion = 0;
    final db = await AppDatabase.instance();
    try {
      localVersion = await db.getSyncVersion();
    } catch (_) {}

    // Read remote sync/schema version (downloads to temp, reads, cleans up)
    int remoteVersion = 0;
    int remoteSchema = 0;
    if (remoteInfo != null) {
      final versions = await _getRemoteVersions(remotePath);
      remoteVersion = versions.$1;
      remoteSchema = versions.$2;
    }

    // Check schema version compatibility
    final localSchema = db.schemaVersion;
    _localSchemaVersion = localSchema;
    _remoteSchemaVersion = remoteSchema;

    if (remoteSchema > 0 && remoteSchema > localSchema) {
      // Remote is NEWER → this app is outdated, block sync
      _schemaMismatch = true;
      _status = SyncStatus.error;
      _lastError = 'Schema version mismatch: local v$localSchema, remote v$remoteSchema. '
          'Please update the app on this device to continue cloud sync.';
      debugPrint('[CloudSync] SCHEMA MISMATCH (remote newer) — local: v$localSchema, remote: v$remoteSchema. Aborting sync.');
      notifyListeners();
      return;
    }

    if (remoteSchema > 0 && remoteSchema < localSchema) {
      // Remote is OLDER → this device has a newer app version.
      // Check if the user already confirmed and uploaded this schema version.
      // Google Drive eventual consistency may return the old file briefly,
      // so we persist the upload flag to avoid re-showing the dialog.
      final prefs = await SharedPreferences.getInstance();
      final uploadedSchema = prefs.getInt('cloud_schema_uploaded') ?? 0;
      if (uploadedSchema >= localSchema) {
        // Already uploaded — just overwrite the stale remote copy.
        debugPrint('[CloudSync] Remote schema v$remoteSchema < local v$localSchema, '
            'but v$uploadedSchema was already uploaded — overwriting remote.');
        await db.bumpSyncVersion();
        await db.checkpoint();
        await _provider!.uploadFile(localPath, remotePath);
        _syncedFiles++;
        _processedFiles++;
        notifyListeners();
        return;
      }

      // First time seeing this mismatch — prompt user before uploading.
      debugPrint('[CloudSync] Remote schema v$remoteSchema < local v$localSchema — will download and migrate.');

      if (localVersion == 0 && remoteInfo != null) {
        // Fresh install: download the old schema DB so we get the user's data
        await AppDatabase.closeAndReset();
        await _provider!.downloadFile(remotePath, localPath);
        try { await File('$localPath-wal').delete(); } catch (_) {}
        try { await File('$localPath-shm').delete(); } catch (_) {}

        // Reopen — Drift migration will automatically upgrade v2→v3
        await AppDatabase.instance();

        _syncedFiles++;
        _dbWasDownloaded = true;
        debugPrint('[CloudSync] Downloaded v$remoteSchema DB and migrated to v$localSchema');
      }

      // Flag so caller can show a warning dialog before uploading
      _pendingSchemaUpgrade = true;
      _processedFiles++;
      notifyListeners();
      return; // Do NOT upload yet — wait for user confirmation
    }

    debugPrint('[CloudSync] DB versions — local: $localVersion, remote: $remoteVersion (schema v$localSchema)');

    if (remoteInfo == null) {
      // No remote DB yet → bump version and upload
      if (localVersion == 0) await db.bumpSyncVersion();
      await db.checkpoint();
      await _provider!.uploadFile(localPath, remotePath);
      _syncedFiles++;
      debugPrint('[CloudSync] Uploaded database (first sync)');
    } else if (localVersion == 0 && remoteVersion == 0) {
      // Both versions 0 → first sync after migration on both sides.
      // Upload local as source of truth (merging would cause duplicates
      // because independent migrations generated different UUIDs).
      await db.bumpSyncVersion();
      await db.checkpoint();
      await _provider!.uploadFile(localPath, remotePath);
      _syncedFiles++;
      debugPrint('[CloudSync] First sync after migration — uploaded local DB as source of truth');
    } else if (localVersion == 0 && remoteVersion > 0) {
      // Fresh install with existing remote → download and replace
      await AppDatabase.closeAndReset();
      await _provider!.downloadFile(remotePath, localPath);
      try { await File('$localPath-wal').delete(); } catch (_) {}
      try { await File('$localPath-shm').delete(); } catch (_) {}
      await AppDatabase.instance();
      _syncedFiles++;
      _dbWasDownloaded = true;
      debugPrint('[CloudSync] Fresh install — downloaded remote DB (version $remoteVersion)');
    } else if (localVersion == remoteVersion && localVersion > 0) {
      // Versions match → nothing to do
      debugPrint('[CloudSync] Skipped DB sync — versions match ($localVersion)');
    } else {
      // Versions differ → download remote to temp, merge, then upload
      final tempDir = await Directory.systemTemp.createTemp('fp_merge_');
      final tempPath = path.join(tempDir.path, 'remote.db');
      try {
        await _provider!.downloadFile(remotePath, tempPath);

        // Run row-level merge
        final merged = await DatabaseMergeService.mergeRemoteIntoLocal(db, tempPath);

        if (merged) {
          _dbWasDownloaded = true; // signal callers to reload repos
        }

        // Always upload after merge so both sides converge
        await db.checkpoint();
        await _provider!.uploadFile(localPath, remotePath);
        _syncedFiles++;
        debugPrint('[CloudSync] Merged and uploaded database');
      } catch (e) {
        debugPrint('[CloudSync] Merge failed: $e');
        rethrow;
      } finally {
        try { await Directory(tempDir.path).delete(recursive: true); } catch (_) {}
      }
    }

    _processedFiles++;
    notifyListeners();
  }

  /// Read the sync version AND schema version from a remote database.
  /// Downloads to a temp directory, opens with raw SQL, reads, and cleans up.
  /// Returns (syncVersion, schemaVersion).
  Future<(int, int)> _getRemoteVersions(String remotePath) async {
    final tempDir = await Directory.systemTemp.createTemp('fp_sync_version_');
    final tempPath = path.join(tempDir.path, 'remote_check.db');
    try {
      await _provider!.downloadFile(remotePath, tempPath);
      final tempFile = File(tempPath);
      if (!await tempFile.exists()) return (0, 0);

      // Open a raw sqlite3 connection via Drift's NativeDatabase
      final tempDb = NativeDatabase(tempFile);
      final executor = tempDb;
      await executor.ensureOpen(_SyncVersionUser());

      // Read sync version from sync_meta table
      int syncVersion = 0;
      try {
        final result = await executor.runSelect(
          'SELECT version FROM sync_meta WHERE id = 1', [],
        );
        syncVersion = result.isNotEmpty ? result.first['version'] as int : 0;
      } catch (_) {}

      // Read schema version via PRAGMA user_version (Drift uses this)
      int schemaVersion = 0;
      try {
        final pragmaResult = await executor.runSelect(
          'PRAGMA user_version', [],
        );
        schemaVersion = pragmaResult.isNotEmpty
            ? pragmaResult.first['user_version'] as int
            : 0;
      } catch (_) {}

      await executor.close();
      return (syncVersion, schemaVersion);
    } catch (e) {
      debugPrint('[CloudSync] Could not read remote versions: $e');
      return (0, 0);
    } finally {
      try { await Directory(tempDir.path).delete(recursive: true); } catch (_) {}
    }
  }



  /// Upload local files to remote (no downloading). Used for characters
  /// so the user can selectively choose which remote characters to pull.
  Future<void> _uploadOnlyDirectory({
    required String localDir,
    required String remoteDir,
    List<String>? extensions,
  }) async {
    final localDirectory = Directory(localDir);
    debugPrint('[CloudSync] _uploadOnlyDirectory: localDir=$localDir, remoteDir=$remoteDir');
    if (!await localDirectory.exists()) {
      debugPrint('[CloudSync] _uploadOnlyDirectory: local directory does NOT exist, skipping');
      return;
    }

    final localFiles = <String, File>{};
    await _collectLocalFiles(localDirectory, localDir, localFiles, false, extensions);
    debugPrint('[CloudSync] _uploadOnlyDirectory: found ${localFiles.length} local files');
    for (final f in localFiles.keys) {
      debugPrint('[CloudSync]   local file: $f');
    }

    // Gather remote files for comparison
    List<RemoteFileInfo> remoteFiles;
    try {
      remoteFiles = await _provider!.listFiles(remoteDir);
    } catch (e) {
      debugPrint('[CloudSync] _uploadOnlyDirectory: error listing remote: $e');
      remoteFiles = [];
    }
    debugPrint('[CloudSync] _uploadOnlyDirectory: found ${remoteFiles.length} remote files');

    final remoteNames = remoteFiles
        .map((rf) => path.basename(rf.remotePath))
        .toSet();

    for (final entry in localFiles.entries) {
      final relativePath = entry.key;
      final localFile = entry.value;
      final remotePath = '$remoteDir/${relativePath.replaceAll('\\', '/')}';
      final baseName = path.basename(relativePath);

      if (!remoteNames.contains(baseName)) {
        await _provider!.ensureDir(path.dirname(remotePath).replaceAll('\\', '/'));
        await _provider!.uploadFile(localFile.path, remotePath);
        _syncedFiles++;
      } else {
        // Upload if local is newer
        final remoteInfo = remoteFiles.firstWhere(
          (rf) => path.basename(rf.remotePath) == baseName,
          orElse: () => RemoteFileInfo(remotePath: '', lastModified: null),
        );
        if (remoteInfo.lastModified != null) {
          final localStat = await localFile.stat();
          if (localStat.modified.isAfter(remoteInfo.lastModified!)) {
            await _provider!.uploadFile(localFile.path, remotePath);
            _syncedFiles++;
          }
        }
      }
      _processedFiles++;
      notifyListeners();
    }
  }

  /// List ALL character PNGs on the remote.
  /// Returns a list of (filename, existsLocally) pairs.
  Future<List<({String name, bool existsLocally})>> listAllRemoteCharacters(String localCharactersDir) async {
    debugPrint('[CloudSync] listAllRemoteCharacters: localCharactersDir=$localCharactersDir');
    if (_provider == null || !_provider!.isConnected) {
      debugPrint('[CloudSync] listAllRemoteCharacters: provider null or not connected');
      return [];
    }

    try {
      await _provider!.ensureDir('/FrontPorchAI/characters');
      final remoteFiles = await _provider!.listFiles('/FrontPorchAI/characters');
      debugPrint('[CloudSync] listAllRemoteCharacters: ${remoteFiles.length} remote files found');
      for (final rf in remoteFiles) {
        debugPrint('[CloudSync]   remote: ${rf.remotePath}');
      }

      final localDir = Directory(localCharactersDir);
      final localNames = <String>{};
      if (await localDir.exists()) {
        await for (final entity in localDir.list()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
            localNames.add(path.basename(entity.path));
          }
        }
        debugPrint('[CloudSync] listAllRemoteCharacters: ${localNames.length} local PNGs found');
      } else {
        debugPrint('[CloudSync] listAllRemoteCharacters: local dir does NOT exist');
      }

      final result = <({String name, bool existsLocally})>[];
      for (final rf in remoteFiles) {
        final name = path.basename(rf.remotePath);
        if (name.toLowerCase().endsWith('.png')) {
          result.add((name: name, existsLocally: localNames.contains(name)));
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error listing remote characters: $e');
      return [];
    }
  }

  /// List character PNGs that exist on the remote but NOT locally.
  /// Returns a list of filenames (e.g. ['char_abc.png', 'char_def.png']).
  Future<List<String>> listRemoteOnlyCharacters(String localCharactersDir) async {
    if (_provider == null || !_provider!.isConnected) return [];

    try {
      await _provider!.ensureDir('/FrontPorchAI/characters');
      final remoteFiles = await _provider!.listFiles('/FrontPorchAI/characters');

      final localDir = Directory(localCharactersDir);
      final localNames = <String>{};
      if (await localDir.exists()) {
        await for (final entity in localDir.list()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
            localNames.add(path.basename(entity.path));
          }
        }
      }

      final remoteOnly = <String>[];
      for (final rf in remoteFiles) {
        final name = path.basename(rf.remotePath);
        if (name.toLowerCase().endsWith('.png') && !localNames.contains(name)) {
          remoteOnly.add(name);
        }
      }
      return remoteOnly;
    } catch (e) {
      debugPrint('Error listing remote characters: $e');
      return [];
    }
  }

  /// Download specific character PNGs from remote by filename.
  Future<int> downloadCharacters(String localCharactersDir, List<String> filenames) async {
    if (_provider == null || !_provider!.isConnected) return 0;

    final dir = Directory(localCharactersDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    int downloaded = 0;
    for (final name in filenames) {
      try {
        final remotePath = '/FrontPorchAI/characters/$name';
        final localPath = path.join(localCharactersDir, name);
        await _provider!.downloadFile(remotePath, localPath);
        downloaded++;
      } catch (e) {
        debugPrint('Error downloading character $name: $e');
      }
    }
    return downloaded;
  }

  /// Download remote-only character PNGs to a temp directory for preview.
  /// Returns a map of filename → temp file path.
  Future<Map<String, String>> downloadCharactersToTemp(List<String> filenames) async {
    if (_provider == null || !_provider!.isConnected) return {};

    final tempDir = await Directory.systemTemp.createTemp('fp_char_preview_');
    final result = <String, String>{};

    for (final name in filenames) {
      try {
        final remotePath = '/FrontPorchAI/characters/$name';
        final localPath = path.join(tempDir.path, name);
        await _provider!.downloadFile(remotePath, localPath);
        result[name] = localPath;
      } catch (e) {
        debugPrint('Error downloading preview for $name: $e');
      }
    }
    return result;
  }

  /// Upload a single file after saving (fire-and-forget).
  Future<void> uploadFile(String localPath, String remoteBasePath) async {
    if (_provider == null || !_provider!.isConnected) return;

    try {
      final filename = path.basename(localPath);
      final remotePath = '$remoteBasePath/$filename';
      await _provider!.uploadFile(localPath, remotePath);
    } catch (e) {
      debugPrint('Cloud upload error: $e');
    }
  }

  /// Upload a chat session after it's saved locally (legacy, kept for compatibility).
  Future<void> uploadChatSession(String localFilePath, String charId) async {
    // No-op: chat data is now synced via the .db file
  }

  /// Test the connection to the provider.
  Future<bool> testConnection() async {
    if (_provider == null || !_provider!.isConnected) return false;
    try {
      await _provider!.ensureDir('/FrontPorchAI');
      await _provider!.listFiles('/FrontPorchAI');
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Delete a character's remote files (chat folder + character PNG).
  Future<void> deleteRemoteCharacter(String charId, String? pngFileName) async {
    if (_provider == null || !_provider!.isConnected) return;
    try {
      // Delete chat history folder
      await _provider!.deleteDirectory('/FrontPorchAI/chats/$charId');
      debugPrint('AG_DEBUG: Deleted remote chat folder for $charId');
    } catch (e) {
      debugPrint('Cloud delete chat folder error: $e');
    }
    if (pngFileName != null) {
      try {
        await _provider!.deleteFile('/FrontPorchAI/characters/$pngFileName');
        debugPrint('AG_DEBUG: Deleted remote character PNG $pngFileName');
      } catch (e) {
        debugPrint('Cloud delete character PNG error: $e');
      }
    }
  }

  /// Delete a group chat's remote files.
  Future<void> deleteRemoteGroupChat(String groupId) async {
    if (_provider == null || !_provider!.isConnected) return;
    try {
      await _provider!.deleteDirectory('/FrontPorchAI/chats/group_$groupId');
      debugPrint('AG_DEBUG: Deleted remote group chat folder for $groupId');
    } catch (e) {
      debugPrint('Cloud delete group chat folder error: $e');
    }
  }

  /// Bi-directional sync of a local directory with a remote directory.
  Future<void> _syncDirectory({
    required String localDir,
    required String remoteDir,
    bool recursive = false,
    List<String>? extensions,
  }) async {
    final localDirectory = Directory(localDir);
    if (!await localDirectory.exists()) {
      await localDirectory.create(recursive: true);
    }

    // Gather local files
    final localFiles = <String, File>{};
    await _collectLocalFiles(localDirectory, localDir, localFiles, recursive, extensions);

    // Gather remote files
    List<RemoteFileInfo> remoteFiles;
    try {
      remoteFiles = await _provider!.listFiles(remoteDir);
    } catch (_) {
      remoteFiles = [];
    }

    final remoteMap = <String, RemoteFileInfo>{};
    for (final rf in remoteFiles) {
      // Extract relative path from remote path
      final relativePath = rf.remotePath.replaceFirst('$remoteDir/', '');
      if (relativePath.isNotEmpty && !relativePath.endsWith('/')) {
        remoteMap[relativePath] = rf;
      }
    }

    // Download files that exist remotely but not locally, or are newer remotely
    for (final entry in remoteMap.entries) {
      final relativePath = entry.key;
      final remoteInfo = entry.value;
      final localPath = path.join(localDir, relativePath.replaceAll('/', Platform.pathSeparator));
      final localFile = File(localPath);

      bool shouldDownload = false;
      if (!await localFile.exists()) {
        await localFile.parent.create(recursive: true);
        shouldDownload = true;
      } else if (remoteInfo.lastModified != null) {
        final localStat = await localFile.stat();
        if (remoteInfo.lastModified!.isAfter(localStat.modified)) {
          shouldDownload = true;
        }
      }

      if (shouldDownload) {
        // Download to a temp file first, then rename on success.
        // This prevents data loss if the download is interrupted.
        final tempPath = '$localPath.tmp';
        try {
          await _provider!.downloadFile(remoteInfo.remotePath, tempPath);
          final tempFile = File(tempPath);
          if (await tempFile.exists()) {
            await tempFile.rename(localPath);
          }
          _syncedFiles++;
        } catch (e) {
          // Clean up partial temp file on failure
          try { await File(tempPath).delete(); } catch (_) {}
          debugPrint('[CloudSync] Download failed for $relativePath: $e');
        }
      }
      _processedFiles++;
      notifyListeners();
    }

    // Upload files that exist locally but not remotely, or are newer locally
    for (final entry in localFiles.entries) {
      final relativePath = entry.key;
      final localFile = entry.value;
      final remotePath = '$remoteDir/${relativePath.replaceAll('\\', '/')}';

      try {
        if (!remoteMap.containsKey(relativePath.replaceAll('\\', '/'))) {
          final remoteParent = path.dirname(remotePath).replaceAll('\\', '/');
          await _provider!.ensureDir(remoteParent);
          await _provider!.uploadFile(localFile.path, remotePath);
          _syncedFiles++;
        } else {
          final remoteInfo = remoteMap[relativePath.replaceAll('\\', '/')]!;
          if (remoteInfo.lastModified != null) {
            final localStat = await localFile.stat();
            if (localStat.modified.isAfter(remoteInfo.lastModified!)) {
              await _provider!.uploadFile(localFile.path, remotePath);
              _syncedFiles++;
            }
          }
        }
      } catch (e) {
        debugPrint('[CloudSync] Failed to upload ${path.basename(relativePath)}: $e');
      }
      _processedFiles++;
      notifyListeners();
    }
  }

  /// Recursively collect local files into a map of relativePath → File.
  Future<void> _collectLocalFiles(
    Directory dir,
    String baseDir,
    Map<String, File> result,
    bool recursive,
    List<String>? extensions,
  ) async {
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is File) {
        if (extensions != null && !extensions.any((ext) => entity.path.endsWith(ext))) {
          continue;
        }
        final relativePath = entity.path.substring(baseDir.length + 1);
        result[relativePath] = entity;
      }
    }
  }

  /// Count total unique files in a sync pair (local + remote) for progress tracking.
  Future<int> _countSyncFiles(
    String localDir, String remoteDir, bool recursive, List<String>? extensions,
  ) async {
    final localDirectory = Directory(localDir);
    final localFiles = <String, File>{};
    if (await localDirectory.exists()) {
      await _collectLocalFiles(localDirectory, localDir, localFiles, recursive, extensions);
    }

    List<RemoteFileInfo> remoteFiles;
    try {
      remoteFiles = await _provider!.listFiles(remoteDir);
    } catch (_) {
      remoteFiles = [];
    }

    // Count unique files (union of local and remote)
    final allKeys = <String>{};
    for (final key in localFiles.keys) {
      allKeys.add(key.replaceAll('\\', '/'));
    }
    for (final rf in remoteFiles) {
      final rel = rf.remotePath.replaceFirst('$remoteDir/', '');
      if (rel.isNotEmpty && !rel.endsWith('/')) {
        allKeys.add(rel);
      }
    }
    return allKeys.length;
  }

}

/// Minimal QueryExecutorUser for opening a raw NativeDatabase to read sync_meta.
/// This avoids going through AppDatabase (which would run migrations on the temp file).
class _SyncVersionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 3; // Match current schema so Drift doesn't try to migrate

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {
    // No-op: we just want to read one row, no migrations needed
  }
}
