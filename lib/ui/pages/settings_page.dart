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
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

// Barrel imports (high-frequency services + widgets)
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

// Modules and dialogs not in the barrels (internal, low-frequency, or single-use)
import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/services/model_manager.dart';
import 'package:front_porch_ai/services/optimization_service.dart';
import 'package:front_porch_ai/services/web/web_server_host.dart';
import 'package:front_porch_ai/ui/dialogs/web_access_setup_dialog.dart';
import 'package:front_porch_ai/ui/dialogs/rocm_guidance_dialog.dart';
import 'package:front_porch_ai/ui/dialogs/database_cleanup_dialog.dart';

import 'package:front_porch_ai/ui/settings/tabs/general_tab.dart';
import 'package:front_porch_ai/ui/settings/tabs/generation_tab.dart';
import 'package:front_porch_ai/ui/settings/tabs/backend_tab.dart';

import 'package:front_porch_ai/ui/settings/tabs/voice_media_tab.dart';
import 'package:front_porch_ai/ui/settings/widgets/web_login_section.dart';
import 'package:front_porch_ai/utils/picker_prefs.dart';
// Note: Image Generation *config* options (backend / model / LoRAs) live in a first-class
// tab-like panel inside the Image Studio (see generation_options_tab.dart + studio integration).
// Only the discoverable on/off switch was re-surfaced in the Voice & Media tab via
// ImageGenEnableSection — the chat toolbar's Image Studio button stays hidden until it is on.

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _gpuLayersController = TextEditingController(text: '0');
  final _contextSizeController = TextEditingController(text: '8192');
  double? _dragContextSize;
  double? _dragCallBuffer;
  final _apiController = TextEditingController();
  final _remoteApiUrlController = TextEditingController();
  final _remoteApiKeyController = TextEditingController();
  bool _useVulkan = false;
  bool _useCublas = false;
  bool _useMetal = false;
  bool _useRocm = false;
  String? _selectedModelPath;
  final TextEditingController _systemPromptController = TextEditingController();
  final TextEditingController _bannedPhrasesController =
      TextEditingController();

  // Remote API state (the fetched model list is shared with the Voice tab;
  // the fetch/check spinners now live in the extracted backend sections).
  List<RemoteModelInfo> _availableModels = [];

  // Local Preset state
  List<File> _localPresets = [];

  @override
  void initState() {
    super.initState();
    _apiController.text = Provider.of<KoboldService>(
      context,
      listen: false,
    ).baseUrl;
    _systemPromptController.text = Provider.of<StorageService>(
      context,
      listen: false,
    ).systemPrompt;
    _bannedPhrasesController.text = Provider.of<StorageService>(
      context,
      listen: false,
    ).bannedPhrases.join('\n');
    _remoteApiUrlController.text = Provider.of<StorageService>(
      context,
      listen: false,
    ).backendSettings.remoteApiUrl;
    _remoteApiKeyController.text = Provider.of<StorageService>(
      context,
      listen: false,
    ).backendSettings.remoteApiKey;

    // Sync local state with storage
    final storage = Provider.of<StorageService>(context, listen: false);
    // Default to false if null, logic below handles the "first run" auto-enable
    _useCublas = storage.useCublas == true;
    _useVulkan = storage.useVulkan == true;
    _useMetal = storage.useMetal == true;
    // Apply hardware-based defaults once hardware info is available.
    // HardwareService.detectHardware() is already called in its constructor,
    // so we just use the cached result. If detection is still in progress,
    // listen for changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hardwareService = Provider.of<HardwareService>(
        context,
        listen: false,
      );

      if (hardwareService.hardwareInfo != null) {
        _applyHardwareDefaults(hardwareService.hardwareInfo!);
      } else {
        // Detection still in progress — listen for completion
        void listener() {
          if (!mounted) return;
          if (!hardwareService.isDetecting &&
              hardwareService.hardwareInfo != null) {
            hardwareService.removeListener(listener);
            _applyHardwareDefaults(hardwareService.hardwareInfo!);
          }
        }

        hardwareService.addListener(listener);
      }

      // Auto-fetch available models if API is configured
      _autoFetchModels();

      // Auto-fetch .kcpps presets
      _scanLocalPresets();
    });
  }

  void _scanLocalPresets() {
    final storage = Provider.of<StorageService>(context, listen: false);
    final files = scanKcppsPresets(storage.binDir);
    setState(() {
      _localPresets = files;
    });
  }

  /// Fetch available models from the configured API on startup.
  void _autoFetchModels() async {
    final storage = Provider.of<StorageService>(context, listen: false);
    // Allow empty API key for local backends (LM Studio, vLLM, etc.)
    final isLocal =
        storage.remoteApiUrl.contains('localhost') ||
        storage.remoteApiUrl.contains('127.0.0.1');
    if (storage.remoteApiUrl.isEmpty) return; // No API URL configured
    if (storage.remoteApiKey.isEmpty && !isLocal) return; // no API configured

    final openRouter = Provider.of<OpenRouterService>(context, listen: false);
    // Explicit-target fetch — configure() here silently re-routed the ACTIVE
    // backend (opening Settings while on oMLX pointed all chat traffic at the
    // Remote API provider until the next storage sync).
    try {
      final models = await openRouter.fetchAvailableModels(
        apiUrl: storage.remoteApiUrl,
        apiKey: storage.remoteApiKey,
      );
      if (mounted && models.isNotEmpty) {
        setState(() => _availableModels = models);
      }
    } catch (_) {
      // Silent fail on startup — user can manually refresh
    }
  }

  /// Apply GPU defaults based on detected hardware info.
  void _applyHardwareDefaults(HardwareInfo hw) {
    final storage = Provider.of<StorageService>(context, listen: false);
    bool changed = false;

    // NVIDIA Logic: Default to CuBLAS if not set
    if (hw.vendor == 'Nvidia') {
      if (storage.useCublas == null) {
        storage.setUseCublas(true);
        storage.setUseVulkan(false);
        _useCublas = true;
        _useVulkan = false;
        changed = true;
      } else {
        _useCublas = storage.useCublas!;
        if (storage.useVulkan != null) {
          _useVulkan = storage.useVulkan!;
        } else if (_useCublas) {
          _useVulkan = false;
        }
      }
    }
    // MacOS Logic: Default to Metal if not set
    else if (Platform.isMacOS) {
      if (storage.useMetal == null) {
        storage.setUseMetal(true);
        storage.setUseVulkan(false);
        storage.setUseCublas(false);
        _useMetal = true;
        _useVulkan = false;
        _useCublas = false;
        changed = true;
      } else {
        _useMetal = storage.useMetal!;
        if (storage.useVulkan != null) _useVulkan = storage.useVulkan!;
        if (storage.useCublas != null) _useCublas = storage.useCublas!;
        if (storage.useRocm != null) _useRocm = storage.useRocm!;
      }
    }
    // Non-NVIDIA/Non-Mac Logic: Default to ROCm if available, else Vulkan
    else {
      if (storage.useVulkan == null && storage.useRocm == null) {
        // First run: auto-detect best GPU backend
        if (hw.vendor == 'AMD' && Platform.isLinux && hw.hasRocm) {
          storage.setUseRocm(true);
          storage.setUseVulkan(false);
          storage.setUseCublas(false);
          storage.setUseMetal(false);
          _useRocm = true;
          _useVulkan = false;
          _useCublas = false;
          _useMetal = false;
        } else {
          storage.setUseVulkan(true);
          storage.setUseCublas(false);
          storage.setUseMetal(false);
          storage.setUseRocm(false);
          _useVulkan = true;
          _useCublas = false;
          _useMetal = false;
          _useRocm = false;
        }
        changed = true;
      } else {
        _useVulkan = storage.useVulkan ?? false;
        if (storage.useCublas != null) _useCublas = storage.useCublas!;
        if (storage.useMetal != null) _useMetal = storage.useMetal!;
        if (storage.useRocm != null) _useRocm = storage.useRocm!;
      }
    }

    if (changed) {
      setState(() {});
      final String msg;
      if (hw.vendor == 'Nvidia') {
        msg = 'NVIDIA GPU detected: CuBLAS enabled.';
      } else if (Platform.isMacOS) {
        msg = 'Apple Silicon detected: Metal enabled.';
      } else if (hw.vendor == 'AMD' && Platform.isLinux && hw.hasRocm) {
        msg = 'AMD GPU detected: ROCm enabled for native GPU acceleration.';
      } else if (hw.vendor == 'AMD' &&
          Platform.isLinux &&
          hw.hasRocm == false) {
        msg =
            'AMD GPU detected: Vulkan enabled. Install ROCm for better performance.';
        showRocmGuidanceDialog(context, hw.linuxDistro);
      } else {
        msg = 'Non-NVIDIA GPU detected: Vulkan enabled.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else {
      // Just update UI to match loaded persistence
      setState(() {});
    }

    // Trigger silent autoconfig on load if model is present
    // BUT only if user hasn't manually customized GPU layers.
    // A non-zero persisted gpuLayers means the user or a previous
    // explicit auto-config set it — don't silently overwrite.
    if (_selectedModelPath != null && storage.gpuLayers == 0) {
      // Warm before the silent auto-config so the solver gets good data on first run
      final modelManager = Provider.of<ModelManager>(context, listen: false);
      modelManager.getModelArchitectureInfo(_selectedModelPath!);
      _applyAutoConfiguration(silent: true);
    } else if (_selectedModelPath != null) {
      // Respect previously saved settings — just load them into the UI
      _gpuLayersController.text = storage.gpuLayers.toString();
      _contextSizeController.text = storage.backendSettings.contextSize
          .toString();
    }
  }

  @override
  void dispose() {
    _gpuLayersController.dispose();
    _contextSizeController.dispose();
    _apiController.dispose();
    _remoteApiUrlController.dispose();
    _remoteApiKeyController.dispose();
    _bannedPhrasesController.dispose();
    super.dispose();
  }

  Future<void> _pickStoragePath() async {
    String? selectedDirectory = await PickerPrefs.getDirectoryPath(
      category: PickerPrefs.catDirectory,
    );
    if (selectedDirectory != null) {
      if (mounted) {
        // Close the current database so the file can be moved
        await AppDatabase.closeAndReset();
        await Provider.of<StorageService>(
          context,
          listen: false,
        ).setRootPath(selectedDirectory);
        // Reopen the database from the new location
        final newDb = await AppDatabase.instance();
        // Update ALL downstream services that hold a DB reference
        if (mounted) {
          Provider.of<CharacterRepository>(
            context,
            listen: false,
          ).updateDatabase(newDb);
          Provider.of<FolderService>(
            context,
            listen: false,
          ).updateDatabase(newDb);
          Provider.of<UserPersonaService>(
            context,
            listen: false,
          ).updateDatabase(newDb);
          Provider.of<GroupChatRepository>(
            context,
            listen: false,
          ).updateDatabase(newDb);
          Provider.of<WorldRepository>(
            context,
            listen: false,
          ).updateDatabase(newDb);
          Provider.of<ChatService>(
            context,
            listen: false,
          ).updateDatabase(newDb);
          // Rebind the web server + Porch Stories too — they held the closed
          // pre-move DB, so after a storage move remote users were dropped and
          // couldn't log back in, and story queries threw, until an app restart.
          Provider.of<StoryRepository>(
            context,
            listen: false,
          ).updateDatabase(newDb);
          Provider.of<WebServerHost>(
            context,
            listen: false,
          ).setDatabase(newDb);
          // Reload data from the new DB location
          await Provider.of<CharacterRepository>(
            context,
            listen: false,
          ).loadCharacters();
          await Provider.of<FolderService>(context, listen: false).reload();
          // Refresh backend/models after path change
          Provider.of<BackendManager>(
            context,
            listen: false,
          ).checkBackendAvailability();
          Provider.of<ModelManager>(context, listen: false).refreshModels();
        }
      }
    }
  }

  void _applyAutoConfiguration({bool silent = false}) {
    final hardware = Provider.of<HardwareService>(
      context,
      listen: false,
    ).hardwareInfo;
    if (hardware == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hardware not detected yet.')),
        );
      }
      return;
    }

    if (silent) {
      _runOptimization(hardware.vramMb, hardware, silent: true);
    } else {
      final vramController = TextEditingController(
        text: hardware.vramMb.toString(),
      );
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardOf(context),
          title: const Text(
            'Auto-Configuration',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm your System VRAM (MB):',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: vramController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Note: Some systems report incorrect VRAM (e.g. 4095MB for >4GB cards). Adjust if necessary.',
                style: TextStyle(color: Colors.white30, fontSize: 10),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final adjustedVram =
                    int.tryParse(vramController.text) ?? hardware.vramMb;
                Navigator.pop(context);
                _runOptimization(adjustedVram, hardware, silent: false);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      );
    }
  }

  void _runOptimization(
    int vramMb,
    HardwareInfo hardware, {
    required bool silent,
  }) {
    // Create temp hardware info with adjusted VRAM
    final adjustedHw = HardwareInfo(
      gpuName: hardware.gpuName,
      vramMb: vramMb,
      ramMb: hardware.ramMb,
      vendor: hardware.vendor,
    );

    // Attempt to estimate model size from selected model
    int modelSize = 5000;
    if (_selectedModelPath != null) {
      try {
        final file = File(_selectedModelPath!);
        if (file.existsSync()) {
          modelSize = (file.lengthSync() / (1024 * 1024)).round();
        }
      } catch (e) {
        print('Error getting file size: $e');
      }
    }

    // Respect user's context size — pass it to the optimizer so only GPU layers adjust
    final userContext = int.tryParse(_contextSizeController.text);

    int? kvBytesPerToken;
    if (_selectedModelPath != null && mounted) {
      final modelManager = Provider.of<ModelManager>(context, listen: false);
      kvBytesPerToken = modelManager.getCachedKvBytesPerToken(
        _selectedModelPath!,
      );
    }

    final suggestion = OptimizationService.calculateSettings(
      adjustedHw,
      modelSizeMb: modelSize,
      requestedContextSize: userContext,
      kvBytesPerToken: kvBytesPerToken,
      kvQuantizationLevel: Provider.of<StorageService>(
        context,
        listen: false,
      ).kvQuantizationLevel,
    );

    // Persist settings to storage so they survive app restart
    final storage = Provider.of<StorageService>(context, listen: false);
    storage.setGpuLayers(suggestion.gpuLayers);
    storage.setContextSize(suggestion.contextSize);

    setState(() {
      _gpuLayersController.text = suggestion.gpuLayers.toString();
      _contextSizeController.text = suggestion.contextSize.toString();
      // If user has Mac, suggest Metal
      if (Platform.isMacOS) {
        _useMetal = true;
        _useVulkan = false;
        _useCublas = false;
        storage.setUseMetal(true);
        storage.setUseVulkan(false);
        storage.setUseCublas(false);
      }
      // If user has Nvidia, suggest Cublas instead of Vulkan usually
      else if (hardware.vendor == 'Nvidia') {
        _useCublas = true;
        _useVulkan = false;
        _useMetal = false;
        storage.setUseCublas(true);
        storage.setUseVulkan(false);
      } else {
        _useCublas = false;
        _useMetal = false;
      }
    });

    if (!silent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(suggestion.reasoning)));
    }
  }

  void _autoConfigure() {
    _applyAutoConfiguration(silent: false);
  }

  Future<void> _toggleManagedBackend(BuildContext context) async {
    final koboldService = Provider.of<KoboldService>(context, listen: false);
    final backendManager = Provider.of<BackendManager>(context, listen: false);

    if (koboldService.isRunning || koboldService.isStarting) {
      await koboldService.stopKobold();
      return;
    }

    if (backendManager.backendPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend not found. Please download it first.'),
        ),
      );
      return;
    }
    final storage = Provider.of<StorageService>(context, listen: false);

    final presetOwnsModel = storage.kcppsHasModel;

    if (!presetOwnsModel) {
      if (_selectedModelPath == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a model.')));
        return;
      }
      if (!File(_selectedModelPath!).existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected model file does not exist!')),
        );
        return;
      }
    }

    final gpuLayers = int.tryParse(_gpuLayersController.text) ?? 0;
    final contextSize = int.tryParse(_contextSizeController.text) ?? 4096;

    storage.setGpuLayers(gpuLayers);
    storage.setContextSize(contextSize);
    storage.setUseCublas(_useCublas);
    storage.setUseVulkan(_useVulkan);
    storage.setUseMetal(_useMetal);
    storage.setUseRocm(_useRocm);

    final effectiveModel = presetOwnsModel ? '' : _selectedModelPath!;
    await koboldService.startKobold(
      backendManager.backendPath!,
      effectiveModel,
      kcppsPath: storage.activeKcppsPath,
      mmprojPath: _selectedModelPath != null
          ? storage.mmprojForModel(_selectedModelPath!)
          : null,
      gpuLayers: gpuLayers,
      contextSize: contextSize,
      useVulkan: _useVulkan,
      useCublas: _useCublas,
      useMetal: _useMetal,
      useRocm: _useRocm,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        DefaultTabController(
          length: 5,
          child: Scaffold(
            backgroundColor: AppColors.backgroundOf(
              context,
            ).withValues(alpha: 0),
            appBar: AppBar(
              title: Text('Settings', style: theme.textTheme.titleLarge),
              backgroundColor: AppColors.backgroundOf(
                context,
              ).withValues(alpha: 0),
              elevation: 0,
              iconTheme: theme.iconTheme,
              bottom: TabBar(
                labelColor: AppColors.textPrimary(context),
                unselectedLabelColor: AppColors.textSecondary(context),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                overlayColor: WidgetStateProperty.all(
                  AppColors.surfaceOf(context).withValues(alpha: 0),
                ),
                splashFactory: NoSplash.splashFactory,
                tabs: const [
                  Tab(text: 'General'),
                  Tab(text: 'Generation'),
                  Tab(text: 'Voice & Media'),
                  Tab(text: 'Backend'),
                  Tab(text: 'Advanced'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                GeneralTab(systemPromptController: _systemPromptController),
                GenerationTab(bannedPhrasesController: _bannedPhrasesController),
                VoiceMediaTab(
                  dragCallBuffer: _dragCallBuffer,
                  onDragCallBufferChanged: (v) =>
                      setState(() => _dragCallBuffer = v),
                  availableModels: _availableModels,
                ),
                _backendTab(),
                _buildAdvancedTab(context),
              ],
            ),
          ),
        ),
        // Glassmorphic download overlay — shown only while ONNX model is downloading
        Consumer<ExpressionClassifierService>(
          builder: (context, expressionService, _) {
            if (!expressionService.isDownloading) {
              return const SizedBox.shrink();
            }
            return _buildDownloadOverlay(expressionService);
          },
        ),
      ],
    );
  }

  /// Full-screen glassmorphic overlay shown during ONNX model download.
  /// AppColors enforced (part of Stage 5 refactor surfaces).
  Widget _buildDownloadOverlay(ExpressionClassifierService service) {
    final progress = service.downloadProgress;
    final fraction = progress?.fraction ?? 0.0;
    final fileName = progress?.file ?? 'Preparing…';
    final pct = (fraction * 100).toStringAsFixed(0);

    final accent = AppColors.logReady;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: AppColors.textPrimary(context).withValues(alpha: 0.55),
          child: Center(
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.cardOf(context).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accent.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: AppColors.textPrimary(
                      context,
                    ).withValues(alpha: 0.6),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      color: AppColors.textPrimary(context),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Downloading Expression Model',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'distilbert-go-emotions-onnx',
                    style: TextStyle(
                      color: AppColors.textPrimary(
                        context,
                      ).withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        // Track
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary(
                              context,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        // Fill
                        FractionallySizedBox(
                          widthFactor: fraction.clamp(0.0, 1.0),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accent, accent],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          fileName,
                          style: TextStyle(
                            color: AppColors.textPrimary(
                              context,
                            ).withValues(alpha: 0.55),
                            fontSize: 11,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fraction > 0 ? '$pct%' : '…',
                        style: TextStyle(
                          color: accent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This only happens once. Files are saved\nto your Front Porch AI data folder.',
                    style: TextStyle(
                      color: AppColors.textPrimary(
                        context,
                      ).withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // _buildOnnxDownloadButton deleted (dead after voice extraction + lift of copy to voice tab; deletion part of task).

  // _buildGeneralTab extracted to lib/ui/settings/tabs/general_tab.dart (Stage 5 remaining tabs step); deletion part of task.
  // Shell now delegates; state passed via ctor.

  // _buildColorRow deleted (dead after general tab extraction; deletion part of task).

  // _buildVoiceMediaTab extracted to VoiceMediaTab (Stage 5; largest tab first per plan;
  // full lift + AppColors exclusive + shared state via ctor; body deleted as part of task).
  // See lib/ui/settings/tabs/voice_media_tab.dart

  /// Backend tab: thin wrapper that wires the extracted [BackendTab] widget
  /// with the page's shared launch state. The auto-select-first-model default
  /// and every state-mutating callback are the original _buildBackendTab
  /// closures, moved here verbatim so launch behavior is unchanged.
  Widget _backendTab() {
    final storageService = Provider.of<StorageService>(context);
    final modelManager = Provider.of<ModelManager>(context);

    // Auto-select first model if none selected and models exist. Skip when a
    // kcpps preset with a valid model is active (use "Managed by kcpps").
    if (_selectedModelPath == null &&
        modelManager.models.isNotEmpty &&
        !(storageService.kcppsHasModel &&
            storageService.kcppsModelFileExists)) {
      _selectedModelPath = modelManager.models.first.path;
    }
    // Warm architecture info for the (possibly just auto-selected) model so
    // the first Auto-Configure or gauge update is accurate.
    if (_selectedModelPath != null) {
      modelManager.getModelArchitectureInfo(_selectedModelPath!);
    }

    return BackendTab(
      apiUrlController: _remoteApiUrlController,
      apiKeyController: _remoteApiKeyController,
      availableModels: _availableModels,
      onModelsFetched: (m) => setState(() => _availableModels = m),
      selectedModelPath: _selectedModelPath,
      localPresets: _localPresets,
      onModelSelected: (val) {
        if (val == null) {
          setState(() {
            _selectedModelPath = null;
          });
        } else {
          setState(() {
            _selectedModelPath = val;
          });
          storageService.setLastUsedModelPath(val);
          final savedPreset = storageService.modelPresetMap[val];
          if (savedPreset != null &&
              savedPreset.isNotEmpty &&
              File(savedPreset).existsSync()) {
            storageService.setActiveKcppsPath(savedPreset);
          } else {
            storageService.setActiveKcppsPath(null);
          }

          // Eagerly warm the GGUF architecture + KV cache so that
          // Auto-Configure (and the live VRAM gauge) get accurate
          // nLayers / bytes-per-layer on the first click instead of
          // falling back to weaker heuristics.
          modelManager.getModelArchitectureInfo(val); // fire-and-forget

          _applyAutoConfiguration(silent: true);
        }
      },
      onVisionChanged: () => setState(() {}),
      onScanPresets: _scanLocalPresets,
      onKcppsChanged: (val) {
        storageService.setActiveKcppsPath(val);
        if (_selectedModelPath != null && val != null) {
          storageService.setModelPreset(_selectedModelPath!, val);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Preset saved for model: ${p.basename(_selectedModelPath!)}',
              ),
            ),
          );
        } else if (_selectedModelPath != null && val == null) {
          storageService.setModelPreset(_selectedModelPath!, '');
        }
        if (val != null &&
            storageService.kcppsHasModel &&
            storageService.kcppsModelFileExists) {
          setState(() {
            _selectedModelPath = null;
          });
        }
      },
      onKcppsExternalClear: () {
        storageService.setActiveKcppsPath(null);
        if (_selectedModelPath != null) {
          storageService.setModelPreset(_selectedModelPath!, '');
        }
      },
      onKcppsBrowsePicked: (path) {
        if (_selectedModelPath != null) {
          storageService.setModelPreset(_selectedModelPath!, path);
        }
        _scanLocalPresets();
        if (storageService.kcppsHasModel &&
            storageService.kcppsModelFileExists) {
          setState(() {
            _selectedModelPath = null;
          });
        }
      },
      onKcppsModelStatusChanged: (_) {
        setState(() {});
      },
      onGenerateKcppsDone: () {
        _scanLocalPresets();
        setState(() {});
      },
      onToggleBackend: () => _toggleManagedBackend(context),
    );
  }

  Widget _buildAdvancedTab(BuildContext context) {
    final storageService = Provider.of<StorageService>(context);
    final hardwareService = Provider.of<HardwareService>(context);
    final llmProvider = Provider.of<LLMProvider>(context);
    final theme = Theme.of(context);
    final isPresetActive =
        storageService.activeKcppsPath != null &&
        storageService.activeKcppsPath!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Storage Configuration', context),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Data Directory', style: theme.textTheme.bodySmall),
                      Text(
                        storageService.rootPath ?? 'Not set',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: theme.iconTheme.color),
                  onPressed: _pickStoragePath,
                  tooltip: 'Change Data Directory',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Web Server', context),
          const SizedBox(height: 8),
          Consumer2<StorageService, WebServerHost>(
            builder: (context, storage, webServer, _) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              webServer.isRunning
                                  ? Icons.wifi_tethering
                                  : Icons.wifi_tethering_off,
                              color: webServer.isRunning
                                  ? Colors.greenAccent
                                  : Colors.white38,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Enable Web Server',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Switch(
                          value: storage.webServerEnabled,
                          onChanged: (val) async {
                            await storage.setWebServerEnabled(val);
                            if (val) {
                              // startSafely reverts + disables on failure so a
                              // bad start can never leave the app in a launch
                              // crash loop.
                              final ok = await webServer.startSafely(
                                storage.webServerPort,
                              );
                              if (!context.mounted) return;
                              if (ok) {
                                // Guide the user through how they'll reach it.
                                await WebAccessSetupDialog.show(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Web server failed to start and was '
                                      'turned off.',
                                    ),
                                  ),
                                );
                              }
                            } else {
                              await webServer.stop();
                            }
                          },
                        ),
                      ],
                    ),
                    if (storage.webServerEnabled) ...[
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Port', style: theme.textTheme.bodySmall),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    initialValue: storage.webServerPort
                                        .toString(),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: theme.scaffoldBackgroundColor,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                    ),
                                    onFieldSubmitted: (val) async {
                                      final port = int.tryParse(val) ?? 8085;
                                      await storage.setWebServerPort(port);
                                      if (webServer.isRunning) {
                                        await webServer.stop();
                                        await webServer.start(port);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Login', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      if (webServer.auth case final auth?)
                        WebLoginSection(
                          // Rebuild after a reset from the web side too.
                          key: ValueKey(webServer.isRunning),
                          auth: auth,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: webServer.isRunning
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      webServer.isRunning
                                          ? 'Running'
                                          : 'Stopped',
                                      style: TextStyle(
                                        color: webServer.isRunning
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (webServer.lanIp != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.language,
                                color: Colors.blueAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  'http://${webServer.lanIp}:${storage.webServerPort}',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (webServer.hasActiveClient) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.devices,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Client connected: ${webServer.connectedClientIp ?? "Unknown"}',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Hardware & GPU', context),
              TextButton.icon(
                onPressed: _autoConfigure,
                icon: const Icon(Icons.auto_fix_high, color: Colors.amber),
                label: const Text(
                  'Auto-Configure',
                  style: TextStyle(color: Colors.amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Hardware Info with VRAM Gauge (always shown)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: hardwareService.isDetecting
                ? const Center(child: CircularProgressIndicator())
                : hardwareService.hardwareInfo == null
                ? const Text(
                    'Hardware not detected.',
                    style: TextStyle(color: Colors.redAccent),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // GPU Name header
                      Row(
                        children: [
                          Icon(
                            Icons.memory,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              hardwareService.hardwareInfo!.gpuName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // VRAM Gauge
                      if (llmProvider.isLocal)
                        FutureBuilder<int?>(
                          future: _selectedModelPath != null
                              ? Provider.of<ModelManager>(
                                  context,
                                  listen: false,
                                ).getKvCacheBytesPerToken(_selectedModelPath!)
                              : Future.value(null),
                          builder: (context, snapshot) {
                            final totalVram = hardwareService
                                .hardwareInfo!
                                .vramMb
                                .toDouble();
                            if (totalVram <= 0) return const SizedBox.shrink();

                            // Estimate model VRAM usage from model size
                            final modelSizeMb = _getSelectedModelSizeMb();
                            final contextSize =
                                int.tryParse(_contextSizeController.text) ??
                                4096;

                            // Use exact KV cost if parsed, else fallback to 100MB per 1k heuristic
                            final kvBytesPerToken = snapshot.data;
                            double contextVramMb = kvBytesPerToken != null
                                ? (contextSize *
                                      kvBytesPerToken /
                                      (1024 * 1024))
                                : (contextSize / 1024 * 100.0);

                            if (storageService.kvQuantizationLevel == 1) {
                              contextVramMb *= 0.5;
                            } else if (storageService.kvQuantizationLevel ==
                                2) {
                              contextVramMb *= 0.25;
                            }

                            final gpuLayers =
                                int.tryParse(_gpuLayersController.text) ?? 0;

                            // Improved model VRAM estimate using real architecture data when available
                            double modelVramMb;
                            if (gpuLayers >= 99) {
                              modelVramMb = modelSizeMb.toDouble();
                            } else {
                              final archInfo = _selectedModelPath != null
                                  ? Provider.of<ModelManager>(
                                      context,
                                      listen: false,
                                    ).getCachedModelArchitectureInfo(
                                      _selectedModelPath!,
                                    )
                                  : null;
                              if (archInfo != null && archInfo.nLayers > 0) {
                                final bytesPerLayer = archInfo
                                    .estimateBytesPerLayer(
                                      (modelSizeMb * 1024 * 1024).toInt(),
                                    );
                                modelVramMb =
                                    (bytesPerLayer * gpuLayers / (1024 * 1024))
                                        .toDouble();
                              } else {
                                // Fallback to old heuristic only when we have no architecture data
                                modelVramMb = (modelSizeMb * (gpuLayers / 40.0))
                                    .clamp(0, modelSizeMb.toDouble());
                              }
                            }
                            final usedVram = modelVramMb + contextVramMb;
                            final usedRatio = (usedVram / totalVram).clamp(
                              0.0,
                              1.0,
                            );
                            final modelRatio = (modelVramMb / totalVram).clamp(
                              0.0,
                              1.0,
                            );
                            final contextRatio = (contextVramMb / totalVram)
                                .clamp(0.0, usedRatio);
                            final freeVram = (totalVram - usedVram).clamp(
                              0,
                              totalVram,
                            );

                            Color gaugeColor;
                            if (usedRatio > 0.95) {
                              gaugeColor = Colors.redAccent;
                            } else if (usedRatio > 0.8) {
                              gaugeColor = Colors.orangeAccent;
                            } else {
                              gaugeColor = Colors.greenAccent;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // VRAM bar
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final totalWidth = constraints.maxWidth;
                                    final modelWidth = totalWidth * modelRatio;
                                    final contextWidth =
                                        totalWidth * contextRatio;

                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                        height: 20,
                                        child: Stack(
                                          children: [
                                            // Background (free)
                                            Container(
                                              width: double.infinity,
                                              color: Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                            ),
                                            // Model portion (starts at left)
                                            Positioned(
                                              left: 0,
                                              top: 0,
                                              bottom: 0,
                                              width: modelWidth,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.blueAccent,
                                                      Colors.blue.shade700,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Context portion (starts exactly where model ends)
                                            if (contextWidth > 0)
                                              Positioned(
                                                left: modelWidth,
                                                top: 0,
                                                bottom: 0,
                                                width: contextWidth,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.tealAccent,
                                                        Colors.teal.shade700,
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                // Legend
                                Row(
                                  children: [
                                    _buildVramLegendDot(
                                      Colors.blueAccent,
                                      'Model ~${modelVramMb.round()} MB',
                                    ),
                                    const SizedBox(width: 16),
                                    _buildVramLegendDot(
                                      Colors.tealAccent,
                                      'Context ~${contextVramMb.round()} MB',
                                    ),
                                    const SizedBox(width: 16),
                                    _buildVramLegendDot(
                                      Colors.white24,
                                      'Free ~${freeVram.round()} MB',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${usedVram.round()} / ${totalVram.round()} MB used',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: gaugeColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      else ...[
                        // Remote API — show total VRAM only, no usage estimate
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 20,
                            width: double.infinity,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildVramLegendDot(
                              Colors.white24,
                              'Total ${hardwareService.hardwareInfo!.vramMb} MB',
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Remote API — GPU not in use',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),

          const SizedBox(height: 16),
          if (isPresetActive) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A configuration preset is active. Advanced settings are managed by the preset and cannot be edited here.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          IgnorePointer(
            ignoring: isPresetActive,
            child: Opacity(
              opacity: isPresetActive ? 0.4 : 1.0,
              child: Tooltip(
                message: isPresetActive
                    ? 'Context size is controlled by the active .kcpps preset and cannot be edited here.'
                    : '',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Context Size — slider with presets + text field
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.straighten,
                                color: Colors.tealAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Context Window',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              // Manual text input
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: _contextSizeController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: theme.scaffoldBackgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.tealAccent.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    final parsed = int.tryParse(val);
                                    if (parsed != null && parsed > 0) {
                                      storageService.setContextSize(parsed);
                                      setState(() {}); // refresh VRAM gauge
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Slider
                          Builder(
                            builder: (context) {
                              final currentVal =
                                  int.tryParse(_contextSizeController.text) ??
                                  4096;
                              // Map context size to slider position (log scale)
                              final presets = [
                                512,
                                1024,
                                2048,
                                4096,
                                8192,
                                16384,
                                32768,
                                65536,
                                131072,
                              ];
                              int closestIdx = 0;
                              int closestDist = (presets[0] - currentVal).abs();
                              for (int i = 1; i < presets.length; i++) {
                                final dist = (presets[i] - currentVal).abs();
                                if (dist < closestDist) {
                                  closestDist = dist;
                                  closestIdx = i;
                                }
                              }

                              return Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: Colors.tealAccent,
                                      inactiveTrackColor: Colors.tealAccent
                                          .withValues(alpha: 0.15),
                                      thumbColor: Colors.tealAccent,
                                      overlayColor: Colors.tealAccent
                                          .withValues(alpha: 0.2),
                                    ),
                                    child: Slider(
                                      value:
                                          _dragContextSize ??
                                          closestIdx.toDouble(),
                                      min: 0,
                                      max: (presets.length - 1).toDouble(),
                                      divisions: presets.length - 1,
                                      onChanged: (val) {
                                        setState(() => _dragContextSize = val);
                                        _contextSizeController.text =
                                            presets[val.round()].toString();
                                      },
                                      onChangeEnd: (val) {
                                        _dragContextSize = null;
                                        final newSize = presets[val.round()];
                                        _contextSizeController.text = newSize
                                            .toString();
                                        storageService.setContextSize(newSize);
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  // Preset chips
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children:
                                        [
                                          512,
                                          2048,
                                          4096,
                                          8192,
                                          16384,
                                          32768,
                                          65536,
                                          131072,
                                        ].map((size) {
                                          final isSelected = currentVal == size;
                                          final label = size >= 1024
                                              ? '${size ~/ 1024}K'
                                              : '$size';
                                          return ChoiceChip(
                                            label: Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.white54,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            selected: isSelected,
                                            selectedColor: Colors.tealAccent,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.05),
                                            side: BorderSide(
                                              color: isSelected
                                                  ? Colors.tealAccent
                                                  : Colors.white12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            onSelected: (_) {
                                              _contextSizeController.text = size
                                                  .toString();
                                              storageService.setContextSize(
                                                size,
                                              );
                                              setState(() {});
                                            },
                                          );
                                        }).toList(),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                'KV Cache Quantization:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: storageService.kvQuantizationLevel,
                                    isExpanded: true,
                                    dropdownColor: AppColors.surfaceContainerOf(
                                      context,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    onChanged: (val) {
                                      if (val != null) {
                                        storageService.setKvQuantizationLevel(
                                          val,
                                        );
                                        setState(() {}); // Refresh VRAM gauge
                                      }
                                    },
                                    items: const [
                                      DropdownMenuItem(
                                        value: 0,
                                        child: Text(
                                          '0 - None (Highest Quality, FP16)',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 1,
                                        child: Text(
                                          '1 - 8-Bit Q8 (~50% VRAM Savings)',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 2,
                                        child: Text(
                                          '2 - 4-Bit Q4 (~75% VRAM Savings)',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message:
                                    'Quantizes the context window to save significant VRAM with minimal quality loss. Note: KoboldCPP dynamically disables Context Shifting when this is active.',
                                child: Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.tealAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Larger context = more memory per conversation. Auto-configure adjusts GPU layers to fit.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ], // Close Tooltip's Column children
                ), // Close Tooltip's Column
              ), // Close Tooltip
            ), // Close Opacity
          ), // Close IgnorePointer

          const SizedBox(height: 16),
          // GPU Layers
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'GPU Layers',
                  controller: _gpuLayersController,
                  context: context,
                  isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Use Vulkan'),
                selected: _useVulkan,
                onSelected: (val) {
                  setState(() {
                    _useVulkan = val;
                    if (val) {
                      _useCublas = false;
                      _useRocm = false;
                      _useMetal = false;
                    }
                  });
                  final ss = Provider.of<StorageService>(
                    context,
                    listen: false,
                  );
                  ss.setUseVulkan(val);
                  if (val) {
                    ss.setUseCublas(false);
                    ss.setUseRocm(false);
                    ss.setUseMetal(false);
                  }
                },
              ),
              Tooltip(
                message: hardwareService.hardwareInfo?.hasRocm == true
                    ? 'Use ROCm for native AMD GPU acceleration'
                    : 'Requires ROCm installation (AMD GPU)',
                child: FilterChip(
                  label: const Text('Use ROCm (AMD)'),
                  selected: _useRocm,
                  onSelected: hardwareService.hardwareInfo?.hasRocm == true
                      ? (val) {
                          setState(() {
                            _useRocm = val;
                            if (val) {
                              _useVulkan = false;
                              _useCublas = false;
                              _useMetal = false;
                            }
                          });
                          final ss = Provider.of<StorageService>(
                            context,
                            listen: false,
                          );
                          ss.setUseRocm(val);
                          if (val) {
                            ss.setUseVulkan(false);
                            ss.setUseCublas(false);
                            ss.setUseMetal(false);
                          }
                        }
                      : null, // Disabled if ROCm not installed
                  avatar: hardwareService.hardwareInfo?.hasRocm == true
                      ? null
                      : const Icon(Icons.block, size: 16),
                ),
              ),
              Tooltip(
                message: hardwareService.hardwareInfo?.vendor == 'Nvidia'
                    ? 'Use CUDA (NVIDIA only)'
                    : 'Requires NVIDIA GPU',
                child: FilterChip(
                  label: const Text('Use CuBLAS (Nvidia)'),
                  selected: _useCublas,
                  onSelected: hardwareService.hardwareInfo?.vendor == 'Nvidia'
                      ? (val) {
                          setState(() {
                            _useCublas = val;
                            if (val) {
                              _useVulkan = false;
                              _useRocm = false;
                              _useMetal = false;
                            }
                          });
                          final ss = Provider.of<StorageService>(
                            context,
                            listen: false,
                          );
                          ss.setUseCublas(val);
                          if (val) {
                            ss.setUseVulkan(false);
                            ss.setUseRocm(false);
                            ss.setUseMetal(false);
                          }
                        }
                      : null, // Disabled if not Nvidia
                  avatar: hardwareService.hardwareInfo?.vendor == 'Nvidia'
                      ? null
                      : const Icon(Icons.block, size: 16),
                ),
              ),
              Tooltip(
                message: hardwareService.hardwareInfo?.hasMetal == true
                    ? 'Use Metal (Apple Silicon/Mac)'
                    : 'Requires MacOS with Metal support',
                child: FilterChip(
                  label: const Text('Use Metal (MacOS)'),
                  selected: _useMetal,
                  onSelected: hardwareService.hardwareInfo?.hasMetal == true
                      ? (val) {
                          setState(() {
                            _useMetal = val;
                            if (val) {
                              _useVulkan = false;
                              _useCublas = false;
                              _useRocm = false;
                            }
                          });
                          final ss = Provider.of<StorageService>(
                            context,
                            listen: false,
                          );
                          ss.setUseMetal(val);
                          if (val) {
                            ss.setUseVulkan(false);
                            ss.setUseCublas(false);
                            ss.setUseRocm(false);
                          }
                        }
                      : null, // Disabled if not MacOS/Metal
                  avatar: hardwareService.hardwareInfo?.hasMetal == true
                      ? null
                      : const Icon(Icons.block, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // \u2500\u2500 Advanced Launch Options \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
          _buildAdvancedLaunchOptions(context, storageService),
          const SizedBox(height: 24),
          _buildDatabaseMaintenanceSection(context, storageService),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDatabaseMaintenanceSection(
    BuildContext context,
    StorageService storageService,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Database Maintenance', context),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.cleaning_services,
                    color: Colors.blueAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Orphaned Data',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Scan & Clean'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const DatabaseCleanupDialog(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Find and remove orphaned avatar images, objectives, data bank '
                'entries, message embeddings, sessions, and messages left behind '
                'after character deletion. Also repairs dangling cross-references '
                'in memory sources and group member lists.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _advancedLaunchExpanded = false;

  Widget _buildAdvancedLaunchOptions(
    BuildContext context,
    StorageService storage,
  ) {
    const accent = Color(0xFF00D4AA); // teal-green consistent with beta accent
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          // Header — tap to expand/collapse
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(
              () => _advancedLaunchExpanded = !_advancedLaunchExpanded,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: accent, size: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'Advanced Launch Options',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  const Text(
                    'Affects next restart',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _advancedLaunchExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible body
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: _buildAdvancedLaunchBody(context, storage, accent),
            crossFadeState: _advancedLaunchExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedLaunchBody(
    BuildContext context,
    StorageService storage,
    Color accent,
  ) {
    Widget _toggle({
      required String label,
      required String tooltip,
      required bool value,
      required ValueChanged<bool> onChanged,
      bool recommended = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              fontSize: 9,
                              color: accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tooltip,
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: accent,
              activeThumbColor: Colors.white,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Flash Attention
          _toggle(
            label: 'Flash Attention',
            tooltip:
                'Faster attention math. ~20\u201340% speed boost on RTX/Apple Silicon. Disabled automatically for ROCm.',
            value: storage.flashAttentionEnabled,
            recommended: true,
            onChanged: (v) => storage.setFlashAttentionEnabled(v),
          ),

          // mlock
          _toggle(
            label: 'Lock Weights in RAM (mlock)',
            tooltip: Platform.isLinux
                ? 'Prevents paging to disk. Requires root or ulimit \u2011l unlimited on Linux \u2014 off by default.'
                : 'Prevents OS from paging model weights to disk. Avoids catastrophic slowdown under memory pressure.',
            value: storage.mlockEnabled,
            recommended: !Platform.isLinux,
            onChanged: (v) => storage.setMlockEnabled(v),
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // GPU ID selector
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GPU ID',
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Which GPU to use for CUDA. Set to 1+ on systems with both a discrete and an integrated GPU.',
                      style: TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 0 / 1 / 2 / 3 quick-pick chips
              Wrap(
                spacing: 6,
                children: [0, 1, 2, 3].map((id) {
                  final isSelected = storage.gpuId == id;
                  return GestureDetector(
                    onTap: () => storage.setGpuId(id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? accent : Colors.white12,
                        ),
                      ),
                      child: Text(
                        '$id',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isSelected ? Colors.black : Colors.white54,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // BLAS Batch Size
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prefill Batch Size',
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tokens processed in parallel during prompt evaluation. Higher = faster context loading, more VRAM.',
                      style: TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: [256, 512, 1024, 2048, 4096, 8192].map((bs) {
                  final isSelected = storage.blasBatchSize == bs;
                  return GestureDetector(
                    onTap: () => storage.setBlasBatchSize(bs),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? accent : Colors.white12,
                        ),
                      ),
                      child: Text(
                        bs >= 1024 ? '${bs ~/ 1024}K' : '$bs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isSelected ? Colors.black : Colors.white54,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 14),
          // Restart button — applies all Advanced Launch changes immediately
          Builder(
            builder: (ctx) {
              final koboldService = Provider.of<KoboldService>(
                ctx,
                listen: true,
              );
              final backendManager = Provider.of<BackendManager>(
                ctx,
                listen: false,
              );
              final storage = Provider.of<StorageService>(ctx, listen: false);
              final canRestart =
                  backendManager.backendPath != null &&
                  storage.lastUsedModelPath != null &&
                  File(storage.lastUsedModelPath!).existsSync();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!canRestart)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber,
                            size: 14,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No model loaded yet. Select a model on the Backend tab first.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (canRestart)
                    ElevatedButton.icon(
                      onPressed: koboldService.isRunning
                          ? () async {
                              await koboldService.stopKobold();
                              await Future.delayed(const Duration(seconds: 1));
                              if (!ctx.mounted) return;
                              koboldService.startKobold(
                                backendManager.backendPath!,
                                storage.lastUsedModelPath!,
                                kcppsPath: storage.activeKcppsPath,
                                mmprojPath: storage.mmprojForModel(
                                  storage.lastUsedModelPath!,
                                ),
                                gpuLayers: storage.gpuLayers,
                                contextSize: storage.contextSize,
                                useVulkan: storage.useVulkan ?? false,
                                useCublas: storage.useCublas ?? false,
                                useMetal: storage.useMetal ?? false,
                                useRocm: storage.useRocm ?? false,
                              );
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Restarting backend with new settings…',
                                  ),
                                ),
                              );
                            }
                          : () {
                              koboldService.startKobold(
                                backendManager.backendPath!,
                                storage.lastUsedModelPath!,
                                kcppsPath: storage.activeKcppsPath,
                                mmprojPath: storage.mmprojForModel(
                                  storage.lastUsedModelPath!,
                                ),
                                gpuLayers: storage.gpuLayers,
                                contextSize: storage.contextSize,
                                useVulkan: storage.useVulkan ?? false,
                                useCublas: storage.useCublas ?? false,
                                useMetal: storage.useMetal ?? false,
                                useRocm: storage.useRocm ?? false,
                              );
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Starting backend…'),
                                ),
                              );
                            },
                      icon: Icon(
                        koboldService.isRunning
                            ? Icons.restart_alt
                            : Icons.play_arrow,
                        size: 18,
                      ),
                      label: Text(
                        koboldService.isRunning
                            ? 'Restart Backend'
                            : 'Start Backend',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4AA),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }


  /// Small colored dot + label for the VRAM gauge legend.
  Widget _buildVramLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white54),
        ),
      ],
    );
  }

  /// Estimate the selected model's file size in MB for the VRAM gauge.
  int _getSelectedModelSizeMb() {
    if (_selectedModelPath == null) return 0;
    try {
      final file = File(_selectedModelPath!);
      if (file.existsSync()) {
        return (file.lengthSync() / (1024 * 1024)).round();
      }
    } catch (_) {}
    return 0;
  }

  Widget _buildSectionHeader(String title, [BuildContext? context]) {
    final theme = context != null ? Theme.of(context) : null;
    return Text(
      title,
      style:
          theme?.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ) ??
          const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
    );
  }

  // ignore: unused_element
  Widget _buildModeChip({
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.tealAccent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.tealAccent : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.tealAccent : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected
                    ? Colors.tealAccent.withValues(alpha: 0.6)
                    : Colors.white30,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildInfoRow(String label, String value, BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required BuildContext context,
    bool isNumber = false,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // _showSavePromptDialog extracted to lib/ui/settings/dialogs/prompt_save_dialog.dart (Stage 5 helper dialogs step); deletion part of task.

  // _showDeletePromptDialog extracted to lib/ui/settings/dialogs/prompt_delete_dialog.dart (Stage 5); deletion part of task.


}

// _showColorPicker extracted to lib/ui/settings/dialogs/color_picker_dialog.dart (Stage 5 helper dialogs); deletion part of task.
