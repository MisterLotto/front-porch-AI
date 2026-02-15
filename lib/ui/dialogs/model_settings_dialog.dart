import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/services/kobold_service.dart';
import 'package:kobold_character_card_manager/services/backend_manager.dart';
import 'package:kobold_character_card_manager/services/model_manager.dart';
import 'package:kobold_character_card_manager/services/storage_service.dart';
import 'package:kobold_character_card_manager/services/hardware_service.dart';
import 'package:kobold_character_card_manager/services/optimization_service.dart';

class ModelSettingsDialog extends StatefulWidget {
  const ModelSettingsDialog({super.key});

  @override
  State<ModelSettingsDialog> createState() => _ModelSettingsDialogState();
}

class _ModelSettingsDialogState extends State<ModelSettingsDialog> {
  final _gpuLayersController = TextEditingController(text: '0');
  final _contextSizeController = TextEditingController(text: '8192');
  bool _useVulkan = false;
  bool _useCublas = false;
  bool _useMetal = false;
  String? _selectedModelPath;

  @override
  void initState() {
    super.initState();
    final storage = Provider.of<StorageService>(context, listen: false);
    _useCublas = storage.useCublas == true;
    _useVulkan = storage.useVulkan == true;
    _useMetal = storage.useMetal == true;
    _selectedModelPath = storage.lastUsedModelPath;
    
    // Attempt to load current settings if running, or defaults
    // In a real scenario, we might want to query the running service for its config if possible, 
    // but for now we rely on user input/defaults.
  }

  @override
  void dispose() {
    _gpuLayersController.dispose();
    _contextSizeController.dispose();
    super.dispose();
  }

  void _applyAutoConfiguration() {
    final hardware = Provider.of<HardwareService>(context, listen: false).hardwareInfo;
    if (hardware == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hardware not detected yet.')));
      return;
    }

    // Estimate model size
    int modelSize = 5000;
    if (_selectedModelPath != null) {
      try {
        final file = File(_selectedModelPath!);
        if (file.existsSync()) {
          modelSize = (file.lengthSync() / (1024 * 1024)).round();
        }
      } catch (e) {
        // ignore
      }
    }

    final suggestion = OptimizationService.calculateSettings(hardware, modelSizeMb: modelSize);

    setState(() {
      _gpuLayersController.text = suggestion.gpuLayers.toString();
      _contextSizeController.text = suggestion.contextSize.toString();
      
      if (Platform.isMacOS) {
        _useMetal = true;
        _useVulkan = false;
        _useCublas = false;
      } else if (hardware.vendor == 'Nvidia') {
        _useCublas = true;
        _useVulkan = false;
        _useMetal = false;
      } else {
        _useVulkan = suggestion.useVulkan;
        _useCublas = false;
        _useMetal = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(suggestion.reasoning)));
  }

  void _restartBackend() {
    final koboldService = Provider.of<KoboldService>(context, listen: false);
    final backendManager = Provider.of<BackendManager>(context, listen: false);

    if (backendManager.backendPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backend not found.')));
      return;
    }
    if (_selectedModelPath == null || !File(_selectedModelPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valid model not selected.')));
      return;
    }

    koboldService.stopKobold();
    
    // Give it a moment to stop before restarting (optional, but safer)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      koboldService.startKobold(
        backendManager.backendPath!,
        _selectedModelPath!,
        gpuLayers: int.tryParse(_gpuLayersController.text) ?? 0,
        contextSize: int.tryParse(_contextSizeController.text) ?? 4096,
        useVulkan: _useVulkan,
        useCublas: _useCublas,
        useMetal: _useMetal,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restarting backend with new settings...')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final modelManager = Provider.of<ModelManager>(context);
    final hardwareService = Provider.of<HardwareService>(context);
    final koboldService = Provider.of<KoboldService>(context);

    // Auto-select if needed
    if (_selectedModelPath == null && modelManager.models.isNotEmpty) {
      _selectedModelPath = modelManager.models.first.path;
    }

    return Dialog(
       backgroundColor: const Color(0xFF1F2937),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       child: Container(
         width: 500,
         padding: const EdgeInsets.all(24),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text('Model Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                 IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
               ],
             ),
             const SizedBox(height: 16),
             
             // Model Selector
             if (modelManager.models.isEmpty)
                const Text('No models found.', style: TextStyle(color: Colors.orange))
             else
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12),
                 decoration: BoxDecoration(
                   color: const Color(0xFF374151),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: DropdownButtonHideUnderline(
                   child: DropdownButton<String>(
                     value: _selectedModelPath,
                     isExpanded: true,
                     dropdownColor: const Color(0xFF374151),
                     style: const TextStyle(color: Colors.white),
                     icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
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
                       _applyAutoConfiguration();
                     },
                   ),
                 ),
               ),
              
              const SizedBox(height: 16),
              
              // Hardware Info
              Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: const Color(0xFF374151),
                   borderRadius: BorderRadius.circular(8),
                 ),
                child: hardwareService.isDetecting
                  ? const Center(child: CircularProgressIndicator())
                  : hardwareService.hardwareInfo == null
                    ? const Text('Hardware not detected.', style: TextStyle(color: Colors.redAccent))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('GPU', hardwareService.hardwareInfo!.gpuName),
                          _buildInfoRow('VRAM', '${hardwareService.hardwareInfo!.vramMb} MB'),
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
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      label: 'Context Size',
                      controller: _contextSizeController,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   TextButton.icon(
                     onPressed: _applyAutoConfiguration,
                     icon: const Icon(Icons.auto_fix_high, color: Colors.amber),
                     label: const Text('Auto-Configure', style: TextStyle(color: Colors.amber)),
                   ),
                 ],
               ),
              const SizedBox(height: 8),
              
               Row(
                children: [
                   FilterChip(
                    label: const Text('Use Vulkan'),
                    selected: _useVulkan,
                    onSelected: (val) {
                       setState(() {
                         _useVulkan = val;
                         if (val) {
                           _useCublas = false; 
                           _useMetal = false;
                         }
                       });
                    },
                  ),
                  const SizedBox(width: 8),
                   Tooltip(
                    message: hardwareService.hardwareInfo?.vendor == 'Nvidia' ? 'Use CUDA (NVIDIA only)' : 'Requires NVIDIA GPU',
                    child: FilterChip(
                     label: const Text('Use CuBLAS'),
                     selected: _useCublas,
                     onSelected: hardwareService.hardwareInfo?.vendor == 'Nvidia' 
                       ? (val) {
                           setState(() {
                             _useCublas = val;
                             if (val) {
                               _useVulkan = false;
                               _useMetal = false;
                             }
                           });
                         }
                       : null, 
                     avatar: hardwareService.hardwareInfo?.vendor == 'Nvidia' 
                       ? null 
                       : const Icon(Icons.block, size: 16),
                    ),
                   ),
                   const SizedBox(width: 8),
                   Tooltip(
                    message: hardwareService.hardwareInfo?.hasMetal == true ? 'Use Metal (Apple Silicon/Mac)' : 'Requires MacOS with Metal support',
                    child: FilterChip(
                     label: const Text('Use Metal'),
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
                         }
                       : null, 
                     avatar: hardwareService.hardwareInfo?.hasMetal == true 
                       ? null 
                       : const Icon(Icons.block, size: 16),
                    ),
                   ),
                ],
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _restartBackend,
                  icon: const Icon(Icons.refresh),
                  label: Text(koboldService.isRunning ? 'Restart Backend' : 'Start Backend'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
           ],
         ),
       ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
