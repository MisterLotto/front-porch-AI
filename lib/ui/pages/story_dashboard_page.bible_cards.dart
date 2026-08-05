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

part of 'story_dashboard_page.dart';

/// Story bible display cards for [_StoryDashboardPageState]: section
/// title/card builders, cast cards (with TTS voice picker), thread cards,
/// and lore chips. Extracted verbatim from the inline builders; `setState`
/// becomes `rebuildState` since extensions cannot touch a State's protected
/// members directly.
extension _StoryDashboardBibleCards on _StoryDashboardPageState {
  Widget _sectionTitle(String title, IconData icon, Color color) => Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _sectionCard(
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _castCard(StoryCastMember c) {
    return Card(
      color: AppColors.cardOf(context),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          c.name,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          c.role,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 12,
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.porchTerracottaOf(
            context,
          ).withValues(alpha: 0.25),
          child: Text(
            c.name.isNotEmpty ? c.name[0] : '?',
            style: TextStyle(color: AppColors.porchTerracottaOf(context)),
          ),
        ),
        iconColor: AppColors.iconSecondary(context),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.description,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13,
                  ),
                ),
                if (c.voiceSample != null && c.voiceSample!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Voice: "${c.voiceSample}"',
                    style: TextStyle(
                      color: AppColors.textSecondary(
                        context,
                      ).withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ],
                // TTS Voice picker
                const SizedBox(height: 10),
                Consumer<TtsService>(
                  builder: (context, tts, _) {
                    final voices = tts.activeVoices;
                    if (voices.isEmpty) return const SizedBox.shrink();
                    return Row(
                      children: [
                        Icon(
                          Icons.record_voice_over,
                          size: 14,
                          color: AppColors.porchHoneyOf(
                            context,
                          ).withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TTS Voice:',
                          style: TextStyle(
                            color: AppColors.textTertiary(context),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value: c.voiceModel,
                            hint: Text(
                              'Default narrator',
                              style: TextStyle(
                                color: AppColors.textTertiary(context),
                                fontSize: 12,
                              ),
                            ),
                            dropdownColor: AppColors.surfaceContainerOf(
                              context,
                            ),
                            isExpanded: true,
                            underline: Container(
                              height: 1,
                              color: AppColors.borderOf(
                                context,
                              ).withValues(alpha: 0.5),
                            ),
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 12,
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(
                                  'Default narrator',
                                  style: TextStyle(
                                    color: AppColors.textTertiary(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              ...voices.map(
                                (v) => DropdownMenuItem<String>(
                                  value: v.id,
                                  child: Text(
                                    v.name,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              c.voiceModel = value;
                              final repo = Provider.of<StoryRepository>(
                                context,
                                listen: false,
                              );
                              final project = _project;
                              if (project != null) repo.saveProject(project);
                              rebuildState(() {});
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                ...c.details.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${e.key}: ${e.value}',
                      style: TextStyle(
                        color: AppColors.textTertiary(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _threadCard(StoryThread t) {
    return Card(
      color: AppColors.cardOf(context),
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.timeline,
          size: 18,
          color: AppColors.frostAccentOf(context),
        ),
        title: Text(
          t.name,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          t.description,
          style: TextStyle(
            color: AppColors.textSecondary(context).withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _loreChip(StoryLoreEntry l) {
    return Tooltip(
      message: l.detail,
      child: Chip(
        label: Text(
          l.topic,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(context),
          ),
        ),
        backgroundColor: AppColors.cardOf(context),
        side: BorderSide(
          color: AppColors.bondHighOf(context).withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
