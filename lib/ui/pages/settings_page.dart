import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/services/kobold_service.dart';
import 'package:kobold_character_card_manager/services/backend_manager.dart';
import 'package:kobold_character_card_manager/services/model_manager.dart';
import 'package:kobold_character_card_manager/services/storage_service.dart';
import 'package:kobold_character_card_manager/services/hardware_service.dart';
import 'package:kobold_character_card_manager/services/optimization_service.dart';
import 'package:kobold_character_card_manager/services/llm_provider.dart';
import 'package:kobold_character_card_manager/services/open_router_service.dart';
import 'package:kobold_character_card_manager/ui/widgets/log_view.dart';
import 'package:kobold_character_card_manager/ui/dialogs/rocm_guidance_dialog.dart';
import 'package:kobold_character_card_manager/providers/app_state.dart';
import 'package:kobold_character_card_manager/services/update_service.dart';

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

    // Refresh hardware info on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hardwareService = Provider.of<HardwareService>(context, listen: false);
      hardwareService.detectHardware().then((_) {
         if (!mounted) return;
         final hw = hardwareService.hardwareInfo;
         final storage = Provider.of<StorageService>(context, listen: false);

         bool changed = false;

         // NVIDIA Logic: Default to CuBLAS if not set
         if (hw?.vendor == 'Nvidia') {
            if (storage.useCublas == null) {
               storage.setUseCublas(true);
               storage.setUseVulkan(false); // Disable Vulkan preference if auto-setting Cublas
               _useCublas = true;
               _useVulkan = false;
               changed = true;
            } else {
               // Restore persistence
               _useCublas = storage.useCublas!;
               // If useVulkan is also set, respect it, otherwise ensure it's off if Cublas is on
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
               // Ensure Cublas/Metal is off
               storage.setUseCublas(false);
               storage.setUseMetal(false);
               _useVulkan = true;
               _useCublas = false; 
               _useMetal = false;
               changed = true;
            } else {
               // Restore persistence
               _useVulkan = storage.useVulkan!;
               if (storage.useCublas != null) _useCublas = storage.useCublas!;
               if (storage.useMetal != null) _useMetal = storage.useMetal!;
            }
         }

         if (changed) {
            setState(() {});
             final String msg;
             if (hw?.vendor == 'Nvidia') {
               msg = 'NVIDIA GPU detected: CuBLAS enabled.';
             } else if (Platform.isMacOS) {
               msg = 'Apple Silicon detected: Metal enabled.';
             } else if (hw?.vendor == 'AMD' && Platform.isLinux && hw?.hasRocm == false) {
               msg = 'AMD GPU detected: Vulkan enabled. Install ROCm for better performance.';
               // Show ROCm guidance dialog
               showRocmGuidanceDialog(context, hw!.linuxDistro);
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
      });
    });
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
}
