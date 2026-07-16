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

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/services/expression_classifier.dart';
import 'package:front_porch_ai/services/model_fetch.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'onnx_emotion_engine.dart';

/// ONNX expression classifier: in-process inference first, legacy Python
/// sidecar as automatic fallback (phase 2 of
/// docs/design/sidecar-retirement.md — same fallback-first pattern as the
/// Draw Things native client).
///
/// Rollback lever: `FP_EXPR_SIDECAR=1` forces the legacy sidecar for both
/// classification and model download.
class OnnxEmotionClassifier implements ExpressionClassifier {
  final StorageService storage;
  final void Function(OnnxDownloadProgress)? onProgress;
  final void Function()? onModelReady;

  static final bool _sidecarForced =
      Platform.environment['FP_EXPR_SIDECAR'] == '1';
  static const String _hfBase =
      'https://huggingface.co/Cohee/distilbert-base-uncased-go-emotions-onnx/resolve/main';

  ONNXExpressionClassifier? _sidecar;

  OnnxEmotionClassifier({
    required this.storage,
    this.onProgress,
    this.onModelReady,
  });

  String get _cacheDir => '${storage.rootPath}/models/emotion_classifier';

  ONNXExpressionClassifier get _sidecarClassifier =>
      _sidecar ??= ONNXExpressionClassifier(
        storage: storage,
        onProgress: onProgress,
        onModelReady: onModelReady,
      );

  /// Locates `(model.onnx, vocab source)` — the native flat dir first, then
  /// the sidecar's HuggingFace hub cache (reused as-is, no re-download).
  /// The hub cache may lack vocab.txt (the fast tokenizer only downloads
  /// tokenizer.json); the engine's vocab loader accepts either file.
  (String, String)? _resolveModelFiles() {
    final nativeModel = File('$_cacheDir/native/model.onnx');
    final nativeVocab = File('$_cacheDir/native/vocab.txt');
    if (nativeModel.existsSync() && nativeVocab.existsSync()) {
      return (nativeModel.path, nativeVocab.path);
    }
    final root = Directory(_cacheDir);
    if (!root.existsSync()) return null;
    try {
      for (final e in root.listSync(recursive: true, followLinks: false)) {
        if (e is! File || !e.path.endsWith('model.onnx')) continue;
        // Hub layout: .../snapshots/<rev>/onnx/model.onnx with tokenizer
        // files in the snapshot root two levels up.
        final snapshot = e.parent.parent;
        for (final name in ['vocab.txt', 'tokenizer.json']) {
          final vocab = File('${snapshot.path}/$name');
          if (vocab.existsSync()) return (e.path, vocab.path);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<EmotionResult> classify(String text) async {
    if (text.trim().isEmpty) {
      return const EmotionResult(emotion: 'neutral', confidence: 0.0);
    }
    final files = _sidecarForced ? null : _resolveModelFiles();
    if (files != null) {
      try {
        final scored = await OnnxEmotionEngine.classify(
          modelPath: files.$1,
          vocabPath: files.$2,
          text: text,
        );
        return EmotionResult(
          emotion: scored.first.$1,
          confidence: scored.first.$2,
          topCandidates: [
            for (final (label, score) in scored.take(3))
              EmotionCandidate(emotion: label, confidence: score),
          ],
        );
      } catch (e) {
        debugPrint(
          '[Expr-Native] in-process classify failed, '
          'trying sidecar: $e',
        );
      }
    }
    return _sidecarClassifier.classify(text);
  }

  @override
  Future<bool> isAvailable() async {
    if (!_sidecarForced && _resolveModelFiles() != null) return true;
    return _sidecarClassifier.isAvailable();
  }

  /// Whether [downloadModel] has a usable path: the direct HTTPS download
  /// needs nothing installed; only the forced-sidecar mode depends on
  /// Python being present.
  Future<bool> canDownload() =>
      _sidecarForced ? _sidecarClassifier.isAvailable() : Future.value(true);

  /// Downloads model.onnx + vocab.txt directly over HTTPS (no Python
  /// involved); falls back to the sidecar's `--download-only` mode if the
  /// direct download fails.
  Future<void> downloadModel() async {
    if (!_sidecarForced) {
      try {
        final dir = Directory('$_cacheDir/native');
        await dir.create(recursive: true);
        await _fetch('$_hfBase/vocab.txt', File('${dir.path}/vocab.txt'));
        await _fetch(
          '$_hfBase/onnx/model.onnx',
          File('${dir.path}/model.onnx'),
        );
        onModelReady?.call();
        return;
      } catch (e) {
        debugPrint(
          '[Expr-Native] direct model download failed, '
          'trying sidecar: $e',
        );
      }
    }
    await _sidecarClassifier.downloadModel();
  }

  /// Fetches [url] to [dest] via the shared [ModelFetch] helper, mapping
  /// its per-file progress onto [onProgress].
  Future<void> _fetch(String url, File dest) {
    final name = url.split('/').last;
    return ModelFetch.fetch(
      url,
      dest,
      onProgress: (done, total) => onProgress?.call(
        OnnxDownloadProgress(file: name, downloaded: done, total: total),
      ),
    );
  }

  void dispose() => _sidecar?.dispose();
}
