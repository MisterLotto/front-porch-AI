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

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_porch_ai/app_version.dart';

/// Cross-platform self-update service.
/// Checks GitHub Releases for new versions and downloads/runs the update.
/// Supports Windows (Inno Setup), Linux (AppImage), and macOS (DMG).
class UpdateService extends ChangeNotifier {
  static const String _repoOwner = 'linux4life1';
  static const String _repoName = 'front-porch-AI';
  static const String _windowsAsset = 'Front_Porch_AI_Setup.exe';
  static const String _linuxAsset = 'Front_Porch_AI-Linux.AppImage';
  static const String _macosAsset = 'Front_Porch_AI.dmg';
  static const String _prefsKeyAutoCheck = 'update_auto_check';

  String _currentVersion = '';
  String _latestVersion = '';
  String _downloadUrl = '';
  String _releaseNotes = '';
  bool _updateAvailable = false;
  bool _checking = false;
  bool _downloading = false;
  bool _downloadComplete = false;
  double _downloadProgress = 0.0;
  bool _autoCheckEnabled = true;
  String? _pendingInstallerPath;

  String get currentVersion => _currentVersion;
  String get latestVersion => _latestVersion;
  String get releaseNotes => _releaseNotes;
  bool get updateAvailable => _updateAvailable;
  bool get checking => _checking;
  bool get downloading => _downloading;
  bool get downloadComplete => _downloadComplete;
  double get downloadProgress => _downloadProgress;
  bool get autoCheckEnabled => _autoCheckEnabled;
  bool get hasPendingInstaller => _pendingInstallerPath != null;

