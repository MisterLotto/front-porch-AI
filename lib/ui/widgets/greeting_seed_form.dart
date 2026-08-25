// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/pockets.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/chip_list_editor.dart';
import 'package:front_porch_ai/ui/widgets/slider_with_input.dart';
import 'package:front_porch_ai/ui/widgets/story_begins_row.dart';
import 'package:front_porch_ai/ui/widgets/synced_text_field.dart';

/// Compact opening-state editor for one alternate greeting.
///
/// Off (null) = this alt still gets reading-the-room. On = authored seed:
/// empty fields inherit the card/group defaults at chat start.
class GreetingSeedForm extends StatelessWidget {
  final GreetingRealismSeed? seed;
  final ValueChanged<GreetingRealismSeed?> onChanged;
  final bool showNeeds;
  final bool showInventory;

  const GreetingSeedForm({
    super.key,
    required this.seed,
    required this.onChanged,
    this.showNeeds = false,
    this.showInventory = false,
  });

  static const _times = [
    'dawn',
    'morning',
    'late_morning',
    'afternoon',
    'evening',
    'night',
  ];
  static const _intensities = ['mild', 'moderate', 'strong'];

  @override
  Widget build(BuildContext context) {
    final enabled = seed != null;
    final s = seed ?? const GreetingRealismSeed();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Custom opening state',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            enabled
                ? 'Blank fields inherit the card defaults. This alt will not '
                      'read the room.'
                : 'No seed — the engine reads the room from this greeting.',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
          value: enabled,
          onChanged: (on) => onChanged(on ? const GreetingRealismSeed() : null),
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          _labeledField(
            context,
            label: 'Emotion',
            child: SyncedTextField(
              value: s.characterEmotion ?? '',
              onChanged: (v) => onChanged(
                s.copyWith(
                  characterEmotion: v.trim().isEmpty ? null : v.trim(),
                ),
              ),
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
              ),
              decoration: _deco(context, 'e.g. furious, warm, guarded'),
            ),
          ),
          const SizedBox(height: 8),
          _dropdown(
            context,
            label: 'Intensity',
            value: s.emotionIntensity ?? 'moderate',
            items: _intensities,
            onChanged: (v) => onChanged(s.copyWith(emotionIntensity: v)),
          ),
          const SizedBox(height: 8),
          SliderWithInput(
            label: 'Short-term bond',
            value: (s.shortTermBond ?? 0).toDouble(),
            min: -300,
            max: 300,
            isInteger: true,
            divisions: 600,
            context: context,
            onChanged: (v) => onChanged(s.copyWith(shortTermBond: v.round())),
          ),
          SliderWithInput(
            label: 'Long-term bond',
            value: (s.longTermBond ?? 0).toDouble(),
            min: -300,
            max: 300,
            isInteger: true,
            divisions: 600,
            context: context,
            onChanged: (v) => onChanged(s.copyWith(longTermBond: v.round())),
          ),
          SliderWithInput(
            label: 'Trust',
            value: (s.trustLevel ?? 0).toDouble(),
            min: -100,
            max: 100,
            isInteger: true,
            divisions: 200,
            context: context,
            onChanged: (v) => onChanged(s.copyWith(trustLevel: v.round())),
          ),
          const SizedBox(height: 8),
          _dropdown(
            context,
            label: 'Time of day',
            value: s.timeOfDay ?? 'morning',
            items: _times,
            onChanged: (v) => onChanged(s.copyWith(timeOfDay: v)),
          ),
          const SizedBox(height: 8),
          _labeledField(
            context,
            label: 'Day number',
            child: SyncedTextField(
              value: (s.dayCount ?? 1).toString(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n >= 1) {
                  onChanged(s.copyWith(dayCount: n));
                }
              },
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
              ),
              decoration: _deco(context, null),
            ),
          ),
          const SizedBox(height: 8),
          StoryBeginsRow(
            storyStartDate: s.storyStartDate,
            onStoryStartDateChanged: (v) =>
                onChanged(s.copyWith(storyStartDate: v)),
            storyStartTime: s.storyStartTime,
            onStoryStartTimeChanged: (v) =>
                onChanged(s.copyWith(storyStartTime: v)),
          ),
          const SizedBox(height: 8),
          _labeledField(
            context,
            label: 'Starting task',
            child: SyncedTextField(
              value: s.currentTask ?? '',
              onChanged: (v) => onChanged(
                s.copyWith(currentTask: v.trim().isEmpty ? null : v.trim()),
              ),
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
              ),
              decoration: _deco(context, 'Optional in-voice objective'),
            ),
          ),
          if (showNeeds) ...[
            const SizedBox(height: 12),
            Text(
              'Needs baselines (0–100). Blank inherits the card.',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
              ),
            ),
            for (final need in _needs)
              SliderWithInput(
                label: need.$1,
                value: (need.$2(s) ?? 80).toDouble(),
                min: 0,
                max: 100,
                isInteger: true,
                divisions: 100,
                context: context,
                onChanged: (v) => onChanged(need.$3(s, v.round())),
              ),
          ],
          if (showInventory) ...[
            const SizedBox(height: 8),
            ChipListEditor(
              label: 'Wearing (this opening)',
              values: _wornOf(s),
              onChanged: (v) => _setWardrobe(s, worn: v),
              hintText: 'sundress (rain-soaked)',
            ),
            ChipListEditor(
              label: 'Carrying (this opening)',
              values: _carryingOf(s),
              onChanged: (v) => _setWardrobe(s, carrying: v),
              hintText: 'keys',
            ),
          ],
        ],
      ],
    );
  }

  static final _needs =
      <
        (
          String,
          int? Function(GreetingRealismSeed),
          GreetingRealismSeed Function(GreetingRealismSeed, int),
        )
      >[
        (
          'Hunger',
          (s) => s.needsBaselineHunger,
          (s, v) => s.copyWith(needsBaselineHunger: v),
        ),
        (
          'Bladder',
          (s) => s.needsBaselineBladder,
          (s, v) => s.copyWith(needsBaselineBladder: v),
        ),
        (
          'Energy',
          (s) => s.needsBaselineEnergy,
          (s, v) => s.copyWith(needsBaselineEnergy: v),
        ),
        (
          'Social',
          (s) => s.needsBaselineSocial,
          (s, v) => s.copyWith(needsBaselineSocial: v),
        ),
        (
          'Fun',
          (s) => s.needsBaselineFun,
          (s, v) => s.copyWith(needsBaselineFun: v),
        ),
        (
          'Hygiene',
          (s) => s.needsBaselineHygiene,
          (s, v) => s.copyWith(needsBaselineHygiene: v),
        ),
        (
          'Comfort',
          (s) => s.needsBaselineComfort,
          (s, v) => s.copyWith(needsBaselineComfort: v),
        ),
      ];

  List<String> _wornOf(GreetingRealismSeed s) {
    final inv = s.inventory;
    if (inv == null) return const [];
    return Pockets.fromJson(inv).worn.map((e) => e.display).toList();
  }

  List<String> _carryingOf(GreetingRealismSeed s) {
    final inv = s.inventory;
    if (inv == null) return const [];
    return Pockets.fromJson(inv).carrying.map((e) => e.display).toList();
  }

  void _setWardrobe(
    GreetingRealismSeed s, {
    List<String>? worn,
    List<String>? carrying,
  }) {
    final next = Pockets.cardJsonFrom(
      worn: worn ?? _wornOf(s),
      carrying: carrying ?? _carryingOf(s),
    );
    onChanged(s.copyWith(inventory: next.isEmpty ? null : next));
  }

  Widget _dropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return _labeledField(
      context,
      label: label,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: items.contains(value) ? value : items.first,
        items: [
          for (final i in items)
            DropdownMenuItem(value: i, child: Text(i.replaceAll('_', ' '))),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        decoration: _deco(context, null),
        dropdownColor: AppColors.surfaceContainerOf(context),
        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
      ),
    );
  }

  Widget _labeledField(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  InputDecoration _deco(BuildContext context, String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textTertiary(context).withValues(alpha: 0.6),
        fontSize: 13,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
