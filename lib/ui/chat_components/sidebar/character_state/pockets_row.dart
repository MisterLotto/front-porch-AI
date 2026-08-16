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

import 'package:front_porch_ai/services/chat/chat.dart'
    show PocketItem, PocketSection, Pockets;
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Sidebar Pockets rows — what the focused character is wearing and carrying,
/// with hand editing.
///
/// Purely presentational, like every other Character State widget: values
/// arrive as plain data and edits go back out through callbacks. The parent
/// writes to the record and the injection re-reads it next turn, so a hand
/// edit needs no extra plumbing — the same arrangement the Journal editor uses.
///
/// Editing by hand matters more here than it looks. The detection eval is a
/// model doing bookkeeping, and when it misses something the record quietly
/// stops matching the story. Being able to strike a line out yourself is what
/// keeps a wrong entry from becoming permanent.
class PocketsRow extends StatelessWidget {
  final Pockets pockets;

  /// Current story day — filters set-aside clothing the same way the prompt
  /// does, so the panel can never show yesterday's expired outfit in the
  /// window before the next pass rewrites the stored record.
  final int day;

  /// Remove one item. [section] picks the list; [index] is within it.
  final void Function({required PocketSection section, required int index})?
  onRemove;

  /// Open the add-item flow (the parent owns the dialog and the write, same
  /// as the eraser). When set, the panel renders even for an EMPTY record —
  /// otherwise the very first item could never be added by hand.
  final VoidCallback? onAdd;

  const PocketsRow({
    super.key,
    required this.pockets,
    required this.day,
    this.onRemove,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    // Set-aside things — parked in the scene (the nightstand, the doorway
    // table), still hers, greyed so "not on her" is legible at a glance.
    // Rendering this is load-bearing, not decoration: after an undress the
    // Wearing row goes empty, and an empty row with no explanation looks
    // exactly like the missed-update bug this feature used to have.
    final aside = [for (final e in pockets.setAsideOn(day)) e.item];
    if (pockets.worn.isEmpty &&
        pockets.carrying.isEmpty &&
        aside.isEmpty &&
        onAdd == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pockets & Wardrobe',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
            if (onAdd != null)
              InkWell(
                onTap: onAdd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 13,
                    color: AppColors.porchAmberOf(context),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (pockets.worn.isNotEmpty)
          _group(context, 'Wearing', pockets.worn, section: PocketSection.worn),
        if (pockets.carrying.isNotEmpty)
          _group(
            context,
            'Carrying',
            pockets.carrying,
            section: PocketSection.carrying,
          ),
        if (aside.isNotEmpty)
          _group(
            context,
            'Set aside',
            aside,
            section: PocketSection.setAside,
            dimmed: true,
          ),
      ],
    );
  }

  Widget _group(
    BuildContext context,
    String label,
    List<PocketItem> items, {
    required PocketSection section,
    bool dimmed = false,
  }) {
    final amber = AppColors.porchAmberOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary(context),
            ),
          ),
          const SizedBox(height: 3),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              for (var i = 0; i < items.length; i++)
                Container(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 4,
                    top: 2,
                    bottom: 2,
                  ),
                  decoration: BoxDecoration(
                    color: amber.withValues(alpha: dimmed ? 0.04 : 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: amber.withValues(alpha: dimmed ? 0.15 : 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          items[i].display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: dimmed
                                ? AppColors.textSecondary(context)
                                : AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      if (onRemove != null)
                        InkWell(
                          onTap: () => onRemove!(section: section, index: i),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                              Icons.close,
                              size: 11,
                              color: AppColors.textTertiary(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
