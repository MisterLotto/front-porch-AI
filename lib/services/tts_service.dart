import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/voice_manager.dart';
import 'package:front_porch_ai/services/tts_engine.dart';
import 'package:front_porch_ai/services/kokoro_engine.dart';
import 'package:front_porch_ai/services/openai_tts_engine.dart';
import 'package:front_porch_ai/services/tts_voice_info.dart';

/// Text-to-speech service — multi-engine architecture.
///
/// Supports: Kokoro (local, default), OpenAI TTS (cloud), Piper (fallback).
/// Handles buffered playback, progress tracking, and text sanitization.
class TtsService extends ChangeNotifier {
  final StorageService _storageService;
  final VoiceManager _voiceManager;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Engines
  final KokoroEngine _kokoroEngine = KokoroEngine();
  final OpenAiTtsEngine _openaiEngine = OpenAiTtsEngine();

  Process? _piperProcess;
  bool _isSpeaking = false;
  bool _isGenerating = false;
  String? _currentMessageId;
  double _generationProgress = 0.0;
  double _modelDownloadProgress = 0.0;
  bool _isDownloadingModel = false;

  // Audio cache — keeps the last generated WAV for instant replay
  File? _cachedWav;
  String? _cachedMessageId;
  int? _cachedTextHash; // hash of sanitized text to detect edits
  String? _cachedVoice;
  String? _cachedEngine;

  bool get isSpeaking => _isSpeaking;
  bool get isGenerating => _isGenerating;
  String? get currentMessageId => _currentMessageId;
  double get generationProgress => _generationProgress;
  double get modelDownloadProgress => _modelDownloadProgress;
  bool get isDownloadingModel => _isDownloadingModel;

  /// The currently active TTS engine instance.
  TtsEngine get activeEngine {
    switch (_storageService.ttsEngine) {
      case 'openai':
        _openaiEngine.apiKey = _storageService.openaiTtsApiKey;
        _openaiEngine.model = _storageService.openaiTtsModel;
        return _openaiEngine;
      case 'kokoro':
        return _kokoroEngine;
      default:
        return _kokoroEngine; // Piper handled separately for backward compat
    }
  }

  /// Whether the current engine is Piper (legacy path).
  bool get _isPiperEngine => _storageService.ttsEngine == 'piper';

  /// Available voices for the active engine.
  List<TtsVoiceInfo> get activeVoices => activeEngine.availableVoices;

  /// Manually download / ensure the model for the active engine is ready.
  /// Returns true if the model is ready after this call.
  Future<bool> downloadModel() async {
    if (_isDownloadingModel) return false; // already downloading
    _isDownloadingModel = true;
    _modelDownloadProgress = 0.0;
    notifyListeners();

    try {
      final ready = await activeEngine.ensureModelReady(onProgress: (p) {
        _modelDownloadProgress = p;
        notifyListeners();
      });
      return ready;
    } catch (e) {
      print('TTS downloadModel error: $e');
      return false;
    } finally {
      _isDownloadingModel = false;
      notifyListeners();
    }
  }

  /// Whether the active engine's model files are already downloaded.
  Future<bool> isModelDownloaded() => activeEngine.isAvailable;

  TtsService(this._storageService, this._voiceManager);

