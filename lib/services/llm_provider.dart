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

import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:front_porch_ai/services/backend_manager.dart';
import 'package:front_porch_ai/services/capability/vision_support_resolver.dart';
import 'package:front_porch_ai/services/live_gen_progress.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/lmstudio_log_streamer.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/omlx_status_poller.dart';
import 'package:front_porch_ai/services/open_router_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';

/// The available backend types. The former `pseudoRemote` (a local KoboldCpp
/// launched from a .kcpps preset) was folded into [kobold]: the local backend
/// launches a preset via `--config` when one is active, so it was a redundant
/// second path. Presets are now just a launch option of the Kobold backend.
enum BackendType { kobold, openRouter, omlx }

/// Manages switching between LLM backends (local KoboldCPP, remote APIs).
///
/// Sits between ChatService and the actual backend implementations.
/// Listens to StorageService for config changes and hot-swaps the active service.
class LLMProvider extends ChangeNotifier {
  final KoboldService _koboldService;
  final OpenRouterService _openRouterService;
  final StorageService _storageService;
  final BackendManager _backendManager;

  BackendType _activeBackend = BackendType.kobold;

  // ── Live generation status sources (truthful status bar) ────────────────
  // One shared struct per non-Kobold source; [activeLiveProgress] resolves
  // which one the UIs read. Wired lazily: the oMLX poller only issues HTTP
  // while [isGenerationActive] says a chat generation is running, and the
  // LM Studio log stream only spawns for a localhost OpenAI backend with
  // LM Studio's CLI present.
  late final OmlxStatusPoller _omlxPoller = OmlxStatusPoller(
    isActive: () => isGenerationActive?.call() ?? false,
  );
  final LmStudioLogStreamer _lmStudioStreamer = LmStudioLogStreamer();

  /// Set from main.dart wiring (mirrors the setX style): lets the status
  /// sources gate their work on ChatService.isGenerating without this class
  /// depending on ChatService.
  bool Function()? isGenerationActive;

  /// The live progress source for the ACTIVE backend, or null when none can
  /// exist (plain remote APIs — providers expose no prefill data).
  LiveGenProgress? get activeLiveProgress {
    switch (_activeBackend) {
      case BackendType.kobold:
        return _koboldService.liveProgress;
      case BackendType.omlx:
        return _omlxPoller.progress;
      case BackendType.openRouter:
        // LM Studio presents as an OpenAI backend on localhost; its runtime
        // log is only attachable when its CLI exists on this machine.
        return _lmStudioStreamer.isRunning ? _lmStudioStreamer.progress : null;
    }
  }

  /// Start/stop the per-backend live-status sources for the current backend
  /// + URL. Called on backend switches; safe to call repeatedly.
  void _syncLiveStatusSources() {
    if (_activeBackend == BackendType.omlx) {
      _omlxPoller.start(_openRouterService.apiUrl);
    } else {
      _omlxPoller.stop();
    }
    final url = _openRouterService.apiUrl;
    final isLocalOpenAi =
        _activeBackend == BackendType.openRouter &&
        (url.contains('localhost') || url.contains('127.0.0.1'));
    if (isLocalOpenAi) {
      // Only attach to servers that really ARE LM Studio: its /api/v0/models
      // endpoint is the same signature the vision resolver uses. Without
      // this check, `lms log stream` could spawn against someone else's
      // local OpenAI server (llama.cpp, text-gen-webui) and — worse — wake
      // LM Studio's background service uninvited.
      _startLmStudioStreamerIfConfirmed(url);
    } else {
      _lmStudioStreamer.stop();
    }
  }

  Future<void> _startLmStudioStreamerIfConfirmed(String apiUrl) async {
    if (_lmStudioStreamer.isRunning) return;
    if (LmStudioLogStreamer.lmsBinaryPath() == null) return;
    try {
      final base = apiUrl.replaceFirst(RegExp(r'/v1/?$'), '');
      final resp = await http
          .get(Uri.parse('$base/api/v0/models'))
          .timeout(const Duration(seconds: 2));
      if (resp.statusCode == 200) {
        await _lmStudioStreamer.start();
      }
    } catch (_) {
      // Not LM Studio (or not up) — stay detached; a later backend switch
      // re-probes.
    }
  }

  BackendType get activeBackend => _activeBackend;
  LLMService get activeService {
    switch (_activeBackend) {
      case BackendType.kobold:
        return _koboldService;
      case BackendType.openRouter:
      case BackendType.omlx:
        return _openRouterService;
    }
  }

  /// Whether the active backend is the local KoboldCpp instance (native or
  /// launched from a .kcpps preset). Gates the local niceties — real
  /// tokenizer counts and prefill perf metrics — and sequential eval dispatch
  /// (one KoboldCpp generation slot).
  bool get isLocal => _activeBackend == BackendType.kobold;

  /// Whether the active backend manages a local subprocess.
  bool get hasManagedProcess => _activeBackend == BackendType.kobold;

