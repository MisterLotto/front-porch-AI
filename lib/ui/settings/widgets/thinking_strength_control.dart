// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Visible thinking-strength picker: three chips (Low / Medium / High) plus a
// live caption of how the pick maps onto the current model's accepted tiers.

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/reasoning_effort.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Segmented thinking-strength control used in Settings and per-chat settings.
class ThinkingStrengthControl extends StatelessWidget {
  const ThinkingStrengthControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.modelId = '',
    this.compact = false,
  });

  /// Current app pick: low | medium | high.
  final String value;

  final ValueChanged<String> onChanged;

  /// Active remote model id (e.g. deepseek/…:thinking). Empty = generic help.
  final String modelId;

  /// Tighter padding for dialogs.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.porchAmberOf(context);
    final selected = kAppReasoningEfforts.contains(value) ? value : 'medium';
    final caption = reasoningEffortMappingCaption(modelId, selected);
    final remapped = reasoningEffortIsRemapped(modelId, selected);
    final wire = wireReasoningEffort(modelId, selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thinking strength',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.w600,
            fontSize: compact ? 13 : 14,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 360;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in kAppReasoningEfforts)
                  _StrengthChip(
                    id: id,
                    selected: selected == id,
                    accent: accent,
                    wide: wide,
                    modelId: modelId,
                    onTap: () => onChanged(id),
                  ),
              ],
            );
          },
        ),
        SizedBox(height: compact ? 8 : 10),
        if (remapped)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.swap_horiz_rounded, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Maps to ${reasoningEffortTitle(wire)} on this model',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (remapped) SizedBox(height: compact ? 6 : 8),
        Text(
          caption.isEmpty
              ? 'How hard the model thinks before replying. Some models only '
                  'accept a subset of levels — Front Porch maps your pick to '
                  'the closest one they support.'
              : caption,
          style: TextStyle(
            color: AppColors.textTertiary(context),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _StrengthChip extends StatelessWidget {
  const _StrengthChip({
    required this.id,
    required this.selected,
    required this.accent,
    required this.wide,
    required this.modelId,
    required this.onTap,
  });

  final String id;
  final bool selected;
  final Color accent;
  final bool wide;
  final String modelId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wire = wireReasoningEffort(modelId, id);
    final showsMap = modelId.isNotEmpty && wire != id;
    final title = reasoningEffortTitle(id);
    final blurb = reasoningEffortBlurb(id);

    return Material(
      color: selected
          ? accent
          : AppColors.surfaceContainerOf(context),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: wide ? 112 : null,
          constraints: const BoxConstraints(minWidth: 96),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? accent
                  : AppColors.borderOf(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected
                      ? AppColors.onChaosAccent
                      : AppColors.textPrimary(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                showsMap
                    ? '→ ${reasoningEffortTitle(wire)}'
                    : blurb,
                style: TextStyle(
                  color: selected
                      ? AppColors.onChaosAccent.withValues(alpha: 0.85)
                      : AppColors.textTertiary(context),
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: showsMap ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
