// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Matches kClimateDanger on the climate editor cards.
const Color _clash = Color(0xFFE0644C); // theme-keep: mockup danger

/// Month + day start for one season. Clash paints the numbers danger-red.
class SeasonStartRow extends StatelessWidget {
  const SeasonStartRow({
    super.key,
    required this.month,
    required this.day,
    required this.onStart,
    this.clash = false,
  });

  final int month;
  final int day;
  final void Function(int month, int day) onStart;
  final bool clash;

  @override
  Widget build(BuildContext context) {
    final color = clash ? _clash : AppColors.textSecondary(context);
    final style = TextStyle(fontSize: 11.5, color: color);
    final surface = AppColors.surfaceContainerOf(context);
    return Row(
      children: [
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: month,
              isDense: true,
              isExpanded: true,
              dropdownColor: surface,
              style: style,
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(kMonthShort[m - 1])),
              ],
              onChanged: (m) {
                if (m == null) return;
                onStart(m, day.clamp(1, daysInMonth365(m)));
              },
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: day.clamp(1, daysInMonth365(month)),
              isDense: true,
              isExpanded: true,
              dropdownColor: surface,
              style: style,
              items: [
                for (var d = 1; d <= daysInMonth365(month); d++)
                  DropdownMenuItem(value: d, child: Text('$d')),
              ],
              onChanged: (d) {
                if (d != null) onStart(month, d);
              },
            ),
          ),
        ),
      ],
    );
  }
}