  /// True when the managed process is currently running.
  bool get hasAnyManagedProcessRunning => _koboldService.isRunning;

  /// Ensures the local Kobold backend is running when the user enters a chat —
  /// including when a .kcpps preset owns the model. Good "it just works" for
  /// normal users; safe to call repeatedly (no-op if already running or the
  /// active backend is remote / oMLX).
  Future<void> ensureManagedBackendIsRunning() async {
    if (!hasManagedProcess || hasAnyManagedProcessRunning) return;

    // Make sure we have the backend binary
    if (_backendManager.backendPath == null) {
      await _backendManager.checkBackendAvailability();
      if (_backendManager.backendPath == null) {
        // Binary not available (download may be needed). Let the user
        // trigger it manually via Settings or the normal flow.
        return;
      }
    }

    try {
      // Auto-start the local Kobold backend, whether it loads a plain model
      // file (lastUsedModelPath) or a .kcpps preset that owns its own model.
      if (_activeBackend == BackendType.kobold) {
        final modelPath = _storageService.lastUsedModelPath;
        final hasPresetWithModel =
            _storageService.kcppsHasModel &&
            _storageService.kcppsModelFileExists;

        if (modelPath != null || hasPresetWithModel) {
          await _koboldService.startKobold(
            _backendManager.backendPath!,
            modelPath ?? '',
            kcppsPath: _storageService.activeKcppsPath,
            mmprojPath: modelPath != null
                ? _storageService.mmprojForModel(modelPath)
                : null,
            gpuLayers: _storageService.gpuLayers,
            contextSize: _storageService.contextSize,
            useVulkan: _storageService.useVulkan ?? false,
            useCublas: _storageService.useCublas ?? false,
            useMetal: _storageService.useMetal ?? false,
            useRocm: _storageService.useRocm ?? false,
          );
        }
      }
    } catch (e) {
      // Never let an auto-start failure prevent the user from entering the chat.
      debugPrint('[LLMProvider] ensureManagedBackendIsRunning failed: $e');
    }
  }

  /// Convenience getters for the underlying services (for UI that needs specifics).
  KoboldService get koboldService => _koboldService;
  OpenRouterService get openRouterService => _openRouterService;

  // ── Backend-aware model catalog ────────────────────────────────────────
  // The list every model dropdown reads. Auto-refetched whenever the active
  // backend (or the remote URL/key behind it) changes, so switching oMLX ↔
  // Remote API pings the newly selected provider immediately instead of
  // leaving the previous provider's models on screen until a manual refresh
  // (maintainer report, 2026-07-14: the chat-side dropdown kept oMLX's local
  // models after switching to OpenRouter/Nano-GPT).
  List<RemoteModelInfo> _modelCatalog = const [];
  String? _catalogIdentity;
  String? _catalogFetchInFlight;

  List<RemoteModelInfo> get modelCatalog => _modelCatalog;
  bool get modelCatalogLoading => _catalogFetchInFlight != null;

  /// What the catalog is FOR right now: backend + the URL/key that feed it.
  /// Null for the local Kobold backend (its models are GGUF files on disk,
  /// picked through the Model Hub — no HTTP catalog exists).
  String? get _liveCatalogIdentity {
    switch (_activeBackend) {
      case BackendType.kobold:
        return null;
      case BackendType.omlx:
        return 'omlx|http://localhost:8000/v1|${_storageService.remoteApiKey}';
      case BackendType.openRouter:
        return 'openRouter|${_storageService.remoteApiUrl}|'
            '${_storageService.remoteApiKey}';
    }
  }

  /// Fetch the active provider's model list if the cached one is for a
  /// different backend/URL/key (or [force]). Uses the explicit-override fetch
  /// so the live chat configuration is never mutated. A result that arrives
  /// after ANOTHER switch is discarded — the last selected backend wins.
  Future<List<RemoteModelInfo>> refreshModelCatalog({bool force = false}) async {
    final identity = _liveCatalogIdentity;
    if (identity == null) {
      if (_modelCatalog.isNotEmpty || _catalogIdentity != null) {
        _modelCatalog = const [];
        _catalogIdentity = null;
        notifyListeners();
      }
      return const [];
    }
    if (!force && identity == _catalogIdentity && _modelCatalog.isNotEmpty) {
      return _modelCatalog;
    }
    // Dedupe per TARGET, not globally: a fetch for this same identity is
    // already running → let it land. A fetch for a DIFFERENT identity (the
    // user just switched backends mid-fetch) must NOT block this one — a
    // global single-flight here skipped the new backend's fetch entirely and
    // left the catalog stuck empty until the next settings write (review
    // finding). The last-selected-wins publish guard below keeps a late
    // stale result from clobbering the fresh one.
    if (_catalogFetchInFlight == identity && !force) return _modelCatalog;
    _catalogFetchInFlight = identity;
    notifyListeners();
    try {
      final url = _activeBackend == BackendType.omlx
          ? 'http://localhost:8000/v1'
          : _storageService.remoteApiUrl;
      final models = await _openRouterService.fetchAvailableModels(
        apiUrl: url,
        apiKey: _storageService.remoteApiKey,
      );
      if (identity == _liveCatalogIdentity) {
        _modelCatalog = models;
        _catalogIdentity = models.isEmpty ? null : identity;
      }
      return models;
    } catch (e) {
      debugPrint('[LLMProvider] model catalog fetch failed: $e');
      return const [];
    } finally {
      if (_catalogFetchInFlight == identity) _catalogFetchInFlight = null;
      notifyListeners();
    }
  }

