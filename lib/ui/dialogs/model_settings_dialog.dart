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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/backend_manager.dart';
import 'package:front_porch_ai/services/model_manager.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/hardware_service.dart';
import 'package:front_porch_ai/services/optimization_service.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/services/open_router_service.dart';

class ModelSettingsDialog extends StatefulWidget {
  const ModelSettingsDialog({super.key});

  @override
  State<ModelSettingsDialog> createState() => _ModelSettingsDialogState();
}

class _ModelSettingsDialogState extends State<ModelSettingsDialog> {
  // Local backend fields
  final _gpuLayersController = TextEditingController(text: '0');
  final _contextSizeController = TextEditingController(text: '8192');
  bool _useVulkan = false;
  bool _useCublas = false;
  bool _useMetal = false;
  bool _useRocm = false;
  String? _selectedModelPath;

  // Remote API fields
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();
  String? _connectionStatus;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final storage = Provider.of<StorageService>(context, listen: false);
    // Local settings
    _useCublas = storage.useCublas == true;
    _useVulkan = storage.useVulkan == true;
    _useMetal = storage.useMetal == true;
    _useRocm = storage.useRocm == true;
    _selectedModelPath = storage.lastUsedModelPath;
    _gpuLayersController.text = storage.gpuLayers.toString();
    _contextSizeController.text = storage.contextSize.toString();
    // Remote settings
    _apiUrlController.text = storage.remoteApiUrl;
    _apiKeyController.text = storage.remoteApiKey;
    _modelNameController.text = storage.remoteModelName;
  }

  @override
  void dispose() {
    _gpuLayersController.dispose();
    _contextSizeController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _modelNameController.dispose();
    super.dispose();
  }

  void _applyAutoConfiguration() {
    final hardware = Provider.of<HardwareService>(context, listen: false).hardwareInfo;
    if (hardware == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hardware not detected yet.')));
      return;
    }

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
        _useRocm = false;
      } else if (hardware.vendor == 'Nvidia') {
        _useCublas = true;
        _useVulkan = false;
        _useMetal = false;
        _useRocm = false;
      } else if (hardware.vendor == 'AMD' && Platform.isLinux && hardware.hasRocm) {
        _useRocm = true;
        _useVulkan = false;
        _useCublas = false;
        _useMetal = false;
      } else {
        _useVulkan = suggestion.useVulkan;
        _useCublas = false;
        _useMetal = false;
        _useRocm = false;
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

    final storage = Provider.of<StorageService>(context, listen: false);
    storage.setLastUsedModelPath(_selectedModelPath);
    storage.setGpuLayers(int.tryParse(_gpuLayersController.text) ?? 0);
    storage.setContextSize(int.tryParse(_contextSizeController.text) ?? 8192);
    storage.setUseCublas(_useCublas);
    storage.setUseVulkan(_useVulkan);
    storage.setUseMetal(_useMetal);
    storage.setUseRocm(_useRocm);

    koboldService.stopKobold();
    
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
        useRocm: _useRocm,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restarting backend with new settings...')));
    });
  }

  void _saveRemoteSettings() {
    final storage = Provider.of<StorageService>(context, listen: false);
    storage.setRemoteApiUrl(_apiUrlController.text.trim());
    storage.setRemoteApiKey(_apiKeyController.text.trim());
    storage.setRemoteModelName(_modelNameController.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API settings saved.')),
    );
  }

  Future<void> _testConnection() async {
    setState(() { _isTesting = true; _connectionStatus = null; });
    _saveRemoteSettings();
    final openRouter = Provider.of<OpenRouterService>(context, listen: false);
    // Ensure the service has the latest config
    openRouter.configure(
      apiUrl: _apiUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      modelName: _modelNameController.text.trim(),
    );
    final result = await openRouter.testConnection();
    if (mounted) {
      setState(() { _isTesting = false; _connectionStatus = result; });
    }
  }

  Future<void> _showModelPicker() async {
    // Ensure the service has the latest config before fetching
    final openRouter = Provider.of<OpenRouterService>(context, listen: false);
    openRouter.configure(
      apiUrl: _apiUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      modelName: _modelNameController.text.trim(),
    );

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<RemoteModelInfo> models;
    try {
      models = await openRouter.fetchAvailableModels();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch models: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No models available. Check your API URL and key.')),
      );
      return;
    }

    // Show the model picker dialog
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = searchQuery.isEmpty
                ? models
                : models.where((m) => m.id.toLowerCase().contains(searchQuery.toLowerCase())).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Model', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search models...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF374151),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (val) => setDialogState(() => searchQuery = val),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                height: 400,
                child: filtered.isEmpty
                    ? Center(child: Text('No models match "$searchQuery"', style: const TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final model = filtered[index];
                          final isSelected = model.id == _modelNameController.text;
                          return ListTile(
                            dense: true,
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
                                      color: Colors.green.withValues(alpha: 0.2),
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
                            onTap: () => Navigator.pop(ctx, model.id),
                          );
                        },
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

    if (selected != null && mounted) {
      setState(() {
        _modelNameController.text = selected;
      });
      _saveRemoteSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final llmProvider = Provider.of<LLMProvider>(context);
    final isLocal = llmProvider.isLocal;

    return Dialog(
       backgroundColor: const Color(0xFF1F2937),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       child: Container(
         width: 500,
         constraints: const BoxConstraints(maxHeight: 600),
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

             // Backend toggle
             Container(
               decoration: BoxDecoration(
                 color: const Color(0xFF374151),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Row(
                 children: [
                   Expanded(
                     child: _buildToggleButton(
                       label: 'Local',
                       icon: Icons.computer,
                       isSelected: isLocal,
                       onTap: () => llmProvider.setActiveBackend(BackendType.kobold),
                     ),
                   ),
                   Expanded(
                     child: _buildToggleButton(
                       label: 'Remote API',
                       icon: Icons.cloud,
                       isSelected: !isLocal,
                       onTap: () => llmProvider.setActiveBackend(BackendType.openRouter),
                     ),
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 16),

             // Content area
             Flexible(
               child: SingleChildScrollView(
                 child: isLocal ? _buildLocalSettings() : _buildRemoteSettings(),
               ),
             ),
           ],
         ),
       ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalSettings() {
    final modelManager = Provider.of<ModelManager>(context);
    final hardwareService = Provider.of<HardwareService>(context);
    final koboldService = Provider.of<KoboldService>(context);

    if (_selectedModelPath == null && modelManager.models.isNotEmpty) {
      _selectedModelPath = modelManager.models.first.path;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  setState(() { _selectedModelPath = val; });
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
                    _buildInfoRow('VRAM', '${hardwareService.hardwareInfo!.vramMb} MB${hardwareService.hardwareInfo!.isSharedMemory ? ' (Shared)' : ''}'),
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
                  if (val) { _useCublas = false; _useRocm = false; _useMetal = false; }
                });
              },
            ),
            Tooltip(
              message: Provider.of<HardwareService>(context, listen: false).hardwareInfo?.hasRocm == true ? 'Use ROCm for native AMD GPU acceleration' : 'Requires ROCm installation (AMD GPU)',
              child: FilterChip(
                label: const Text('Use ROCm (AMD)'),
                selected: _useRocm,
                onSelected: Provider.of<HardwareService>(context, listen: false).hardwareInfo?.hasRocm == true
                  ? (val) {
                      setState(() {
                        _useRocm = val;
                        if (val) { _useVulkan = false; _useCublas = false; _useMetal = false; }
                      });
                    }
                  : null,
                avatar: Provider.of<HardwareService>(context, listen: false).hardwareInfo?.hasRocm == true
                  ? null
                  : const Icon(Icons.block, size: 16),
              ),
            ),
            Tooltip(
              message: Provider.of<HardwareService>(context, listen: false).hardwareInfo?.vendor == 'Nvidia' ? 'Use CUDA (NVIDIA only)' : 'Requires NVIDIA GPU',
              child: FilterChip(
                label: const Text('Use CuBLAS'),
                selected: _useCublas,
                onSelected: Provider.of<HardwareService>(context, listen: false).hardwareInfo?.vendor == 'Nvidia' 
                  ? (val) {
                      setState(() {
                        _useCublas = val;
                        if (val) { _useVulkan = false; _useRocm = false; _useMetal = false; }
                      });
                    }
                  : null, 
                avatar: Provider.of<HardwareService>(context, listen: false).hardwareInfo?.vendor == 'Nvidia' 
                  ? null 
                  : const Icon(Icons.block, size: 16),
              ),
            ),
            Tooltip(
              message: Provider.of<HardwareService>(context, listen: false).hardwareInfo?.hasMetal == true ? 'Use Metal (Apple Silicon/Mac)' : 'Requires MacOS with Metal support',
              child: FilterChip(
                label: const Text('Use Metal'),
                selected: _useMetal,
                onSelected: Provider.of<HardwareService>(context, listen: false).hardwareInfo?.hasMetal == true 
                  ? (val) {
                      setState(() {
                        _useMetal = val;
                        if (val) { _useVulkan = false; _useCublas = false; _useRocm = false; }
                      });
                    }
                  : null, 
                avatar: Provider.of<HardwareService>(context, listen: false).hardwareInfo?.hasMetal == true 
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
    );
  }

  Widget _buildRemoteSettings() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(label: 'API URL', controller: _apiUrlController),
        const SizedBox(height: 12),
        _buildTextField(label: 'API Key', controller: _apiKeyController, isObscured: true),
        const SizedBox(height: 12),
        // Model selector — tappable chip that opens a model picker dialog
        InkWell(
          onTap: () => _showModelPicker(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Model',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _modelNameController.text.isEmpty ? 'Tap to select a model...' : _modelNameController.text,
                        style: TextStyle(
                          color: _modelNameController.text.isEmpty ? Colors.white38 : Colors.white,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white54),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Connection status
        if (_connectionStatus != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _connectionStatus!.contains('successful')
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _connectionStatus!.contains('successful')
                    ? Colors.greenAccent.withValues(alpha: 0.3)
                    : Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _connectionStatus!,
              style: TextStyle(
                color: _connectionStatus!.contains('successful') ? Colors.greenAccent : Colors.redAccent,
                fontSize: 13,
              ),
            ),
          ),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.wifi_tethering),
                label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saveRemoteSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(color: Colors.white10),
        const SizedBox(height: 8),

        // Reasoning toggle
        Builder(builder: (context) {
          final storage = Provider.of<StorageService>(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, size: 18, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  const Text('Request Reasoning', style: TextStyle(color: Colors.white)),
                  const Spacer(),
                  Switch(
                    value: storage.reasoningEnabled,
                    onChanged: (val) => storage.setReasoningEnabled(val),
                    activeTrackColor: Colors.blueAccent,
                  ),
                ],
              ),
              if (storage.reasoningEnabled)
                Padding(
                  padding: const EdgeInsets.only(left: 26, bottom: 4),
                  child: Row(
                    children: [
                      const Text('Effort', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: storage.reasoningEffort,
                            isDense: true,
                            dropdownColor: const Color(0xFF374151),
                            style: const TextStyle(color: Colors.white),
                            items: const [
                              DropdownMenuItem(value: 'low', child: Text('Low')),
                              DropdownMenuItem(value: 'medium', child: Text('Medium')),
                              DropdownMenuItem(value: 'high', child: Text('High')),
                            ],
                            onChanged: (val) {
                              if (val != null) storage.setReasoningEffort(val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!storage.reasoningEnabled)
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(
                    'Request thinking output from compatible models',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isNumber = false,
    bool isObscured = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      obscureText: isObscured,
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
