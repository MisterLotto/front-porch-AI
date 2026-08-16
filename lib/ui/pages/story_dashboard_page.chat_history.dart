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

/// Chat History preview section for [_StoryDashboardPageState]: the
/// collapsible header (events-distilled badge), the Timeline/Raw Messages
/// tab row, Redistill, and the two content views. Extracted verbatim from
/// the inline `_buildChatHistorySection`/`_tabButton`; `setState` calls
/// become `rebuildState` since extensions cannot touch a State's protected
/// members directly. NOTE: `_showRawMessages` itself stays a shell field
/// (see story_dashboard_page.dart) — extensions cannot hold fields.
///
/// Number of `[EVENT N]` markers in a distilled timeline — the badge's count.
/// The pattern must stay byte-identical to the one the distiller itself
/// counts with (`story_pipeline_service.llm.dart`) and to the web twin's
/// `/\[EVENT \d+\]/g`; the badge used to carry a double-escaped copy inside a
/// raw string, which matched nothing and always reported 0 events.
int distilledEventCount(String timeline) =>
    RegExp(r'\[EVENT \d+\]').allMatches(timeline).length;

extension _StoryDashboardChatHistory on _StoryDashboardPageState {
  Widget _buildChatHistorySection(StoryProject project) {
    final hasTimeline = project.distilledTimeline.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () =>
                rebuildState(() => _showChatPreview = !_showChatPreview),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 20,
                    color: AppColors.frostAccentOf(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Chat History',
                    style: TextStyle(
                      color: AppColors.frostAccentOf(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasTimeline)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bondHighOf(
                          context,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${distilledEventCount(project.distilledTimeline)} events distilled',
                        style: TextStyle(
                          color: AppColors.bondHighOf(context),
                          fontSize: 11,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.taskAccentOf(
                          context,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Not distilled yet',
                        style: TextStyle(
                          color: AppColors.taskAccentOf(context),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Icon(
                    _showChatPreview ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.iconSecondary(context),
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_showChatPreview) ...[
            Divider(
              color: AppColors.borderOf(context).withValues(alpha: 0.3),
              height: 1,
            ),
            // Tab row: Timeline | Raw Messages | Redistill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  if (hasTimeline) ...[
                    _tabButton(
                      'Timeline',
                      !_showRawMessages,
                      () => rebuildState(() => _showRawMessages = false),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _tabButton(
                    'Raw Messages',
                    _showRawMessages || !hasTimeline,
                    () {
                      if (_chatPreviewMessages.isEmpty &&
                          !_loadingChatPreview) {
                        _loadChatPreview(project);
                      }
                      rebuildState(() => _showRawMessages = true);
                    },
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final pipeline = Provider.of<StoryPipelineService>(
                        context,
                        listen: false,
                      );
                      project.distilledTimeline = ''; // Force re-distill
                      await pipeline.runChatDistiller(project);
                      if (mounted) rebuildState(() => _showRawMessages = false);
                    },
                    icon: Icon(
                      Icons.refresh,
                      size: 14,
                      color: AppColors.frostAccentOf(context),
                    ),
                    label: Text(
                      hasTimeline ? 'Redistill' : 'Distill Now',
                      style: TextStyle(
                        color: AppColors.frostAccentOf(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Content
            if (!_showRawMessages && hasTimeline) ...[
              // Distilled timeline view
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SelectableText(
                    project.distilledTimeline,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ] else if (_loadingChatPreview) ...[
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.frostAccentOf(context),
                  ),
                ),
              ),
            ] else if (_chatPreviewMessages.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shrinkWrap: true,
                  itemCount: _chatPreviewMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatPreviewMessages[index];
                    if (msg.startsWith('---')) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: AppColors.borderOf(
                            context,
                          ).withValues(alpha: 0.3),
                        ),
                      );
                    }
                    final isUser =
                        msg.startsWith('User:') ||
                        msg.startsWith('user:') ||
                        msg.startsWith('{{user}}:');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isUser ? Icons.person : Icons.smart_toy,
                            size: 14,
                            color: isUser
                                ? AppColors.bondHighOf(context)
                                : AppColors.fixationAccentOf(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Click "Raw Messages" to load the full chat history.',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.frostAccentOf(context).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? AppColors.frostAccentOf(context).withValues(alpha: 0.5)
                : AppColors.borderOf(context).withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? AppColors.frostAccentOf(context)
                : AppColors.textTertiary(context),
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
