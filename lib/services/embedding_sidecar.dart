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
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Manages the lifecycle of the local ONNX embedding server sidecar.
///
/// The server is a Rust binary that runs nomic-embed-text-v1.5
/// via ONNX Runtime on localhost:5055.
class EmbeddingSidecar extends ChangeNotifier {
  static const int port = 5055;
  static const String _baseUrl = 'http://localhost:$port';

  Process? _process;
  bool _isRunning = false;
  bool _modelReady = false;
  String? _error;
  String _statusMessage = 'Idle';
  double _downloadProgress = -1; // -1 = no download in progress

  bool get isRunning => _isRunning;
  bool get modelReady => _modelReady;
  String? get error => _error;
  String get statusMessage => _statusMessage;
  double get downloadProgress => _downloadProgress;

  /// Whether the sidecar binary exists on disk.
  bool get binaryExists {
    final path = _binaryPath;
    return path != null && File(path).existsSync();
  }

  /// Resolve the path to the embed_server binary.
  ///
  /// Release layout:
  ///   Windows/Linux: <exe_dir>/embed_server/embed_server(.exe)
  ///   macOS:         <bundle>/Contents/Resources/embed_server/embed_server
  ///
  /// Dev mode: walk up from exe dir looking for embed_server.py
  String? get _binaryPath {
    final execDir = File(Platform.resolvedExecutable).parent.path;

    // macOS app bundle
    if (Platform.isMacOS) {
      final contentsDir = File(Platform.resolvedExecutable).parent.parent.path;
      final bundled = p.join(contentsDir, 'Resources', 'embed_server', 'embed_server');
      if (File(bundled).existsSync()) return bundled;
    }

    // Windows / Linux release
    final ext = Platform.isWindows ? '.exe' : '';
    final bundled = p.join(execDir, 'embed_server', 'embed_server$ext');
    if (File(bundled).existsSync()) return bundled;

    return null;
  }

