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

import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Reusable multi-line text editor for banned phrases.
///
/// Displays a section header, description, a multi-line [TextField] in a
/// rounded container, and an optional count footer. The parent owns the
/// controller and persistence; this widget owns only the presentation.
class BannedPhrasesEditor extends StatelessWidget {
  const BannedPhrasesEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.phraseCount,
    this.description = 'One phrase per line. If any appear during generation '
        'the model backtracks and retries.',
    this.maxLines = 6,
    this.backgroundColor,
  });

  final TextEditingController controller;
  final ValueChanged<List<String>> onChanged;
  final int phraseCount;
  final String description;
  final int maxLines;

  /// Container background color. Defaults to [AppColors.cardOf].
  final Color? backgroundColor;

  static const _hintText = 'shivers down\na cold shiver\nher eyes sparkled';

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.cardOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            color: AppColors.textTertiary(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: 2,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: _hintText,
              hintStyle: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
            ),
            onChanged: (val) {
              final phrases = val
                  .split('\n')
                  .where((s) => s.trim().isNotEmpty)
                  .map((s) => s.trim())
                  .toList();
              onChanged(phrases);
            },
          ),
        ),
        if (phraseCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '$phraseCount phrase${phraseCount == 1 ? '' : 's'} banned',
              style: TextStyle(
                color: AppColors.porchHoneyOf(context),
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}
