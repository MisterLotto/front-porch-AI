import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_porch_ai/app_version.dart';

/// Windows-only self-update service.
/// Checks GitHub Releases for new versions and downloads/runs the installer.
class UpdateService extends ChangeNotifier {
  static const String _repoOwner = 'linux4life1';
  static const String _repoName = 'front-porch-AI';
  static const String _installerAsset = 'Front_Porch_AI_Setup.exe';
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
  /// Returns true only on Windows AND when installed via the installer
  /// (not from the portable zip). The installer creates a .installed marker file.
  static bool get isSupported {
    if (!Platform.isWindows) return false;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return File('$exeDir\\.installed').existsSync();
  }

  Future<void> initialize() async {
    if (!isSupported) return;
    
    // Use hardcoded version constant instead of PackageInfo.fromPlatform()
    // which is unreliable on Windows (returns stale version from exe resources).
    _currentVersion = appVersion;
    
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

      // Find the installer asset
      String? installerUrl;
      for (final asset in assets) {
        if (asset['name'] == _installerAsset) {
          installerUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (installerUrl == null) {
        debugPrint('No installer asset found in latest release');
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
      final installerPath = '${tempDir.path}\\$_installerAsset';
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

  /// Run the installer immediately and exit the app.
  Future<void> installNow() async {
    if (_pendingInstallerPath == null) return;
    await _launchInstaller(_pendingInstallerPath!);
    exit(0);
  }

  /// Run the pending installer on app close.
  /// Call this from the window close handler.
  Future<void> installOnClose() async {
    if (_pendingInstallerPath == null) return;
    await _launchInstaller(_pendingInstallerPath!);
  }

  Future<void> _launchInstaller(String path) async {
    await Process.start(path, [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
    ]);
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
