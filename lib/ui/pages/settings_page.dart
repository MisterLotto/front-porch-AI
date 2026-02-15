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
import 'package:kobold_character_card_manager/ui/widgets/log_view.dart';
import 'package:kobold_character_card_manager/providers/app_state.dart';

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
          _buildSectionHeader('Model Instructions', context),
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
            _buildSlider('Context Size', _contextSizeValue, 4098, 15000, (val) {
              setState(() {
                _contextSizeValue = val;
                _contextSizeController.text = val.toInt().toString();
              });
            }, context, divisions: 15000 - 4098),
           
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
}
