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

/// Editable act cards for [_StoryDashboardPageState]: lazily creates the
/// title/description controllers into the shell-owned controller maps and
/// renders the expandable act editor (title/description fields + knots
/// preview). Extracted verbatim from the inline `_editableActCard`;
/// `setState` becomes `rebuildState` since extensions cannot touch a
/// State's protected members directly. Edits are only persisted via
/// `_saveActEdits` (story_dashboard_page.actions.dart), wired from the
/// body's "Save Edits" button.
extension _StoryDashboardActCards on _StoryDashboardPageState {
  Widget _editableActCard(int index, StoryAct act, StoryProject project) {
    // Initialize controllers lazily
    if (!_actTitleControllers.containsKey(index)) {
      _actTitleControllers[index] = TextEditingController(text: act.title);
      _actDescControllers[index] = TextEditingController(text: act.description);
    }

    final sceneCount = project.scenes[act.number - 1]?.length ?? 0;

    return Card(
      color: AppColors.cardOf(context),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: CircleAvatar(
          backgroundColor: AppColors.porchAmberOf(
            context,
          ).withValues(alpha: 0.2),
          radius: 18,
          child: Text(
            '${act.number}',
            style: TextStyle(
              color: AppColors.porchAmberOf(context),
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          _actTitleControllers[index]?.text ?? act.title,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          (act.description.length > 100
              ? '${act.description.substring(0, 100)}...'
              : act.description),
          style: TextStyle(
            color: AppColors.textSecondary(context).withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
        trailing: sceneCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.frostAccentOf(
                    context,
                  ).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$sceneCount scenes',
                  style: TextStyle(
                    color: AppColors.frostAccentOf(context),
                    fontSize: 11,
                  ),
                ),
              )
            : null,
        iconColor: AppColors.iconSecondary(context),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Title',
                  style: TextStyle(
                    color: AppColors.porchAmberOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                AppTextField(
                  controller: _actTitleControllers[index],
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                  ),
                  onChanged: (_) => rebuildState(() {}),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceContainerOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Description',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                AppTextField(
                  controller: _actDescControllers[index],
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13,
                  ),
                  maxLines: 8,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceContainerOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                // Knots preview
                if (act.knots.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Convergence Points',
                    style: TextStyle(
                      color: AppColors.frostAccentOf(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...act.knots.map(
                    (k) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.merge_type,
                            size: 14,
                            color: AppColors.frostAccentOf(context),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${k.description} — ${k.interaction}',
                              style: TextStyle(
                                color: AppColors.textTertiary(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
