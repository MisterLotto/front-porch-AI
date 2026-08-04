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
import 'package:provider/provider.dart';

import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

/// "Reprocess Needs Deltas" — critique a message's Needs outcome and have the
/// Realism Director re-evaluate it.
///
/// Lifted out of message_bubble.dart when the per-need scope chips pushed that
/// file back over its god-file ratchet entry. It was never bubble logic; it
/// only lived there because that is where the button is.
///
/// The need chips are the point: leaving them all unticked reprocesses every
/// need, which makes the model re-emit all seven against the same scene text —
/// so a critique about energy would quietly re-roll hunger, hygiene and comfort
/// too. Ticking narrows the pass to exactly those needs and the rest keep the
/// deltas they already had.

void showReprocessNeedsDialog(BuildContext context, int index) {
  final chatService = Provider.of<ChatService>(context, listen: false);
  // The bubble's State is gone by the time the pass returns, so the snack
  // guards on the CALLER's context instead of a widget `mounted` flag.
  final host = context;
  final controller = TextEditingController();
  // Empty = every need, which is what this dialog always did. Ticking any
  // need narrows the pass to exactly those; the rest keep the deltas they
  // already have instead of being re-rolled against the same scene text.
  final selected = <String>{};
  // Capture for snack after dialog pop (A: user feedback on success/fail)
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: const Text('Reprocess Needs Deltas'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your critique to correct the Needs Simulation deltas. The Realism Director will re-evaluate the scene based on this input.',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: controller,
                  maxLines: 5,
                  minLines: 2,
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText:
                        'e.g., She rested on the sofa — energy should have improved.',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary(context),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Limit to these needs',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected.isEmpty
                      ? 'Nothing ticked — every need is re-evaluated.'
                      : 'Only the ticked needs change. The rest keep their current deltas.',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final need in NeedsSimulation.needKeys)
                      FilterChip(
                        label: Text(
                          '${need[0].toUpperCase()}${need.substring(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected.contains(need)
                                ? AppColors.onChaosAccent
                                : AppColors.textSecondary(context),
                          ),
                        ),
                        selected: selected.contains(need),
                        showCheckmark: false,
                        backgroundColor: AppColors.surfaceContainerOf(context),
                        selectedColor: AppColors.porchAmberOf(context),
                        side: BorderSide(color: AppColors.borderOf(context)),
                        onSelected: (on) => setSheetState(() {
                          if (on) {
                            selected.add(need);
                          } else {
                            selected.remove(need);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textTertiary(context)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.porchAmberOf(context),
              foregroundColor: AppColors.onChaosAccent,
            ),
            onPressed: () async {
              final text = controller.text.trim();
              final scope = Set<String>.from(selected);
              Navigator.of(context).pop();
              if (text.isNotEmpty) {
                bool success = false;
                try {
                  success = await chatService.manualReprocessNeeds(
                    index,
                    text,
                    onlyNeeds: scope,
                  );
                } catch (e) {
                  debugPrint('[Realism:Needs] reprocess error: $e');
                }
                if (host.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? (scope.isEmpty
                                  ? 'Needs deltas reprocessed with your critique.'
                                  : 'Reprocessed ${scope.join(', ')} with your critique.')
                            : 'Reprocess received no response from the model. Original deltas preserved.',
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            child: const Text('Reprocess'),
          ),
        ],
      ),
    ),
  );
}
