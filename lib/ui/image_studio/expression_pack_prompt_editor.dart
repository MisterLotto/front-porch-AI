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

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/expression_pack_service.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Prefilled prompt editor for one slot, opened from the pencil that appears
/// after the app's automatic re-roll didn't satisfy. A non-empty result
/// becomes the slot's custom prompt (kept for every later re-roll of that
/// slot); Cancel changes nothing.
Future<void> editPackSlotPrompt(
  BuildContext context,
  ExpressionPackSession session,
  int index,
) async {
  final controller = TextEditingController(
    text: session.effectivePromptFor(index),
  );
  final emotion = session.slots[index].emotion;
  final edited = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Re-roll «$emotion» with your prompt',
        style: TextStyle(fontSize: 15, color: AppColors.textPrimary(context)),
      ),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          minLines: 3,
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textPrimary(context),
            height: 1.4,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.borderOf(context)),
            ),
            helperText:
                'Your wording replaces the automatic prompt for this slot '
                '(this and future re-rolls).',
            helperMaxLines: 2,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(controller.text),
          icon: const Icon(Icons.casino_outlined, size: 16),
          label: const Text('Re-roll'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.formMasterAccent,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
  controller.dispose();
  if (edited != null && edited.trim().isNotEmpty) {
    unawaited(session.reroll(index, promptOverride: edited));
  }
}
