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
import 'package:http/http.dart' as http;

import 'package:front_porch_ai/services/capability/model_capabilities.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/utils/gguf_vision.dart';

/// Resolves ONE cached vision verdict per backend+model identity, mirroring the
/// tool-calling capability probe pattern (resolve with the best signal
/// available, cache the verdict, tolerate every failure by returning "none").
///
/// Resolution priority:
///  - Local GGUF (KoboldCpp / PseudoRemote): parse the file — embedded
///    projector, or multimodal-arch + configured mmproj.
///  - OpenRouter: `architecture.input_modalities` from `/models`.
///  - Nano-GPT: `capabilities.vision` from `/models?detailed=true`.
///  - Generic OpenAI-compatible / MLX / unknown: a tiny runtime image probe.
///
/// A process-wide singleton so a verdict computed in Settings is reused
/// everywhere without re-reading the file or re-hitting the network.
class VisionSupportResolver {
  VisionSupportResolver._();
  static final VisionSupportResolver instance = VisionSupportResolver._();

  final Map<String, VisionSupport> _remoteCache = {};
  final Map<String, GgufVisionInfo?> _ggufCache = {};

  /// 1×1 transparent PNG used by the runtime probe.
  static const String _tinyPngB64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9Q'
      'DwADhgGAWjR9awAAAABJRU5ErkJggg==';

  /// Clear all cached verdicts (e.g. after the user swaps models/backends).
  void clear() {
    _remoteCache.clear();
    _ggufCache.clear();
  }

  /// Parse (and cache) the vision facts for a local GGUF model file.
  /// Returns null when the file can't be read/parsed.
  Future<GgufVisionInfo?> resolveLocalGgufInfo(String modelPath) async {
    if (_ggufCache.containsKey(modelPath)) return _ggufCache[modelPath];
    GgufVisionInfo? info;
    try {
      info = await GgufVisionParser.getVisionInfo(modelPath);
    } catch (_) {
      info = null;
    }
    _ggufCache[modelPath] = info;
    return info;
  }

  /// Resolve vision for an OpenAI-compatible remote backend, choosing the best
  /// signal for the provider inferred from [apiUrl].
  Future<VisionSupport> resolveRemote({
    required String apiUrl,
    required String apiKey,
    required String modelName,
  }) async {
    if (modelName.isEmpty || apiUrl.isEmpty) return VisionSupport.none;
    final key = '$apiUrl::$modelName';
    final cached = _remoteCache[key];
    if (cached != null) return cached;

    final verdict = await _computeRemote(
      apiUrl: apiUrl,
      apiKey: apiKey,
      modelName: modelName,
    );
    _remoteCache[key] = verdict;
    return verdict;
  }

  /// Vision verdict for the ACTIVE text LLM as configured right now — "can
  /// the current chat model see images?".
  ///
  /// Local backends (kobold / pseudoRemote) are judged from the last used
  /// GGUF file: embedded projector, or multimodal arch plus a configured
  /// mmproj that still exists on disk (the same test the Settings projector
  /// field applies). Known gap: when a .kcpps preset owns the model
  /// ([StorageService.lastUsedModelPath] empty) or the server was started
  /// externally, there is no file to interrogate, so the verdict is "none" —
  /// and KoboldCpp silently ignores images when no projector is loaded
  /// rather than erroring, so a false negative here degrades gracefully.
  /// Remote backends (openRouter / omlx) reuse [resolveRemote] (provider
  /// metadata where available, else the cached 1×1-PNG probe); oMLX rides
  /// OpenRouterService at its fixed local URL (see LLMProvider).
  Future<VisionSupport> resolveForActiveLlm({
    required BackendType backend,
    required StorageService storage,
  }) async {
    switch (backend) {
      case BackendType.kobold:
      case BackendType.pseudoRemote:
        final modelPath = storage.lastUsedModelPath ?? '';
        if (modelPath.isEmpty || !File(modelPath).existsSync()) {
          return VisionSupport.none;
        }
        final info = await resolveLocalGgufInfo(modelPath);
        final mmproj = storage.mmprojForModel(modelPath);
        return VisionSupport.fromGguf(
          info,
          mmprojConfigured:
              mmproj != null && mmproj.isNotEmpty && File(mmproj).existsSync(),
        );
      case BackendType.openRouter:
        return resolveRemote(
          apiUrl: storage.remoteApiUrl,
          apiKey: storage.remoteApiKey,
          modelName: storage.remoteModelName,
        );
      case BackendType.omlx:
        return resolveRemote(
          apiUrl: 'http://localhost:8000/v1',
          apiKey: storage.remoteApiKey,
          modelName: storage.remoteModelName,
        );
    }
  }

