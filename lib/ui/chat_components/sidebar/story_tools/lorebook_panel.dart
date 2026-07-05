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

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import '../sidebar_tokens.dart';

/// Trigger-state dot color: red = enabled but inactive (or an inclusion-group
/// loser this turn), blue = constant (always injected), green =
/// keyword-triggered. [injected] is the post-group-filter truth from
/// ChatService.currentlyActiveLoreEntries().
Color _loreDotColor(BuildContext context, LorebookEntry entry, bool injected) {
  if (!injected) return AppColors.negativeAccentOf(context);
  if (entry.constant) return AppColors.bondMidOf(context);
  return AppColors.bondHighOf(context);
}

/// One lorebook entry row (dot + name) — shared by the 1:1 and group panels.
class _LoreEntryRow extends StatelessWidget {
  final LorebookEntry entry;
  final String label;
  final double verticalPadding;
  final bool injected;

  const _LoreEntryRow({
    required this.entry,
    required this.label,
    required this.verticalPadding,
    required this.injected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _loreDotColor(context, entry, injected),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: injected
                    ? AppColors.textPrimary(context)
                    : AppColors.textSecondary(context),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lorebook triggers panel for 1:1 chats — lives inside the Story Tools
/// accordion, entries list always visible.
class LorebookSection extends StatelessWidget {
  final CharacterCard character;

  /// Post-group-filter injected set (ChatService.currentlyActiveLoreEntries).
  final Set<LorebookEntry> activeLore;

  const LorebookSection({
    super.key,
    required this.character,
    required this.activeLore,
  });

  @override
  Widget build(BuildContext context) {
    final entries =
        character.lorebook != null && character.lorebook!.entries.isNotEmpty
        ? character.lorebook!.entries.where((e) => e.enabled).toList()
        : <LorebookEntry>[];
    final hasLorebook =
        character.lorebook != null && character.lorebook!.entries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarSubHeader(
          icon: Icons.menu_book,
          label: 'Lorebook',
          accent: AppColors.porchHoneyOf(context),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: !hasLorebook
              ? Text(
                  'No lorebook entries.',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 12,
                  ),
                )
              : entries.isEmpty
              ? Text(
                  'No enabled entries.',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 12,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in entries)
                      _LoreEntryRow(
                        entry: entry,
                        label: entry.key.isEmpty && entry.constant
                            ? 'Always Active'
                            : entry.displayName,
                        verticalPadding: 4,
                        injected: activeLore.contains(entry),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Group-aware lorebook triggers panel for the group chat sidebar — active
/// entry count badge in the header, entries list always visible.
class GroupLorebookSection extends StatelessWidget {
  final ChatService chatService;
  const GroupLorebookSection({super.key, required this.chatService});

  @override
  Widget build(BuildContext context) {
    final activeEntries = chatService.getActiveGroupLoreEntries();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarSubHeader(
          icon: Icons.menu_book,
          label: 'Lorebook',
          accent: AppColors.porchHoneyOf(context),
          trailing: activeEntries.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bondHighOf(
                      context,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${activeEntries.length}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.bondHighOf(context),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: activeEntries.isEmpty
              ? Text(
                  'No active lorebook entries.',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 12,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in activeEntries)
                      _LoreEntryRow(
                        entry: entry,
                        label: entry.displayName,
                        verticalPadding: 3,
                        injected: true,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
