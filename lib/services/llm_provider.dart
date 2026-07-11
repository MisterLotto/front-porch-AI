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

import 'package:flutter/foundation.dart';
import 'package:front_porch_ai/services/backend_manager.dart';
import 'package:front_porch_ai/services/capability/vision_support_resolver.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
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
    }

    if (newType != _activeBackend) {
      _activeBackend = newType;
      notifyListeners();
    }
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

    notifyListeners();
  }

  /// Stop the managed KoboldCpp process if it is running.
  Future<void> stopAllManagedProcesses() async {
    if (_koboldService.isRunning) {
      await _koboldService.stopKobold();
    }
  }
}