  Future<VisionSupport> _computeRemote({
    required String apiUrl,
    required String apiKey,
    required String modelName,
  }) async {
    final host = apiUrl.toLowerCase();
    final isOpenRouter = host.contains('openrouter.ai');
    final isNanoGpt = host.contains('nano-gpt');

    // Metadata path for the two providers whose /models describe capabilities.
    if (isOpenRouter || isNanoGpt) {
      final caps = await _fetchModelCapabilities(
        apiUrl: apiUrl,
        apiKey: apiKey,
        modelName: modelName,
        isNanoGpt: isNanoGpt,
      );
      // Provider metadata is authoritative when the model entry was found.
      if (caps != null) return VisionSupport.fromApi(caps);
      // Entry not found / fetch failed → fall through to the probe.
    }

    // Generic OpenAI-compatible / MLX / unknown, or a metadata miss above.
    final probed = await _probeVision(
      apiUrl: apiUrl,
      apiKey: apiKey,
      modelName: modelName,
    );
    return probed
        ? const VisionSupport(true, VisionSource.probe)
        : VisionSupport.none;
  }

  /// Fetch `/models` (detailed for Nano-GPT) and parse the matching entry.
  /// Returns null when the entry can't be found or the request fails.
  Future<ModelApiCapabilities?> _fetchModelCapabilities({
    required String apiUrl,
    required String apiKey,
    required String modelName,
    required bool isNanoGpt,
  }) async {
    final client = http.Client();
    try {
      final base = apiUrl.endsWith('/')
          ? apiUrl.substring(0, apiUrl.length - 1)
          : apiUrl;
      final uri = Uri.parse(
        isNanoGpt ? '$base/models?detailed=true' : '$base/models',
      );
      final response = await client
          .get(
            uri,
            headers: {
              if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      final data =
          (body is Map ? body['data'] : null) as List<dynamic>? ?? const [];
      for (final entry in data) {
        if (entry is! Map) continue;
        final id =
            (entry['id'] ?? entry['name'] ?? entry['model'])?.toString() ?? '';
        if (id != modelName) continue;
        return isNanoGpt
            ? ModelApiCapabilities.fromNanoGptEntry(entry)
            : ModelApiCapabilities.fromOpenRouterEntry(entry);
      }
      return null;
    } catch (e) {
      debugPrint('[VisionResolver] metadata fetch failed: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Send a tiny image via `/chat/completions` and treat a non-error response
  /// as acceptance. Best-effort: any failure → false.
  Future<bool> _probeVision({
    required String apiUrl,
    required String apiKey,
    required String modelName,
  }) async {
    final client = http.Client();
    try {
      final base = apiUrl.endsWith('/')
          ? apiUrl.substring(0, apiUrl.length - 1)
          : apiUrl;
      final uri = Uri.parse('$base/chat/completions');
      final payload = {
        'model': modelName,
        'max_tokens': 1,
        'stream': false,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'ok'},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,$_tinyPngB64'},
              },
            ],
          },
        ],
      };
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) return true;
      // A 4xx that names images/vision/modality means the model rejected the
      // image specifically → definitively no vision.
      if (response.statusCode >= 400 && response.statusCode < 500) {
        final lower = response.body.toLowerCase();
        if (lower.contains('image') ||
            lower.contains('vision') ||
            lower.contains('modality') ||
            lower.contains('multimodal')) {
          return false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[VisionResolver] probe failed: $e');
      return false;
    } finally {
      client.close();
    }
  }
}
