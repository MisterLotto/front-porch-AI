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
import 'package:path/path.dart' as path_lib;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Barrel imports
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

// Not in barrels (internal or low-frequency)
import 'package:front_porch_ai/services/model_file_check.dart';
import 'package:front_porch_ai/services/optimization_service.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

// The local-backend actions/settings, remote-settings, and model-picker
// builders live in these `part of` files (extensions on
// _ModelSettingsDialogState) to keep every file under the 500-LOC cap — same
// pattern settings_page.dart uses. They share this library's imports and
// access the dialog's private state directly, so behavior is unchanged.
part 'model_settings_dialog.local_actions.dart';
part 'model_settings_dialog.remote.dart';
part 'model_settings_dialog.picker.dart';
part 'model_settings_dialog.local.dart';

/// Fixed oMLX localhost endpoint, shared by the "Test Connection" probe
/// (model_settings_dialog.remote.dart) and the model picker's fetch
/// (model_settings_dialog.picker.dart) — both force this URL when the oMLX
/// backend is active instead of whatever is in the API URL field.
const _omlxLocalhostUrl = 'http://localhost:8000/v1';

class ModelSettingsDialog extends StatefulWidget {
  const ModelSettingsDialog({super.key});

  @override
  State<ModelSettingsDialog> createState() => _ModelSettingsDialogState();
}

class _ModelSettingsDialogState extends State<ModelSettingsDialog> {
  // Local backend fields
  final _gpuLayersController = TextEditingController(text: '0');
  final _contextSizeController = TextEditingController(text: '');
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

  // Preset fields
  List<File> _localPresets = [];

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scanLocalPresets();
    });
  }

  void _scanLocalPresets() {
    final storage = Provider.of<StorageService>(context, listen: false);
    setState(() {
      _localPresets = scanKcppsPresets(storage.binDir);
    });
  }

  /// Check whether a .kcpps preset is currently active.
  bool _isPresetActive(BuildContext ctx) {
    final storage = Provider.of<StorageService>(ctx, listen: false);
    return storage.activeKcppsPath != null &&
        storage.activeKcppsPath!.isNotEmpty;
  }

  /// Re-exposes the protected [setState] for the `part of` extensions
  /// (`model_settings_dialog.*.dart`), which hold the local-backend actions,
  /// remote settings, and model picker but can't call a State's protected
  /// members directly.
  void rebuildState(VoidCallback fn) => setState(fn);

  @override
  void dispose() {
    _gpuLayersController.dispose();
    _contextSizeController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _modelNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final llmProvider = Provider.of<LLMProvider>(context);
    final backend = llmProvider.activeBackend;

    return Dialog(
      backgroundColor: AppColors.surfaceOf(context),
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
                Text(
                  'Model Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textSecondary(context),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Backend toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerOf(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      label: 'Local',
                      icon: Icons.computer,
                      isSelected: backend == BackendType.kobold,
                      onTap: () =>
                          llmProvider.setActiveBackend(BackendType.kobold),
                    ),
                  ),
                  Expanded(
                    child: _buildToggleButton(
                      label: 'Remote API',
                      icon: Icons.cloud,
                      isSelected: backend == BackendType.openRouter,
                      onTap: () =>
                          llmProvider.setActiveBackend(BackendType.openRouter),
                    ),
                  ),
                  if (Platform.isMacOS)
                    Expanded(
                      child: _buildToggleButton(
                        label: 'oMLX',
                        icon: Icons.apple,
                        isSelected: backend == BackendType.omlx,
                        onTap: () =>
                            llmProvider.setActiveBackend(BackendType.omlx),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content area
            Flexible(
              child: SingleChildScrollView(
                child: backend == BackendType.kobold
                    ? _buildLocalSettings()
                    : _buildRemoteSettings(isOmLx: backend == BackendType.omlx),
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
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.formMasterAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? AppColors.onChaosAccent
                  : AppColors.textSecondary(context),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.onChaosAccent
                    : AppColors.textSecondary(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
      style: TextStyle(color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary(context)),
        filled: true,
        fillColor: AppColors.surfaceContainerOf(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