  /// Path to the Rust embed_server binary for dev mode.
  String? get _devBinaryPath {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    var dir = Directory(execDir);
    for (int i = 0; i < 8; i++) {
      final candidate = File(p.join(dir.path, 'tools', 'embed_server', 'target', 'release', 'embed_server'));
      if (candidate.existsSync()) return candidate.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// Whether we can run the sidecar (either bundled binary or dev binary).
  bool get isUsable => _binaryPath != null || _devBinaryPath != null;

  /// Start the embedding server. Returns when the server is listening
  /// (but model may still be loading in background).
  Future<void> startServer() async {
    if (_isRunning) return;

    _error = null;
    _statusMessage = 'Starting embedding server...';
    _downloadProgress = -1;
    notifyListeners();

    // Check if a server from a previous session is already listening (e.g. hot restart)
    try {
      final response = await http.Client()
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 1));
      if (response.statusCode == 200) {
        debugPrint('[EmbedSidecar] Found existing server on port $port — adopting');
        _isRunning = true;
        _statusMessage = 'Adopted existing server';
        _modelReady = false; // Will be updated by waitForModelReady
        notifyListeners();
        return;
      }
    } catch (_) {
      // No existing server — proceed with starting a new one
    }

    try {
      final binaryPath = _binaryPath ?? _devBinaryPath;

      if (binaryPath != null) {
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', binaryPath]);
        }
        _process = await Process.start(binaryPath, []);
      } else {
        _error = 'Embedding server binary not found';
        _statusMessage = 'Error';
        notifyListeners();
        return;
      }

      _isRunning = true;
      _statusMessage = 'Starting...';
      notifyListeners();

      // Listen to stdout for JSON progress events
      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen(_handleStdoutLine);

      // Listen to stderr for errors
      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        debugPrint('[EmbedSidecar:stderr] $line');
      });

      // Monitor process exit
      _process!.exitCode.then((code) {
        debugPrint('[EmbedSidecar] Process exited with code $code');
        _isRunning = false;
        _modelReady = false;
        if (code != 0 && _error == null) {
          _error = 'Embedding server exited with code $code';
          _statusMessage = 'Crashed';
        } else {
          _statusMessage = 'Stopped';
        }
        _process = null;
        notifyListeners();
      });

      // Wait for the server to start listening (poll /health)
      await _waitForListening();

    } catch (e) {
      _error = 'Failed to start embedding server: $e';
      _statusMessage = 'Error';
      _isRunning = false;
      notifyListeners();
      debugPrint('[EmbedSidecar] Start failed: $e');
    }
  }

  /// Parse JSON status lines from the Python server's stdout.
  void _handleStdoutLine(String line) {
    debugPrint('[EmbedSidecar:stdout] $line');
    try {
      final data = jsonDecode(line) as Map<String, dynamic>;
      final event = data['event'] as String?;

      switch (event) {
        case 'status':
          _statusMessage = data['message'] as String? ?? 'Working...';
          notifyListeners();
          break;
        case 'listening':
          _statusMessage = 'Server listening on port $port';
          notifyListeners();
          break;
        case 'ready':
          _modelReady = true;
          _statusMessage = 'Ready';
          _downloadProgress = -1;
          notifyListeners();
          break;
        case 'error':
          _error = data['message'] as String?;
          _statusMessage = 'Error';
          notifyListeners();
          break;
        case 'download_progress':
          _downloadProgress = (data['progress'] as num?)?.toDouble() ?? -1;
          final mb = data['downloaded_mb'] as num?;
          final total = data['total_mb'] as num?;
          if (mb != null && total != null) {
            _statusMessage = 'Downloading model (${mb.toStringAsFixed(0)}/${total.toStringAsFixed(0)} MB)...';
          }
          notifyListeners();
          break;
      }
    } catch (_) {
      // Not JSON — ignore (library debug output, etc.)
    }
  }

  /// Poll /health until the server responds (max 30s).
  Future<void> _waitForListening() async {
    final client = http.Client();
    try {
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_isRunning) return;
        try {
          final response = await client
              .get(Uri.parse('$_baseUrl/health'))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            debugPrint('[EmbedSidecar] Server is listening');
            return;
          }
        } catch (_) {
          // Server not up yet — keep polling
        }
      }
      // Timed out
      if (_error == null) {
        _error = 'Embedding server did not start within 30 seconds';
        _statusMessage = 'Timeout';
        notifyListeners();
      }
    } finally {
      client.close();
    }
  }

  /// Wait for the model to be ready (fully loaded). Max 10 minutes
  /// (first-time model download can be slow on limited connections).
  Future<bool> waitForModelReady() async {
    if (_modelReady) return true;

    final client = http.Client();
    try {
      for (int i = 0; i < 600; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!_isRunning) return false;
        if (_modelReady) return true;
        if (_error != null) return false;

        // Also poll the health endpoint
        try {
          final response = await client
              .get(Uri.parse('$_baseUrl/health/model'))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            _modelReady = true;
            _statusMessage = 'Ready';
            notifyListeners();
            return true;
          }
        } catch (_) {}
      }
    } finally {
      client.close();
    }
    return false;
  }

  /// Ensure server is running and model is ready. Idempotent.
  Future<bool> ensureRunning() async {
    if (_isRunning && _modelReady) return true;
    if (!_isRunning) {
      await startServer();
    }
    if (_error != null) return false;
    return await waitForModelReady();
  }

  /// Stop the embedding server.
  Future<void> stopServer() async {
    if (_process == null) return;
    debugPrint('[EmbedSidecar] Stopping server...');
    _statusMessage = 'Stopping...';
    notifyListeners();

    _process!.kill(ProcessSignal.sigterm);
    try {
      await _process!.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      // Force kill if SIGTERM didn't work
      _process!.kill(ProcessSignal.sigkill);
    }
    _process = null;
    _isRunning = false;
    _modelReady = false;
    _statusMessage = 'Stopped';
    notifyListeners();
  }

  /// Reset error state for a retry.
  void clearError() {
    _error = null;
    _statusMessage = 'Idle';
    notifyListeners();
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
