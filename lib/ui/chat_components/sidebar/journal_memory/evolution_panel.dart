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
import 'package:front_porch_ai/ui/widgets/widgets.dart';
import '../sidebar_tokens.dart';

/// Character Evolution sidebar panel — consolidates the old MemorySection
/// evolution block (enable toggle, interval slider, count, review/reset
/// dialogs) and chat_page's evolution section body (evolved personality/
/// scenario read wells, Review & Edit / Reset / Evolve Now actions).
/// The dialog-based evolution runner stays in chat_page — "Evolve Now"
/// threads out via [onEvolveNow].
class EvolutionPanel extends StatefulWidget {
  final ChatService chatService;
  final VoidCallback onEvolveNow;

  const EvolutionPanel({
    super.key,
    required this.chatService,
    required this.onEvolveNow,
  });

  @override
  State<EvolutionPanel> createState() => _EvolutionPanelState();
}

class _EvolutionPanelState extends State<EvolutionPanel> {
  double? _dragEvolutionInterval;

  @override
  Widget build(BuildContext context) {
    final storage = Provider.of<StorageService>(context);
    final enabled = storage.characterEvolutionEnabled;
    final accent = AppColors.journalAccentOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with enable toggle
        SidebarSubHeader(
          icon: Icons.psychology_alt,
          label: 'Character Evolution',
          accent: accent,
          trailing: SizedBox(
            height: 28,
            child: FittedBox(
              child: Switch(
                value: enabled,
                onChanged: (val) => storage.setCharacterEvolutionEnabled(val),
                activeTrackColor: accent,
              ),
            ),
          ),
        ),

        if (!enabled)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Personality & scenario evolve based on conversations. Original card is always preserved.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary(context),
              ),
            ),
          ),

        if (enabled) ...[
          const SizedBox(height: 4),
          // Evolve-every interval slider
          Row(
            children: [
              Text(
                'Evolve every',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              Text(
                '${(_dragEvolutionInterval ?? storage.evolutionInterval.toDouble()).round()} messages',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value:
                _dragEvolutionInterval ?? storage.evolutionInterval.toDouble(),
            min: 10,
            max: 50,
            divisions: 8,
            activeColor: accent,
            onChanged: (val) => setState(() => _dragEvolutionInterval = val),
            onChangeEnd: (val) {
              _dragEvolutionInterval = null;
              storage.setEvolutionInterval(val.round());
            },
          ),
          Consumer<ChatService>(
            builder: (context, chat, _) {
              final count = chat.characterEvolutionCount;
              final evolvedP = chat.getEffectivePersonality;
              final evolvedS = chat.getEffectiveScenario;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count > 0
                        ? 'Evolved $count time${count > 1 ? 's' : ''}'
                        : 'Not yet evolved',
                    style: TextStyle(
                      fontSize: 10,
                      color: count > 0
                          ? accent
                          : AppColors.textTertiary(context),
                      fontWeight: count > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (count > 0) ...[
                    if (evolvedP != null && evolvedP.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildReadWell(context, 'Evolved Personality', evolvedP),
                    ],
                    if (evolvedS != null && evolvedS.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildReadWell(context, 'Evolved Scenario', evolvedS),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showEvolutionReview(context, chat),
                          icon: Icon(Icons.edit, size: 14, color: accent),
                          label: Text(
                            'Review & Edit',
                            style: TextStyle(fontSize: 11, color: accent),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: accent.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showResetEvolutionConfirm(context, chat),
                          icon: Icon(
                            Icons.restart_alt,
                            size: 14,
                            color: AppColors.negativeAccentOf(context),
                          ),
                          label: Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.negativeAccentOf(context),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.negativeAccentOf(
                                context,
                              ).withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildEvolveNowButton(context),
                  ] else ...[
                    const SizedBox(height: 4),
                    _buildEvolveNowButton(context),
                    const SizedBox(height: 4),
                    Text(
                      'Personality & scenario will evolve as you chat, or tap above to evolve now.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary(context),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  /// Read-only evolved text well (deep inset).
  Widget _buildReadWell(BuildContext context, String label, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.deepWellOf(context),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.journalAccentOf(
                context,
              ).withValues(alpha: 0.3),
            ),
          ),
          constraints: const BoxConstraints(maxHeight: 100),
          child: SingleChildScrollView(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvolveNowButton(BuildContext context) {
    final accent = AppColors.journalAccentOf(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.onEvolveNow,
        icon: Icon(Icons.auto_fix_high, size: 14, color: accent),
        label: Text(
          'Evolve Now',
          style: TextStyle(fontSize: 11, color: accent),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: accent),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
    );
  }

  void _showEvolutionReview(BuildContext context, ChatService chat) {
    final character = chat.activeCharacter;
    if (character == null) return;
    final charName = character.name;
    final accent = AppColors.journalAccentOf(context);

    // Get evolved versions from chat service cache
    final evolvedPersonality = chat.getEffectivePersonality ?? '';
    final evolvedScenario = chat.getEffectiveScenario ?? '';

    final personalityController = TextEditingController(
      text: evolvedPersonality,
    );
    final scenarioController = TextEditingController(text: evolvedScenario);

    Widget originalWell(String text) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.deepWellOf(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.5),
        ),
      ),
      constraints: const BoxConstraints(maxHeight: 80),
      child: SingleChildScrollView(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary(context),
          ),
        ),
      ),
    );

    Widget evolvedField(TextEditingController controller) => AppTextField(
      controller: controller,
      maxLines: 4,
      style: TextStyle(fontSize: 11, color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.sunkenSurfaceOf(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: accent),
        ),
        contentPadding: const EdgeInsets.all(8),
      ),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: Row(
          children: [
            Icon(Icons.psychology_alt, size: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$charName — Evolution',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Evolved ${chat.characterEvolutionCount} time${chat.characterEvolutionCount > 1 ? "s" : ""}',
                  style: TextStyle(fontSize: 11, color: accent),
                ),
                const SizedBox(height: 12),
                // Original personality (read-only)
                Text(
                  'Original Personality',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary(context),
                  ),
                ),
                const SizedBox(height: 4),
                originalWell(character.personality),
                const SizedBox(height: 8),
                // Evolved personality (editable)
                Text(
                  'Evolved Personality',
                  style: TextStyle(fontSize: 11, color: accent),
                ),
                const SizedBox(height: 4),
                evolvedField(personalityController),
                const SizedBox(height: 12),
                // Original scenario (read-only)
                Text(
                  'Original Scenario',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary(context),
                  ),
                ),
                const SizedBox(height: 4),
                originalWell(character.scenario),
                const SizedBox(height: 8),
                // Evolved scenario (editable)
                Text(
                  'Evolved Scenario',
                  style: TextStyle(fontSize: 11, color: accent),
                ),
                const SizedBox(height: 4),
                evolvedField(scenarioController),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              chat.updateEvolvedPersonality(personalityController.text);
              chat.updateEvolvedScenario(scenarioController.text);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showResetEvolutionConfirm(BuildContext context, ChatService chat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: const Text('Reset Character Evolution?'),
        content: Text(
          'This will reset the character\'s personality and scenario back to the original card values. '
          'The evolution count will also reset to 0. This cannot be undone.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              chat.resetCharacterEvolution();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negativeAccentOf(context),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
