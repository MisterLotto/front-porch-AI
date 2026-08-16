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

part of 'edit_group_page.dart';

/// Dialogue tab: First Message field + the disabled "Alternate Greetings —
/// Coming soon" stub. No Example Dialogue section exists by design (GroupChat
/// has no mes_example). Split out of `edit_group_page.dart` (extension on
/// _EditGroupPageState) to keep every file under the 500-LOC cap — same
/// pattern model_settings_dialog.dart uses. Verbatim: this tab touches only
/// _firstMessageController, so there are zero setState/rebuildState sites and
/// zero Provider reads here.
extension _EditGroupDialogueTab on _EditGroupPageState {
  Widget _buildDialogueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

                Text(
                  'First Message (optional)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _firstMessageController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'The scene opens with...',
                  ),
                ),

                const SizedBox(height: 20),

                // Alternate Greetings stub — disabled, exact text per spec.
                // No Example Dialogue section at all (GroupChat has none).
                Opacity(
                  opacity: 0.6,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerOf(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.borderOf(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horiz,
                              color: AppColors.iconSecondary(context),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Alternate Greetings',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.resolve(
                                  context,
                                  AppColors.surfaceContainer,
                                  AppColors.surfaceContainerLight,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Coming soon',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Alternate greetings for groups are coming in a future update. The opening message above is used for new sessions today.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary(context),
                          ),
                        ),
                      ],
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
}
