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

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/image_gen_service.dart';
import 'package:front_porch_ai/services/image_prompt/image_gen_context.dart';
import 'package:front_porch_ai/services/image_prompt/image_prompt_builder.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

import 'prompt_workspace.dart';
import 'reference_image_picker.dart';
import 'generation_panel.dart';
import 'result_view.dart';
import 'generation_history.dart';
import 'mode_info_card.dart';
import 'style_preview.dart';
import 'studio_helpers.dart';
import 'subject_picker.dart';
import 'settings_panel.dart';

/// Presentational shell for the Image Studio: the dialog frame, header, subject
/// picker, style/reference/prompt canvas, generate/result/history, and the
/// collapsible settings panel. All state + handlers live in the `ImageStudio`
/// coordinator; this widget is pure layout driven by the passed values and
/// callbacks (extracted to keep the coordinator under the 500-line cap).
class StudioView extends StatelessWidget {
  const StudioView({
    super.key,
    required this.activeMode,
    required this.characterName,
    required this.selectedStyle,
    required this.paradigm,
    required this.prompt,
    required this.negative,
    required this.referenceBytes,
    required this.currentImageBytes,
    required this.error,
    required this.isCrafting,
    required this.isGenerating,
    required this.saving,
    required this.isBusy,
    required this.llmAvailable,
    required this.configured,
    required this.builder,
    required this.ctx,
    required this.history,
    required this.onClose,
    required this.onSelectSubject,
    required this.onStyleChanged,
    required this.onParadigmChanged,
    required this.onPickReference,
    required this.onClearReference,
    required this.onPromptChanged,
    required this.onNegativeChanged,
    required this.onCraftLlm,
    required this.onGenerate,
    required this.onSave,
    required this.onAccept,
    required this.onVariations,
    required this.onEditRegen,
    required this.onSendToChat,
    required this.onRestore,
  });

  final ImageGenMode activeMode;
  final String? characterName;
  final String selectedStyle;
  final String paradigm;
  final String prompt;
  final String negative;
  final Uint8List? referenceBytes;
  final Uint8List? currentImageBytes;
  final String error;
  final bool isCrafting;
  final bool isGenerating;
  final bool saving;
  final bool isBusy;
  final bool llmAvailable;
  final bool configured;
  final ImagePromptBuilder builder;
  final ImageGenContext ctx;
  final List<({String prompt, Uint8List bytes, String style})> history;

  final VoidCallback onClose;
  final ValueChanged<ImageGenMode> onSelectSubject;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<String> onParadigmChanged;
  final VoidCallback onPickReference;
  final VoidCallback onClearReference;
  final ValueChanged<String> onPromptChanged;
  final ValueChanged<String> onNegativeChanged;
  final VoidCallback onCraftLlm;
  final VoidCallback onGenerate;
  final VoidCallback onSave;
  final VoidCallback onAccept;
  final VoidCallback onVariations;
  final VoidCallback onEditRegen;
  final VoidCallback? onSendToChat;
  final ValueChanged<({String prompt, Uint8List bytes, String style})> onRestore;

  @override
  Widget build(BuildContext context) {
    final view = currentImageBytes != null && error.isEmpty
        ? 'result'
        : (isCrafting || isGenerating)
        ? 'generating'
        : 'workspace';

    return Dialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubjectPicker(
                      selected: activeMode,
                      characterName: characterName,
                      onChanged: isBusy ? null : onSelectSubject,
                    ),
                    const SizedBox(height: 12),
                    ModeInfoCard(mode: activeMode),
                    const SizedBox(height: 12),
                    // Generation Settings live above the style box so they're
                    // visible without scrolling; the fold-out stays collapsible.
                    StudioSettingsPanel(initiallyExpanded: !configured),
                    const SizedBox(height: 12),
                    StylePreview(
                      selectedStyle: selectedStyle,
                      paradigm: paradigm,
                      builder: builder,
                      onStyleChanged: isBusy ? null : onStyleChanged,
                      onParadigmChanged: isBusy ? null : onParadigmChanged,
                    ),
                    const SizedBox(height: 12),
                    ReferenceImagePicker(
                      referenceBytes: referenceBytes,
                      isBusy: isBusy,
                      onPick: onPickReference,
                      onClear: onClearReference,
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: view == 'workspace'
                          ? PromptWorkspace(
                              key: const ValueKey('workspace'),
                              prompt: prompt,
                              negative: negative,
                              ctx: ctx,
                              builder: builder,
                              paradigm: paradigm,
                              llmAvailable: llmAvailable,
                              isBusy: isBusy,
                              onPromptChanged: onPromptChanged,
                              onNegativeChanged: onNegativeChanged,
                              onCraftLlm: onCraftLlm,
                            )
                          : const SizedBox.shrink(),
                    ),
                    GenerationPanel(
                      onGenerate: isBusy ? null : onGenerate,
                      isGenerating: isGenerating,
                      isCrafting: isCrafting,
                      error: error,
                      promptIsSane: prompt.trim().isNotEmpty,
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: view == 'result'
                          ? ResultView(
                              key: const ValueKey('result'),
                              imageBytes: currentImageBytes!,
                              hasAccept: hasAcceptAction(activeMode),
                              acceptLabel: getAcceptLabel(activeMode),
                              isSaving: saving,
                              onSave: onSave,
                              onAccept: onAccept,
                              onVariations: onVariations,
                              onEditRegen: onEditRegen,
                              onSendToChat: onSendToChat,
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (history.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GenerationHistory(entries: history, onRestore: onRestore),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.formMasterAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Image Studio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.iconSecondary(context)),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
