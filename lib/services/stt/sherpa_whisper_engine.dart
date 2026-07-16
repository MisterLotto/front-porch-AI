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

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'package:front_porch_ai/services/model_fetch.dart';

/// In-process Whisper STT via sherpa-onnx (phase 3 of
/// docs/design/sidecar-retirement.md). Replaces the faster-whisper Python
/// sidecar, which was single-shot — it reloaded the CTranslate2 model on
/// EVERY transcription — so the isolate-run load-decode-free pattern here
/// (smolvlm/emotion precedent) is at worst behavior parity and in practice
/// faster (no interpreter startup).
///
/// Models: the sidecar's CTranslate2 files are NOT reusable — sherpa uses
/// its own ONNX export (`csukuangfj/sherpa-onnx-whisper-<size>` int8:
/// encoder + decoder + tokens). Same user-facing size names ('tiny.en',
/// 'base.en', 'small.en') so the settings value carries over; a one-time
/// re-download happens per the retirement playbook, surfaced in Rawhide.md.
///
/// Known divergence, documented + accepted for the soak: the sidecar ran
/// faster-whisper's VAD filter. Here a simple RMS energy trim drops
/// leading/trailing silence (and returns '' for all-silent clips, matching
/// VAD-drops-everything → "No speech detected"); mid-clip silence is left
/// to Whisper. `FP_STT_SIDECAR=1` restores the legacy path entirely.
class SherpaWhisperEngine {
  static final bool sidecarForced =
      Platform.environment['FP_STT_SIDECAR'] == '1';

  static const _hfBase = 'https://huggingface.co/csukuangfj';

  static const _fileSuffixes = [
    'encoder.int8.onnx',
    'decoder.int8.onnx',
    'tokens.txt',
  ];

  /// Where the sherpa export for [size] lives — a `sherpa/` sibling of the
  /// sidecar's CT2 cache so the old files stay untouched until the
  /// post-soak cleanup UI offers to reclaim them.
  static String modelDir(String root, String size) =>
      p.join(root, 'system', 'whisper_models', 'sherpa', size);

  static bool isModelPresent(String root, String size) => _fileSuffixes.every(
    (s) => File(p.join(modelDir(root, size), '$size-$s')).existsSync(),
  );