  /// Whether this platform supports self-update.
  /// Windows: true when installed via the Inno Setup installer (.installed marker).
  /// Linux: true when running as an AppImage ($APPIMAGE env var is set).
  static bool get isSupported {
    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      return File('$exeDir\\.installed').existsSync();
    }
    if (Platform.isLinux) {
      return Platform.environment.containsKey('APPIMAGE');
    }
    if (Platform.isMacOS) {
      // Supported when running as an .app bundle (not flutter run debug).
      // Check that the executable is inside a .app/Contents/MacOS/ structure.
      final exe = Platform.resolvedExecutable;
      return exe.contains('.app/Contents/MacOS/');
    }
    return false;
  }

  /// The correct asset name for this platform's update package.
  static String get _platformAsset {
    if (Platform.isWindows) return _windowsAsset;
    if (Platform.isLinux) return _linuxAsset;
    if (Platform.isMacOS) return _macosAsset;
    return '';
  }

  Future<void> initialize() async {
    // Always set version so the sidebar displays it on every platform.
    _currentVersion = appVersion;

    if (!isSupported) {
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _autoCheckEnabled = prefs.getBool(_prefsKeyAutoCheck) ?? true;
    notifyListeners();
  }

  Future<void> setAutoCheckEnabled(bool enabled) async {
    _autoCheckEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyAutoCheck, enabled);
    notifyListeners();
  }

  /// Check GitHub Releases API for a newer version.
  /// Returns true if an update is available.
  Future<bool> checkForUpdate() async {
    if (!isSupported || _checking) return false;

    _checking = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        debugPrint('Update check failed: ${response.statusCode}');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^[vV]'), '');
      final assets = data['assets'] as List<dynamic>? ?? [];

      // Find the platform-specific update asset
      final targetAsset = _platformAsset;
      String? installerUrl;
      for (final asset in assets) {
        if (asset['name'] == targetAsset) {
          installerUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (installerUrl == null) {
        debugPrint('No update asset ($targetAsset) found in latest release');
        return false;
      }

      _latestVersion = tagName;
      _downloadUrl = installerUrl;
      _releaseNotes = data['body'] as String? ?? '';
      _updateAvailable = _isNewerVersion(tagName, _currentVersion);

      return _updateAvailable;
    } catch (e) {
      debugPrint('Update check error: $e');
      return false;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  /// Download the installer to a temp directory.
  /// Does NOT run it — call installNow() or let installOnClose() handle it.
  Future<void> downloadUpdate() async {
    if (!isSupported || _downloadUrl.isEmpty || _downloading) return;

    _downloading = true;
    _downloadComplete = false;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final tempDir = Directory.systemTemp;
      final assetName = _platformAsset;
      final sep = Platform.isWindows ? '\\' : '/';
      final installerPath = '${tempDir.path}$sep$assetName';
      final file = File(installerPath);

      final request = http.Request('GET', Uri.parse(_downloadUrl));
      final response = await http.Client().send(request);
      
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress = receivedBytes / totalBytes;
          notifyListeners();
        }
      }
      await sink.close();

      _pendingInstallerPath = installerPath;
      _downloadComplete = true;
      _downloading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Download error: $e');
      _downloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }

  /// Run the update immediately and exit (or relaunch on Linux/macOS).
  Future<void> installNow() async {
    if (_pendingInstallerPath == null) return;
    try {
      if (Platform.isLinux) {
        await _replaceAppImage(_pendingInstallerPath!);
        await _relaunchAppImage();
      } else if (Platform.isMacOS) {
        await _replaceMacApp(_pendingInstallerPath!);
        await _relaunchMacApp();
      } else {
        await _launchWindowsInstaller(_pendingInstallerPath!);
      }
      exit(0);
    } catch (e) {
      debugPrint('Install now failed: $e');
      rethrow;
    }
  }

  /// Run the pending update on app close.
  /// Call this from the window close handler.
  Future<void> installOnClose() async {
    if (_pendingInstallerPath == null) return;
    try {
      if (Platform.isLinux) {
        await _replaceAppImage(_pendingInstallerPath!);
      } else if (Platform.isMacOS) {
        await _replaceMacApp(_pendingInstallerPath!);
      } else {
        await _launchWindowsInstaller(_pendingInstallerPath!);
      }
    } catch (e) {
      debugPrint('Install on close failed: $e');
    }
  }

  Future<void> _launchWindowsInstaller(String path) async {
    // Use /SILENT (shows license page) for 0.8→0.9 upgrades (GPL→AGPL change)
    // Use /VERYSILENT (fully silent) for same-license upgrades
    final needsLicenseAcceptance = _currentVersion.startsWith('0.8');
    final silentFlag = needsLicenseAcceptance ? '/SILENT' : '/VERYSILENT';
    await Process.start(path, [
      silentFlag,
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
    ]);
  }

  /// Replace the currently running AppImage with the downloaded update.
  /// Uses rm + cp instead of Dart's File.copy() because the destination
  /// may be a running executable — deleting first avoids write conflicts.
  Future<void> _replaceAppImage(String downloadedPath) async {
    final currentAppImage = Platform.environment['APPIMAGE'];
    if (currentAppImage == null || currentAppImage.isEmpty) {
      debugPrint('APPIMAGE env var not set — cannot replace');
      return;
    }
    debugPrint('Replacing AppImage: $currentAppImage with $downloadedPath');

    // Delete the old AppImage first (Linux allows unlinking running executables)
    final rmResult = await Process.run('rm', ['-f', currentAppImage]);
    if (rmResult.exitCode != 0) {
      debugPrint('rm failed: ${rmResult.stderr}');
    }

    // Copy the new AppImage to the original location
    final cpResult = await Process.run('cp', [downloadedPath, currentAppImage]);
    if (cpResult.exitCode != 0) {
      debugPrint('cp failed: ${cpResult.stderr}');
      throw Exception('Failed to copy new AppImage: ${cpResult.stderr}');
    }

    // Make executable
    await Process.run('chmod', ['+x', currentAppImage]);
    debugPrint('AppImage replaced successfully');
  }

  /// Relaunch the AppImage after replacing it.
  Future<void> _relaunchAppImage() async {
    final currentAppImage = Platform.environment['APPIMAGE'];
    if (currentAppImage == null || currentAppImage.isEmpty) return;
    debugPrint('Relaunching AppImage: $currentAppImage');
    await Process.start(
      currentAppImage, [],
      mode: ProcessStartMode.detached,
    );
  }

  /// Get the current .app bundle path from the resolved executable.
  /// e.g. /Applications/Front Porch AI.app/Contents/MacOS/front_porch_ai
  ///   → /Applications/Front Porch AI.app
  String get _currentMacAppPath {
    final exe = Platform.resolvedExecutable;
    // Walk up from MacOS/binary → Contents → .app
    return File(exe).parent.parent.parent.path;
  }

  /// Replace the current .app bundle with the one inside the downloaded DMG.
  /// 1. Mount DMG with hdiutil
  /// 2. Find the .app inside
  /// 3. rm -rf old .app, cp -R new .app
  /// 4. Strip quarantine with xattr -cr
  /// 5. Unmount DMG
  Future<void> _replaceMacApp(String dmgPath) async {
    final currentApp = _currentMacAppPath;
    final appParent = File(currentApp).parent.path;
    debugPrint('macOS update: replacing $currentApp from $dmgPath');

    // Mount the DMG (no -quiet: we need stdout to find the mount point)
    final mountResult = await Process.run('hdiutil', [
      'attach', dmgPath, '-nobrowse', '-noverify', '-mountrandom', '/tmp',
    ]);
    if (mountResult.exitCode != 0) {
      throw Exception('Failed to mount DMG: ${mountResult.stderr}');
    }

    // Parse mount point from the last line of hdiutil output.
    // Format: "/dev/disk4s1  Apple_HFS  /private/tmp/dmg.XXXXX"
    // Fields are separated by spaces; the mount path is the last field.
    final mountOutput = (mountResult.stdout as String).trim();
    final lastLine = mountOutput.split('\n').last.trim();
    final mountPoint = lastLine.split(RegExp(r'\s+')).last.trim();
    debugPrint('DMG mounted at: $mountPoint');

    try {
      // Find the .app bundle inside the mounted volume
      final volumeDir = Directory(mountPoint);
      String? newAppPath;
      await for (final entity in volumeDir.list()) {
        if (entity is Directory && entity.path.endsWith('.app')) {
          newAppPath = entity.path;
          break;
        }
      }
      if (newAppPath == null) {
        throw Exception('No .app found inside mounted DMG');
      }
      debugPrint('Found new app: $newAppPath');

      // Remove old .app
      final rmResult = await Process.run('rm', ['-rf', currentApp]);
      if (rmResult.exitCode != 0) {
        debugPrint('rm -rf old app failed: ${rmResult.stderr}');
      }

      // Copy new .app to the same location
      final appName = currentApp.split('/').last;
      final destPath = '$appParent/$appName';
      final cpResult = await Process.run('cp', ['-R', newAppPath, destPath]);
      if (cpResult.exitCode != 0) {
        throw Exception('Failed to copy new app: ${cpResult.stderr}');
      }

      // Strip quarantine to prevent Gatekeeper "damaged app" dialog
      await Process.run('xattr', ['-cr', destPath]);
      debugPrint('macOS app replaced and quarantine stripped');
    } finally {
      // Always unmount the DMG
      await Process.run('hdiutil', ['detach', mountPoint, '-quiet']);
      debugPrint('DMG unmounted');
    }
  }

  /// Relaunch the macOS app after replacing it.
  Future<void> _relaunchMacApp() async {
    final appPath = _currentMacAppPath;
    debugPrint('Relaunching macOS app: $appPath');
    await Process.start(
      'open', ['-n', appPath],
      mode: ProcessStartMode.detached,
    );
  }

  /// Compare version strings (e.g. "0.0.4.1" vs "0.0.4")
  /// Returns true if remote is newer than local.
  bool _isNewerVersion(String remote, String local) {
    final remoteParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final localParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Normalize lengths
    while (remoteParts.length < localParts.length) remoteParts.add(0);
    while (localParts.length < remoteParts.length) localParts.add(0);

    for (int i = 0; i < remoteParts.length; i++) {
      if (remoteParts[i] > localParts[i]) return true;
      if (remoteParts[i] < localParts[i]) return false;
    }
    return false; // Equal
  }
}
