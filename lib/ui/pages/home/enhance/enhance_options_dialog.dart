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

import 'package:front_porch_ai/services/chargen/chargen.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

/// AI Enhance pre-flight: which card fields to rewrite, plus the 18+ toggle.
/// Returns null on cancel. Backend/model choice happens BEFORE this dialog on
/// the EnhanceSetupPage (the creator's full Backend & Model step).
Future<({EnhanceSelection selection, bool nsfw})?> showEnhanceOptionsDialog(
  BuildContext context, {
  required String characterName,
  required bool defaultNsfw,
  required int userTurnCount,
}) {
  var description = true;
  var personality = true;
  var exampleDialogue = true;
  var scenario = false;
  var greetings = false;
  var lorebook = false;
  var nsfw = defaultNsfw;

  return showWarmDialog<({EnhanceSelection selection, bool nsfw})>(
    context,
    title: 'AI Enhance $characterName',
    icon: Icons.auto_awesome,
    accent: AppColors.porchAmberOf(context),
    width: 440,
    content: StatefulBuilder(
      builder: (context, setState) {
        Widget row(
          String label,
          String hint,
          bool value,
          ValueChanged<bool> onChanged,
        ) {
          return CheckboxListTile(
            value: value,
            onChanged: (v) => setState(() => onChanged(v ?? false)),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.porchAmberOf(context),
            checkColor: AppColors.onChaosAccent,
            contentPadding: EdgeInsets.zero,
            title: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary(context),
              ),
            ),
            subtitle: Text(
              hint,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary(context),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rewrites the parts you pick using the real chat as the source '
                'of truth, then shows you every change before anything is '
                'saved. The result becomes a NEW "$characterName (Enhanced)" '
                'character — the original is never touched.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
              if (userTurnCount < 2) ...[
                const SizedBox(height: 8),
                Text(
                  'Heads up: this chat is very short, so the AI has little to '
                  'work with — results may be thin.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.porchHoneyOf(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              row(
                'Description',
                'Physical appearance, rewritten with detail from the story',
                description,
                (v) => description = v,
              ),
              row(
                'Personality',
                'Inner traits grounded in how they actually behaved',
                personality,
                (v) => personality = v,
              ),
              row(
                'Example dialogue',
                'Teaching lines mined from their real voice in the chat',
                exampleDialogue,
                (v) => exampleDialogue = v,
              ),
              Divider(color: AppColors.borderOf(context)),
              row(
                'Scenario',
                'Re-anchor the opening situation to where the story went',
                scenario,
                (v) => scenario = v,
              ),
              row(
                'First message + alternates',
                'Fresh openings written in the voice from the chat',
                greetings,
                (v) => greetings = v,
              ),
              row(
                'Lorebook',
                'World entries built from places and facts the story revealed',
                lorebook,
                (v) => lorebook = v,
              ),
              Divider(color: AppColors.borderOf(context)),
              SwitchListTile(
                value: nsfw,
                onChanged: (v) => setState(() => nsfw = v),
                dense: true,
                activeThumbColor: AppColors.porchAmberOf(context),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Allow 18+ themes',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                subtitle: Text(
                  'Lets suggestive material from the chat shape the card',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
    actions: [
      warmDialogCancel(context),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.porchAmberOf(context),
          foregroundColor: AppColors.onChaosAccent,
        ),
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Enhance'),
        onPressed: () {
          final selection = EnhanceSelection(
            description: description,
            personality: personality,
            exampleDialogue: exampleDialogue,
            scenario: scenario,
            greetings: greetings,
            lorebook: lorebook,
          );
          if (!selection.anySelected) return;
          Navigator.of(context).pop((selection: selection, nsfw: nsfw));
        },
      ),
    ],
  );
}
