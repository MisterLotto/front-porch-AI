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

/// Settings menu item row (extracted).
///
/// Icons/labels are brightness-aware (audit P3): the popup uses
/// [AppColors.surfaceContainerOf], so hard-coded white was invisible on
/// light-mode paper surfaces.
class SettingsMenuItem extends StatelessWidget {
  const SettingsMenuItem({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.iconSecondary(context)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
