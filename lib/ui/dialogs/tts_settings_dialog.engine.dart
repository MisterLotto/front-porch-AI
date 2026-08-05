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

part of 'tts_settings_dialog.dart';

/// TTS engine selector — the segmented control (Kokoro/OpenAI/ElevenLabs/
/// Piper) shown at the top of [TtsSettingsDialog]. Extracted verbatim from
/// the dialog's inline builders during the god-file split (was over the
/// 500-line cap); direct state access via the extension preserves behavior.
extension _TtsEngineSection on _TtsSettingsDialogState {
  /// Engine selector — segmented control style.
  Widget _buildEngineSelector(StorageService storage) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerOf(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _engineTab(storage, 'kokoro', '🔊 Kokoro', 'Local'),
          _engineTab(storage, 'openai', '☁️ OpenAI', 'Cloud API'),
          _engineTab(storage, 'elevenlabs', '🎙 ElevenLabs', 'Premium'),
          _engineTab(storage, 'piper', '📦 Piper', 'Lightweight'),
        ],
      ),
    );
  }

  Widget _engineTab(
    StorageService storage,
    String id,
    String label,
    String subtitle,
  ) {
    final selected = storage.ttsEngine == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          storage.setTtsEngine(id);
          // Clear voice model when switching engines
          storage.setTtsVoiceModel('');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.formMasterAccent.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: AppColors.formMasterAccent, width: 1)
                : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.formMasterAccent
                      : AppColors.textSecondary(context),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  // Slightly brighter when selected, matching the original
                  // white38-vs-white24 hierarchy but on the AppColors scale.
                  color: selected
                      ? AppColors.textSecondary(context)
                      : AppColors.textTertiary(context),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