  /// True when the native path can decode [audioPath] — a RIFF/WAVE file
  /// (the desktop recorder always produces one). Browser-uploaded webm/ogg
  /// from the web UI stays on the sidecar until phase-3 completion.
  static bool canDecode(String audioPath) {
    try {
      final raf = File(audioPath).openSync();
      try {
        final h = raf.readSync(12);
        return h.length == 12 &&
            String.fromCharCodes(h.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(h.sublist(8, 12)) == 'WAVE';
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return false;
    }
  }

  /// Downloads the three-file sherpa export for [size] with one aggregate
  /// progress fraction across the set (encoder dominates the bytes).
  static Future<void> downloadModel(
    String root,
    String size, {
    void Function(double fraction)? onProgress,
  }) async {
    final dir = modelDir(root, size);
    final urls = [
      for (final s in _fileSuffixes)
        '$_hfBase/sherpa-onnx-whisper-$size/resolve/main/$size-$s',
    ];
    final sizes = [for (final u in urls) await ModelFetch.contentLength(u)];
    final overall = sizes.every((s) => s > 0)
        ? sizes.reduce((a, b) => a + b)
        : -1;
    var doneBefore = 0;
    for (var i = 0; i < urls.length; i++) {
      final dest = File(p.join(dir, '$size-${_fileSuffixes[i]}'));
      if (dest.existsSync() && dest.lengthSync() > 0) {
        doneBefore += sizes[i] > 0 ? sizes[i] : 0;
        continue;
      }
      final base = doneBefore;
      await ModelFetch.fetch(
        urls[i],
        dest,
        onProgress: (done, total) {
          if (overall > 0) onProgress?.call((base + done) / overall);
        },
      );
      doneBefore += sizes[i] > 0 ? sizes[i] : 0;
    }
    onProgress?.call(1.0);
  }

  /// Transcribes the WAV at [audioPath]; returns the text ('' for silence).
  /// Throws on any failure — the caller owns the sidecar fallback.
  static Future<String> transcribe({
    required String root,
    required String size,
    required String audioPath,
  }) {
    final dir = modelDir(root, size);
    final libDir = _nativeLibDir();
    return Isolate.run(
      () => _transcribeInIsolate(dir, size, audioPath, libDir),
    );
  }

  /// Directory holding libsherpa-onnx-c-api, or null to let dlopen search
  /// default paths (the Flutter bundle case). FP_SHERPA_LIB overrides for
  /// tests/dev.
  static String? _nativeLibDir() {
    final env = Platform.environment['FP_SHERPA_LIB'];
    if (env != null && env.isNotEmpty) return env;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      if (Platform.isMacOS) p.join(File(exeDir).parent.path, 'Frameworks'),
      if (Platform.isLinux) p.join(exeDir, 'lib'),
      if (Platform.isWindows) exeDir,
    ];
    const lib = {
      'macos': 'libsherpa-onnx-c-api.dylib',
      'linux': 'libsherpa-onnx-c-api.so',
      'windows': 'sherpa-onnx-c-api.dll',
    };
    final name = lib[Platform.operatingSystem];
    for (final c in candidates) {
      if (name != null && File(p.join(c, name)).existsSync()) return c;
    }
    return null;
  }

  static String _transcribeInIsolate(
    String dir,
    String size,
    String audioPath,
    String? libDir,
  ) {
    sherpa.initBindings(libDir);
    final wave = sherpa.readWave(audioPath);
    if (wave.samples.isEmpty) {
      throw const FormatException('unreadable or empty WAV');
    }
    final trimmed = trimSilence(wave.samples);
    if (trimmed.isEmpty) return '';

    final config = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: p.join(dir, '$size-encoder.int8.onnx'),
          decoder: p.join(dir, '$size-decoder.int8.onnx'),
        ),
        tokens: p.join(dir, '$size-tokens.txt'),
        modelType: 'whisper',
        numThreads: math.max(1, Platform.numberOfProcessors ~/ 2),
      ),
    );
    final recognizer = sherpa.OfflineRecognizer(config);
    sherpa.OfflineStream? stream;
    try {
      stream = recognizer.createStream();
      stream.acceptWaveform(samples: trimmed, sampleRate: wave.sampleRate);
      recognizer.decode(stream);
      return recognizer.getResult(stream).text.trim();
    } finally {
      stream?.free();
      recognizer.free();
    }
  }

  /// RMS-gate leading/trailing silence: 20ms frames, threshold at the
  /// greater of an absolute floor and 5% of the loudest frame, 0.3s of
  /// context kept on each side. Returns an empty list for all-silent audio
  /// so callers surface "No speech detected" instead of a Whisper
  /// hallucination.
  static Float32List trimSilence(
    Float32List samples, {
    int sampleRate = 16000,
  }) {
    final frame = sampleRate ~/ 50; // 20ms
    if (samples.length < frame) return Float32List(0);
    final n = samples.length ~/ frame;
    final rms = List<double>.generate(n, (i) {
      var sum = 0.0;
      for (var j = i * frame; j < (i + 1) * frame; j++) {
        sum += samples[j] * samples[j];
      }
      return math.sqrt(sum / frame);
    });
    final peak = rms.reduce(math.max);
    final threshold = math.max(0.004, peak * 0.05);
    var first = -1, last = -1;
    for (var i = 0; i < n; i++) {
      if (rms[i] >= threshold) {
        if (first < 0) first = i;
        last = i;
      }
    }
    if (first < 0) return Float32List(0);
    final pad = (0.3 * sampleRate) ~/ frame;
    final start = math.max(0, first - pad) * frame;
    final end = math.min(samples.length, (last + 1 + pad) * frame);
    return samples.sublist(start, end);
  }
}
