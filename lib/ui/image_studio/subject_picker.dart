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
import 'package:front_porch_ai/services/image_gen_service.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Subject selector for the Image Studio: what the image is *of*.
///
/// The three subjects map onto the surviving [ImageGenMode]s:
/// - **Freeform** → `customPrompt` (type anything; blank + Craft pictures the scene)
/// - **Character** → `characterPortrait` (the active chat character's appearance)
/// - **Your persona** → `userAvatar` (the user persona's appearance)
///
/// Picking Character/Persona auto-fills the prompt from their appearance (handled
/// by the coordinator); the box stays fully editable.
class SubjectPicker extends StatelessWidget {
  final ImageGenMode selected;

  /// The active chat character's display name. When null/empty the Character
  /// option is disabled (nothing to portray).
  final String? characterName;

  final ValueChanged<ImageGenMode>? onChanged;

  const SubjectPicker({
    super.key,
    required this.selected,
    required this.characterName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasCharacter = (characterName ?? '').trim().isNotEmpty;
    final options = <(ImageGenMode, String, IconData, bool)>[
      (ImageGenMode.customPrompt, 'Freeform', Icons.brush, true),
      (
        ImageGenMode.characterPortrait,
        hasCharacter ? characterName!.trim() : 'Character',
        Icons.face,
        hasCharacter,
      ),
      (ImageGenMode.userAvatar, 'Your persona', Icons.person, true),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final (mode, label, icon, enabled) = o;
            final isSel = mode == selected;
            final accent = AppColors.formMasterAccent;
            return OutlinedButton.icon(
              onPressed: (onChanged == null || !enabled)
                  ? null
                  : () => onChanged!(mode),
              icon: Icon(
                icon,
                size: 16,
                color: isSel ? accent : AppColors.iconSecondary(context),
              ),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSel
                      ? AppColors.textPrimary(context)
                      : AppColors.textSecondary(context),
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                side: BorderSide(
                  color: isSel ? accent : AppColors.borderOf(context),
                ),
                backgroundColor: isSel ? AppColors.cardOf(context) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
