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
import 'package:path/path.dart' as p;

/// The legacy Python `whisper_stt` sidecar transport, extracted verbatim
/// from SttService when the in-process sherpa-onnx engine became the
/// primary path (docs/design/sidecar-retirement.md phase 3). Kept as the
/// automatic fallback for one release of soak — this whole file gets
/// deleted at phase-3 completion along with the sidecar itself.
class WhisperSidecarTransport {
  static String get wrapperPath {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isMacOS) {
      final contentsDir = File(Platform.resolvedExecutable).parent.parent.path;
      return p.join(contentsDir, 'Resources', 'whisper_stt', 'whisper_stt');
    }
    if (Platform.isWindows) {
      return p.join(execDir, 'whisper_stt', 'whisper_stt.exe');
    }
    return p.join(execDir, 'whisper_stt', 'whisper_stt');
  }

  static bool get hasWrapper {
    try {
      return File(wrapperPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  static String? get helperScriptPath {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    final bundled = p.join(execDir, 'whisper_stt.py');
    if (File(bundled).existsSync()) return bundled;

    var dir = Directory(execDir);
    for (int i = 0; i < 8; i++) {
      final candidate = File(p.join(dir.path, 'whisper_stt.py'));
      if (candidate.existsSync()) return candidate.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  static bool get isUsable => hasWrapper || helperScriptPath != null;

  /// Spawns the sidecar (PyInstaller wrapper preferred, raw python dev
  /// fallback). Returns null when neither exists.
  static Future<Process?> _start() async {
    if (hasWrapper) {
      return Process.start(wrapperPath, []);
    }
    final helperPath = helperScriptPath;
    if (helperPath == null) return null;
    final pythonCmd = Platform.isWindows ? 'python' : 'python3';
    return Process.start(pythonCmd, [
      helperPath,
    ], includeParentEnvironment: true);
  }

  /// Pre-downloads the CTranslate2 model via the sidecar's download_only
  /// mode, parsing tqdm percentages off stderr. Returns true on success.
  static Future<bool> download({
    required String modelSize,
    required String modelDir,
    required void Function(double fraction, String status) onProgress,
    required void Function(String message) onError,
  }) async {
    final request = jsonEncode({
      'model_size': modelSize,
      'model_dir': modelDir,
      'download_only': true,
    });

    final process = await _start();
    if (process == null) {
      onError('Whisper helper script not found');
      return false;
    }

    process.stdin.writeln(request);
    await process.stdin.flush();
    await process.stdin.close();

    // Stream stderr to capture tqdm download progress
    final percentRegex = RegExp(r'(\d+)%');
    String stderrBuffer = '';
    process.stderr.transform(utf8.decoder).listen((chunk) {
      stderrBuffer += chunk;
      // Parse tqdm-style progress: "Downloading: 45%|████ | 45.0M/100M"
      final match = percentRegex.allMatches(chunk).lastOrNull;
      if (match != null) {
        final percent = int.tryParse(match.group(1) ?? '');
        if (percent != null) {
          onProgress(percent / 100.0, 'Downloading... $percent%');
        }
      }
    });

    final output = await process.stdout.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;

    if (exitCode == 0) {
      debugPrint('STT: model download complete');
      return true;
    }
    onError('Download failed');
    debugPrint('STT: download failed: $output $stderrBuffer');
    return false;
  }

  /// Transcribes [audioPath] through the sidecar. Returns the text, or
  /// null after reporting the reason via [onError].
  static Future<String?> transcribe({
    required String audioPath,
    required String modelSize,
    required String modelDir,
    required void Function(String message) onError,
  }) async {
    final request = jsonEncode({
      'audio': audioPath,
      'model_size': modelSize,
      'model_dir': modelDir,
    });

    final process = await _start();
    if (process == null) {
      onError('Whisper helper script not found');
      return null;
    }

    process.stdin.writeln(request);
    await process.stdin.close();

    final stdout = await process.stdout
        .transform(const SystemEncoding().decoder)
        .join();
    final stderr = await process.stderr
        .transform(const SystemEncoding().decoder)
        .join();

    if (stderr.isNotEmpty) {
      debugPrint('STT stderr: $stderr');
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      onError('Whisper process failed (exit code $exitCode)');
      debugPrint('STT: whisper failed with exit code $exitCode');
      return null;
    }

    final trimmed = stdout.trim();
    if (trimmed.isEmpty) {
      onError('Empty response from Whisper');
      return null;
    }

    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      if (json.containsKey('error')) {
        onError(json['error'] as String);
        return null;
      }
      final text = (json['text'] as String? ?? '').trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      onError('Failed to parse Whisper output');
      debugPrint('STT: JSON parse error: $e, output: $trimmed');
      return null;
    }
  }
}
