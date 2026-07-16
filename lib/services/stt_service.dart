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
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/stt/sherpa_whisper_engine.dart';
import 'package:front_porch_ai/services/stt/whisper_sidecar_transport.dart';
import 'package:front_porch_ai/services/tts_service.dart';

/// Call status phases for the voice call loop.
enum CallStatus { idle, listening, transcribing, thinking, speaking }

/// Speech-to-text service using Whisper (faster-whisper) via Python subprocess.
///
/// Handles microphone recording via the `record` package and transcription
/// via a Python helper script (`whisper_stt.py`), mirroring the Kokoro TTS
/// architecture. Supports both push-to-talk and continuous call mode.
class SttService extends ChangeNotifier {
  final StorageService _storageService;
  final AudioRecorder _recorder = AudioRecorder();

  // ---- Push-to-talk state ----
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _lastTranscription;
  String? _lastError;
  String? _recordingPath;

  // ---- Device selection ----
  List<InputDevice> _inputDevices = [];
  String? _selectedDeviceId;

  // ---- Call mode state ----
  bool _isInCall = false;
  bool _isMuted = false;
  CallStatus _callStatus = CallStatus.idle;
  DateTime? _callStartTime;
  Timer? _callTimer;
  Timer? _amplitudeTimer;
  Timer? _ttsWaitTimer;
  Timer? _silenceTimer;
  Duration _callDuration = Duration.zero;
  double _currentAmplitude = 0.0; // 0.0 – 1.0 normalized
  TtsService? _ttsService;

  // ---- Silence detection ----
  double _noiseFloor = 0.15; // default, calibrated at call start
  bool _isCalibrating = false;
  final List<double> _calibrationSamples = [];
  bool _speechDetected = false; // true once user starts talking
  static const double _silenceThresholdMultiplier =
      1.8; // above noise floor = speech
  static const Duration _silenceDuration = Duration(
    seconds: 2,
  ); // silence before auto-send

  /// Called when a transcription is ready during call mode.
  /// The UI should wire this to chatService.sendMessage().
  void Function(String text)? onTranscription;

  /// Called when a full call cycle completes (TTS done speaking, ready to listen).
  /// Used by the UI to know when to auto-resume.
  VoidCallback? onReadyToListen;

  // ---- Getters ----
  bool get isRecording => _isRecording;
  bool get isTranscribing => _isTranscribing;
  bool get isBusy => _isRecording || _isTranscribing;
  String? get lastTranscription => _lastTranscription;
  String? get lastError => _lastError;
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  CallStatus get callStatus => _callStatus;
  Duration get callDuration => _callDuration;
  double get currentAmplitude => _currentAmplitude;
  List<InputDevice> get inputDevices => _inputDevices;
  String? get selectedDeviceId => _selectedDeviceId;

  SttService(this._storageService) {
    _selectedDeviceId = _storageService.selectedMicId;
  }

  // ---- Device Management ----

  /// Refresh the list of available input devices.
  Future<List<InputDevice>> refreshInputDevices() async {
    try {
      _inputDevices = await _recorder.listInputDevices();
      debugPrint('STT: found ${_inputDevices.length} input devices');
      // If selected device no longer exists, reset to default
      if (_selectedDeviceId != null &&
          !_inputDevices.any((d) => d.id == _selectedDeviceId)) {
        _selectedDeviceId = null;
        await _storageService.setSelectedMicId(null);
      }
      notifyListeners();
      return _inputDevices;
    } catch (e) {
      debugPrint('STT: failed to list devices: $e');
      _inputDevices = [];
      notifyListeners();
      return [];
    }
  }

  /// Set the selected microphone device.
  Future<void> setSelectedDevice(String? deviceId) async {
    _selectedDeviceId = deviceId;
    await _storageService.setSelectedMicId(deviceId);
    notifyListeners();
  }

  /// Find the InputDevice object for the selected ID.
  InputDevice? get _selectedDevice {
    if (_selectedDeviceId == null) return null;
    try {
      return _inputDevices.firstWhere((d) => d.id == _selectedDeviceId);
    } catch (_) {
      return null;
    }
  }

  /// Check if any microphone is available. Returns false if none found.
  Future<bool> checkMicAvailable() async {
    await refreshInputDevices();
    // Also check permission
    final hasPerm = await _recorder.hasPermission();
    return hasPerm;
  }

  /// Wire TtsService for call-mode TTS-aware resume.
  void setTtsService(TtsService service) {
    _ttsService = service;
  }

  // ---- Engine availability ----

  /// The in-process sherpa-onnx engine ships with the app, so STT is
  /// always usable natively; only the forced-sidecar mode
  /// (FP_STT_SIDECAR=1) depends on the legacy Python transport existing.
  bool get isEngineUsable =>
      !SherpaWhisperEngine.sidecarForced || WhisperSidecarTransport.isUsable;
  bool get isAvailable => _storageService.sttEnabled && isEngineUsable;

