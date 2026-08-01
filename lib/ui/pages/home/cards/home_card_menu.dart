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

/// One row of a home-grid card's right-click menu. Character and group cards
/// were each hand-rolling the identical 18-line PopupMenuItem/ListTile shape
/// per entry (≈14 copies between them), which is what pushed
/// character_grid_card past the size cap. Colours default to the standard
/// treatment; [iconColor]/[labelColor] cover the accented (amber) and
/// destructive (red) rows.
PopupMenuItem<String> homeCardMenuItem(
  BuildContext context, {
  required String value,
  required IconData icon,
  required String label,
  Color? iconColor,
  Color? labelColor,
}) {
  return PopupMenuItem<String>(
    value: value,
    child: ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? AppColors.iconSecondary(context),
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(color: labelColor ?? AppColors.textPrimary(context)),
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
    ),
  );
}
