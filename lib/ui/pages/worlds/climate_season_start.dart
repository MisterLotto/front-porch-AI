// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Matches kClimateDanger on the climate editor cards.
const Color _clash = Color(0xFFE0644C); // theme-keep: mockup danger

/// Non-leap year so the Material calendar has no Feb 29 — the climate year
/// is 365 days. first/lastDate pin this year so the picker cannot walk off.
const int _kSeasonPickerYear = 2001;

/// Month + day start for one season. Opens the same [showDatePicker]
/// Story begins uses; stacked Jan/Feb dropdowns overflowed the dialog.
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
    final amber = AppColors.porchAmberOf(context);
    final color = clash ? _clash : AppColors.textSecondary(context);
    final cap = daysInMonth365(month);
    final safeDay = day.clamp(1, cap);
    final label = '${kMonthShort[month - 1]} $safeDay';
    return Material(
      color: AppColors.surfaceContainerOf(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _pick(context, safeDay),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: clash ? _clash : amber.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 13, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, int safeDay) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_kSeasonPickerYear, month, safeDay),
      firstDate: DateTime(_kSeasonPickerYear, 1, 1),
      lastDate: DateTime(_kSeasonPickerYear, 12, 31),
      helpText: 'Season starts',
    );
    if (picked == null) return;
    onStart(picked.month, picked.day.clamp(1, daysInMonth365(picked.month)));
  }
}
