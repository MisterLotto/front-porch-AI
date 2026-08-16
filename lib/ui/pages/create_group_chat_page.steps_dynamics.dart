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
// Group wizard: the Group Dynamics step (hidden inter-member feelings),
// its disabled-state screen, and the relationship setter.
// Extracted verbatim from create_group_chat_page.dart (god-file campaign,
// Tranche A); `part of` the same library, so every private member and the
// mandatory wizard step-indicator flow stay exactly as they were.

part of 'create_group_chat_page.dart';

extension _GroupWizardDynamicsStep on _CreateGroupChatPageState {
  // ── Group Dynamics (Intra-group relationships) ──────────────────────

  Widget _buildGroupDynamicsDisabledStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_alt,
              size: 64,
              color: AppColors.textTertiary(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Group Dynamics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Intra-group relationship seeding is only available for groups with 4 or fewer members.\n\n'
              'Your current group has ${_members.length} members.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 24),
            Text(
              'Larger groups use different social dynamics modeling.',
              style: TextStyle(
                color: AppColors.textTertiary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDynamicsStep() {
    // This should only be called when _members.length <= 4
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Group Dynamics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    'Pre-seed hidden intra-group relationship scores (same -300..+300 raw scale as Long-Term Bond in Realism). Only available for groups of 4 or fewer per engine limits. These private feelings (never shown in UI) influence how members treat each other in prompts and behavior when the Realism Engine is active. Values persist in the Group Card export and round-trip on split-to-solo.',
                preferBelow: false,
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.textTertiary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pre-seed how the characters feel toward each other. These hidden relationships influence behavior in small groups (4 or fewer members).',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 24),

          ..._members.map((source) {
            final sourceId = _stableId(source);
            final relationships =
                (_memberRealismSeeds[sourceId]?['relationships'] as Map?)
                    ?.cast<String, int>() ??
                {};

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _avatar(source, radius: 20),
                        const SizedBox(width: 12),
                        Text(
                          'How ${source.name} feels about others',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ..._members.where((target) => _stableId(target) != sourceId).map((
                      target,
                    ) {
                      final targetId = _stableId(target);
                      final currentValue = relationships[targetId] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _avatar(target, radius: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(target.name)),
                                Tooltip(
                                  message:
                                      'Hidden relationship score on the same -300..+300 scale as Long-Term Bond. Positive values mean the source character privately feels warmly toward the target.',
                                  child: Text(
                                    currentValue > 0
                                        ? '+$currentValue'
                                        : currentValue.toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: relationshipScaleColor(
                                        context,
                                        currentValue,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: relationshipScaleColor(
                                  context,
                                  currentValue,
                                ),
                                inactiveTrackColor: AppColors.borderOf(
                                  context,
                                ).withValues(alpha: 0.3),
                                thumbColor: relationshipScaleColor(
                                  context,
                                  currentValue,
                                ),
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                              ),
                              child: Slider(
                                value: currentValue.toDouble().clamp(-300, 300),
                                min: -300,
                                max: 300,
                                divisions: 120,
                                label: currentValue.toString(),
                                onChanged: (v) {
                                  _updateRelationship(
                                    sourceId,
                                    targetId,
                                    v.round(),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Tooltip(
                              message:
                                  'Starting hidden feeling of ${source.name} toward ${target.name}. Matches the Long-Term Bond tier system used in the 1:1 Realism creator and runtime evaluations. These scores only affect groups of 4 or fewer and drive realistic intra-group behavior when Realism is enabled.',
                              child: Text(
                                relationshipTierName(currentValue),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: relationshipScaleColor(
                                    context,
                                    currentValue,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          Text(
            'These values are private to the group and affect how characters treat each other when Realism is active.',
            style: TextStyle(
              color: AppColors.textTertiary(context),
              fontSize: 12,
            ),
          ),

          _buildNavButtons(currentStep: 5),
        ],
      ),
    );
  }

  void _updateRelationship(String fromId, String toId, int value) {
    rebuildState(() {
      final seed = _memberRealismSeeds[fromId] ??= _defaultRealismSeedFor(
        _members.firstWhere((c) => _stableId(c) == fromId),
      );

      final rels =
          (seed['relationships'] as Map<String, int>?)?.cast<String, int>() ??
          {};
      rels[toId] = value;
      seed['relationships'] = rels;
    });
  }

  // Relationship tier-name + valence color are shared with the group editor
  // (relationshipTierName / relationshipScaleColor in
  // group_realism_dynamics_editor.dart) so both surfaces label + color a hidden
  // feeling score identically — one UX standard, no duplicated logic.
}
