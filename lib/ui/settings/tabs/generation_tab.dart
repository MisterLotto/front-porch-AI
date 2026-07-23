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

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/settings/widgets/section_header.dart';
import 'package:front_porch_ai/ui/settings/widgets/slider_setting.dart';

/// Generation-settings tab extracted from settings_page (Stage 5, remaining
/// tabs). Pure lift of _buildGenerationTab: reasoning, sampling parameters,
/// output limits, smooth-output display buffer, stop sequences, and (local
/// backends only) banned phrases. Reads storage/LLM state via Provider; the
/// banned-phrases controller is the only shared state, passed via ctor.
/// AppColors exclusive, warm-porch accents.
class GenerationTab extends StatefulWidget {
  const GenerationTab({super.key, required this.bannedPhrasesController});

  final TextEditingController bannedPhrasesController;

  @override
  State<GenerationTab> createState() => _GenerationTabState();
}

class _GenerationTabState extends State<GenerationTab> {
  final TextEditingController _stopSequenceController =
      TextEditingController();
  final TextEditingController _sanitizerFindController =
      TextEditingController();
  final TextEditingController _sanitizerReplaceController =
      TextEditingController();

  @override
  void dispose() {
    _stopSequenceController.dispose();
    _sanitizerFindController.dispose();
    _sanitizerReplaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = Provider.of<StorageService>(context);
    final llmProvider = Provider.of<LLMProvider>(context);
    final isRemote = !llmProvider.isLocal;
    final accent = AppColors.porchAmberOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Reasoning (thinking models — local KoboldCpp & remote) ─────
          const SectionHeader('Reasoning'),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Request Reasoning',
                style: TextStyle(color: AppColors.textPrimary(context)),
              ),
              const Spacer(),
              Switch(
                value: storage.reasoningEnabled,
                onChanged: (val) => storage.setReasoningEnabled(val),
              ),
            ],
          ),
          if (storage.reasoningEnabled)
            Row(
              children: [
                Text(
                  'Effort Level',
                  style: TextStyle(color: AppColors.textSecondary(context)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: storage.reasoningEffort,
                      dropdownColor: AppColors.cardOf(context),
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
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
          const SizedBox(height: 24),

          // ── Generation Parameters ──────────────────────────────────────
          const SectionHeader('Generation Parameters'),
          const SizedBox(height: 8),
          SliderSetting(
            label: 'Temperature',
            value: storage.generationSettings.temperature,
            min: 0.0,
            max: 2.0,
            onChanged: (val) => storage.setTemperature(val),
            divisions: 20,
            showInput: true,
            decimalPlaces: 1,
          ),
          SliderSetting(
            label: 'Min-P',
            value: storage.generationSettings.minP,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => storage.setMinP(val),
            divisions: 100,
            showInput: true,
            decimalPlaces: 2,
          ),
          SliderSetting(
            label: 'Top-P',
            value: storage.topP,
            min: 0.1,
            max: 1.0,
            onChanged: (val) => storage.setTopP(val),
            divisions: 90,
            showInput: true,
            decimalPlaces: 2,
          ),
          SliderSetting(
            label: 'Top-K',
            value: storage.topK.toDouble(),
            min: 0,
            max: 200,
            onChanged: (val) => storage.setTopK(val.toInt()),
            divisions: 200,
            showInput: true,
            isInteger: true,
          ),
          SliderSetting(
            label: 'Repeat Penalty',
            value: storage.generationSettings.repeatPenalty,
            min: 1.0,
            max: 3.0,
            onChanged: (val) => storage.setRepeatPenalty(val),
            divisions: 200,
            showInput: true,
            decimalPlaces: 2,
          ),
          SliderSetting(
            label: 'Repeat Penalty Tokens',
            value: storage.repeatPenaltyTokens.toDouble(),
            min: 0,
            max: 2048,
            onChanged: (val) => storage.setRepeatPenaltyTokens(val.toInt()),
            divisions: 256,
            showInput: true,
            isInteger: true,
          ),
          // XTC and DRY are llama.cpp samplers — only the KoboldCpp
          // backend honors them, so they are hidden (not just annotated)
          // on oMLX/remote (maintainer request 2026-07-15).
          if (llmProvider.activeBackend == BackendType.kobold) ...[
            SliderSetting(
              label: 'XTC Threshold',
              value: storage.xtcThreshold,
              min: 0.0,
              max: 0.5,
              onChanged: (val) => storage.setXtcThreshold(val),
              divisions: 50,
              showInput: true,
              decimalPlaces: 2,
            ),
            SliderSetting(
              label: 'XTC Probability',
              value: storage.xtcProbability,
              min: 0.0,
              max: 1.0,
              onChanged: (val) => storage.setXtcProbability(val),
              divisions: 20,
              showInput: true,
              decimalPlaces: 2,
            ),
            SliderSetting(
              label: 'DRY Strength',
              value: storage.dryMultiplier,
              min: 0.0,
              max: 3.0,
              onChanged: (val) => storage.setDryMultiplier(val),
              divisions: 60,
              showInput: true,
              decimalPlaces: 2,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Dynamic Temperature',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
              const Spacer(),
              Switch(
                value: storage.dynamicTempEnabled,
                onChanged: (val) => storage.setDynamicTempEnabled(val),
                activeTrackColor: accent,
              ),
            ],
          ),
          if (storage.dynamicTempEnabled)
            SliderSetting(
              label: 'Dynatemp Range',
              value: storage.dynamicTempRange,
              min: 0.0,
              max: 2.0,
              onChanged: (val) => storage.setDynamicTempRange(val),
              divisions: 20,
              showInput: true,
              decimalPlaces: 1,
            ),
          const SizedBox(height: 24),

          // ── Output Limits ──────────────────────────────────────────────
          const SectionHeader('Output Limits'),
          const SizedBox(height: 8),
          SliderSetting(
            label: 'Max Output Tokens',
            value: storage.maxLength.toDouble(),
            min: 16,
            max: 16384,
            onChanged: (val) => storage.setMaxLength(val.toInt()),
            showInput: true,
            isInteger: true,
          ),
          SliderSetting(
            label: 'Min Output Tokens',
            value: storage.minLength.toDouble(),
            min: 0,
            max: 512,
            onChanged: (val) => storage.setMinLength(val.toInt()),
            divisions: 512,
            showInput: true,
            isInteger: true,
          ),
          // Context size — wider range for remote backends.
          SliderSetting(
            label: 'Context Size',
            value: storage.contextSize.toDouble().clamp(
              512,
              isRemote ? 500000.0 : 131072.0,
            ),
            min: 512,
            max: isRemote ? 500000.0 : 131072.0,
            onChanged: (val) => storage.setContextSize(val.toInt()),
            divisions: isRemote ? null : ((131072 - 512) ~/ 512),
            showInput: true,
            isInteger: true,
          ),
          const SizedBox(height: 24),

          // ── Display Output ─────────────────────────────────────────────
          const SectionHeader('Display Output'),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Smooth Output Buffer',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
              const Spacer(),
              Switch(
                value: storage.displayBufferEnabled,
                onChanged: (val) => storage.setDisplayBufferEnabled(val),
                activeTrackColor: accent,
              ),
            ],
          ),
          if (storage.displayBufferEnabled) ...[
            SliderSetting(
              label: 'Target Display Speed (t/s)',
              value: storage.targetDisplayTps,
              min: 5.0,
              max: 60.0,
              onChanged: (val) => storage.setTargetDisplayTps(val),
              divisions: 55,
            ),
            SliderSetting(
              label: 'Buffer Duration (seconds)',
              value: storage.bufferDurationSeconds,
              min: 1.0,
              max: 10.0,
              onChanged: (val) => storage.setBufferDurationSeconds(val),
              divisions: 9,
            ),
          ],
          const SizedBox(height: 24),

          // ── Stop Sequences ─────────────────────────────────────────────
          const SectionHeader('Stop Sequences'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _stopSequenceController,
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add stop sequence...',
                            hintStyle: TextStyle(
                              color: AppColors.textTertiary(context),
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) {
                            if (val.isNotEmpty) {
                              storage.addStopSequence(val);
                              _stopSequenceController.clear();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle,
                          color: accent,
                          size: 22,
                        ),
                        onPressed: () {
                          final val = _stopSequenceController.text;
                          if (val.isNotEmpty) {
                            storage.addStopSequence(val);
                            _stopSequenceController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.borderOf(context)),
                  ...storage.stopSequences.map(
                    (seq) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              seq.replaceAll('\n', '\\n'),
                              style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.negativeAccentOf(context),
                              size: 22,
                            ),
                            onPressed: () => storage.removeStopSequence(seq),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Banned Phrases (KoboldCpp only) ────────────────────────────
          if (!isRemote) ...[
            const SectionHeader('Banned Phrases'),
            const SizedBox(height: 4),
            Text(
              'One phrase per line. If any appear during generation the model '
              'backtracks and retries.',
              style: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardOf(context),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: widget.bannedPhrasesController,
                maxLines: 6,
                minLines: 2,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'shivers down\na cold shiver\nher eyes sparkled',
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                onChanged: (val) {
                  final phrases = val
                      .split('\n')
                      .where((s) => s.trim().isNotEmpty)
                      .map((s) => s.trim())
                      .toList();
                  storage.setBannedPhrases(phrases);
                },
              ),
            ),
            if (storage.bannedPhrases.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${storage.bannedPhrases.length} phrase'
                  '${storage.bannedPhrases.length == 1 ? '' : 's'} banned',
                  style: TextStyle(
                    color: AppColors.porchHoneyOf(context),
                    fontSize: 11,
                  ),
                ),
              ),
          ],

          const SizedBox(height: 24),

          // ── Output Sanitizer ───────────────────────────────────────────
          const SectionHeader('Output Sanitizer'),
          const SizedBox(height: 4),
          Text(
            'Replace specific character sequences in model output before '
            'saving to chat history.',
            style: TextStyle(
              color: AppColors.textTertiary(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Enable Output Sanitizer',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
              const Spacer(),
              Switch(
                value: storage.generationSettings.outputSanitizerEnabled,
                onChanged: (val) =>
                    storage.generationSettings.setOutputSanitizerEnabled(val),
                activeTrackColor: accent,
              ),
            ],
          ),
          if (storage.generationSettings.outputSanitizerEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sanitise Existing History',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      Text(
                        'When enabled, opening a chat will permanently '
                        'apply the rules above to all messages already '
                        'saved in that chat\'s history. This cannot be '
                        'undone.',
                        style: TextStyle(
                          color: AppColors.textTertiary(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: storage.generationSettings.sanitiseExistingHistory,
                  onChanged: (val) async {
                    storage.generationSettings
                        .setSanitiseExistingHistory(val);
                    if (val && mounted) {
                      final chatService = Provider.of<ChatService>(
                        context,
                        listen: false,
                      );
                      await chatService.reloadCurrentSession();
                    }
                  },
                  activeTrackColor: accent,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardOf(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sanitizerFindController,
                              style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Find...',
                                hintStyle: TextStyle(
                                  color: AppColors.textTertiary(context),
                                  fontSize: 13,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.borderOf(context),
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.borderOf(context),
                                  ),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: accent),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: AppColors.borderOf(context),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _sanitizerReplaceController,
                              style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Replace with...',
                                hintStyle: TextStyle(
                                  color: AppColors.textTertiary(context),
                                  fontSize: 13,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.borderOf(context),
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.borderOf(context),
                                  ),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: accent),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.add_circle,
                              color: accent,
                              size: 22,
                            ),
                            onPressed: () {
                              final find =
                                  _sanitizerFindController.text;
                              final replace =
                                  _sanitizerReplaceController.text;
                              if (find.isNotEmpty) {
                                final current = storage
                                    .generationSettings.outputSanitizerRules
                                    .toList();
                                current.add(
                                  OutputSanitizerRule(
                                    find: find,
                                    replace: replace,
                                  ),
                                );
                                storage.generationSettings.setOutputSanitizerRules(current);
                                _sanitizerFindController.clear();
                                _sanitizerReplaceController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  Divider(
                    height: 1,
                    color: AppColors.borderOf(context),
                  ),
                  ...storage.generationSettings.outputSanitizerRules.map(
                    (rule) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontSize: 13,
                                ),
                                children: [
                                  TextSpan(
                                    text: rule.find,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(text: ' → '),
                                  TextSpan(text: rule.replace),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.negativeAccentOf(context),
                              size: 22,
                            ),
                            onPressed: () {
                              final current = storage
                                  .generationSettings.outputSanitizerRules
                                  .toList();
                              current.remove(rule);
                              storage.generationSettings.setOutputSanitizerRules(current);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (storage.generationSettings.outputSanitizerRules.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'No rules configured',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 11,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${storage.generationSettings.outputSanitizerRules.length} rule${storage.generationSettings.outputSanitizerRules.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AppColors.porchHoneyOf(context),
                    fontSize: 11,
                  ),
                ),
              ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
