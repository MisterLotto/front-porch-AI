import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';

/// Google Drive cloud storage provider using OAuth 2.0 localhost redirect.
class GoogleDriveProvider extends CloudStorageProvider {
  // TODO: Replace with your actual Google Cloud OAuth Client ID
  static final _clientId = ClientId(
    '641126691714-ccmdjssop6m5s3jt0s7ehm45h891dv4o.apps.googleusercontent.com',
    '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',
  );

  static const _scopes = [drive.DriveApi.driveAppdataScope];

  AutoRefreshingAuthClient? _authClient;
  drive.DriveApi? _driveApi;
  bool _connected = false;

  // Cache of folder IDs to avoid repeated lookups
  final Map<String, String> _folderIdCache = {};

  @override
  bool get isConnected => _connected;

  @override
  String get displayName => 'Google Drive';

  @override
  Future<void> connect(Map<String, String> credentials) async {
    // Check for saved credentials first
    final prefs = await SharedPreferences.getInstance();
    final savedCreds = prefs.getString('gdrive_credentials');

    // Check if scope has changed — if so, force re-auth
    final savedScope = prefs.getString('gdrive_scope') ?? '';
    final currentScope = _scopes.join(',');
    if (savedScope != currentScope && savedCreds != null) {
      debugPrint('AG_DEBUG: Google Drive scope changed, clearing saved credentials for re-auth');
      await prefs.remove('gdrive_credentials');
      await prefs.remove('gdrive_scope');
      // Fall through to interactive sign-in below
    } else if (savedCreds != null) {
      try {
        final json = jsonDecode(savedCreds);
        final accessToken = AccessToken(
          json['type'] ?? 'Bearer',
          json['data'] ?? '',
          DateTime.parse(json['expiry']),
        );
        final accessCreds = AccessCredentials(
          accessToken,
          json['refreshToken'],
          _scopes,
        );
        _authClient = autoRefreshingClient(_clientId, accessCreds, http.Client());
        _driveApi = drive.DriveApi(_authClient!);
        _connected = true;
        return;
      } catch (e) {
        debugPrint('Failed to restore Google Drive credentials: $e');
        // Fall through to interactive sign-in
      }
    }

    // Interactive sign-in: opens system browser via localhost redirect
    try {
      _authClient = await clientViaUserConsent(
        _clientId,
        _scopes,
        (url) async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      );
      _driveApi = drive.DriveApi(_authClient!);
      _connected = true;

      // Save credentials and scope for next time
      final creds = _authClient!.credentials;
      await prefs.setString('gdrive_credentials', jsonEncode({
        'type': creds.accessToken.type,
        'data': creds.accessToken.data,
        'expiry': creds.accessToken.expiry.toIso8601String(),
        'refreshToken': creds.refreshToken,
      }));
      await prefs.setString('gdrive_scope', _scopes.join(','));
    } catch (e) {
      _connected = false;
      debugPrint('Google Drive sign-in error: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _authClient?.close();
    _authClient = null;
    _driveApi = null;
    _connected = false;
    _folderIdCache.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gdrive_credentials');
  }

  @override
  Future<List<RemoteFileInfo>> listFiles(String remotePath) async {
    if (_driveApi == null) throw Exception('Not connected to Google Drive');
    try {
      return await _listFilesInternal(remotePath);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 404) {
        // Stale folder ID cached — invalidate and retry once
        debugPrint('[GDrive] 404 in listFiles for $remotePath, clearing cache and retrying');
        _invalidateCacheForPath(remotePath);
        return await _listFilesInternal(remotePath);
      }
      rethrow;
    }
  }

  Future<List<RemoteFileInfo>> _listFilesInternal(String remotePath) async {
    final result = <RemoteFileInfo>[];
    final folderId = await _getOrCreateFolderId(remotePath);
    if (folderId == null) return result;

    String? pageToken;
    do {
      final fileList = await _driveApi!.files.list(
        q: "'$folderId' in parents and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, mimeType, modifiedTime, size), nextPageToken',
        pageToken: pageToken,
      );

      for (final file in fileList.files ?? []) {
        if (file.mimeType == 'application/vnd.google-apps.folder') {
          // Recurse into subfolders
          final subPath = '$remotePath/${file.name}';
          _folderIdCache[subPath] = file.id!;
          try {
            final subFiles = await listFiles(subPath);
            result.addAll(subFiles);
          } catch (_) {}
        } else {
          result.add(RemoteFileInfo(
            remotePath: '$remotePath/${file.name}',
            lastModified: file.modifiedTime,
            size: int.tryParse(file.size ?? '0'),
          ));
        }
      }
      pageToken = fileList.nextPageToken;
    } while (pageToken != null);

    return result;
  }

  @override
  Future<void> uploadFile(String localPath, String remotePath) async {
    if (_driveApi == null) throw Exception('Not connected to Google Drive');
    try {
      await _uploadFileInternal(localPath, remotePath);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 404) {
        // Stale folder ID cached — invalidate and retry once
        final parentPath = remotePath.substring(0, remotePath.lastIndexOf('/'));
        debugPrint('[GDrive] 404 in uploadFile for $remotePath, clearing cache and retrying');
        _invalidateCacheForPath(parentPath);
        await _uploadFileInternal(localPath, remotePath);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _uploadFileInternal(String localPath, String remotePath) async {
    final fileName = remotePath.split('/').last;
    final parentPath = remotePath.substring(0, remotePath.lastIndexOf('/'));
    debugPrint('[GDrive] Upload: resolving parent folder $parentPath');
    final parentId = await _getOrCreateFolderId(parentPath);
    debugPrint('[GDrive] Upload: parent folder ID = $parentId');

    // Check if file already exists
    debugPrint('[GDrive] Upload: checking for existing $fileName');
    final existing = await _driveApi!.files.list(
      q: "'$parentId' in parents and name = '$fileName' and trashed = false",
      spaces: 'appDataFolder',
      $fields: 'files(id)',
    );
    debugPrint('[GDrive] Upload: found ${existing.files?.length ?? 0} existing files');

    final localFile = File(localPath);
    final fileSize = await localFile.length();
    debugPrint('[GDrive] Upload: $fileName ($fileSize bytes)');
    final media = drive.Media(localFile.openRead(), fileSize);

    if (existing.files != null && existing.files!.isNotEmpty) {
      // Update existing file
      debugPrint('[GDrive] Upload: updating existing file ${existing.files!.first.id}');
      await _driveApi!.files.update(
        drive.File()..modifiedTime = (await localFile.stat()).modified,
        existing.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      // Create new file
      debugPrint('[GDrive] Upload: creating new file in $parentId');
      await _driveApi!.files.create(
        drive.File()
          ..name = fileName
          ..parents = [parentId!]
          ..modifiedTime = (await localFile.stat()).modified,
        uploadMedia: media,
      );
    }
    debugPrint('[GDrive] Upload: $fileName complete');
  }

  @override
  Future<void> downloadFile(String remotePath, String localPath) async {
    if (_driveApi == null) throw Exception('Not connected to Google Drive');

    final fileName = remotePath.split('/').last;
    final parentPath = remotePath.substring(0, remotePath.lastIndexOf('/'));
    final parentId = await _getOrCreateFolderId(parentPath);

    final fileList = await _driveApi!.files.list(
      q: "'$parentId' in parents and name = '$fileName' and trashed = false",
      spaces: 'appDataFolder',
      $fields: 'files(id)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception('File not found on Google Drive: $remotePath');
    }

    final response = await _driveApi!.files.get(
      fileList.files!.first.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);
    final sink = localFile.openWrite();
    await response.stream.pipe(sink);
    await sink.close();
  }

  @override
  Future<void> ensureDir(String remotePath) async {
    await _getOrCreateFolderId(remotePath);
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    if (_driveApi == null) throw Exception('Not connected to Google Drive');

    final fileName = remotePath.split('/').last;
    final parentPath = remotePath.substring(0, remotePath.lastIndexOf('/'));
    final parentId = await _getOrCreateFolderId(parentPath);
    if (parentId == null) return;

    final fileList = await _driveApi!.files.list(
      q: "'$parentId' in parents and name = '$fileName' and trashed = false",
      spaces: 'appDataFolder',
      $fields: 'files(id)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      await _driveApi!.files.delete(fileList.files!.first.id!);
    }
  }

  @override
  Future<void> deleteDirectory(String remotePath) async {
    if (_driveApi == null) throw Exception('Not connected to Google Drive');

    final folderId = await _getOrCreateFolderId(remotePath);
    if (folderId == null || folderId == 'root' || folderId == 'appDataFolder') return;

    // Delete the folder (Google Drive cascades to contents)
    try {
      await _driveApi!.files.delete(folderId);
      // Remove from cache
      _folderIdCache.remove(remotePath);
    } catch (e) {
      debugPrint('Google Drive deleteDirectory error: $e');
    }
  }

  /// Clear all cached folder IDs. Call after purging cloud data
  /// to prevent stale references to deleted folders.
  void clearFolderCache() {
    _folderIdCache.clear();
    debugPrint('[GDrive] Folder ID cache cleared');
  }

  /// Invalidate all cached folder IDs at or below the given path.
  /// This forces a fresh lookup on the next call to _getOrCreateFolderId.
  void _invalidateCacheForPath(String remotePath) {
    _folderIdCache.removeWhere((key, _) => key == remotePath || key.startsWith('$remotePath/'));
  }

  /// Get or create a folder hierarchy and return the leaf folder's ID.
  Future<String?> _getOrCreateFolderId(String remotePath) async {
    if (_driveApi == null) return null;
    if (_folderIdCache.containsKey(remotePath)) return _folderIdCache[remotePath];

    final parts = remotePath.split('/').where((p) => p.isNotEmpty).toList();
    String parentId = 'appDataFolder';

    for (int i = 0; i < parts.length; i++) {
      final partPath = '/${parts.sublist(0, i + 1).join('/')}';
      if (_folderIdCache.containsKey(partPath)) {
        parentId = _folderIdCache[partPath]!;
        continue;
      }

      // Search for existing folder
      final query = "'$parentId' in parents and name = '${parts[i]}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final list = await _driveApi!.files.list(q: query, spaces: 'appDataFolder', $fields: 'files(id)');

      if (list.files != null && list.files!.isNotEmpty) {
        parentId = list.files!.first.id!;
      } else {
        // Create folder
        final folder = await _driveApi!.files.create(drive.File()
          ..name = parts[i]
          ..mimeType = 'application/vnd.google-apps.folder'
          ..parents = [parentId]);
        parentId = folder.id!;
      }
      _folderIdCache[partPath] = parentId;
    }

    return parentId;
  }
}
