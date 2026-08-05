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

part of 'generation_options_tab.dart';

/// Backend chip row + the remote-backend panel for [_GenerationOptionsTabState],
/// split out of the shell to keep every file under the 500-LOC cap (mirrors the
/// settings_page.dart `part of` pattern). These methods keep direct access to
/// the tab's private state, so behavior is identical to when they lived
/// inline. AppColors exclusive.
extension _GenerationOptionsSource on _GenerationOptionsTabState {
  Widget _buildBackendSelector(StorageService st) {
    final bs = ImageGenBackend.values;
    final ac = AppColors.formMasterAccent;
    return Row(
      children: bs.map((b) {
        final sel = st.imageGenBackend == b.key;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: b == bs.last ? 0 : 8),
            child: GestureDetector(
              onTap: () {
                st.setImageGenBackend(b.key);
                rebuildState(() {
                  _connectionOk = null;
                  _localModels = [];
                  _localLoras = [];
                  _localSamplers = [];
                  _localSchedulers = [];
                });
                // Auto-test the newly selected local backend (the status card
                // reflects progress; success populates models/LoRAs/samplers).
                if (b != ImageGenBackend.remote) _testConnection();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.cardOf(context)
                      : AppColors.surfaceContainerOf(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel ? ac : AppColors.borderOf(context),
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      b == ImageGenBackend.remote
                          ? Icons.cloud_outlined
                          : b == ImageGenBackend.drawThings
                          ? Icons.apple
                          : b == ImageGenBackend.comfyUi
                          ? Icons.account_tree_outlined
                          : Icons.computer_outlined,
                      size: 16,
                      color: sel ? ac : AppColors.iconSecondary(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: sel ? ac : AppColors.textTertiary(context),
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRemotePanel(StorageService st) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Image Model',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ModelSlotDropdown(
                settings: st.imageGenSettings,
                editSlot: widget.editScoped,
                keyPrefix: 'remote-model',
                fontSize: 12,
                decoration: _deco(
                  hint: _loadingModels
                      ? 'Loading...'
                      : (_models.isEmpty ? 'No models' : 'Select'),
                ),
                options: [
                  for (final m in _models) (value: m.id, label: m.displayName),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: _loadingModels
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.formMasterAccent,
                      ),
                    )
                  : Icon(
                      Icons.refresh,
                      color: AppColors.iconSecondary(context),
                      size: 18,
                    ),
              onPressed: _loadingModels ? null : _fetchModels,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSharedFields(st),
      ],
    );
  }
}
