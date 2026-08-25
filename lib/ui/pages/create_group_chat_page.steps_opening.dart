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
//
// Group wizard steps 3-4: the opening scene and the prompt overrides.
// Extracted verbatim from create_group_chat_page.dart (god-file campaign,
// Tranche A); `part of` the same library, so every private member and the
// mandatory wizard step-indicator flow stay exactly as they were.

part of 'create_group_chat_page.dart';

extension _GroupWizardOpeningSteps on _CreateGroupChatPageState {
  Widget _buildOpeningStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opening Scene',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Dialogue subsection (groups): first message + alternate greetings.
          // Completely omits Example Dialogue (CharacterCard / mes_example concept only; no such field on GroupChat).
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.porchAmberOf(context),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dialogue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.porchAmberOf(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'First Message (optional)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final dynamics = _buildDynamicsContextForGeneration();
                        await _generateFirstMessage(dynamicsContext: dynamics);
                      },
                      icon: _isGeneratingFirst
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.auto_awesome,
                              color: AppColors.resolve(
                                context,
                                Colors.amberAccent,
                                Colors.amber.shade700,
                              ),
                            ),
                      label: Text(
                        _isGeneratingFirst
                            ? 'Generating...'
                            : 'Generate with Dynamics',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _firstMessageController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'The scene opens with...',
                  ),
                ),
                const SizedBox(height: 8),
                if (_directorMode)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.resolve(
                        context,
                        Colors.amber.withValues(alpha: 0.08),
                        Colors.amber.withValues(alpha: 0.08),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Director Mode: generated opening will be a self-contained group scene.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.resolve(
                          context,
                          Colors.amberAccent,
                          Colors.amber.shade700,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                GroupAlternateGreetingsEditor(
                  greetings: _altGreetings,
                  seeds: _altGreetingSeeds,
                  showNeeds: _needsSimEnabled,
                  onChanged: (g, s) {
                    rebuildState(() {
                      _altGreetings = g;
                      _altGreetingSeeds = s;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Scenario (optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final dynamics = _buildDynamicsContextForGeneration();
                  await _generateScenario(dynamicsContext: dynamics);
                },
                icon: _isGeneratingScenario
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.auto_awesome,
                        color: AppColors.resolve(
                          context,
                          Colors.amberAccent,
                          Colors.amber.shade700,
                        ),
                      ),
                label: Text(
                  _isGeneratingScenario
                      ? 'Generating...'
                      : 'Generate with Dynamics',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: _scenarioController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'The group is...'),
          ),

          _buildNavButtons(currentStep: 6),
        ],
      ),
    );
  }

  Widget _buildPromptsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Personality & World" subsection for groups (per spec): only group-applicable fields.
          // Omits Description/Personality (CharacterCard-only concepts). Scenario lives in Opening.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      color: AppColors.resolve(
                        context,
                        const Color(0xFF0EA5E9),
                        const Color(0xFF0284C8),
                      ),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Personality & World',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.resolve(
                          context,
                          const Color(0xFF0EA5E9),
                          const Color(0xFF0284C8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Group-level equivalents to character personality live in the system prompt and scenario.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Group System Prompt',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _groupSystemController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Global instructions for this group...',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Per-Character Overrides (optional)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._members.map((c) {
            final id = _stableId(c);
            final ctrl = StyledTextController(
              preset: StyledTextPreset.prose,
              text: _characterSystemPrompts[id]?.text ?? '',
            );
            ctrl.addListener(() {
              _characterSystemPrompts[id] = ctrl;
            });
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _avatar(c, radius: 16),
                        const SizedBox(width: 8),
                        Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: ctrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText:
                            'Extra instructions only for this character in this group',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_members.isEmpty)
            const Text('Add members first to configure per-character prompts.'),

          _buildNavButtons(currentStep: 2),
        ],
      ),
    );
  }
}
