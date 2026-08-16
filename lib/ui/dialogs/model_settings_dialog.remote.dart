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

part of 'model_settings_dialog.dart';

/// Remote-API (OpenRouter / oMLX) settings: save, connection test, and the
/// content builder. Split out of `model_settings_dialog.dart` — verbatim
/// except `setState` -> `rebuildState` (extensions can't call a State's
/// protected members).
extension _ModelSettingsRemoteSection on _ModelSettingsDialogState {
  void _saveRemoteSettings() {
    final storage = Provider.of<StorageService>(context, listen: false);
    final llmProvider = Provider.of<LLMProvider>(context, listen: false);
    // Never overwrite the user's remote API URL when oMLX is active (it uses a fixed localhost URL)
    if (llmProvider.activeBackend != BackendType.omlx) {
      storage.setRemoteApiUrl(_apiUrlController.text.trim());
    }
    storage.setRemoteApiKey(_apiKeyController.text.trim());
    storage.setRemoteModelName(_modelNameController.text.trim());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API settings saved.')));
  }

  Future<void> _testConnection() async {
    rebuildState(() {
      _isTesting = true;
      _connectionStatus = null;
    });
    _saveRemoteSettings();
    final openRouter = Provider.of<OpenRouterService>(context, listen: false);
    final llmProvider = Provider.of<LLMProvider>(context, listen: false);
    // Force oMLX localhost URL when oMLX backend is active (ignores whatever is in the URL field)
    final apiUrl = llmProvider.activeBackend == BackendType.omlx
        ? _omlxLocalhostUrl
        : _apiUrlController.text.trim();
    // Override form — NEVER configure() the live service just to probe
    // (that silently re-routes active chat traffic; see the service's own
    // fetchAvailableModels doc note).
    final result = await openRouter.testConnection(
      apiUrl: apiUrl,
      apiKey: _apiKeyController.text.trim(),
    );
    if (mounted) {
      rebuildState(() {
        _isTesting = false;
        _connectionStatus = result;
      });
    }
  }

  Widget _buildRemoteSettings({bool isOmLx = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOmLx) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.formMasterAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.formMasterAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.apple,
                  color: AppColors.formMasterAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'oMLX mode on Apple Silicon. URL fixed to http://localhost:8000/v1. oMLX must be running (`omlx serve`). Model name below is used for generation.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.formMasterAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!isOmLx)
          _buildTextField(label: 'API URL', controller: _apiUrlController),
        if (!isOmLx) const SizedBox(height: 12),
        if (!isOmLx)
          _buildTextField(
            label: 'API Key',
            controller: _apiKeyController,
            isObscured: true,
          ),
        if (!isOmLx) const SizedBox(height: 12),
        // Model selector — tappable chip that opens a model picker dialog
        InkWell(
          onTap: () => _showModelPicker(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerOf(context),
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
                        style: TextStyle(
                          color: AppColors.textTertiary(context),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _modelNameController.text.isEmpty
                            ? 'Tap to select a model...'
                            : _modelNameController.text,
                        style: TextStyle(
                          color: _modelNameController.text.isEmpty
                              ? AppColors.textTertiary(context)
                              : AppColors.textPrimary(context),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.iconSecondary(context),
                ),
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
              // theme-keep: success/failure status semantics (green/red), not chrome
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
                color: _connectionStatus!.contains('successful')
                    ? Colors.greenAccent
                    : Colors.redAccent,
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
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onChaosAccent,
                        ),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.formMasterAccent,
                  foregroundColor: AppColors.onChaosAccent,
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
                  foregroundColor: AppColors.textSecondary(context),
                  side: BorderSide(color: AppColors.borderOf(context)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
