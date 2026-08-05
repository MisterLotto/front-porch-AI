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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/dialogs/tts_settings_dialog.dart';
import 'package:front_porch_ai/ui/settings/widgets/widgets.dart';

part 'voice_media_tab.tts.dart';
part 'voice_media_tab.stt.dart';
part 'voice_media_tab.voice_call.dart';
part 'voice_media_tab.expressions.dart';

/// Voice & Media tab extracted from settings_page god file (Stage 5).
/// Pure lift of _buildVoiceMediaTab + voice-specific helpers + onnx button.
/// Shared local state (drag buffer, available models) passed via constructor
/// to keep owning state in _SettingsPageState (per plan). AppColors used
/// exclusively for all colors/surfaces/text/icons (no new hard-coded
/// Color(0xFF...) or raw Colors.whiteXX/Colors.blackXX). Follows patterns
/// from prior extractions (const, composition, no build side effects).
///
/// God-file split (this tab alone was 1,273 lines): the shell above stays
/// here; the four section builders — Text-to-Speech, Voice Input (STT),
/// the Voice Call sub-block, and Expression Images — live in the `part`
/// files above as extensions on this same StatelessWidget so they can share
/// its fields (dragCallBuffer/onDragCallBufferChanged/availableModels)
/// without re-plumbing. No setState lives in this file (StatelessWidget),
/// so unlike the settings_page shell there is no rebuildState bridge.
class VoiceMediaTab extends StatelessWidget {
  const VoiceMediaTab({
    super.key,
    this.dragCallBuffer,
    required this.onDragCallBufferChanged,
    required this.availableModels,
  });

  final double? dragCallBuffer;
  final void Function(double?) onDragCallBufferChanged;
  final List<RemoteModelInfo>
  availableModels; // typed for shared state from shell (smallest fix for loose/edge)

  @override
  Widget build(BuildContext context) {
    final storageService = Provider.of<StorageService>(context);
    final modelManager = Provider.of<ModelManager>(context);
    final llmProvider = Provider.of<LLMProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTtsSection(context, storageService),
          _buildSttSection(context, storageService, modelManager, llmProvider),

          // Self-hiding: renders nothing (header included) until the offline
          // vision helper is installed — the feature is offered only in chat.
          const PhotoUnderstandingCard(),

          _buildExpressionSection(context),

          const SizedBox(height: 24),
          const ImageGenEnableSection(),
          // Appears only while old-engine model files still sit on disk.
          const LegacyCleanupCard(),
        ],
      ),
    );
  }
}