  @override
  void dispose() {
    stop();
    _clearCache();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Speak the given text using the active TTS engine.
  ///
  /// Generates audio for the entire message first (buffered), then plays
  /// it back seamlessly. Shows generation progress.
  Future<void> speak(String text, {String? voiceKey, String? messageId}) async {
    if (!_storageService.ttsEnabled) {
      print('TTS: disabled, skipping');
      return;
    }

    await stop();

    // Resolve voice
    final voice = (voiceKey != null && voiceKey.isNotEmpty)
        ? voiceKey
        : _storageService.ttsVoiceModel;
    if (voice.isEmpty) {
      print('TTS: no voice configured');
      return;
    }

    final sanitized = _sanitizeText(text);
    if (sanitized.trim().isEmpty) {
      print('TTS: text empty after sanitization');
      return;
    }

    // For Piper, check model file exists
    if (_isPiperEngine) {
      final modelPath = await _voiceManager.getVoiceModelPath(voice);
      if (!File(modelPath).existsSync()) {
        print('TTS: Piper voice model not found at $modelPath');
        return;
      }
    }

    // Check cache — replay instantly if same message & same content
    final textHash = sanitized.hashCode;
    if (messageId != null &&
        messageId == _cachedMessageId &&
        textHash == _cachedTextHash &&
        voice == _cachedVoice &&
        _storageService.ttsEngine == _cachedEngine &&
        _cachedWav != null &&
        _cachedWav!.existsSync()) {
      print('TTS: cache hit for message $messageId');
      _isSpeaking = true;
      _isGenerating = false;
      _currentMessageId = messageId;
      notifyListeners();
      try {
        await _playWavFile(_cachedWav!);
      } catch (e) {
        print('TTS cache playback error: $e');
      } finally {
        _isSpeaking = false;
        _currentMessageId = null;
        notifyListeners();
      }
      return;
    }

    // Different message — clear old cache
    if (messageId != _cachedMessageId) {
      _clearCache();
    }

    print('TTS: engine=${_storageService.ttsEngine}, voice=$voice, text="${sanitized.substring(0, sanitized.length.clamp(0, 60))}..."');
    _isSpeaking = true;
    _isGenerating = true;
    _generationProgress = 0.0;
    _currentMessageId = messageId;
    notifyListeners();

    try {
      // For Kokoro, ensure model is downloaded
      if (_storageService.ttsEngine == 'kokoro') {
        final ready = await activeEngine.ensureModelReady(onProgress: (p) {
          _modelDownloadProgress = p;
          _isDownloadingModel = p < 1.0;
          notifyListeners();
        });
        _isDownloadingModel = false;
        if (!ready || !_isSpeaking) {
          print('TTS: Kokoro model not ready');
          return;
        }
      }

      final sentences = _splitSentences(sanitized);
      final wavFiles = List<File?>.filled(sentences.length, null);

      // Phase 1: Generate sentence WAV files in parallel batches
      // Piper uses a shared process handle, so it stays sequential.
      // Kokoro/OpenAI spawn independent subprocesses — parallelise them.
      final maxConcurrency = _storageService.ttsConcurrency;

      if (_isPiperEngine) {
        // Sequential for Piper (legacy)
        for (int i = 0; i < sentences.length; i++) {
          if (!_isSpeaking) break;
          final modelPath = await _voiceManager.getVoiceModelPath(voice);
          wavFiles[i] = await _generatePiperWav(sentences[i], modelPath, i);
          if (wavFiles[i] == null || !_isSpeaking) break;
          _generationProgress = (i + 1) / sentences.length;
          notifyListeners();
        }
      } else {
        // Parallel for Kokoro / OpenAI
        final engine = activeEngine;
        final speed = _storageService.ttsSpeechRate;

        for (int batchStart = 0; batchStart < sentences.length; batchStart += maxConcurrency) {
          if (!_isSpeaking) break;

          final batchEnd = (batchStart + maxConcurrency).clamp(0, sentences.length);
          final futures = <Future<File?>>[];

          for (int i = batchStart; i < batchEnd; i++) {
            futures.add(engine.generateAudio(sentences[i], voice, speed));
          }

          final results = await Future.wait(futures);

          // Store results in order
          bool failed = false;
          for (int j = 0; j < results.length; j++) {
            if (results[j] == null || !_isSpeaking) { failed = true; break; }
            wavFiles[batchStart + j] = results[j];
          }
          if (failed) break;

          _generationProgress = batchEnd / sentences.length;
          notifyListeners();
        }
      }

      // Collect non-null results in order
      final validWavFiles = wavFiles.whereType<File>().toList();

      if (!_isSpeaking || validWavFiles.isEmpty) {
        _cleanupFiles(validWavFiles);
        return;
      }

      // Phase 2: Concatenate and play
      _isGenerating = false;
      notifyListeners();

      final combinedWav = await _concatenateWavFiles(validWavFiles);
      _cleanupFiles(validWavFiles);

      if (combinedWav != null && _isSpeaking) {
        // Cache the combined WAV for instant replay
        _cachedWav = combinedWav;
        _cachedMessageId = messageId;
        _cachedTextHash = sanitized.hashCode;
        _cachedVoice = voice;
        _cachedEngine = _storageService.ttsEngine;
        await _playWavFile(combinedWav);
        // Don't delete — it's cached now
      }
    } catch (e) {
      print('TTS error: $e');
    } finally {
      _isSpeaking = false;
      _isGenerating = false;
      _generationProgress = 0.0;
      _currentMessageId = null;
      notifyListeners();
    }
  }

  /// Stop any active speech.
  Future<void> stop() async {
    _isSpeaking = false;
    _isGenerating = false;
    _generationProgress = 0.0;
    _currentMessageId = null;

    _piperProcess?.kill();
    _piperProcess = null;

    await _audioPlayer.stop();
    notifyListeners();
  }

  // ---- Piper legacy support ----

  /// Resolve the path to the bundled Piper binary (PyInstaller-built).
  String _piperBinaryPath() {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isWindows) {
      return p.join(execDir, 'piper', 'piper.exe');
    } else if (Platform.isMacOS) {
      final contentsDir = File(Platform.resolvedExecutable).parent.parent.path;
      return p.join(contentsDir, 'Resources', 'piper', 'piper');
    } else {
      return p.join(execDir, 'piper', 'piper');
    }
  }

