import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:kobold_character_card_manager/services/storage_service.dart';

class BackendManager extends ChangeNotifier {
  final StorageService _storageService;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _backendPath;
  String? _error;

  String _statusMessage = '';
  String _arch = 'x64';

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get backendPath => _backendPath;
  String? get error => _error;
  String get statusMessage => _statusMessage;

  BackendManager(this._storageService) {
    _init();
    _storageService.addListener(_init); // React to path changes
  }

  @override // IMPORTANT
  void dispose() {
    _storageService.removeListener(_init);
    super.dispose();
  }

  Future<void> _init() async {
    if (Platform.isMacOS) {
      try {
        final result = await Process.run('uname', ['-m']);
         if (result.exitCode == 0 && result.stdout.toString().trim() == 'arm64') {
           _arch = 'arm64';
         }
      } catch (_) {}
    }
    await checkBackendAvailability();
  }

  Future<void> checkBackendAvailability() async {
    if (_storageService.rootPath == null) return;

    final binDir = _storageService.binDir;
    final executableName = _getExecutableName();
    final file = File(path.join(binDir.path, executableName));

    if (await file.exists()) {
      _backendPath = file.path;
      _statusMessage = 'Ready';
      // On Linux/Mac, ensure executable permission
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', _backendPath!]);
      }
      // On macOS, clear quarantine attribute that sandbox sets on downloaded binaries
      if (Platform.isMacOS) {
        await Process.run('xattr', ['-cr', _backendPath!]);
        print('AG_DEBUG: Cleared quarantine on $_backendPath');
      }
    } else {
      _backendPath = null;
      _statusMessage = 'Not Installed';
    }
    notifyListeners();
  }

  Future<void> downloadBackend() async {
    if (_isDownloading) return;
    if (_storageService.rootPath == null) return;

    _isDownloading = true;
    _error = null;
    _downloadProgress = 0.0;
    _statusMessage = 'Initializing download...';
    notifyListeners();

    try {
      print('AG_DEBUG: Starting download process...');
      final binDir = _storageService.binDir;
      if (!await binDir.exists()) {
        print('AG_DEBUG: Creating directory ${binDir.path}');
        await binDir.create(recursive: true);
      }

      final executableName = _getExecutableName();
      final downloadUrl = _getDownloadUrl();
      final savePath = path.join(binDir.path, executableName);
      print('AG_DEBUG: Download target: $savePath');
      print('AG_DEBUG: Download URL: $downloadUrl');

      _statusMessage = 'Connecting to GitHub...';
      notifyListeners();

      // Use a fresh client
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      
      print('AG_DEBUG: Sending request...');
      final response = await client.send(request);
      print('AG_DEBUG: Response received. Status: ${response.statusCode}');

      if (response.statusCode != 200) {
         print('AG_DEBUG: Download failed with status ${response.statusCode}');
         throw Exception('Failed to download backend: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      print('AG_DEBUG: Content length: $contentLength');
      
      int received = 0;
      final file = File(savePath);
      final sink = file.openWrite();
      
      _statusMessage = 'Downloading...'; 
      notifyListeners();

      DateTime startTime = DateTime.now();
      DateTime lastUpdateTime = startTime;
      int lastWebBytes = 0;

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          
          final now = DateTime.now();
          if (now.difference(lastUpdateTime).inMilliseconds >= 500) {
            final timeDiff = now.difference(lastUpdateTime).inMilliseconds / 1000.0;
            final bytesDiff = received - lastWebBytes;
            final speed = bytesDiff / timeDiff; // bytes per second
            
            String speedStr = _formatSpeed(speed);
            String etaStr = '';
            
            if (contentLength > 0 && speed > 0) {
              final remainingBytes = contentLength - received;
              final remainingSeconds = remainingBytes / speed;
              etaStr = ' - ETA: ${_formatDuration(Duration(seconds: remainingSeconds.round()))}';
            }

            if (contentLength > 0) {
              _downloadProgress = received / contentLength;
              _statusMessage = 'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}% ($speedStr)$etaStr';
            } else {
               _statusMessage = 'Downloading: ${(received / 1024 / 1024).toStringAsFixed(1)} MB ($speedStr)';
            }
            
            notifyListeners();
            lastUpdateTime = now;
            lastWebBytes = received;
          }
        }
        print('AG_DEBUG: Stream verified complete. Received: $received bytes.');
      } catch (e) {
        print('AG_DEBUG: Stream error: $e');
        rethrow;
      } finally {
        print('AG_DEBUG: Closing file sink...');
        await sink.flush();
        await sink.close();
        client.close();
        print('AG_DEBUG: File sink closed.');
      }

      _isDownloading = false;
      _downloadProgress = 1.0;
      _statusMessage = 'Finalizing...';
      notifyListeners();
      
      print('AG_DEBUG: Checking backend availability...');
      await Future.delayed(const Duration(milliseconds: 500)); // Brief pause
      await checkBackendAvailability();
      print('AG_DEBUG: Backend check complete. Status: $_statusMessage');

    } catch (e, stack) {
      _isDownloading = false;
      _error = 'Error: $e';
      _statusMessage = 'Failed';
      notifyListeners();
      print('AG_DEBUG: Download fatal error: $e');
      print('AG_DEBUG: Stack: $stack');
    }
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(1)} B/s';
    if (bytesPerSec < 1024 * 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }



  String _getExecutableName() {
    if (Platform.isWindows) return 'koboldcpp.exe';
    if (Platform.isLinux) return 'koboldcpp-linux-x64';
    if (Platform.isMacOS) {
      return _arch == 'arm64' ? 'koboldcpp-mac-arm64' : 'koboldcpp-mac-x64';
    }
    return 'koboldcpp';
  }

  String _getDownloadUrl() {
    if (Platform.isWindows) return 'https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp.exe';
    if (Platform.isLinux) return 'https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp-linux-x64';
    if (Platform.isMacOS) {
       return _arch == 'arm64' 
           ? 'https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp-mac-arm64'
           : 'https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp-mac-x64';
    }
    throw Exception('Unsupported platform');
  }
}

