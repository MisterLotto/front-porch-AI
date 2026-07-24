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
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/models/chat_generation_settings.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/dialogs/chat_settings_generation_section.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

class ChatSettingsDialog extends StatefulWidget {
  const ChatSettingsDialog({super.key});

  @override
  State<ChatSettingsDialog> createState() => _ChatSettingsDialogState();
}

class _ChatSettingsDialogState extends State<ChatSettingsDialog> {
  late final TextEditingController _bannedPhrasesController;
  late ChatGenerationSettings _gen;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final storage = Provider.of<StorageService>(context, listen: false);
      _gen = chatService.sessionGenSettings;
      _bannedPhrasesController = TextEditingController(
        text: _gen.resolveBannedPhrases(storage).join('\n'),
      );
      _initialised = true;
    }
  }

  @override
  void dispose() {
    _bannedPhrasesController.dispose();
    super.dispose();
  }

  /// Write the mutated [_gen] back to ChatService (which persists to DB).
  void _save() {
    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.sessionGenSettings = _gen;
  }

  @override
  Widget build(BuildContext context) {
    final storage = Provider.of<StorageService>(context);
    final llmProvider = Provider.of<LLMProvider>(context);
    final isRemote = !llmProvider.isLocal;
    final hasOverrides = _gen.hasOverrides;

    return Dialog(
      backgroundColor: AppColors.surface,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chat Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (hasOverrides) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.porchAmberOf(
                            context,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.porchAmberOf(
                              context,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.porchAmberOf(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasOverrides)
                      Tooltip(
                        message: 'Reset to global defaults',
                        child: IconButton(
                          icon: Icon(
                            Icons.restart_alt,
                            color: AppColors.porchAmberOf(context),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _gen = ChatGenerationSettings();
                              _bannedPhrasesController.text = storage
                                  .bannedPhrases
                                  .join('\n');
                            });
                            _save();
                          },
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.iconSecondary(context)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            if (hasOverrides)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'This chat has custom generation settings that override global defaults.',
                  style: TextStyle(
                    color: AppColors.porchAmberOf(
                      context,
                    ).withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reasoning toggle — all backends. KoboldCpp honors
                    // thinking too now (native chat_template_kwargs +
                    // reasoning_effort in openai_chat_stream.dart), so this is
                    // no longer remote-only.
                    ...[
                      const Text(
                        'Reasoning',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.formMasterAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Request Reasoning',
                            style: TextStyle(color: AppColors.textPrimary(context)),
                          ),
                          const Spacer(),
                          Switch(
                            value: _gen.resolveReasoningEnabled(storage),
                            onChanged: (val) {
                              setState(() => _gen.reasoningEnabled = val);
                              _save();
                            },
                            activeTrackColor: AppColors.formMasterAccent,
                          ),
                        ],
                      ),
                      if (_gen.resolveReasoningEnabled(storage))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(
                                'Effort Level',
                                style: TextStyle(color: AppColors.textSecondary(context)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _gen.resolveReasoningEffort(storage),
                                    dropdownColor: AppColors.surfaceContainer,
                                    style: TextStyle(color: AppColors.textPrimary(context)),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'low',
                                        child: Text('Low'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'medium',
                                        child: Text('Medium'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'high',
                                        child: Text('High'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(
                                          () => _gen.reasoningEffort = val,
                                        );
                                        _save();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!_gen.resolveReasoningEnabled(storage))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Enable to request thinking/reasoning from compatible models',
                            style: TextStyle(
                              color: AppColors.textTertiary(context),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Divider(color: AppColors.borderOf(context)),
                      const SizedBox(height: 8),
                    ],

                    ChatSettingsGenerationSection(
                      gen: _gen,
                      storage: storage,
                      llmProvider: llmProvider,
                      isRemote: isRemote,
                      onChanged: () {
                        setState(() {});
                        _save();
                      },
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Stop Sequences',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.formMasterAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StopSequenceList(
                      sequences: _gen.resolveStopSequences(storage),
                      onSequencesChanged: (newList) {
                        setState(() => _gen.stopSequences = newList);
                        _save();
                      },
                      backgroundColor: AppColors.surfaceContainer,
                    ),

                    // ── Banned Phrases (Anti-Slop) — local KoboldCpp only ──
                    if (!isRemote) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            'Banned Phrases',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.formMasterAccent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message:
                                'If any of these phrases appear during generation, the model backtracks and regenerates without them.',
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.textTertiary(context),
                            ),
                          ),
                        ],
                      ),
                      BannedPhrasesEditor(
                        controller: _bannedPhrasesController,
                        onChanged: (phrases) {
                          _gen.bannedPhrases = phrases;
                          _save();
                        },
                        phraseCount: _gen.resolveBannedPhrases(storage).length,
                        description: 'One phrase per line',
                      ),

                    ],

                    // ── Output Sanitizer ─────────────────────────────────
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text(
                          'Output Sanitizer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.formMasterAccent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message:
                              'Replace specific character sequences in model output '
                              'before saving to chat history.',
                          child: Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.textTertiary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Enable Output Sanitizer',
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _gen.resolveOutputSanitizerEnabled(storage),
                          onChanged: (val) {
                            setState(
                              () => _gen.outputSanitizerEnabled = val,
                            );
                            _save();
                          },
                          activeTrackColor: AppColors.formMasterAccent,
                        ),
                      ],
                    ),
                    if (_gen.resolveOutputSanitizerEnabled(storage)) ...[
                      const SizedBox(height: 8),
                      OutputSanitizerRuleEditor(
                        rules: _gen.resolveOutputSanitizerRules(storage),
                        onRulesChanged: (newRules) {
                          setState(() => _gen.outputSanitizerRules = newRules);
                          _save();
                        },
                        backgroundColor: AppColors.aiBubble,
                      ),
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
}
