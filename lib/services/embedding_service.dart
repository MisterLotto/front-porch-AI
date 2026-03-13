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
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';

/// Service that generates text embeddings (numerical vectors) for RAG memory retrieval.
///
/// Supports three embedding sources:
/// - **ONNX Local:** A local Python sidecar running nomic-embed-text-v1.5 on CPU (localhost:5055)
/// - **Local:** KoboldCpp's `/api/extra/generate/embed` endpoint (uses the loaded model)
/// - **API:** Any OpenAI-compatible `/v1/embeddings` endpoint (NanoGPT, OpenRouter, etc.)
class EmbeddingService extends ChangeNotifier {
  final KoboldService _koboldService;
  final StorageService _storageService;

  bool _available = false;
  String _activeSource = 'none'; // 'onnx', 'kobold', 'api', 'none'
  int _dimensions = 0;
  static const String _onnxBaseUrl = 'http://localhost:5055';

  bool get isAvailable => _available;
  String get activeSource => _activeSource;
  int get dimensions => _dimensions;

  EmbeddingService(this._koboldService, this._storageService);

  /// Check if embeddings are available and determine the best source.
  /// Call this after backend connection is established.
  Future<void> checkAvailability() async {
    final preferredSource = _storageService.ragEmbeddingSource;
    debugPrint('[RAG:Embed] ── Checking embedding availability (preferred: $preferredSource) ──');

    if (preferredSource == 'onnx' || preferredSource == 'auto') {
      debugPrint('[RAG:Embed] Trying local ONNX embedding server (localhost:5055)...');
      if (await _checkOnnxEmbeddings()) {
        _available = true;
        _activeSource = 'onnx';
        debugPrint('[RAG:Embed] ✅ Local ONNX embeddings available (${_dimensions}d vectors)');
        notifyListeners();
        return;
      }
      debugPrint('[RAG:Embed] ✗ Local ONNX server not available');
    }

    if (preferredSource == 'kobold' || preferredSource == 'auto') {
      debugPrint('[RAG:Embed] Trying KoboldCpp local embeddings...');
      if (await _checkKoboldEmbeddings()) {
        _available = true;
        _activeSource = 'kobold';
        debugPrint('[RAG:Embed] ✅ KoboldCpp embeddings available (${_dimensions}d vectors)');
        notifyListeners();
        return;
      }
      debugPrint('[RAG:Embed] ✗ KoboldCpp embeddings not available');
    }

    if (preferredSource == 'api' || preferredSource == 'auto') {
      debugPrint('[RAG:Embed] Trying API embeddings (${_storageService.remoteApiUrl})...');
      if (await _checkApiEmbeddings()) {
        _available = true;
        _activeSource = 'api';
        debugPrint('[RAG:Embed] ✅ API embeddings available (${_dimensions}d, model: ${_storageService.ragEmbeddingModel})');
        notifyListeners();
        return;
      }
      debugPrint('[RAG:Embed] ✗ API embeddings not available');
    }

    _available = false;
    _activeSource = 'none';
    debugPrint('[RAG:Embed] ⚠ No embedding source available — RAG retrieval will be inactive');
    notifyListeners();
  }

  /// Test if the local ONNX embedding server is running.
  Future<bool> _checkOnnxEmbeddings() async {
    try {
      final result = await _embedViaOnnx('test');
      if (result != null && result.isNotEmpty) {
        _dimensions = result.length;
        return true;
      }
    } catch (e) {
      debugPrint('[RAG:Embed] ONNX server check failed: $e');
    }
    return false;
  }

  /// Test if KoboldCpp supports embeddings by sending a small test request.
  Future<bool> _checkKoboldEmbeddings() async {
    if (!_koboldService.isRunning) return false;
    try {
      final result = await _embedViaKobold('test');
      if (result != null && result.isNotEmpty) {
        _dimensions = result.length;
        return true;
      }
    } catch (e) {
      debugPrint('[EmbeddingService] KoboldCpp embedding check failed: $e');
    }
    return false;
  }

  /// Test if the remote API supports embeddings.
  Future<bool> _checkApiEmbeddings() async {
    final apiKey = _storageService.remoteApiKey;
    final apiUrl = _storageService.remoteApiUrl;
    if (apiKey.isEmpty || apiUrl.isEmpty) return false;

    try {
      final result = await _embedViaApi('test');
      if (result != null && result.isNotEmpty) {
        _dimensions = result.length;
        return true;
      }
    } catch (e) {
      debugPrint('[EmbeddingService] API embedding check failed: $e');
    }
    return false;
  }

