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
import 'package:front_porch_ai/services/pseudo_remote_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';

/// The available backend types.
enum BackendType { kobold, openRouter, pseudoRemote, omlx }

/// Manages switching between LLM backends (local KoboldCPP, Pseudo-Remote, remote APIs).
///
/// Sits between ChatService and the actual backend implementations.
/// Listens to StorageService for config changes and hot-swaps the active service.
class LLMProvider extends ChangeNotifier {
  final KoboldService _koboldService;
  final OpenRouterService _openRouterService;
  final PseudoRemoteService _pseudoRemoteService;
  final StorageService _storageService;
  final BackendManager _backendManager;

  BackendType _activeBackend = BackendType.kobold;

  BackendType get activeBackend => _activeBackend;
  LLMService get activeService {
    switch (_activeBackend) {
      case BackendType.kobold:
        return _koboldService;
      case BackendType.pseudoRemote:
        return _pseudoRemoteService;
      case BackendType.openRouter:
      case BackendType.omlx:
        return _openRouterService;
    }
  }

  /// Whether the currently active backend is the local KoboldCPP native API.
  /// Pseudo-remote returns false here — it uses the OpenAI protocol,
  /// so eval logic (concurrent dispatch, remote-style params) matches remote.
  bool get isLocal => _activeBackend == BackendType.kobold;

  /// Whether the active backend manages a local subprocess (kobold or pseudoRemote).
  bool get hasManagedProcess =>
      _activeBackend == BackendType.kobold ||
      _activeBackend == BackendType.pseudoRemote;

  /// True when any managed process (kobold or pseudoRemote) is currently running.
  bool get hasAnyManagedProcessRunning =>
      _koboldService.isRunning || _pseudoRemoteService.isRunning;

  /// Ensures that the simple local Kobold backend is running when the user
  /// enters a chat.
  ///
  /// This provides a good "it just works" experience for normal users.
  ///
  /// We deliberately do **not** auto-start the Pseudo-Remote backend here.
  /// Using .kcpps presets is an advanced/power-user feature and those users
  /// are expected to start the backend manually.
  ///
  /// Safe to call repeatedly — it is a no-op if already running or if the
  /// current backend is remote / oMLX / Pseudo-Remote.
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
      // Only auto-start the simple native Kobold backend.
      // Pseudo-Remote (.kcpps) is an advanced feature — those users are
      // expected to start the backend themselves.
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
  PseudoRemoteService get pseudoRemoteService => _pseudoRemoteService;

  LLMProvider(
    this._koboldService,
    this._openRouterService,
    this._pseudoRemoteService,
    this._storageService,
    this._backendManager,
  ) {
    _syncFromStorage();
    _storageService.addListener(_syncFromStorage);
    _koboldService.addListener(_onServiceChanged);
    _pseudoRemoteService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _storageService.removeListener(_syncFromStorage);
    _koboldService.removeListener(_onServiceChanged);
    _pseudoRemoteService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    notifyListeners();
  }

  void _syncFromStorage() {
    final typeStr = _storageService.backendType;
    BackendType newType;
    switch (typeStr) {
      case 'pseudoRemote':
        newType = BackendType.pseudoRemote;
      case 'openRouter':
        newType = BackendType.openRouter;
      case 'omlx':
        newType = BackendType.omlx;
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
      case BackendType.pseudoRemote:
        persistValue = 'pseudoRemote';
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

  /// Stop any running managed processes (kobold and/or pseudoRemote).
  Future<void> stopAllManagedProcesses() async {
    if (_koboldService.isRunning) {
      await _koboldService.stopKobold();
    }
    if (_pseudoRemoteService.isRunning) {
      await _pseudoRemoteService.stop();
    }
  }

  /// Start the currently selected managed backend.
  /// Throws if [BackendType.openRouter] is active (no process to start).
  Future<void> startActiveManagedProcess({
    required String executablePath,
    required String kcppsPath,
  }) async {
    switch (_activeBackend) {
      case BackendType.kobold:
        // The caller should provide model path etc. via the existing flow.
        // This method is used by the unified start button in settings.
        throw UnimplementedError(
          'Use koboldService.startKobold() directly for local backend.',
        );
      case BackendType.pseudoRemote:
        await _pseudoRemoteService.start(
          executablePath: executablePath,
          kcppsPath: kcppsPath,
        );
      case BackendType.openRouter:
        throw Exception('Cannot start a process for the OpenRouter backend.');
      case BackendType.omlx:
        throw Exception('Cannot start a process for the oMLX backend.');
    }
  }
}
