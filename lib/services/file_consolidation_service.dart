import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/app_version.dart';

class FileConsolidationService {
  /// Root-path pref key, chosen by channel exactly as StorageService
  /// (`_rootPathKey`) and AppDatabase do. This consolidator physically MOVES
  /// the database, chats and models under whatever root that key names, so
  /// reading the stable key on a beta/nightly build relocated the STABLE
  /// installation's live data on the beta's first launch (both channels share
  /// one SharedPreferences store — that is why every other key is prefixed).
  static String rootPathKeyFor({required bool preRelease}) =>
      preRelease ? 'root_path_beta' : 'root_path';

  /// Folder this channel nests into — matches AppDatabase's `defaultRootName`.
  static String rootFolderNameFor({required bool preRelease}) =>
      preRelease ? 'FrontPorchAI-Beta' : 'FrontPorchAI';

  /// True when [basename] is already one of our roots, so we must not nest
  /// again. Both channel names are accepted on both channels — a beta rooted
  /// at FrontPorchAI-Beta would otherwise be re-nested every launch.
  static bool isAlreadyNested(String basename) {
    final lower = basename.toLowerCase();
    return lower == 'frontporchai' ||
        lower == 'frontporch' ||
        lower == 'frontporchai-beta';
  }

  /// Checks if the folder structure is scattered, and consolidates it
  /// underneath a dedicated "FrontPorchAI" directory if needed.
  /// Also dynamically retrieves support files and moves them to "system".
  ///
  /// [preRelease] defaults to this build's own channel; it exists because a
  /// test cannot rebuild the app with a beta version string.
  static Future<void> consolidate({bool? preRelease}) async {
    final beta = preRelease ?? isPreRelease;
    final rootPathKey = rootPathKeyFor(preRelease: beta);
    final prefs = await SharedPreferences.getInstance();

    // Existing root path (which might just be the raw Documents folder).
    final docsDir = await getApplicationDocumentsDirectory();
    final currentRootPath = prefs.getString(rootPathKey) ?? docsDir.path;

    // Determine target consolidated path.
    // Ensure we don't nest if the basename is already FrontPorchAI or something similar.
    final basename = p.basename(currentRootPath);
    if (isAlreadyNested(basename)) {
      // It's already cleanly nested. We just need to ensure the system files are moved there.
      await _migrateSystemDependencies(currentRootPath);
      return;
    }

    // It's a raw scattered directory! We need to consolidate it.
    final targetRootPath = p.join(
      currentRootPath,
      rootFolderNameFor(preRelease: beta),
    );
    final targetRoot = Directory(targetRootPath);

    // Folders that were historically dumped loosely in rootPath.
    final internalScatteredFolders = [
      'KoboldManager',
      'chats',
      'worlds',
      'models',
      'koboldcpp_bin',
    ];

    bool needsMigration = false;
    for (String folder in internalScatteredFolders) {
      if (await Directory(p.join(currentRootPath, folder)).exists()) {
        needsMigration = true;
        break;
      }
    }

    if (!needsMigration && prefs.getString(rootPathKey) != null) {
      // Nothing scattered found in the raw custom path, but we still want
      // to wrap things cleanly going forward, so shift the root path.
      if (!await targetRoot.exists()) {
        await targetRoot.create(recursive: true);
      }
      await prefs.setString(rootPathKey, targetRootPath);
      await _migrateSystemDependencies(targetRootPath);
      return;
    } else if (needsMigration) {
      debugPrint(
        '[Consolidator] Scattered files detected. Aggregating into ${targetRoot.path}...',
      );
      if (!await targetRoot.exists()) {
        await targetRoot.create(recursive: true);
      }

      // Move everything to nested structure.
      for (String folder in internalScatteredFolders) {
        final scatteredDir = Directory(p.join(currentRootPath, folder));
        final targetDir = Directory(p.join(targetRootPath, folder));

        if (await scatteredDir.exists()) {
          try {
            await _moveDirectory(scatteredDir, targetDir);
            await scatteredDir.delete(recursive: true);
            debugPrint('[Consolidator] Relocated $folder');
          } catch (e) {
            debugPrint('[Consolidator] Error relocating $folder: $e');
          }
        }
      }

      // Update root path tracking.
      await prefs.setString(rootPathKey, targetRootPath);
      await _migrateSystemDependencies(targetRootPath);
    }
  }

  /// Locate hidden OS dependency folders from ApplicationSupport and migrate
  /// them directly into the target [systemRootPath] for user visibility.
  static Future<void> _migrateSystemDependencies(String targetRootPath) async {
    final appSupport = await getApplicationSupportDirectory();
    final systemDir = Directory(p.join(targetRootPath, 'system'));

    if (!await systemDir.exists()) {
      await systemDir.create(recursive: true);
    }

    final systemFoldersMap = {
      'piper_voices': 'piper_voices',
      'kokoro_models': 'kokoro_models',
      'whisper_models': 'whisper_models',
      'image_cache': 'image_cache',
    };

    for (var entry in systemFoldersMap.entries) {
      final oldDir = Directory(p.join(appSupport.path, entry.key));
      final newDir = Directory(p.join(systemDir.path, entry.value));

      if (await oldDir.exists()) {
        debugPrint(
          '[Consolidator] Moving hidden system files: ${entry.key} -> ${newDir.path}',
        );
        try {
          await _moveDirectory(oldDir, newDir);
          await oldDir.delete(recursive: true);
        } catch (e) {
          debugPrint(
            '[Consolidator] Failed to move system folder ${entry.key}: $e',
          );
        }
      }
    }
  }

  /// Helper to recursively move a directory (cross-volume compatible).
  static Future<void> _moveDirectory(
    Directory source,
    Directory destination,
  ) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }
    await for (final entity in source.list(recursive: false)) {
      final baseName = p.basename(entity.path);
      final newPath = p.join(destination.path, baseName);
      if (entity is File) {
        await entity.copy(newPath);
        await entity.delete();
      } else if (entity is Directory) {
        await _moveDirectory(entity, Directory(newPath));
      }
    }
  }
}