  LLMProvider(
    this._koboldService,
    this._openRouterService,
    this._storageService,
    this._backendManager,
  ) {
    _syncFromStorage();
    _storageService.addListener(_syncFromStorage);
    _koboldService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _storageService.removeListener(_syncFromStorage);
    _koboldService.removeListener(_onServiceChanged);
    _omlxPoller.stop();
    _lmStudioStreamer.stop();
    super.dispose();
  }

  void _onServiceChanged() {
    notifyListeners();
  }

  void _syncFromStorage() {
    final typeStr = _storageService.backendType;
    BackendType newType;
    switch (typeStr) {
      case 'openRouter':
        newType = BackendType.openRouter;
      case 'omlx':
        newType = BackendType.omlx;
      // 'pseudoRemote' (legacy) falls through to kobold — the preset now runs
      // under the local Kobold backend. The stored value is rewritten to
      // 'kobold' by the migration in BackendSettings.load().
      default:
        newType = BackendType.kobold;
    }

    if (newType == BackendType.omlx) {
      _openRouterService.configure(
        apiUrl: 'http://localhost:8000/v1',
        apiKey: _storageService.remoteApiKey,
        modelName: _storageService.remoteModelName,
      );
    } else {
      _openRouterService.configure(
        apiUrl: _storageService.remoteApiUrl,
        apiKey: _storageService.remoteApiKey,
        modelName: _storageService.remoteModelName,
      );
    }
    debugPrint(
      '[LLMProvider] Synced from storage: backend=$typeStr, URL=${_storageService.remoteApiUrl}',
    );

    // Drop cached vision/tool-calling verdicts whenever the model identity the
    // app is pointed at changes — backend type, remote URL/model, or active
    // preset. Otherwise a switch from a vision model to a text-only one on the
    // same endpoint keeps reporting the old "supported" verdict, and the photo
    // attach path trusts it. (Local-model verdicts are re-derived from config
    // each call, so this mainly guards the remote /models-metadata cache.)
    final identity =
        '$typeStr|${_storageService.remoteApiUrl}|'
        '${_storageService.remoteModelName}|${_storageService.activeKcppsPath}|'
        '${_storageService.lastUsedModelPath}';
    if (identity != _lastModelIdentity) {
      _lastModelIdentity = identity;
      VisionSupportResolver.instance.clear();
      // URL/model changes without a backend-type flip must also re-evaluate
      // the live-status sources (e.g. the remote URL edited from a cloud
      // host to a localhost LM Studio, or an oMLX port change) — review
      // finding: type-only syncing left the streamer attached/detached
      // against the wrong server.
      _syncLiveStatusSources();
    }

    if (newType != _activeBackend) {
      _activeBackend = newType;
      _syncLiveStatusSources();
      notifyListeners();
    }

    // Keep the model catalog pointed at the selected provider. Identity-
    // guarded internally, so repeated syncs with nothing changed are no-ops;
    // fire-and-forget so storage listeners never await network.
    unawaited(refreshModelCatalog());
  }

  /// Last model-identity string synced from storage; used to clear stale
  /// capability verdicts on change (see [_syncFromStorage]).
  String? _lastModelIdentity;

  /// Switch the active backend and persist the choice.
  /// Does NOT start or stop any processes — that is handled by the caller (UI).
  Future<void> setActiveBackend(BackendType type) async {
    if (type == _activeBackend) return;

    _activeBackend = type;
    String persistValue;
    switch (type) {
      case BackendType.openRouter:
        persistValue = 'openRouter';
      case BackendType.omlx:
        persistValue = 'omlx';
      case BackendType.kobold:
        persistValue = 'kobold';
    }
    await _storageService.setBackendType(persistValue);

    // Auto-configure oMLX URL when switching to it
    if (type == BackendType.omlx) {
      _openRouterService.configure(
        apiUrl: 'http://localhost:8000/v1',
        apiKey: _storageService.remoteApiKey,
        modelName: _storageService.remoteModelName,
      );
    }

    _syncLiveStatusSources();
    notifyListeners();
  }

  /// Stop the managed KoboldCpp process if it is running.
  Future<void> stopAllManagedProcesses() async {
    if (_koboldService.isRunning) {
      await _koboldService.stopKobold();
    }
  }
}
