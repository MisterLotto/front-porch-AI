import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/backend_manager.dart';
import 'package:front_porch_ai/services/model_manager.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/hardware_service.dart';
import 'package:front_porch_ai/services/optimization_service.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/services/open_router_service.dart';
import 'package:front_porch_ai/ui/widgets/log_view.dart';
import 'package:front_porch_ai/ui/dialogs/rocm_guidance_dialog.dart';
import 'package:front_porch_ai/providers/app_state.dart';
import 'package:front_porch_ai/services/update_service.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/group_chat_repository.dart';
import 'package:front_porch_ai/services/folder_service.dart';
import 'package:path/path.dart' as path;
import 'package:front_porch_ai/services/cloud_providers/webdav_provider.dart';
import 'package:front_porch_ai/services/cloud_providers/google_drive_provider.dart';

import 'package:front_porch_ai/services/v2_card_service.dart';
import 'package:front_porch_ai/ui/dialogs/tts_settings_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _gpuLayersController = TextEditingController(text: '0');
  final _contextSizeController = TextEditingController(text: '8192');
  double _contextSizeValue = 8192;
  final _apiController = TextEditingController();
  bool _useVulkan = false;
  bool _useCublas = false;
  bool _useMetal = false;
  String? _selectedModelPath;
  late final TextEditingController _systemPromptController;

  // Remote API state
  List<RemoteModelInfo> _availableModels = [];
  bool _isFetchingModels = false;
  bool _isCheckingConnection = false;

  @override
  void initState() {
    super.initState();
    _apiController.text = Provider.of<KoboldService>(context, listen: false).baseUrl;
    _systemPromptController = TextEditingController(
      text: Provider.of<StorageService>(context, listen: false).systemPrompt,
    );
    
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
      final hardwareService = Provider.of<HardwareService>(context, listen: false);
      
      if (hardwareService.hardwareInfo != null) {
        _applyHardwareDefaults(hardwareService.hardwareInfo!);
      } else {
        // Detection still in progress — listen for completion
        void listener() {
          if (!mounted) return;
          if (!hardwareService.isDetecting && hardwareService.hardwareInfo != null) {
            hardwareService.removeListener(listener);
            _applyHardwareDefaults(hardwareService.hardwareInfo!);
          }
        }
        hardwareService.addListener(listener);
      }
    });
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
      }
    }
    // Non-NVIDIA/Non-Mac Logic: Default to Vulkan if not set
    else {
      if (storage.useVulkan == null) {
        storage.setUseVulkan(true);
        storage.setUseCublas(false);
        storage.setUseMetal(false);
        _useVulkan = true;
        _useCublas = false;
        _useMetal = false;
        changed = true;
      } else {
        _useVulkan = storage.useVulkan!;
        if (storage.useCublas != null) _useCublas = storage.useCublas!;
        if (storage.useMetal != null) _useMetal = storage.useMetal!;
      }
    }

    if (changed) {
      setState(() {});
      final String msg;
      if (hw.vendor == 'Nvidia') {
        msg = 'NVIDIA GPU detected: CuBLAS enabled.';
      } else if (Platform.isMacOS) {
        msg = 'Apple Silicon detected: Metal enabled.';
      } else if (hw.vendor == 'AMD' && Platform.isLinux && hw.hasRocm == false) {
        msg = 'AMD GPU detected: Vulkan enabled. Install ROCm for better performance.';
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
    if (_selectedModelPath != null) {
      _applyAutoConfiguration(silent: true);
    }
  }

  @override
  void dispose() {
    _gpuLayersController.dispose();
    _contextSizeController.dispose();
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _pickStoragePath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      if (mounted) {
        await Provider.of<StorageService>(context, listen: false).setRootPath(selectedDirectory);
        // Refresh backend/models after path change
         Provider.of<BackendManager>(context, listen: false).checkBackendAvailability();
         Provider.of<ModelManager>(context, listen: false).refreshModels();
      }
    }
  }

  void _applyAutoConfiguration({bool silent = false}) {
    final hardware = Provider.of<HardwareService>(context, listen: false).hardwareInfo;
    if (hardware == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hardware not detected yet.')));
      }
      return;
    }

    if (silent) {
      _runOptimization(hardware.vramMb, hardware, silent: true);
    } else {
      final vramController = TextEditingController(text: hardware.vramMb.toString());
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Auto-Configuration', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Confirm your System VRAM (MB):', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: vramController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                final adjustedVram = int.tryParse(vramController.text) ?? hardware.vramMb;
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

  void _runOptimization(int vramMb, HardwareInfo hardware, {required bool silent}) {
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

    final suggestion = OptimizationService.calculateSettings(adjustedHw, modelSizeMb: modelSize);

    setState(() {
      _gpuLayersController.text = suggestion.gpuLayers.toString();
      _contextSizeController.text = suggestion.contextSize.toString();
      // If user has Mac, suggest Metal
      if (Platform.isMacOS) {
        _useMetal = true;
        _useVulkan = false;
        _useCublas = false;
      }
      // If user has Nvidia, suggest Cublas instead of Vulkan usually
      else if (hardware.vendor == 'Nvidia') {
        _useCublas = true;
        _useVulkan = false;
        _useMetal = false;
      } else {
        _useCublas = false;
        _useMetal = false;
      }
    });

    if (!silent) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(suggestion.reasoning)),
      );
    }
  }

  void _autoConfigure() {
    _applyAutoConfiguration(silent: false);
  }

  void _toggleKobold(BuildContext context) {
    final koboldService = Provider.of<KoboldService>(context, listen: false);
    final backendManager = Provider.of<BackendManager>(context, listen: false);

    if (koboldService.isRunning) {
      koboldService.stopKobold();
    } else {
      if (backendManager.backendPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backend not found. Please download it first.')),
        );
        return;
      }
      if (_selectedModelPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a model.')),
        );
        return;
      }

      // Check if model file actually exists
      if (!File(_selectedModelPath!).existsSync()) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected model file does not exist!')),
        );
        return;
      }

      koboldService.startKobold(
        backendManager.backendPath!,
        _selectedModelPath!,
        gpuLayers: int.tryParse(_gpuLayersController.text) ?? 0,
        contextSize: int.tryParse(_contextSizeController.text) ?? 4096,
        useVulkan: _useVulkan,
        useCublas: _useCublas,
        useMetal: _useMetal,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Settings', style: theme.textTheme.titleLarge),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: theme.iconTheme,
          bottom: TabBar(
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color,
            tabs: const [
              Tab(text: 'General'),
              Tab(text: 'Advanced / GPU'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGeneralTab(context),
            _buildAdvancedTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralTab(BuildContext context) {
    final storageService = Provider.of<StorageService>(context);
    final modelManager = Provider.of<ModelManager>(context);
    final backendManager = Provider.of<BackendManager>(context);
    final koboldService = Provider.of<KoboldService>(context);
    final llmProvider = Provider.of<LLMProvider>(context);
    final theme = Theme.of(context);

    // Auto-select first model if none selected and models exist
    if (_selectedModelPath == null && modelManager.models.isNotEmpty) {
      _selectedModelPath = modelManager.models.first.path;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dark Mode', style: theme.textTheme.titleMedium),
              Switch(
                value: Provider.of<AppState>(context).darkMode,
                onChanged: (_) => Provider.of<AppState>(context, listen: false).toggleTheme(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (UpdateService.isSupported)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Check for Updates', style: theme.textTheme.titleMedium),
                Consumer<UpdateService>(
                  builder: (context, updateService, _) => Switch(
                    value: updateService.autoCheckEnabled,
                    onChanged: (val) => updateService.setAutoCheckEnabled(val),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          _buildSlider(
            'Font Size Scale',
            storageService.textScale,
            0.7,
            2.0,
            (val) => storageService.setTextScale(val),
            context,
            divisions: 13,
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Model Instructions', context),
          const SizedBox(height: 8),
          // Prompt library row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: null,
                  isExpanded: true,
                  hint: const Text('Load saved prompt...', style: TextStyle(fontSize: 13)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: storageService.savedPrompts.map((p) => DropdownMenuItem<String>(
                    value: p['name'],
                    child: Text(p['name']!, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (name) {
                    if (name != null) {
                      storageService.loadSavedPrompt(name);
                      _systemPromptController.text = storageService.systemPrompt;
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Save current prompt',
                icon: const Icon(Icons.save, color: Colors.amber),
                onPressed: () => _showSavePromptDialog(context, storageService),
              ),
              IconButton(
                tooltip: 'Delete a saved prompt',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _showDeletePromptDialog(context, storageService),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Built-in preset chips
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildPresetChip(
                label: '📡 API Default',
                prompt: ChatService.defaultApiSystemPrompt,
                storageService: storageService,
                context: context,
              ),
              _buildPresetChip(
                label: '🖥️ KoboldCPP',
                prompt: ChatService.defaultKoboldSystemPrompt,
                storageService: storageService,
                context: context,
              ),
              _buildPresetChip(
                label: '👥 Group Chat',
                prompt: ChatService.defaultGroupSystemPrompt,
                storageService: storageService,
                context: context,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _systemPromptController,
            maxLines: 5,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'System Prompt...',
              hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => storageService.setSystemPrompt(val),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Text-to-Speech', context),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.volume_up, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_engineDisplayName(storageService.ttsEngine), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        storageService.ttsEnabled
                            ? 'Enabled — Voice: ${storageService.ttsVoiceModel.isEmpty ? "Not set" : storageService.ttsVoiceModel}'
                            : 'Disabled',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const TtsSettingsDialog(),
                  ),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Configure'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
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
                         Text('Installation Directory', style: theme.textTheme.bodySmall),
                         Text(
                           storageService.rootPath ?? 'Not set',
                           style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                         ),
                       ],
                     ),
                   ),
                   IconButton(
                     icon: Icon(Icons.edit, color: theme.iconTheme.color),
                     onPressed: _pickStoragePath,
                     tooltip: 'Change Install Location',
                   ),
                 ],
               ),
             ),

          const SizedBox(height: 24),
          _buildCloudSyncSection(context, storageService, theme),

          const SizedBox(height: 24),
          _buildSectionHeader('Backend Mode', context),
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
                    Expanded(
                      child: RadioListTile<BackendType>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(Icons.computer, size: 18, color: theme.iconTheme.color),
                            const SizedBox(width: 6),
                            const Text('Local (KoboldCPP)', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        value: BackendType.kobold,
                        groupValue: llmProvider.activeBackend,
                        onChanged: (val) async {
                          if (val != null) {
                            await llmProvider.setActiveBackend(val);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Switched to local KoboldCPP backend.')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<BackendType>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(Icons.cloud, size: 18, color: theme.iconTheme.color),
                            const SizedBox(width: 6),
                            const Text('Remote API', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        value: BackendType.openRouter,
                        groupValue: llmProvider.activeBackend,
                        onChanged: (val) async {
                          if (val != null) {
                            final stoppedKobold = await llmProvider.setActiveBackend(val);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(
                                  stoppedKobold
                                      ? 'Shutting down KoboldCPP… Switched to Remote API.'
                                      : 'Switched to Remote API backend.',
                                )),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (llmProvider.isLocal)
                  Text(
                    'Use a local KoboldCPP instance to run models on your hardware.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  )
                else
                  Text(
                    'Connect to OpenRouter, Nano-GPT, or any OpenAI-compatible API.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
              ],
            ),
          ),

          // ── Remote API Configuration ──
          if (!llmProvider.isLocal) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('API Configuration', context),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API URL', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: storageService.remoteApiUrl,
                    decoration: InputDecoration(
                      hintText: 'https://openrouter.ai/api/v1',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) => storageService.setRemoteApiUrl(val.trim()),
                  ),
                  const SizedBox(height: 16),
                  Text('API Key', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: storageService.remoteApiKey,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'sk-or-...',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: const Icon(Icons.key, size: 18),
                    ),
                    onChanged: (val) => storageService.setRemoteApiKey(val.trim()),
                  ),
                  const SizedBox(height: 12),
                  // ── Check Connection Button ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCheckingConnection ? null : () async {
                        setState(() => _isCheckingConnection = true);
                        final openRouter = Provider.of<OpenRouterService>(context, listen: false);
                        // Ensure service has latest config
                        openRouter.configure(
                          apiUrl: storageService.remoteApiUrl,
                          apiKey: storageService.remoteApiKey,
                        );
                        final result = await openRouter.testConnection();
                        if (mounted) {
                          setState(() => _isCheckingConnection = false);
                          final isSuccess = result.contains('successful');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    isSuccess ? Icons.check_circle : Icons.error,
                                    color: isSuccess ? Colors.greenAccent : Colors.redAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(result)),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                      icon: _isCheckingConnection
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.wifi_tethering, size: 18),
                      label: Text(_isCheckingConnection ? 'Checking...' : 'Check Connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Model Selection ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Model', style: theme.textTheme.bodySmall),
                      TextButton.icon(
                        onPressed: _isFetchingModels ? null : () async {
                          setState(() => _isFetchingModels = true);
                          final openRouter = Provider.of<OpenRouterService>(context, listen: false);
                          openRouter.configure(
                            apiUrl: storageService.remoteApiUrl,
                            apiKey: storageService.remoteApiKey,
                          );
                          final models = await openRouter.fetchAvailableModels();
                          if (mounted) {
                            setState(() {
                              _availableModels = models;
                              _isFetchingModels = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(
                                models.isEmpty
                                    ? 'No models found. Check your API URL and key.'
                                    : 'Found ${models.length} available models.',
                              )),
                            );
                          }
                        },
                        icon: _isFetchingModels
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh, size: 16),
                        label: Text(_isFetchingModels ? 'Loading...' : 'Refresh Models'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_availableModels.isNotEmpty)
                    InkWell(
                      onTap: () => _showModelSearchDialog(context, storageService),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    storageService.remoteModelName.isNotEmpty
                                        ? storageService.remoteModelName
                                        : 'Tap to select a model...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: storageService.remoteModelName.isNotEmpty
                                          ? null
                                          : Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (storageService.remoteModelName.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Builder(builder: (context) {
                                      final match = _availableModels
                                          .where((m) => m.id == storageService.remoteModelName)
                                          .toList();
                                      if (match.isEmpty) return const SizedBox.shrink();
                                      return Text(
                                        match.first.pricingLabel,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                          ],
                        ),
                      ),
                    )
                  else
                    TextFormField(
                      initialValue: storageService.remoteModelName,
                      decoration: InputDecoration(
                        hintText: 'e.g. nousresearch/hermes-3-llama-3.1-405b',
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: const Icon(Icons.smart_toy, size: 18),
                      ),
                      onChanged: (val) => storageService.setRemoteModelName(val.trim()),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Works with OpenRouter, Nano-GPT, or any OpenAI-compatible endpoint.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Reasoning Settings ──
                  Row(
                    children: [
                      const Icon(Icons.psychology, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text('Request Reasoning', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Switch(
                        value: storageService.reasoningEnabled,
                        onChanged: (val) => storageService.setReasoningEnabled(val),
                        activeTrackColor: Colors.blueAccent,
                      ),
                    ],
                  ),
                  if (storageService.reasoningEnabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 22, bottom: 8),
                      child: Row(
                        children: [
                          Text('Effort Level', style: theme.textTheme.bodySmall),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: storageService.reasoningEffort,
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(value: 'low', child: Text('Low')),
                                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                                  DropdownMenuItem(value: 'high', child: Text('High')),
                                ],
                                onChanged: (val) {
                                  if (val != null) storageService.setReasoningEffort(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!storageService.reasoningEnabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 22, bottom: 8),
                      child: Text(
                        'Enable to request thinking/reasoning from compatible models',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── Local KoboldCPP sections (only when local mode) ──
          if (llmProvider.isLocal) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('Koboldcpp Backend', context),
           // ... (Existing Backend Logic adapted) ...
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                 if (backendManager.error != null)
                   Padding(
                     padding: const EdgeInsets.only(bottom: 8.0),
                     child: Text(backendManager.error!, style: const TextStyle(color: Colors.redAccent)),
                   ),
                 
                 Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            backendManager.backendPath != null ? 'Status: Ready' : 'Status: Missing',
                             style: TextStyle(
                              color: backendManager.backendPath != null ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (backendManager.backendPath != null)
                            Text(
                              backendManager.backendPath!,
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                               overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (backendManager.isDownloading)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      ElevatedButton(
                        onPressed: () => backendManager.downloadBackend(),
                        child: Text(backendManager.backendPath != null ? 'Update' : 'Download'),
                      ),
                  ],
                ),
                if (backendManager.isDownloading)
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: LinearProgressIndicator(value: backendManager.downloadProgress),
                   ),
              ],
            ),

          const SizedBox(height: 24),
          _buildSectionHeader('Model Selection', context),
           const SizedBox(height: 16),
            if (modelManager.models.isEmpty)
              const Text('No models available. Go to "Manage Models" to download one.', style: TextStyle(color: Colors.orange))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedModelPath,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    style: theme.textTheme.bodyMedium,
                    icon: Icon(Icons.arrow_drop_down, color: theme.iconTheme.color),
                    items: modelManager.models.map((file) {
                      return DropdownMenuItem(
                        value: file.path,
                        child: Text(file.path.split(Platform.pathSeparator).last),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                         _selectedModelPath = val;
                      });
                      Provider.of<StorageService>(context, listen: false).setLastUsedModelPath(val);
                      _applyAutoConfiguration(silent: true);
                    },
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: backendManager.backendPath == null ? null : () => _toggleKobold(context),
                icon: Icon(koboldService.isRunning ? Icons.stop : Icons.play_arrow),
                label: Text(koboldService.isRunning ? 'Stop Backend' : 'Start Backend'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: koboldService.isRunning ? Colors.red.withOpacity(0.8) : Colors.green.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Process Logs', context),
            const SizedBox(height: 8),
            LogView(logs: koboldService.logs),
          ], // end isLocal
        ],
      ),
    );
  }

  Widget _buildAdvancedTab(BuildContext context) {
     final storageService = Provider.of<StorageService>(context);
     final hardwareService = Provider.of<HardwareService>(context);
     final theme = Theme.of(context);

     return SingleChildScrollView(
       padding: const EdgeInsets.all(24.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           _buildSectionHeader('Generation Settings', context),
           const SizedBox(height: 16),
           
           _buildSlider('Min-P', storageService.minP, 0.0, 1.0, (val) => storageService.setMinP(val), context),
           _buildSlider('Temperature', storageService.temperature, 0.0, 2.0, (val) => storageService.setTemperature(val), context, divisions: 20),
           _buildSlider('Repeat Penalty', storageService.repeatPenalty, 1.0, 3.0, (val) => storageService.setRepeatPenalty(val), context),
           _buildSlider('Rep Pen Tokens', storageService.repeatPenaltyTokens.toDouble(), 0, 512, (val) => storageService.setRepeatPenaltyTokens(val.toInt()), context, divisions: 512),
           _buildSlider('Max Output Tokens', storageService.maxLength.toDouble(), 16, 2048, (val) => storageService.setMaxLength(val.toInt()), context, divisions: 2048 - 16),
           _buildSlider('Min Output Tokens', storageService.minLength.toDouble(), 0, 512, (val) => storageService.setMinLength(val.toInt()), context, divisions: 512),
            Builder(builder: (context) {
              final isApi = !Provider.of<LLMProvider>(context, listen: false).isLocal;
              final maxCtx = isApi ? 500000.0 : 15000.0;
              return _buildSlider('Context Size', _contextSizeValue.clamp(4098, maxCtx), 4098, maxCtx, (val) {
                setState(() {
                  _contextSizeValue = val;
                  _contextSizeController.text = val.toInt().toString();
                });
                storageService.setContextSize(val.toInt());
              }, context, divisions: (maxCtx - 4098).toInt());
            }),
           
           Row(
             children: [
               Text('Dynamic Temperature', style: theme.textTheme.bodyMedium),
               Switch(
                 value: storageService.dynamicTempEnabled, 
                 onChanged: (val) => storageService.setDynamicTempEnabled(val)
               ),
             ],
           ),
           if (storageService.dynamicTempEnabled)
             _buildSlider('Dynatemp Range', storageService.dynamicTempRange, 0.0, 2.0, (val) => storageService.setDynamicTempRange(val), context),

           const SizedBox(height: 24),
           Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Hardware & GPU', context),
                TextButton.icon(
                  onPressed: _autoConfigure,
                  icon: const Icon(Icons.auto_fix_high, color: Colors.amber),
                  label: const Text('Auto-Configure', style: TextStyle(color: Colors.amber)),
                ),
              ],
            ),
           const SizedBox(height: 16),
           // Hardware Info
            Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: theme.cardColor,
                 borderRadius: BorderRadius.circular(8),
               ),
              child: hardwareService.isDetecting
                ? const Center(child: CircularProgressIndicator())
                : hardwareService.hardwareInfo == null
                  ? const Text('Hardware not detected.', style: TextStyle(color: Colors.redAccent))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('GPU', hardwareService.hardwareInfo!.gpuName, context),
                        _buildInfoRow('VRAM', '${hardwareService.hardwareInfo!.vramMb} MB', context),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
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
             Row(
              children: [
                 FilterChip(
                  label: const Text('Use Vulkan'),
                  selected: _useVulkan,
                  onSelected: (val) {
                     setState(() {
                       _useVulkan = val;
                       if (val) _useCublas = false; // Mutually exclusive usually
                     });
                     Provider.of<StorageService>(context, listen: false).setUseVulkan(val);
                     if (val) Provider.of<StorageService>(context, listen: false).setUseCublas(false);
                  },
                ),
                const SizedBox(width: 8),
                 Tooltip(
                   message: hardwareService.hardwareInfo?.vendor == 'Nvidia' ? 'Use CUDA (NVIDIA only)' : 'Requires NVIDIA GPU',
                   child: FilterChip(
                    label: const Text('Use CuBLAS (Nvidia)'),
                    selected: _useCublas,
                    onSelected: hardwareService.hardwareInfo?.vendor == 'Nvidia' 
                      ? (val) {
                          setState(() {
                            _useCublas = val;
                            if (val) _useVulkan = false;
                          });
                          // Persist change
                          Provider.of<StorageService>(context, listen: false).setUseCublas(val);
                        }
                      : null, // Disabled if not Nvidia
                    avatar: hardwareService.hardwareInfo?.vendor == 'Nvidia' 
                      ? null 
                      : const Icon(Icons.block, size: 16),
                  ),
                 ),
                 const SizedBox(width: 8),
                 Tooltip(
                   message: hardwareService.hardwareInfo?.hasMetal == true ? 'Use Metal (Apple Silicon/Mac)' : 'Requires MacOS with Metal support',
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
                            }
                          });
                          // Persist change
                          Provider.of<StorageService>(context, listen: false).setUseMetal(val);
                          if (val) {
                            Provider.of<StorageService>(context, listen: false).setUseVulkan(false);
                            Provider.of<StorageService>(context, listen: false).setUseCublas(false);
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
            _buildStopSequencesSection(context),
         ],
       ),
     );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged, BuildContext context, {int? divisions}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color)),
            Text(value.toStringAsFixed(2), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, [BuildContext? context]) {
    final theme = context != null ? Theme.of(context) : null;
    return Text(
      title,
      style: theme?.textTheme.titleMedium?.copyWith(
         fontWeight: FontWeight.bold,
         color: Colors.blueAccent,
      ) ?? const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blueAccent,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
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

  Widget _buildStopSequencesSection(BuildContext context) {
    final storageService = Provider.of<StorageService>(context);
    final theme = Theme.of(context);
    final controller = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Stop Sequences (SillyTavern Style)', context),
        const SizedBox(height: 8),
        const Text(
          'Generation will immediately stop if these strings are encountered. '
          'Useful for preventing hallucinations or user impersonation.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Add new stop string...',
                          hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onSubmitted: (val) {
                          if (val.isNotEmpty) {
                            storageService.addStopSequence(val);
                            controller.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                      onPressed: () {
                        if (controller.text.isNotEmpty) {
                          storageService.addStopSequence(controller.text);
                          controller.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...storageService.stopSequences.map((seq) => ListTile(
                title: Text(
                  seq.replaceAll('\n', '\\n'),
                  style: theme.textTheme.bodyMedium,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => storageService.removeStopSequence(seq),
                ),
                dense: true,
              )).toList(),
            ],
          ),
        ),
      ],
    );
  }

  void _showSavePromptDialog(BuildContext context, StorageService storageService) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Save Prompt', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Prompt name...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              storageService.savePrompt(value.trim(), storageService.systemPrompt);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Prompt "${value.trim()}" saved!')),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                storageService.savePrompt(controller.text.trim(), storageService.systemPrompt);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Prompt "${controller.text.trim()}" saved!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeletePromptDialog(BuildContext context, StorageService storageService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Delete Saved Prompt', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: storageService.savedPrompts.isEmpty
              ? const Text('No saved prompts.', style: TextStyle(color: Colors.white54))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: storageService.savedPrompts.map((p) => ListTile(
                    title: Text(p['name']!, style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        storageService.deleteSavedPrompt(p['name']!);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Prompt "${p['name']}" deleted.')),
                        );
                      },
                    ),
                    dense: true,
                  )).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  /// Shows a full dialog with a search bar to filter and select from available models.
  void _showModelSearchDialog(BuildContext context, StorageService storageService) {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = searchQuery.isEmpty
                ? _availableModels
                : _availableModels.where((m) {
                    final q = searchQuery.toLowerCase();
                    return m.id.toLowerCase().contains(q) ||
                           m.name.toLowerCase().contains(q);
                  }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF1F2937),
              title: const Text('Select Model', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 500,
                height: 450,
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search ${_availableModels.length} models...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF111827),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) => setDialogState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 8),
                    // Result count
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filtered.length} models',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Model list
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No models match your search.', style: TextStyle(color: Colors.white38)))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final model = filtered[i];
                                final isSelected = model.id == storageService.remoteModelName;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: Colors.blueAccent.withOpacity(0.15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  title: Text(
                                    model.id,
                                    style: TextStyle(
                                      color: isSelected ? Colors.blueAccent : Colors.white,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Row(
                                    children: [
                                      if (model.isFree)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('FREE', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                      Flexible(
                                        child: Text(
                                          model.pricingLabel,
                                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: Colors.blueAccent, size: 18)
                                      : null,
                                  onTap: () {
                                    storageService.setRemoteModelName(model.id);
                                    Navigator.pop(ctx);
                                    setState(() {});  // Refresh the settings page
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds a compact chip that loads a built-in system prompt preset.
  Widget _buildPresetChip({
    required String label,
    required String prompt,
    required StorageService storageService,
    required BuildContext context,
  }) {
    final isActive = _systemPromptController.text == prompt;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isActive ? Colors.white : Colors.white70,
        ),
      ),
      backgroundColor: isActive ? Colors.deepPurple : const Color(0xFF2D3748),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? Colors.deepPurpleAccent : Colors.white24,
        ),
      ),
      onPressed: () {
        setState(() {
          _systemPromptController.text = prompt;
        });
        storageService.setSystemPrompt(prompt);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded "$label" system prompt'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  Widget _buildCloudSyncSection(BuildContext context, StorageService storageService, ThemeData theme) {
    final syncService = Provider.of<CloudSyncService>(context);
    final isEnabled = storageService.cloudSyncEnabled;
    final provider = storageService.cloudSyncProvider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('☁️ Cloud Sync', context),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enable toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('Enable Cloud Sync', style: theme.textTheme.titleSmall),
                    ],
                  ),
                  Switch(
                    value: isEnabled,
                    onChanged: (val) async {
                      if (val) {
                        // Show alpha warning before enabling
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade400, size: 24),
                                const SizedBox(width: 10),
                                const Text('Alpha Feature', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: const Text(
                              'Cloud Sync is currently in alpha. While functional, you may encounter '
                              'occasional issues. Your local data will not be affected.\n\n'
                              'Supported providers: Google Drive, Nextcloud (WebDAV).',
                              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Enable Anyway'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          storageService.setCloudSyncEnabled(true);
                        }
                      } else {
                        storageService.setCloudSyncEnabled(false);
                      }
                    },
                  ),
                ],
              ),
              if (isEnabled) ...[
                const SizedBox(height: 12),
                // Provider dropdown
                DropdownButtonFormField<String>(
                  value: provider == 'none' ? null : provider,
                  isExpanded: true,
                  hint: const Text('Select provider...'),
                  decoration: InputDecoration(
                    labelText: 'Cloud Provider',
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'webdav', child: Text('Nextcloud (WebDAV)')),
                    DropdownMenuItem(value: 'gdrive', child: Text('Google Drive')),

                  ],
                  onChanged: (val) {
                    if (val != null) storageService.setCloudSyncProvider(val);
                  },
                ),

                // WebDAV fields
                if (provider == 'webdav') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: storageService.cloudSyncUrl,
                    decoration: InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://your-nextcloud.com/remote.php/dav/files/username',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) => storageService.setCloudSyncUrl(val.trim()),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: storageService.cloudSyncUsername,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) => storageService.setCloudSyncUsername(val.trim()),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: storageService.cloudSyncPassword,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password / App Token',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: const Icon(Icons.key, size: 18),
                    ),
                    onChanged: (val) => storageService.setCloudSyncPassword(val),
                  ),
                ],

                // Google Drive sign-in / disconnect buttons
                if (provider == 'gdrive') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: syncService.isConnected ? null : () async {
                            try {
                              final gProvider = GoogleDriveProvider();
                              await gProvider.connect({});
                              syncService.setProvider(gProvider);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ Signed in to Google Drive!')),
                                );
                                setState(() {});
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('❌ Google sign-in failed: $e')),
                                );
                              }
                            }
                          },
                          icon: Icon(syncService.isConnected ? Icons.check_circle : Icons.login, size: 18),
                          label: Text(syncService.isConnected ? 'Connected' : 'Sign in with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: syncService.isConnected ? Colors.green.shade700 : Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (syncService.isConnected) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await syncService.provider?.disconnect();
                            syncService.clearProvider();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Disconnected from Google Drive')),
                              );
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Disconnect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // Action buttons
                if (provider != 'none') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Test connection
                            CloudStorageProvider testProvider;
                            switch (provider) {
                              case 'webdav':
                                testProvider = WebDavProvider();
                                break;
                              case 'gdrive':
                                testProvider = GoogleDriveProvider();
                                break;

                              default:
                                return;
                            }
                            try {
                              await testProvider.connect({
                                'url': storageService.cloudSyncUrl,
                                'username': storageService.cloudSyncUsername,
                                'password': storageService.cloudSyncPassword,
                              });
                              syncService.setProvider(testProvider);
                              final ok = await syncService.testConnection();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ok ? '✅ Connection successful!' : '❌ Connection failed: ${syncService.lastError}')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('❌ Connection failed: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.wifi_tethering, size: 18),
                          label: const Text('Test'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent.withOpacity(0.8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: syncService.status == SyncStatus.syncing ? null : () async {
                            // Full sync now
                            if (!syncService.isConnected) {
                              CloudStorageProvider p;
                              switch (provider) {
                                case 'webdav':
                                  p = WebDavProvider();
                                  break;
                                case 'gdrive':
                                  p = GoogleDriveProvider();
                                  break;

                                default:
                                  return;
                              }
                              await p.connect({
                                'url': storageService.cloudSyncUrl,
                                'username': storageService.cloudSyncUsername,
                                'password': storageService.cloudSyncPassword,
                              });
                              syncService.setProvider(p);
                            }

                            final chatsPath = storageService.chatsDir.path;
                            final rootPath = storageService.rootPath ?? chatsPath;
                            final charactersPath = '$rootPath${Platform.pathSeparator}KoboldManager${Platform.pathSeparator}Characters';

                            // Build valid ID sets for orphan cleanup
                            final charRepo = Provider.of<CharacterRepository>(context, listen: false);
                            final groupRepo = Provider.of<GroupChatRepository>(context, listen: false);
                            final validCharIds = charRepo.characters
                                .where((c) => c.imagePath != null)
                                .map((c) => path.basenameWithoutExtension(c.imagePath!))
                                .toSet();
                            final validGroupIds = groupRepo.groups.map((g) => g.id).toSet();

                            final folderSvc = Provider.of<FolderService>(context, listen: false);

                            await syncService.fullSync(chatsPath, charactersPath,
                              validCharIds: validCharIds,
                              validGroupIds: validGroupIds,
                              folderService: folderSvc,
                            );
                            if (syncService.status == SyncStatus.success) {
                              await storageService.setCloudSyncLastTime(DateTime.now().toIso8601String());
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✅ Synced ${syncService.syncedFiles} files!')),
                                );
                              }

                              // Check for remote-only characters and offer to download
                              if (mounted) {
                                final remoteOnly = await syncService.listRemoteOnlyCharacters(charactersPath);
                                if (remoteOnly.isNotEmpty && mounted) {
                                  await _showCharacterPullDialog(
                                    context, syncService, charRepo, charactersPath, remoteOnly,
                                  );
                                }
                              }
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('❌ Sync error: ${syncService.lastError}')),
                              );
                            }
                          },
                          icon: syncService.status == SyncStatus.syncing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync, size: 18),
                          label: Text(syncService.status == SyncStatus.syncing
                              ? 'Syncing ${(syncService.progress * 100).toInt()}%'
                              : 'Sync Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Browse Cloud Characters button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: syncService.status == SyncStatus.syncing
                          ? null
                          : () async {
                              final storageService = Provider.of<StorageService>(context, listen: false);
                              final rootPath = storageService.rootPath ?? storageService.chatsDir.path;
                              final charactersPath = '$rootPath${Platform.pathSeparator}KoboldManager${Platform.pathSeparator}Characters';
                              final charRepo = Provider.of<CharacterRepository>(context, listen: false);

                              // Ensure provider is connected
                              if (!syncService.isConnected) {
                                CloudStorageProvider p;
                                switch (storageService.cloudSyncProvider) {
                                  case 'webdav':
                                    p = WebDavProvider();
                                    break;
                                  case 'gdrive':
                                    p = GoogleDriveProvider();
                                    break;
                                  default:
                                    return;
                                }
                                await p.connect({
                                  'url': storageService.cloudSyncUrl,
                                  'username': storageService.cloudSyncUsername,
                                  'password': storageService.cloudSyncPassword,
                                });
                                syncService.setProvider(p);
                              }

                              if (mounted) {
                                await _showCloudCharacterBrowser(
                                  context, syncService, charRepo, charactersPath,
                                );
                              }
                            },
                      icon: const Icon(Icons.cloud_outlined, size: 16),
                      label: const Text('Browse Cloud Characters'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],

                // Status display
                if (storageService.cloudSyncLastTime.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last synced: ${_formatSyncTime(storageService.cloudSyncLastTime)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
                if (syncService.status == SyncStatus.error && syncService.lastError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Error: ${syncService.lastError}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatSyncTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  /// Show a dialog with a grid of remote-only characters for selective download.
  Future<void> _showCharacterPullDialog(
    BuildContext context,
    CloudSyncService syncService,
    CharacterRepository charRepo,
    String charactersDir,
    List<String> remoteFilenames,
  ) async {
    // Download all remote-only PNGs to a temp directory for preview
    final tempPreviews = await syncService.downloadCharactersToTemp(remoteFilenames);
    if (tempPreviews.isEmpty) return;

    // Try to extract character names from the PNGs
    final v2 = V2CardService();
    final charInfos = <String, String>{}; // filename → display name
    for (final entry in tempPreviews.entries) {
      try {
        final card = await v2.readCard(entry.value);
        charInfos[entry.key] = card?.name ?? path.basenameWithoutExtension(entry.key);
      } catch (_) {
        charInfos[entry.key] = path.basenameWithoutExtension(entry.key);
      }
    }

    if (!context.mounted) return;

    final selected = <String>{...tempPreviews.keys}; // select all by default

    final result = await showDialog<Set<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.cloud_download, color: Colors.blueAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Characters Available from Cloud',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${tempPreviews.length} character(s) not on this device',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    // Select all / none bar
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setDialogState(() => selected.addAll(tempPreviews.keys)),
                          child: const Text('Select All', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setDialogState(() => selected.clear()),
                          child: const Text('Select None', style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ),
                        const Spacer(),
                        Text(
                          '${selected.length} selected',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Character grid
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: tempPreviews.length,
                        itemBuilder: (ctx, index) {
                          final filename = tempPreviews.keys.elementAt(index);
                          final tempPath = tempPreviews[filename]!;
                          final displayName = charInfos[filename] ?? filename;
                          final isSelected = selected.contains(filename);

                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selected.remove(filename);
                                } else {
                                  selected.add(filename);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.blueAccent : Colors.white12,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 8)]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Character avatar
                                    Image.file(
                                      File(tempPath),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.black26,
                                        child: const Icon(Icons.person, color: Colors.white24, size: 48),
                                      ),
                                    ),
                                    // Gradient overlay for name readability
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                                          ),
                                        ),
                                        child: Text(
                                          displayName,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Selection checkbox
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? Colors.blueAccent
                                              : Colors.black54,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(
                                          isSelected ? Icons.check : Icons.add,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, <String>{}),
                  child: const Text('Skip', style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, selected),
                  icon: const Icon(Icons.download, size: 16),
                  label: Text('Download ${selected.length}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // Copy selected files to the characters directory
    if (result != null && result.isNotEmpty) {
      final dir = Directory(charactersDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      int copied = 0;
      for (final filename in result) {
        final tempPath = tempPreviews[filename];
        if (tempPath != null && File(tempPath).existsSync()) {
          final destPath = path.join(charactersDir, filename);
          try {
            await File(tempPath).copy(destPath);
            copied++;
          } catch (e) {
            debugPrint('Error copying character $filename: $e');
          }
        }
      }

      // Reload character repository
      await charRepo.loadCharacters();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Downloaded $copied character(s)!')),
        );
      }
    }

    // Clean up temp files
    for (final tempPath in tempPreviews.values) {
      try {
        final f = File(tempPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Show a dialog browsing ALL characters on the cloud.
  Future<void> _showCloudCharacterBrowser(
    BuildContext context,
    CloudSyncService syncService,
    CharacterRepository charRepo,
    String charactersDir,
  ) async {
    // Show a loading indicator while we fetch
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Fetch the list of all remote characters
    final allRemote = await syncService.listAllRemoteCharacters(charactersDir);

    if (!context.mounted) return;
    Navigator.pop(context); // dismiss loading

    if (allRemote.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No characters found on cloud.')),
        );
      }
      return;
    }

    // For characters already on device, use local path; for others, download to temp
    final localExist = <String>{};
    final needDownload = <String>[];
    for (final r in allRemote) {
      if (r.existsLocally) {
        localExist.add(r.name);
      } else {
        needDownload.add(r.name);
      }
    }

    // Show loading for temp downloads if needed
    Map<String, String> tempPreviews = {};
    if (needDownload.isNotEmpty) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text('Fetching ${needDownload.length} preview(s)...',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      tempPreviews = await syncService.downloadCharactersToTemp(needDownload);

      if (context.mounted) Navigator.pop(context); // dismiss loading
    }

    // Build a combined map of filename → image path
    final imagePaths = <String, String>{};
    for (final r in allRemote) {
      if (r.existsLocally) {
        imagePaths[r.name] = path.join(charactersDir, r.name);
      } else if (tempPreviews.containsKey(r.name)) {
        imagePaths[r.name] = tempPreviews[r.name]!;
      }
    }

    // Extract character names
    final v2 = V2CardService();
    final charNames = <String, String>{};
    for (final entry in imagePaths.entries) {
      try {
        final card = await v2.readCard(entry.value);
        charNames[entry.key] = card?.name ?? path.basenameWithoutExtension(entry.key);
      } catch (_) {
        charNames[entry.key] = path.basenameWithoutExtension(entry.key);
      }
    }

    if (!context.mounted) return;

    // Track which remote-only characters the user wants to download
    final selected = <String>{};

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final hasDownloadable = needDownload.isNotEmpty;
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.cloud, color: Colors.blueAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cloud Characters',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${allRemote.length} character(s) • ${localExist.length} on device • ${needDownload.length} available',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    if (hasDownloadable) ...[
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setDialogState(() => selected.addAll(needDownload)),
                            child: const Text('Select All New', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setDialogState(() => selected.clear()),
                            child: const Text('Clear', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ),
                          const Spacer(),
                          if (selected.isNotEmpty)
                            Text(
                              '${selected.length} to download',
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: allRemote.length,
                        itemBuilder: (ctx, index) {
                          final info = allRemote[index];
                          final imgPath = imagePaths[info.name];
                          final displayName = charNames[info.name] ?? info.name;
                          final isLocal = info.existsLocally;
                          final isSelected = selected.contains(info.name);

                          return GestureDetector(
                            onTap: isLocal
                                ? null // already on device, no action
                                : () {
                                    setDialogState(() {
                                      if (isSelected) {
                                        selected.remove(info.name);
                                      } else {
                                        selected.add(info.name);
                                      }
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isLocal
                                      ? Colors.green.withOpacity(0.5)
                                      : isSelected
                                          ? Colors.blueAccent
                                          : Colors.white12,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 8)]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Character avatar
                                    if (imgPath != null)
                                      Image.file(
                                        File(imgPath),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.black26,
                                          child: const Icon(Icons.person, color: Colors.white24, size: 48),
                                        ),
                                      )
                                    else
                                      Container(
                                        color: Colors.black26,
                                        child: const Icon(Icons.person, color: Colors.white24, size: 48),
                                      ),
                                    // Gradient overlay for name
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                                          ),
                                        ),
                                        child: Text(
                                          displayName,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Status badge
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isLocal
                                              ? Colors.green
                                              : isSelected
                                                  ? Colors.blueAccent
                                                  : Colors.black54,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(
                                          isLocal
                                              ? Icons.check
                                              : isSelected
                                                  ? Icons.check
                                                  : Icons.cloud_download_outlined,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                    // "On device" label for local characters
                                    if (isLocal)
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.85),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'On device',
                                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, <String>{}),
                  child: const Text('Close', style: TextStyle(color: Colors.white38)),
                ),
                if (hasDownloadable)
                  ElevatedButton.icon(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(ctx, selected),
                    icon: const Icon(Icons.download, size: 16),
                    label: Text('Download ${selected.length}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    // Download selected characters
    if (result != null && result.isNotEmpty) {
      final dir = Directory(charactersDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      int copied = 0;
      for (final filename in result) {
        final tempPath = tempPreviews[filename];
        if (tempPath != null && File(tempPath).existsSync()) {
          final destPath = path.join(charactersDir, filename);
          try {
            await File(tempPath).copy(destPath);
            copied++;
          } catch (e) {
            debugPrint('Error copying character $filename: $e');
          }
        }
      }

      await charRepo.loadCharacters();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Downloaded $copied character(s)!')),
        );
      }
    }

    // Clean up temp files
    for (final tempPath in tempPreviews.values) {
      try {
        final f = File(tempPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}

String _engineDisplayName(String engineId) {
  switch (engineId) {
    case 'kokoro': return 'Kokoro TTS';
    case 'openai': return 'OpenAI TTS';
    case 'piper': return 'Piper TTS';
    default: return 'TTS';
  }
}