  // ---- Model Download ----
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  String? _downloadError;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;
  String? get downloadError => _downloadError;

  /// Pre-download the selected Whisper model so it's ready for use.
  ///
  /// Downloads for whichever engine will transcribe: the sherpa-onnx
  /// export over direct HTTPS normally, or the sidecar's CTranslate2
  /// model when FP_STT_SIDECAR=1 (the two formats are not interchangeable,
  /// so there is deliberately no cross-engine download fallback).
  Future<bool> downloadModel() async {
    if (_isDownloading) return false;
    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadStatus = 'Starting download...';
    _downloadError = null;
    notifyListeners();

    try {
      final modelSize = _storageService.whisperModel;
      final root =
          _storageService.rootPath ??
          (await getApplicationDocumentsDirectory()).path;
      debugPrint('STT: pre-downloading model=$modelSize');

      bool ok;
      if (!SherpaWhisperEngine.sidecarForced) {
        await SherpaWhisperEngine.downloadModel(
          root,
          modelSize,
          onProgress: (fraction) {
            _downloadProgress = fraction;
            _downloadStatus =
                'Downloading... ${(fraction * 100).round()}%';
            notifyListeners();
          },
        );
        ok = true;
      } else {
        final modelDir = p.join(root, 'system', 'whisper_models');
        await Directory(modelDir).create(recursive: true);
        ok = await WhisperSidecarTransport.download(
          modelSize: modelSize,
          modelDir: modelDir,
          onProgress: (fraction, status) {
            _downloadProgress = fraction;
            _downloadStatus = status;
            notifyListeners();
          },
          onError: (message) => _downloadError = message,
        );
      }

      if (ok) {
        _downloadProgress = 1.0;
        _downloadStatus = 'Complete!';
      }
      _isDownloading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _downloadError = 'Download error: $e';
      debugPrint('STT: download error: $e');
      _isDownloading = false;
      notifyListeners();
      return false;
    }
  }

  // ==== Push-to-Talk (Phase 1) ====

  Future<void> startRecording() async {
    if (_isRecording || _isTranscribing) return;

    if (!await _recorder.hasPermission()) {
      _lastError = 'Microphone permission denied';
      notifyListeners();
      return;
    }

    try {
      final tempDir = Directory.systemTemp;
      _recordingPath = p.join(
        tempDir.path,
        'stt_recording_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
          device: _selectedDevice,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;
      _lastError = null;
      _lastTranscription = null;
      _startAmplitudeMonitor();
      notifyListeners();
      debugPrint('STT: recording started → $_recordingPath');
    } catch (e) {
      _lastError = 'Failed to start recording: $e';
      debugPrint('STT: $e');
      notifyListeners();
    }
  }

  /// Transcribe an already-saved audio file (any format Whisper/ffmpeg can read).
  /// Used by the web server when a browser uploads mic audio recorded on the
  /// client — the host never records. Reuses the same Whisper helper path as the
  /// desktop recorder. The caller owns the file's lifecycle.
  Future<String?> transcribeAudioFile(String audioPath) async {
    if (!File(audioPath).existsSync()) {
      _lastError = 'Audio file not found';
      return null;
    }
    _isTranscribing = true;
    notifyListeners();
    try {
      final result = await _transcribe(audioPath);
      if (result != null && result.isNotEmpty) {
        _lastTranscription = result;
        _lastError = null;
      }
      return result;
    } finally {
      _isTranscribing = false;
      notifyListeners();
    }
  }

  Future<String?> stopRecordingAndTranscribe() async {
    if (!_isRecording) return null;

    try {
      _stopAmplitudeMonitor();
      final path = await _recorder.stop();
      _isRecording = false;
      debugPrint('STT: recording stopped → $path');

      if (path == null || !File(path).existsSync()) {
        _lastError = 'Recording file not found';
        notifyListeners();
        return null;
      }

      final fileSize = File(path).lengthSync();
      if (fileSize < 1000) {
        _lastError = 'Recording too short';
        _cleanupRecording(path);
        notifyListeners();
        return null;
      }

      _isTranscribing = true;
      if (_isInCall) _callStatus = CallStatus.transcribing;
      notifyListeners();

      final result = await _transcribe(path);
      _isTranscribing = false;
      _cleanupRecording(path);

      if (result != null && result.isNotEmpty) {
        _lastTranscription = result;
        _lastError = null;
      } else {
        _lastError = _lastError ?? 'No speech detected';
      }

      notifyListeners();
      return _lastTranscription;
    } catch (e) {
      _isRecording = false;
      _isTranscribing = false;
      _lastError = 'Transcription failed: $e';
      debugPrint('STT error: $e');
      notifyListeners();
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _stopAmplitudeMonitor();
    try {
      final path = await _recorder.stop();
      if (path != null) _cleanupRecording(path);
    } catch (_) {}
    _isRecording = false;
    notifyListeners();
  }

  // ==== Call Mode (Phase 2) ====

  /// Start a voice call. The overlay UI should call this.
  Future<void> startCall() async {
    if (_isInCall) return;

    _isInCall = true;
    _isMuted = false;
    _callStartTime = DateTime.now();
    _callDuration = Duration.zero;
    _lastError = null;
    _lastTranscription = null;
    _speechDetected = false;

    // Start call duration timer
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_callStartTime != null) {
        _callDuration = DateTime.now().difference(_callStartTime!);
        notifyListeners();
      }
    });

