import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:front_porch_ai/services/storage_service.dart';

class ModelManager extends ChangeNotifier {
  final StorageService _storageService;
  List<FileSystemEntity> _models = [];
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _currentDownload;
  String _statusMessage = ''; // Added status message
  
  List<FileSystemEntity> get models => List.unmodifiable(_models);
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get currentDownload => _currentDownload;
  String get statusMessage => _statusMessage;
  String get modelsPath => path.normalize(_storageService.modelsDir.path);

  ModelManager(this._storageService) {
    _init();
    _storageService.addListener(_init);
  }

  @override
  void dispose() {
    _storageService.removeListener(_init);
    super.dispose();
  }

  Future<void> _init() async {
    await refreshModels();
  }

  Future<void> refreshModels() async {
    if (_storageService.rootPath == null) return;
    final modelDir = _storageService.modelsDir;

    if (await modelDir.exists()) {
      print('AG_DEBUG: Scanning for models in ${modelDir.path}');
      try {
        _models = _safeRecursiveScan(modelDir);
        print('AG_DEBUG: Found ${_models.length} models.');
      } catch (e) {
        print('AG_DEBUG: Error scanning models: $e');
        _models = [];
      }
    } else {
      _models = [];
    }
    notifyListeners();
  }

  /// Recursively scans directories for .gguf files, gracefully skipping
  /// any directories that are inaccessible (e.g. System Volume Information).
  List<FileSystemEntity> _safeRecursiveScan(Directory dir) {
    final results = <FileSystemEntity>[];
    try {
      for (final entity in dir.listSync(followLinks: true)) {
        if (entity is Directory) {
          results.addAll(_safeRecursiveScan(entity));
        } else if (entity.path.toLowerCase().endsWith('.gguf')) {
          results.add(entity);
        }
      }
    } catch (e) {
      // Skip directories we can't access (permission denied, etc.)
      print('AG_DEBUG: Skipping inaccessible directory: ${dir.path} ($e)');
    }
    return results;
  }

  Future<void> importLocalModel(String filePath) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file does not exist');
    }

    if (!filePath.toLowerCase().endsWith('.gguf')) {
      throw Exception('File must be a .gguf model');
    }

    final modelDir = _storageService.modelsDir;
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    final fileName = path.basename(filePath);
    final destinationPath = path.join(modelDir.path, fileName);
    
    _statusMessage = 'Importing $fileName...';
    notifyListeners();

    try {
      await sourceFile.copy(destinationPath);
      _statusMessage = 'Imported $fileName';
      await refreshModels();
    } catch (e) {
      _statusMessage = 'Import failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchHFModels(String query) async {
    // Search HF API for models with 'gguf' and 'text-generation' tags
    final url = Uri.parse('https://huggingface.co/api/models?search=$query&filter=gguf,text-generation&limit=10&full=true');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('HF Search Error: $e');
    }
    return [];
  }

  List<String> getRecommendedSearchQueries(int vramMb) {
    // Heuristic recommendations based on VRAM
    final List<String> queries = [];
    
    if (vramMb < 4000) {
      queries.addAll(['TinyLlama', 'Phi-2', 'Qwen-1.5-1.8B']);
    } else if (vramMb < 8000) {
      queries.addAll(['Mistral-7B', 'Llama-2-7b-chat', 'Gemma-7b']);
    } else if (vramMb < 12000) {
      queries.addAll(['Mistral-Nemo', 'Solar-10.7B', 'Yi-9B']);
    } else if (vramMb < 16000) {
      queries.addAll(['Mixtral-8x7B', 'Llama-2-13b', 'Command R']);
    } else {
      queries.addAll(['Llama-3-70B', 'Mixtral-8x22B', 'Midnight-Miqu']);
    }

    return queries;
  }

  Future<List<Map<String, String>>> getModelFiles(String repoId) async {
    // Get file tree
    final url = Uri.parse('https://huggingface.co/api/models/$repoId/tree/main'); // Basic tree fetch
    // Note: Recursive fetch might be needed for subfolders, but start simplest
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .where((f) => f['path'].toString().endsWith('.gguf'))
            .map((f) => {
                  'filename': f['path'].toString(),
                  'url': 'https://huggingface.co/$repoId/resolve/main/${f['path']}',
                  'size': (f['size'] ?? 0).toString(),
                })
            .toList();
      }
    } catch (e) {
      print('HF Files Error: $e');
    }
    return [];
  }

  Future<void> downloadModel(String url, String filename) async {
    if (_isDownloading) return;
    if (_storageService.rootPath == null) return;

    _isDownloading = true;
    _currentDownload = filename;
    _downloadProgress = 0.0;
    _statusMessage = 'Initializing download...';
    notifyListeners();

    try {
      final modelDir = _storageService.modelsDir;
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      final savePath = path.join(modelDir.path, filename);

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download model: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final file = File(savePath);
      final sink = file.openWrite();

      DateTime startTime = DateTime.now();
      DateTime lastUpdateTime = startTime;
      int lastWebBytes = 0;
      
      _statusMessage = 'Downloading...';
      notifyListeners();

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
      } catch (e) {
        print('Stream error: $e');
        rethrow;
      } finally {
        await sink.flush();
        await sink.close();
        client.close();
      }

      _isDownloading = false;
      _currentDownload = null;
      _statusMessage = 'Download complete';
      await refreshModels();
      notifyListeners();

    } catch (e) {
      _isDownloading = false;
      _currentDownload = null;
      _statusMessage = 'Error: $e';
      notifyListeners();
      print('Model download error: $e');
      rethrow;
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

  Future<void> deleteModel(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      await refreshModels();
    }
  }
}

