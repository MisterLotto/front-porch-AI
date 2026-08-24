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

import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

/// Shared greet / regenerated-swipe picker. Tapping a row pops with that
/// variant's index (commit-once — the caller applies it).
Future<int?> showVariantPickerDialog(
  BuildContext context, {
  required String title,
  required List<VariantOption> variants,
}) {
  return showWarmDialog<int>(
    context,
    title: title,
    icon: Icons.view_list,
    accent: AppColors.porchAmberOf(context),
    width: 440,
    content: SizedBox(
      width: 440,
      height: 360,
      child: variants.isEmpty
          ? Center(
              child: Text(
                'No variants.',
                style: TextStyle(color: AppColors.textTertiary(context)),
              ),
            )
          : ListView.separated(
              itemCount: variants.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: AppColors.borderOf(context).withValues(alpha: 0.5),
              ),
              itemBuilder: (context, i) {
                final v = variants[i];
                return ListTile(
                  dense: true,
                  selected: v.isCurrent,
                  selectedTileColor: AppColors.porchAmberOf(
                    context,
                  ).withValues(alpha: 0.12),
                  title: Text(
                    v.snippet.isEmpty ? '(empty)' : v.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  subtitle: Text(
                    '${v.charCount} characters',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary(context),
                    ),
                  ),
                  trailing: v.isCurrent
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.porchAmberOf(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Current',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onChaosAccent,
                            ),
                          ),
                        )
                      : Text(
                          '${v.index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary(context),
                          ),
                        ),
                  onTap: () => Navigator.pop(context, v.index),
                );
              },
            ),
    ),
    actions: [warmDialogCancel(context)],
  );
}