    // Calibrate noise floor before listening
    await _calibrateNoiseFloor();
  }

  /// Sample ambient noise for ~1.5s to set the noise floor threshold.
  Future<void> _calibrateNoiseFloor() async {
    _isCalibrating = true;
    _callStatus = CallStatus.idle; // show 'Calibrating...' in UI
    _calibrationSamples.clear();
    notifyListeners();

    // Start recording to get amplitude readings
    await startRecording();
    _startAmplitudeMonitor();

    // Sample for 1.5 seconds
    await Future.delayed(const Duration(milliseconds: 1500));

    // Calculate noise floor from samples
    if (_calibrationSamples.isNotEmpty) {
      _calibrationSamples.sort();
      // Use the 75th percentile as the noise floor
      final idx = (_calibrationSamples.length * 0.75).floor();
      _noiseFloor = _calibrationSamples[idx].clamp(0.05, 0.5);
      debugPrint(
        'STT: noise floor calibrated to $_noiseFloor from ${_calibrationSamples.length} samples',
      );
    } else {
      _noiseFloor = 0.15;
      debugPrint('STT: no calibration samples, using default noise floor');
    }

    // Stop the calibration recording — start fresh for actual listening
    await cancelRecording();
    _stopAmplitudeMonitor();
    _isCalibrating = false;
    _speechDetected = false;

    if (_isInCall && !_isMuted) {
      _callStatus = CallStatus.listening;
      notifyListeners();
      await _startCallRecording();
    }
  }

  /// End the voice call.
  Future<void> endCall() async {
    if (!_isInCall) return;

    _isInCall = false;
    _callStatus = CallStatus.idle;
    _isMuted = false;
    _callTimer?.cancel();
    _callTimer = null;
    _ttsWaitTimer?.cancel();
    _ttsWaitTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _stopAmplitudeMonitor();

    if (_isRecording) {
      await cancelRecording();
    }

    _currentAmplitude = 0.0;
    notifyListeners();
    debugPrint('STT: call ended, duration=${_callDuration.inSeconds}s');
  }

  /// Toggle mute during a call.
  void toggleMute() {
    if (!_isInCall) return;
    _isMuted = !_isMuted;

    if (_isMuted) {
      // Stop recording when muted
      if (_isRecording) {
        cancelRecording();
      }
      _stopAmplitudeMonitor();
      _currentAmplitude = 0.0;
      _callStatus = CallStatus.idle;
    } else {
      // Resume recording when unmuted (only if not in a TTS/transcription phase)
      if (_callStatus == CallStatus.idle && !_isTranscribing) {
        _callStatus = CallStatus.listening;
        _startCallRecording();
      }
    }
    notifyListeners();
  }

  /// Notify the service that the LLM is now generating a response.
  void notifyThinking() {
    if (!_isInCall) return;
    _callStatus = CallStatus.thinking;
    notifyListeners();
  }

  /// Notify the service that TTS has started speaking.
  /// Begins polling for TTS completion to auto-resume listening.
  void notifySpeaking() {
    if (!_isInCall) return;
    _callStatus = CallStatus.speaking;
    notifyListeners();
    _waitForTtsThenResume();
  }

  /// Notify the service that TTS is done and it can resume (called externally or by timer).
  void notifyTtsDone() {
    if (!_isInCall || _isMuted) return;
    _callStatus = CallStatus.listening;
    notifyListeners();
    _startCallRecording();
  }

  // ---- Call internals ----

  Future<void> _startCallRecording() async {
    if (!_isInCall || _isMuted || _isRecording) return;

    _callStatus = CallStatus.listening;
    notifyListeners();
    await startRecording();
  }

  /// Poll TtsService.isSpeaking and resume listening when TTS finishes.
  void _waitForTtsThenResume() {
    _ttsWaitTimer?.cancel();
    _ttsWaitTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isInCall || _isMuted) {
        timer.cancel();
        return;
      }
      // Check if TTS has finished speaking
      if (_ttsService == null || !_ttsService!.isSpeaking) {
        timer.cancel();
        if (_isInCall && !_isMuted) {
          // Small delay after TTS ends before resuming listening
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_isInCall && !_isMuted && _callStatus == CallStatus.speaking) {
              notifyTtsDone();
              onReadyToListen?.call();
            }
          });
        }
      }
    });
  }

  /// Stop and transcribe for call mode, then trigger the callback.
  Future<void> stopAndSendCallTranscription() async {
    if (!_isInCall || !_isRecording) return;

    final text = await stopRecordingAndTranscribe();

    if (text != null && text.isNotEmpty && _isInCall) {
      _callStatus = CallStatus.thinking;
      notifyListeners();
      onTranscription?.call(text);
    } else if (_isInCall && !_isMuted) {
      // No speech detected — resume listening
      _callStatus = CallStatus.listening;
      notifyListeners();
      await _startCallRecording();
    }
  }

  // ==== Amplitude Monitoring ====

  void _startAmplitudeMonitor() {
    _stopAmplitudeMonitor();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      if (!_isRecording) return;
      // During calibration, just collect samples
      if (_isCalibrating) {
        try {
          final amp = await _recorder.getAmplitude();
          final dbfs = amp.current;
          _currentAmplitude = ((dbfs + 60) / 60).clamp(0.0, 1.0);
          _calibrationSamples.add(_currentAmplitude);
        } catch (_) {}
        return;
      }
      try {
        final amp = await _recorder.getAmplitude();
        final dbfs = amp.current;
        _currentAmplitude = ((dbfs + 60) / 60).clamp(0.0, 1.0);

        // Silence detection for call mode
        if (_isInCall && _callStatus == CallStatus.listening) {
          final speechThreshold = _noiseFloor * _silenceThresholdMultiplier;
          if (_currentAmplitude > speechThreshold) {
            // User is speaking
            _speechDetected = true;
            _silenceTimer?.cancel();
            _silenceTimer = null;
          } else if (_speechDetected && _silenceTimer == null) {
            // Speech was detected but now it's silent — start countdown
            _silenceTimer = Timer(_silenceDuration, () {
              if (_isInCall &&
                  _isRecording &&
                  _callStatus == CallStatus.listening &&
                  _speechDetected) {
                debugPrint('STT: silence detected, auto-sending');
                _speechDetected = false;
                stopAndSendCallTranscription();
              }
            });
          }
        }
        notifyListeners();
      } catch (_) {}
    });
  }

  void _stopAmplitudeMonitor() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _currentAmplitude = 0.0;
  }

  // ==== Transcription (in-process sherpa-onnx, sidecar fallback) ====

  Future<String?> _transcribe(String audioPath) async {
    try {
      final modelSize = _storageService.whisperModel;
      final root =
          _storageService.rootPath ??
          (await getApplicationDocumentsDirectory()).path;

      debugPrint('STT: transcribing with model=$modelSize');

      // Native path: WAV input only (the desktop recorder always produces
      // WAV; browser-uploaded webm from the web UI stays on the sidecar).
      if (!SherpaWhisperEngine.sidecarForced &&
          SherpaWhisperEngine.canDecode(audioPath)) {
        try {
          if (!SherpaWhisperEngine.isModelPresent(root, modelSize)) {
            // First use after the engine switch (or a fresh install): the
            // sherpa export downloads on demand, surfaced through the same
            // progress UI as the settings button — mirrors the sidecar,
            // which also auto-downloaded on first transcription.
            await downloadModel();
          }
          if (SherpaWhisperEngine.isModelPresent(root, modelSize)) {
            final text = await SherpaWhisperEngine.transcribe(
              root: root,
              size: modelSize,
              audioPath: audioPath,
            );
            debugPrint(
              '[STT-Native] transcribed "${text.length > 60 ? '${text.substring(0, 60)}...' : text}"',
            );
            return text.isEmpty ? null : text;
          }
        } catch (e) {
          debugPrint('[STT-Native] failed, trying sidecar: $e');
        }
      }

      final modelDir = p.join(root, 'system', 'whisper_models');
      await Directory(modelDir).create(recursive: true);
      final text = await WhisperSidecarTransport.transcribe(
        audioPath: audioPath,
        modelSize: modelSize,
        modelDir: modelDir,
        onError: (message) => _lastError = message,
      );
      if (text != null) {
        debugPrint(
          'STT: transcribed "${text.length > 60 ? '${text.substring(0, 60)}...' : text}"',
        );
      }
      return text;
    } catch (e) {
      _lastError = 'Transcription error: $e';
      debugPrint('STT error: $e');
      return null;
    }
  }

  // ---- Utilities ----

  void _cleanupRecording(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  @override
  void dispose() {
    endCall();
    cancelRecording();
    _recorder.dispose();
    super.dispose();
  }
}
