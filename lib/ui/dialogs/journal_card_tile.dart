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

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/chat/journal_physics.dart';
import 'package:front_porch_ai/ui/dialogs/journal_card_editor.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// One memory card row shared by the Diary and Belongings tabs: emotion chip,
/// the memory in the character's words, the feeling line (with the
/// "once felt X — now feels Y" healed arc), and pinned/faded state. Pin is
/// one tap; edit/receipts/retire live in the menu.
class JournalCardTile extends StatelessWidget {
  final JournalMemoryData card;

  /// "Day 5 · Tue, Mar 3" (story-calendar §4); null for pre-calendar cards.
  final String? when;
  final VoidCallback onPinToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShowReceipts;

  const JournalCardTile({
    super.key,
    required this.card,
    this.when,
    required this.onPinToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onShowReceipts,
  });

  @override
  Widget build(BuildContext context) {
    final faded = !JournalPhysics.isHot(card);
    final feelingLine = journalFeelingLine(card);
    final feeling = feelingLine == null
        ? when
        : when == null
        ? feelingLine
        : '$feelingLine · $when';
    final hasReceipts =
        card.sourceMessageIds != null && card.sourceMessageIds!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: card.pinned
              ? AppColors.porchHoneyOf(context).withValues(alpha: 0.5)
              : AppColors.borderOf(context).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Opacity(
              opacity: faded ? 0.45 : 1.0,
              child: Text(
                journalCardEmoji(card),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.content,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: faded
                        ? AppColors.textTertiary(context)
                        : AppColors.textPrimary(context),
                  ),
                ),
                if (feeling != null || faded) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (feeling != null)
                        Flexible(
                          child: Text(
                            feeling,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textTertiary(context),
                            ),
                          ),
                        ),
                      if (faded) ...[
                        if (feeling != null) const SizedBox(width: 6),
                        Icon(
                          Icons.ac_unit,
                          size: 10,
                          color: AppColors.frostAccentOf(context),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'faded',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.frostAccentOf(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 15,
            tooltip: card.pinned ? 'Unpin' : 'Pin (never fades)',
            icon: Icon(
              card.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: card.pinned
                  ? AppColors.porchHoneyOf(context)
                  : AppColors.iconSecondary(context),
            ),
            onPressed: onPinToggle,
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            iconSize: 15,
            icon: Icon(
              Icons.more_vert,
              color: AppColors.iconSecondary(context),
            ),
            color: AppColors.surfaceContainerOf(context),
            onSelected: (action) {
              if (action == 'edit') {
                onEdit();
              } else if (action == 'receipts') {
                onShowReceipts();
              } else {
                onDelete();
              }
            },
            itemBuilder: (ctx) => [
              _menuItem(ctx, 'edit', Icons.edit_outlined, 'Edit'),
              if (hasReceipts)
                _menuItem(
                  ctx,
                  'receipts',
                  Icons.format_quote,
                  'Where this came from',
                ),
              _menuItem(ctx, 'retire', Icons.delete_outline, 'Retire'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    BuildContext context,
    String value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.iconSecondary(context)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
