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

import 'package:front_porch_ai/services/chat/chat.dart' show AmbitionService;
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Sidebar Ambitions rows (Living Time §6) — 🧭 text, stage word, and a thin
/// stage bar per ambition, visible from the FIRST frame of a fresh chat so
/// the system is never invisible (smoke-test feedback 2026-07-21: lazily
/// created progress cards meant zero UI until the first tick). Purely
/// presentational — values arrive from ChatService.ambitionsFor via the
/// parent (the plain-values bridge every Character State widget uses);
/// meters are fine in UI, the words-only rule is for prompts.
class AmbitionsRow extends StatelessWidget {
  final List<({String text, int progress})> ambitions;

  /// Ambition text → the open quest serving it, from
  /// [AmbitionService.activeStepsFrom]. Optional and defaulted so a caller
  /// with no objectives to hand renders exactly what it always did; an
  /// ambition with no active step simply shows no step line.
  final Map<String, String> steps;

  const AmbitionsRow({
    super.key,
    required this.ambitions,
    this.steps = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (ambitions.isEmpty) return const SizedBox.shrink();
    final amber = AppColors.porchAmberOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ambitions',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 4),
        for (final a in ambitions)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Tooltip(
              message: [
                '${a.text} — ${AmbitionService.stageWord(a.progress)}.',
                if (steps[a.text] != null)
                  'Working on it now: ${steps[a.text]}',
                'Progress moves when quests that serve it complete.',
              ].join('\n'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🧭', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          a.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AmbitionService.stageWord(a.progress),
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: a.progress >= 100
                              ? amber
                              : AppColors.textTertiary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: a.progress.clamp(0, 100) / 100,
                      minHeight: 3,
                      backgroundColor: AppColors.borderOf(
                        context,
                      ).withValues(alpha: 0.25),
                      valueColor: AlwaysStoppedAnimation<Color>(amber),
                    ),
                  ),
                  // The active step (v46). Since ambitions started steering
                  // objectives, each quest records which mountain it climbs —
                  // this is the reader for that, so a long-horizon goal shows
                  // the switchback being walked right now instead of only a
                  // bar that moves once a quest finishes. Indented to clear
                  // the 🧭 and tinted with the Objectives accent so the two
                  // panels visibly belong to each other.
                  if (steps[a.text] != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 3),
                      child: Text(
                        '↳ ${steps[a.text]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.taskAccentOf(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
