// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Author seeds occupation and work hours. Not a weekday grid. Not an at-work switch.
// Occupation is free text; Hours is the story-time picker (the "Set story time"
// dial) run twice — once for a start, once for an end. Period words
// ("mornings") are not hours: the pickers only write a clock range, and
// presence_derive.dart only matches that range.

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Two fields next to Plan lines. Identity, not a schedule.
///
/// Occupation is a short free-text; Hours is the existing story-time picker
/// (the "Set story time" dial) shown twice — Start and End. The stored card
/// `hours` is derived from the two pickers ("9am–5pm"), and [hoursMatch]
/// reads that same string, so the chips and the "At work" range always agree.
class WorkRow extends StatefulWidget {
  final String occupation;
  final String hours;
  final ValueChanged<String> onOccupationChanged;
  final ValueChanged<String> onHoursChanged;

  const WorkRow({
    super.key,
    required this.occupation,
    required this.hours,
    required this.onOccupationChanged,
    required this.onHoursChanged,
  });

  @override
  State<WorkRow> createState() => _WorkRowState();
}

class _WorkRowState extends State<WorkRow> {
  static const _defaultStart = TimeOfDay(hour: 9, minute: 0);
  static const _defaultEnd = TimeOfDay(hour: 17, minute: 0);

  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    _apply(widget.hours);
  }

  @override
  void didUpdateWidget(WorkRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hours != widget.hours &&
        widget.hours !=
            formatWorkHoursRange(
              _start.hour * 60 + _start.minute,
              _end.hour * 60 + _end.minute,
            )) {
      _apply(widget.hours);
    }
  }

  void _apply(String hours) {
    final range = parseWorkHoursRange(hours);
    if (range == null) {
      _start = _defaultStart;
      _end = _defaultEnd;
      return;
    }
    _start = TimeOfDay(hour: range.$1 ~/ 60, minute: range.$1 % 60);
    _end = TimeOfDay(hour: range.$2 ~/ 60, minute: range.$2 % 60);
  }

  Future<void> _pick({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'Shift starts at…' : 'Shift ends at…',
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
    widget.onHoursChanged(
      formatWorkHoursRange(
        _start.hour * 60 + _start.minute,
        _end.hour * 60 + _end.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.porchAmberOf(context);
    final hoursSet = parseWorkHoursRange(widget.hours) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORK',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textTertiary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'What they do, and when. Not a calendar.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        _field(context),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _timeChip(
                context,
                amber,
                key: const ValueKey('work-start'),
                label: 'Start',
                t: _start,
                isStart: true,
                isSet: hoursSet,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '–',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary(context),
                ),
              ),
            ),
            Expanded(
              child: _timeChip(
                context,
                amber,
                key: const ValueKey('work-end'),
                label: 'End',
                t: _end,
                isStart: false,
                isSet: hoursSet,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The only free-text. [TextFormField.initialValue] — same pattern the
  /// original Hours field used, and the same one Day Number uses.
  Widget _field(BuildContext context) {
    final amber = AppColors.porchAmberOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Occupation',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary(context),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: widget.occupation,
          onChanged: widget.onOccupationChanged,
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'e.g. librarian',
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary(context),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.borderOf(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: amber),
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeChip(
    BuildContext context,
    Color amber, {
    required Key key,
    required String label,
    required TimeOfDay t,
    required bool isStart,
    required bool isSet,
  }) {
    return InkWell(
      key: key,
      onTap: () => _pick(isStart: isStart),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerOf(context),
          border: Border.all(color: amber.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isSet
                  ? StoryClock.formatClock(
                      DateTime.utc(2000, 1, 1, t.hour, t.minute),
                    )
                  : 'Set',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSet
                    ? AppColors.textPrimary(context)
                    : AppColors.textTertiary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
