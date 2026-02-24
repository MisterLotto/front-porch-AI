import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:front_porch_ai/database/database.dart';

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
    notifyListeners();

    try {
      // Ensure remote directories exist
      await _provider!.ensureDir('/FrontPorchAI');
      await _provider!.ensureDir('/FrontPorchAI/characters');

      // Count total files for progress tracking
      _totalFiles = 1 + await _countSyncFiles( // +1 for DB file
        charactersDir, '/FrontPorchAI/characters', false, ['.png'],
      );
      notifyListeners();

      // Sync the database file (replaces per-file chat/folder/persona sync)
      await _syncDatabase();

      // Sync characters (bi-directional for PNGs)
      await _syncDirectory(
        localDir: charactersDir,
        remoteDir: '/FrontPorchAI/characters',
        extensions: ['.png'],
      );

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
  Future<void> _syncDatabase() async {
    if (_provider == null || !_provider!.isConnected) return;

    final localPath = AppDatabase.dbFilePath;
    if (localPath == null) return;

    const remotePath = '/FrontPorchAI/front_porch.db';
    final localFile = File(localPath);
    if (!await localFile.exists()) return;

    // Checkpoint WAL so the .db file is self-contained
    try {
      final db = await AppDatabase.instance();
      await db.checkpoint();
    } catch (e) {
      debugPrint('WAL checkpoint failed: $e');
    }

    // Check remote
    RemoteFileInfo? remoteInfo;
    try {
      final remoteFiles = await _provider!.listFiles('/FrontPorchAI');
      remoteInfo = remoteFiles.where(
        (f) => path.basename(f.remotePath) == 'front_porch.db'
      ).firstOrNull;
    } catch (_) {}

    final localStat = await localFile.stat();

    if (remoteInfo == null) {
      // First sync — upload
      await _provider!.uploadFile(localPath, remotePath);
      _syncedFiles++;
      debugPrint('[CloudSync] Uploaded database (first sync)');
    } else if (remoteInfo.lastModified != null) {
      if (localStat.modified.isAfter(remoteInfo.lastModified!)) {
        // Local is newer — upload
        await _provider!.uploadFile(localPath, remotePath);
        _syncedFiles++;
        debugPrint('[CloudSync] Uploaded database (local newer)');
      } else if (remoteInfo.lastModified!.isAfter(localStat.modified)) {
        // Remote is newer — download
        await _provider!.downloadFile(remotePath, localPath);
        _syncedFiles++;
        debugPrint('[CloudSync] Downloaded database (remote newer)');
      }
    } else {
      // No timestamp info — be safe, upload
      await _provider!.uploadFile(localPath, remotePath);
      _syncedFiles++;
    }

    _processedFiles++;
    notifyListeners();
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

      if (!await localFile.exists()) {
        await localFile.parent.create(recursive: true);
        await _provider!.downloadFile(remoteInfo.remotePath, localPath);
        _syncedFiles++;
      } else if (remoteInfo.lastModified != null) {
        final localStat = await localFile.stat();
        if (remoteInfo.lastModified!.isAfter(localStat.modified)) {
          await _provider!.downloadFile(remoteInfo.remotePath, localPath);
          _syncedFiles++;
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