  /// Generate an embedding vector for a text string.
  /// Returns null if embeddings are not available.
  Future<List<double>?> embed(String text) async {
    if (!_available || text.trim().isEmpty) return null;
    final preview = text.length > 80 ? '${text.substring(0, 80)}...' : text;
    final sw = Stopwatch()..start();

    try {
      List<double>? result;
      if (_activeSource == 'onnx') {
        result = await _embedViaOnnx(text);
      } else if (_activeSource == 'kobold') {
        result = await _embedViaKobold(text);
      } else if (_activeSource == 'api') {
        result = await _embedViaApi(text);
      }
      sw.stop();
      if (result != null) {
        debugPrint('[RAG:Embed] ✅ ${result.length}d vector in ${sw.elapsedMilliseconds}ms ← "$preview"');
      } else {
        debugPrint('[RAG:Embed] ✗ Got null result for "$preview"');
      }
      return result;
    } catch (e) {
      sw.stop();
      debugPrint('[RAG:Embed] ✗ Embedding failed (${sw.elapsedMilliseconds}ms): $e');
    }
    return null;
  }

  /// Batch embed multiple texts. Returns null entries for failures.
  Future<List<List<double>?>> embedBatch(List<String> texts) async {
    if (!_available) return List.filled(texts.length, null);

    // For API, we could batch these in a single request, but for simplicity
    // and compatibility with KoboldCpp, we do them sequentially.
    final results = <List<double>?>[];
    for (final text in texts) {
      results.add(await embed(text));
      // Small delay to avoid hammering the backend
      if (texts.length > 5) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    return results;
  }

  /// Embed text using the local ONNX server (OpenAI-compatible format).
  Future<List<double>?> _embedViaOnnx(String text) async {
    final url = '$_onnxBaseUrl/v1/embeddings';
    final uri = Uri.parse(url);
    debugPrint('[RAG:Embed] POST $url (ONNX local, ${text.length} chars)');
    final client = http.Client();
    try {
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'nomic-embed-text-v1.5',
          'input': text,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('[RAG:Embed] ONNX response: HTTP ${response.statusCode}');
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

  /// Embed text using KoboldCpp's local endpoint.
  Future<List<double>?> _embedViaKobold(String text) async {
    final url = '${_koboldService.baseUrl}/api/extra/generate/embed';
    final uri = Uri.parse(url);
    debugPrint('[RAG:Embed] POST $url (${text.length} chars)');
    final client = http.Client();
    try {
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': text}),
      ).timeout(const Duration(seconds: 30));

      debugPrint('[RAG:Embed] KoboldCpp response: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // KoboldCpp returns {"results": [[...vector...]]}
        final results = data['results'];
        if (results is List && results.isNotEmpty) {
          final firstResult = results[0];
          if (firstResult is List) {
            return firstResult.map((e) => (e as num).toDouble()).toList();
          }
        }
        debugPrint('[RAG:Embed] ✗ Unexpected KoboldCpp response format: ${response.body.substring(0, min(200, response.body.length))}');
      } else {
        debugPrint('[RAG:Embed] ✗ KoboldCpp error: ${response.body.substring(0, min(200, response.body.length))}');
      }
    } finally {
      client.close();
    }
    return null;
  }

  /// Embed text using an OpenAI-compatible API endpoint.
  Future<List<double>?> _embedViaApi(String text) async {
    final apiUrl = _storageService.remoteApiUrl;
    final apiKey = _storageService.remoteApiKey;
    final model = _storageService.ragEmbeddingModel;

    final url = '$apiUrl/embeddings';
    final uri = Uri.parse(url);
    debugPrint('[RAG:Embed] POST $url (model: $model, ${text.length} chars)');
    debugPrint('[RAG:Embed] Auth: Bearer ${apiKey.substring(0, min(8, apiKey.length))}...');
    final client = http.Client();
    try {
      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'input': text,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('[RAG:Embed] API response: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // OpenAI format: {"data": [{"embedding": [...]}]}
        final dataList = data['data'];
        if (dataList is List && dataList.isNotEmpty) {
          final embedding = dataList[0]['embedding'];
          if (embedding is List) {
            return embedding.map((e) => (e as num).toDouble()).toList();
          }
        }
        debugPrint('[RAG:Embed] ✗ Unexpected API response format');
      } else {
        debugPrint('[RAG:Embed] ✗ API error: HTTP ${response.statusCode} - ${response.body.substring(0, min(200, response.body.length))}');
      }
    } finally {
      client.close();
    }
    return null;
  }
}