  /// Check if the Piper binary is available.
  bool get isPiperAvailable {
    try {
      return File(_piperBinaryPath()).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Generate a WAV file using Piper.
  Future<File?> _generatePiperWav(String text, String modelPath, int index) async {
    try {
      final piperPath = _piperBinaryPath();
      final voicesDir = p.dirname(modelPath);
      final voiceName = p.basenameWithoutExtension(modelPath);

      final tempDir = Directory.systemTemp;
      final wavFile = File(p.join(tempDir.path,
          'piper_tts_${DateTime.now().millisecondsSinceEpoch}_$index.wav'));

      _piperProcess = await Process.start(piperPath, [
        '-m', voiceName,
        '--data-dir', voicesDir,
        '-f', wavFile.path,
      ]);

      _piperProcess!.stdin.writeln(text);
      await _piperProcess!.stdin.close();

      final stderr = await _piperProcess!.stderr
          .transform(const SystemEncoding().decoder)
          .join();
      if (stderr.isNotEmpty) print('Piper stderr: $stderr');

      final exitCode = await _piperProcess!.exitCode;
      _piperProcess = null;

      if (exitCode != 0 || !wavFile.existsSync() || wavFile.lengthSync() == 0) {
        print('Piper failed with exit code $exitCode');
        return null;
      }
      return wavFile;
    } catch (e) {
      print('Piper error: $e');
      _piperProcess = null;
      return null;
    }
  }

  // ---- Audio utilities ----

  /// Concatenate multiple WAV files into a single WAV file.
  Future<File?> _concatenateWavFiles(List<File> wavFiles) async {
    if (wavFiles.isEmpty) return null;
    if (wavFiles.length == 1) return wavFiles.first;

    try {
      final firstBytes = await wavFiles.first.readAsBytes();
      if (firstBytes.length < 44) return null;

      final bd = ByteData.sublistView(firstBytes);
      final sampleRate = bd.getUint32(24, Endian.little);
      final channels = bd.getUint16(22, Endian.little);
      final bitsPerSample = bd.getUint16(34, Endian.little);
      final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
      final blockAlign = channels * (bitsPerSample ~/ 8);

      final pcmChunks = <Uint8List>[];
      int totalPcmBytes = 0;

      for (final file in wavFiles) {
        final bytes = await file.readAsBytes();
        if (bytes.length <= 44) continue;

        int dataOffset = 12;
        while (dataOffset < bytes.length - 8) {
          final chunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
          final chunkSize = ByteData.sublistView(bytes).getUint32(dataOffset + 4, Endian.little);
          if (chunkId == 'data') {
            final pcmStart = dataOffset + 8;
            final pcmEnd = (pcmStart + chunkSize).clamp(0, bytes.length);
            final pcm = bytes.sublist(pcmStart, pcmEnd);
            pcmChunks.add(Uint8List.fromList(pcm));
            totalPcmBytes += pcm.length;
            break;
          }
          dataOffset += 8 + chunkSize;
        }
      }

      if (totalPcmBytes == 0) return null;

      final fileSize = 36 + totalPcmBytes;
      final header = ByteData(44);
      // RIFF
      header.setUint8(0, 0x52); header.setUint8(1, 0x49);
      header.setUint8(2, 0x46); header.setUint8(3, 0x46);
      header.setUint32(4, fileSize, Endian.little);
      header.setUint8(8, 0x57); header.setUint8(9, 0x41);
      header.setUint8(10, 0x56); header.setUint8(11, 0x45);
      // fmt
      header.setUint8(12, 0x66); header.setUint8(13, 0x6D);
      header.setUint8(14, 0x74); header.setUint8(15, 0x20);
      header.setUint32(16, 16, Endian.little);
      header.setUint16(20, 1, Endian.little);
      header.setUint16(22, channels, Endian.little);
      header.setUint32(24, sampleRate, Endian.little);
      header.setUint32(28, byteRate, Endian.little);
      header.setUint16(32, blockAlign, Endian.little);
      header.setUint16(34, bitsPerSample, Endian.little);
      // data
      header.setUint8(36, 0x64); header.setUint8(37, 0x61);
      header.setUint8(38, 0x74); header.setUint8(39, 0x61);
      header.setUint32(40, totalPcmBytes, Endian.little);

      final tempDir = Directory.systemTemp;
      final combinedFile = File(p.join(tempDir.path,
          'tts_combined_${DateTime.now().millisecondsSinceEpoch}.wav'));
      final sink = combinedFile.openWrite();
      sink.add(header.buffer.asUint8List());
      for (final chunk in pcmChunks) {
        sink.add(chunk);
      }
      await sink.close();

      return combinedFile;
    } catch (e) {
      print('Error concatenating WAV files: $e');
      return null;
    }
  }

  void _cleanupFiles(List<File> files) {
    for (final file in files) {
      try { file.deleteSync(); } catch (_) {}
    }
  }

  /// Delete the cached audio file and reset cache state.
  void _clearCache() {
    if (_cachedWav != null) {
      try { _cachedWav!.deleteSync(); } catch (_) {}
      _cachedWav = null;
    }
    _cachedMessageId = null;
    _cachedTextHash = null;
    _cachedVoice = null;
    _cachedEngine = null;
  }

  /// Play a WAV file using audioplayers.
  Future<void> _playWavFile(File wavFile) async {
    final completer = Completer<void>();

    late StreamSubscription sub;
    sub = _audioPlayer.onPlayerComplete.listen((_) {
      sub.cancel();
      if (!completer.isCompleted) completer.complete();
    });

    await _audioPlayer.play(DeviceFileSource(wavFile.path));
    await completer.future;
  }

  // ---- Text processing ----

  /// Sanitize text for TTS: remove think tags, markdown, emotes, OOC, etc.
  String _sanitizeText(String text) {
    var result = text;
    result = result.replaceAll(RegExp(r'<think>.*?</think>', caseSensitive: false, dotAll: true), '');
    result = result.replaceAll(RegExp(r'<think>.*$', caseSensitive: false, dotAll: true), '');
    result = result.replaceAll(RegExp(r'\(OOC:.*?\)', caseSensitive: false), '');
    result = result.replaceAll(RegExp(r'\[OOC:.*?\]', caseSensitive: false), '');
    result = result.replaceAll(RegExp(r'\*'), '');
    result = result.replaceAll(RegExp(r'#{1,6}\s'), '');
    result = result.replaceAll(RegExp(r'[_~`]'), '');
    result = result.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    result = result.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');
    result = result.replaceAll(RegExp(r':[a-zA-Z0-9_]+:'), '');
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    return result.trim();
  }

  /// Split text into sentences for progress tracking.
  List<String> _splitSentences(String text) {
    final sentences = <String>[];
    final parts = text.split(RegExp(r'(?<=[.!?])\s+'));
    for (final part in parts) {
      if (part.trim().isEmpty) continue;
      if (sentences.isNotEmpty && sentences.last.length < 20) {
        sentences.last = '${sentences.last} ${part.trim()}';
      } else {
        sentences.add(part.trim());
      }
    }
    if (sentences.isEmpty && text.trim().isNotEmpty) {
      sentences.add(text.trim());
    }
    return sentences;
  }
}
