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

  /// Raw provider metadata per '$apiUrl::$modelName' — ONE fetch serves both
  /// the vision verdict and the tool-calling short-circuit. Misses are cached
  /// too (null): the fallback runtime probes are the right degraded path
  /// either way, and [clear] forgets a transient failure.
  final Map<String, ModelApiCapabilities?> _capsCache = {};

  /// 1×1 transparent PNG used by the runtime probe.
  static const String _tinyPngB64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9Q'
      'DwADhgGAWjR9awAAAABJRU5ErkJggg==';

  /// Clear all cached verdicts (e.g. after the user swaps models/backends).
  void clear() {
    _remoteCache.clear();
    _ggufCache.clear();
    _capsCache.clear();
  }

  /// Raw `/models` capabilities (vision + tool calling) for a remote model,
  /// fetched once and cached. Answers ONLY for capability-metadata providers
  /// (OpenRouter / Nano-GPT) — any other host returns null immediately, so
  /// callers fall back to their runtime probes without a wasted request.
  Future<ModelApiCapabilities?> capabilitiesForRemote({
    required String apiUrl,
    required String apiKey,
    required String modelName,
  }) async {
    if (apiUrl.isEmpty || modelName.isEmpty) return null;
    if (!isCapabilityMetadataProviderUrl(apiUrl)) return null;
    final key = '$apiUrl::$modelName';
    if (_capsCache.containsKey(key)) return _capsCache[key];
    final caps = await _fetchModelCapabilities(
      apiUrl: apiUrl,
      apiKey: apiKey,
      modelName: modelName,
      isNanoGpt: isNanoGptUrl(apiUrl),
    );
    _capsCache[key] = caps;
    return caps;
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
  ///
  /// A probe that never REACHED the server (connection refused, timeout) is
  /// not a verdict: it returns none for now but is NOT cached, so the next
  /// ask retries — otherwise checking a moment before the server was up
  /// branded the model "no vision" for the rest of the session.
  Future<VisionSupport> resolveRemote({
    required String apiUrl,
    required String apiKey,
    required String modelName,
  }) async {
    if (modelName.isEmpty || apiUrl.isEmpty) return VisionSupport.none;
    final key = '$apiUrl::$modelName';
    final cached = _remoteCache[key];
    if (cached != null) return cached;

    // Metadata path for the two providers whose /models describe capabilities
    // (capabilitiesForRemote returns null immediately for every other host,
    // and caches so the tool-calling short-circuit shares this one fetch).
    final caps = await capabilitiesForRemote(
      apiUrl: apiUrl,
      apiKey: apiKey,
      modelName: modelName,
    );
    if (caps != null) {
      final verdict = VisionSupport.fromApi(caps);
      _remoteCache[key] = verdict;
      return verdict;
    }

    // Generic OpenAI-compatible / MLX / unknown, or a metadata miss above.
    final probed = await _probeVision(
      apiUrl: apiUrl,
      apiKey: apiKey,
      modelName: modelName,
    );
    if (probed == null) return VisionSupport.none; // unreachable — don't cache
    final verdict = probed
        ? const VisionSupport(true, VisionSource.probe)
        : VisionSupport.none;
    _remoteCache[key] = verdict;
    return verdict;
  }

  /// Vision verdict for the ACTIVE text LLM as configured right now — "can
  /// the current chat model see images?".
  ///
  /// Local backends (kobold / pseudoRemote) are judged from the GGUF that
  /// would actually load: the active .kcpps preset's model when the preset
  /// owns one (mirroring the launch priority in settings_page /
  /// ensureManagedBackendIsRunning), else the last picker-chosen model.
  /// Vision needs an embedded projector, or multimodal arch plus an mmproj
  /// that exists on disk — from the app's per-model mapping OR the preset's
  /// own `mmproj` key. Remaining gap: a server started entirely outside the
  /// app can't be interrogated, so the verdict is "none" — and KoboldCpp
  /// silently ignores images when no projector is loaded rather than
  /// erroring, so a false negative there degrades gracefully.
  /// Remote backends (openRouter / omlx) reuse [resolveRemote] (provider
  /// metadata where available, else the cached 1×1-PNG probe); oMLX rides
  /// OpenRouterService at its fixed local URL (see LLMProvider).
  ///
  /// Known residual: the local verdict is read from the CONFIGURED model
  /// (active preset / last picker model), not from whatever a running server
  /// was actually launched with. If the user changes vision config
  /// mid-session WITHOUT restarting the backend, this can be a false positive
  /// (config says vision, server is still the old text model) — pixels are
  /// sent (KoboldCpp ignores them) and the offline caption fallback is
  /// skipped. LLMProvider clears this resolver's cache on any model-identity
  /// change so the verdict at least re-derives from current config; fully
  /// reconciling config with the live server would require server-state
  /// tracking the app does not yet have. The normal flow (change model, then
  /// restart the backend) is unaffected.
  Future<VisionSupport> resolveForActiveLlm({
    required BackendType backend,
    required StorageService storage,
  }) async {
    switch (backend) {
      case BackendType.kobold:
      case BackendType.pseudoRemote:
        // Launch semantics: when the active preset carries a model that
        // exists, KoboldCpp loads THAT model (--config wins; the picker
        // model only rides along when the preset has none).
        final presetModel = storage.kcppsModelPath;
        final presetOwnsModel =
            presetModel != null && File(presetModel).existsSync();
        final modelPath = presetOwnsModel
            ? presetModel
            : (storage.lastUsedModelPath ?? '');
        if (modelPath.isEmpty || !File(modelPath).existsSync()) {
          return VisionSupport.none;
        }
        final info = await resolveLocalGgufInfo(modelPath);
        final mmproj = storage.mmprojForModel(modelPath);
        final presetMmproj = presetOwnsModel ? storage.kcppsMmprojPath : null;
        return VisionSupport.fromGguf(
          info,
          mmprojConfigured:
              (mmproj != null &&
                  mmproj.isNotEmpty &&
                  File(mmproj).existsSync()) ||
              (presetMmproj != null && File(presetMmproj).existsSync()),
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
            headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
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
  /// as acceptance. Returns null when the request never reached the server
  /// (connection refused, timeout) — "unreachable" is a connectivity fact,
  /// not a capability verdict, and must not be cached as "no vision".
  Future<bool?> _probeVision({
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
      debugPrint('[VisionResolver] probe unreachable/failed: $e');
      return null;
    } finally {
      client.close();
    }
  }
}
