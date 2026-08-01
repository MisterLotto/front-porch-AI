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
import 'package:front_porch_ai/services/chat/prompt_injection/world_injection.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// The world editor's "Place traits" section (living-worlds.md §3 Rev.3):
/// atmosphere + gravity dropdowns, stance-recipe style — a small structured
/// pick, the app writes the behavior line, defaults are silent and free.
/// Extracted so the (already oversized) world_management_page doesn't grow.
class PlaceTraitsEditor extends StatelessWidget {
  const PlaceTraitsEditor({
    super.key,
    required this.atmosphere,
    required this.gravity,
    required this.onAtmosphere,
    required this.onGravity,
  });

  final WorldAtmosphere atmosphere;
  final WorldGravity gravity;
  final ValueChanged<WorldAtmosphere> onAtmosphere;
  final ValueChanged<WorldGravity> onGravity;

  static const Map<WorldAtmosphere, String> _atmosphereLabels = {
    WorldAtmosphere.breathable: 'Breathable (normal)',
    WorldAtmosphere.thin: 'Thin — masks for exertion',
    WorldAtmosphere.unbreathable: 'Unbreathable — sealed suits',
    WorldAtmosphere.hostile: 'Hostile — damages skin and gear',
  };

  static const Map<WorldGravity, String> _gravityLabels = {
    WorldGravity.earth: 'Earth (normal)',
    WorldGravity.low: 'Low — bounding strides',
    WorldGravity.high: 'High — heavy limbs',
    WorldGravity.micro: 'Micro — everything floats',
  };

  @override
  Widget build(BuildContext context) {
    final atmoLine = atmosphereLine(atmosphere);
    final gravLine = gravityLine(gravity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLACE TRAITS',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: AppColors.porchAmberOf(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Standing facts about this place. Defaults are silent; anything '
          'else adds one line the character always knows.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary(context),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _traitDropdown<WorldAtmosphere>(
                context,
                label: 'Atmosphere',
                value: atmosphere,
                labels: _atmosphereLabels,
                onChanged: onAtmosphere,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _traitDropdown<WorldGravity>(
                context,
                label: 'Gravity',
                value: gravity,
                labels: _gravityLabels,
                onChanged: onGravity,
              ),
            ),
          ],
        ),
        if (atmoLine != null || gravLine != null) ...[
          const SizedBox(height: 8),
          Text(
            [atmoLine, gravLine].nonNulls.map((l) => '“$l”').join('\n'),
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _traitDropdown<T>(
    BuildContext context, {
    required String label,
    required T value,
    required Map<T, String> labels,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerOf(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.surfaceContainerOf(context),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary(context),
              ),
              items: [
                for (final e in labels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
