// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Enhance review: one "Use this" for the Porch Life chip lists, same
// keep-or-accept shape as description / personality.

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/chargen/chargen.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

class EnhancePorchLifeReview extends StatelessWidget {
  const EnhancePorchLifeReview({
    super.key,
    required this.use,
    required this.onUseChanged,
    required this.before,
    required this.ambitions,
    required this.onAmbitions,
    required this.likes,
    required this.onLikes,
    required this.dislikes,
    required this.onDislikes,
    required this.worn,
    required this.onWorn,
    required this.carrying,
    required this.onCarrying,
    required this.intimateInto,
    required this.onIntimateInto,
    required this.intimateNotInto,
    required this.onIntimateNotInto,
    required this.showIntimate,
  });

  final bool use;
  final ValueChanged<bool> onUseChanged;
  final PorchLifeIdentity before;
  final List<String> ambitions;
  final ValueChanged<List<String>> onAmbitions;
  final List<String> likes;
  final ValueChanged<List<String>> onLikes;
  final List<String> dislikes;
  final ValueChanged<List<String>> onDislikes;
  final List<String> worn;
  final ValueChanged<List<String>> onWorn;
  final List<String> carrying;
  final ValueChanged<List<String>> onCarrying;
  final List<String> intimateInto;
  final ValueChanged<List<String>> onIntimateInto;
  final List<String> intimateNotInto;
  final ValueChanged<List<String>> onIntimateNotInto;
  final bool showIntimate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Porch Life (wardrobe, ambitions, likes)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              Text(
                'Use this',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary(context),
                ),
              ),
              Switch(
                value: use,
                activeThumbColor: AppColors.porchAmberOf(context),
                onChanged: onUseChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _before(context, 'Ambitions', before.ambitions),
          _before(context, 'Likes', before.likes),
          _before(context, 'Dislikes', before.dislikes),
          _before(context, 'Wearing', before.worn),
          _before(context, 'Carrying', before.carrying),
          if (showIntimate) ...[
            _before(context, 'Warms to', before.intimateInto),
            _before(context, 'Not interested in', before.intimateNotInto),
          ],
          const SizedBox(height: 8),
          Text(
            'After (editable)',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.porchAmberOf(context),
            ),
          ),
          const SizedBox(height: 6),
          IgnorePointer(
            ignoring: !use,
            child: Opacity(
              opacity: use ? 1 : 0.45,
              child: Column(
                children: [
                  ChipListEditor(
                    label: 'Ambitions',
                    values: ambitions,
                    onChanged: onAmbitions,
                    accent: true,
                  ),
                  const SizedBox(height: 10),
                  ChipListEditor(
                    label: 'Drawn to',
                    values: likes,
                    onChanged: onLikes,
                  ),
                  const SizedBox(height: 10),
                  ChipListEditor(
                    label: 'Put off by',
                    values: dislikes,
                    onChanged: onDislikes,
                  ),
                  const SizedBox(height: 10),
                  ChipListEditor(
                    label: 'Wearing',
                    values: worn,
                    onChanged: onWorn,
                  ),
                  const SizedBox(height: 10),
                  ChipListEditor(
                    label: 'Carrying',
                    values: carrying,
                    onChanged: onCarrying,
                  ),
                  if (showIntimate) ...[
                    const SizedBox(height: 10),
                    ChipListEditor(
                      label: 'Warms to',
                      values: intimateInto,
                      onChanged: onIntimateInto,
                    ),
                    const SizedBox(height: 10),
                    ChipListEditor(
                      label: 'Not interested in',
                      values: intimateNotInto,
                      onChanged: onIntimateNotInto,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _before(BuildContext context, String label, List<String> values) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: ${values.isEmpty ? '(empty)' : values.join(', ')}',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
      ),
    );
  }
}
