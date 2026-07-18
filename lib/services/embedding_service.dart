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
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:front_porch_ai/services/embedding_sidecar.dart';
import 'package:front_porch_ai/services/embedding/native_embedding_engine.dart';
import 'package:front_porch_ai/services/engine_health.dart';

/// Service that generates text embeddings (numerical vectors) for RAG memory retrieval.
///
/// In-process nomic-embed-text-v1.5 via onnxruntime first (phase 5 of
/// docs/design/sidecar-retirement.md, golden-pinned to the Rust server's
/// exact vectors so stored embeddings keep matching); the Rust embed_server
/// sidecar remains the automatic fallback for this soak — and the model
/// downloader for fresh installs, whose fastembed cache the native engine
/// then reuses as-is. `FP_EMBED_SIDECAR=1` forces the legacy path.
class EmbeddingService extends ChangeNotifier {
  final EmbeddingSidecar? _sidecar;
  final NativeEmbeddingEngine _native = NativeEmbeddingEngine();
  ({String model, String vocab})? _nativeFiles;

  bool _available = false;
  int _dimensions = 0;
  static const String _baseUrl = 'http://localhost:5055';

  bool get isAvailable => _available;
  String get activeSource => _available ? 'onnx' : 'none';
  int get dimensions => _dimensions;

  EmbeddingService(this._sidecar);

  /// Check if embeddings are available. Native first (no subprocess at
  /// all when the model is on disk); otherwise starts the sidecar, which
  /// also downloads the model on fresh installs.
  Future<void> checkAvailability() async {
    debugPrint('[RAG:Embed] ── Checking embedding availability ──');

    if (!NativeEmbeddingEngine.sidecarForced) {
      _nativeFiles = NativeEmbeddingEngine.resolveModelFiles(null);
      if (_nativeFiles != null) {
        try {
          // Real end-to-end check — also warms the session so the first
          // user-visible embed isn't the one paying the model load.
          final result = await _nativeEmbed('test');
          _dimensions = result.length;
          _available = true;
          debugPrint(
            '[RAG:Embed] ✅ In-process embeddings available '
            '(${_dimensions}d vectors, no sidecar)',
          );
          notifyListeners();
          return;
        } catch (e) {
          debugPrint(
            '[RAG:Embed] in-process engine failed, trying sidecar: $e',
          );
          EngineHealth.instance.reportFailure(
            EngineHealth.embeddings,
            'in-process engine failed: $e',
          );
          _nativeFiles = null;
        }
      } else {
        debugPrint(
          '[RAG:Embed] no local model yet — the sidecar will download it',
        );
      }
    }

    // Auto-start sidecar if available but not running
    if (_sidecar != null && _sidecar.isUsable && !_sidecar.isRunning) {
      debugPrint('[RAG:Embed] Auto-starting ONNX embedding sidecar...');
      await _sidecar.startServer();
    }

    // Wait for model to be ready (whether we just started or it was already running)
    if (_sidecar != null && _sidecar.isRunning && !_sidecar.modelReady) {
      debugPrint('[RAG:Embed] Waiting for model to finish loading...');
      final ready = await _sidecar.waitForModelReady();
      if (!ready) {
        debugPrint(
          '[RAG:Embed] Sidecar running but model not ready: ${_sidecar.error}',
        );
        _available = false;
        notifyListeners();
        return;
      }
    }

    // Test the endpoint
    try {
      final result = await _embed('test');
      if (result != null && result.isNotEmpty) {
        _dimensions = result.length;
        _available = true;
        debugPrint(
          '[RAG:Embed] ✅ Local ONNX embeddings available (${_dimensions}d vectors)',
        );
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('[RAG:Embed] ONNX server check failed: $e');
    }

    _available = false;
    debugPrint(
      '[RAG:Embed] ⚠ Embedding sidecar not available — RAG retrieval will be inactive',
    );
    notifyListeners();
  }

  /// Generate an embedding vector for a text string.
  /// Returns null if embeddings are not available.
  Future<List<double>?> embed(String text) async {
    if (!_available || text.trim().isEmpty) return null;
    final preview = text.length > 80 ? '${text.substring(0, 80)}...' : text;
    final sw = Stopwatch()..start();

    // In-process path (with automatic sidecar fallback during the soak).
    if (_nativeFiles != null) {
      try {
        final result = await _nativeEmbed(text);
        sw.stop();
        EngineHealth.instance.reportNative(EngineHealth.embeddings);
        debugPrint(
          '[RAG:Embed] ✅ ${result.length}d vector in ${sw.elapsedMilliseconds}ms (in-process) ← "$preview"',
        );
        return result;
      } catch (e) {
        debugPrint('[RAG:Embed] in-process embed failed, trying sidecar: $e');
        EngineHealth.instance.reportFailure(
          EngineHealth.embeddings,
          'in-process embed failed: $e',
        );
        if (_sidecar != null && _sidecar.isUsable && !_sidecar.isRunning) {
          await _sidecar.startServer();
          await _sidecar.waitForModelReady();
        }
      }
    }

    try {
      final result = await _embed(text);
      sw.stop();
      if (result != null) {
        debugPrint(
          '[RAG:Embed] ✅ ${result.length}d vector in ${sw.elapsedMilliseconds}ms ← "$preview"',
        );
      } else {
        debugPrint('[RAG:Embed] ✗ Got null result for "$preview"');
      }
      return result;
    } catch (e) {
      sw.stop();
      debugPrint(
        '[RAG:Embed] ✗ Embedding failed (${sw.elapsedMilliseconds}ms): $e',
      );
    }
    return null;
  }

  Future<List<double>> _nativeEmbed(String text) => _native.embed(
    modelPath: _nativeFiles!.model,
    vocabPath: _nativeFiles!.vocab,
    text: text,
  );

  /// Frees the in-process session (~550MB of weights). Called when RAG is
  /// turned off; the next [checkAvailability] reloads it.
  void shutdownNative() {
    _native.shutdown();
  }

  @override
  void dispose() {
    _native.shutdown();
    super.dispose();
  }

  /// Batch embed multiple texts. Returns null entries for failures.
  Future<List<List<double>?>> embedBatch(List<String> texts) async {
    if (!_available) return List.filled(texts.length, null);

    final results = <List<double>?>[];
    for (final text in texts) {
      results.add(await embed(text));
      // Small delay to avoid hammering the server
      if (texts.length > 5) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    return results;
  }

  /// Send text to the local ONNX embedding server (OpenAI-compatible format).
  Future<List<double>?> _embed(String text) async {
    final url = '$_baseUrl/v1/embeddings';
    final uri = Uri.parse(url);
    final client = http.Client();
    try {
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'model': 'nomic-embed-text-v1.5', 'input': text}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dataList = data['data'];
        if (dataList is List && dataList.isNotEmpty) {
          final embedding = dataList[0]['embedding'];
          if (embedding is List) {
            return embedding.map((e) => (e as num).toDouble()).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('[RAG:Embed] ONNX server error: $e');
    } finally {
      client.close();
    }
    return null;
  }
}
