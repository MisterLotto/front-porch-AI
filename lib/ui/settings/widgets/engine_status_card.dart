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
import 'package:flutter/services.dart';

import 'package:front_porch_ai/services/engine_health.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Per-feature native-vs-legacy tally for the retired-sidecar engines
/// (Expressions / Kokoro / Piper / Voice input), fed live by [EngineHealth].
/// Green = ran on the built-in engine, amber = fell back to the legacy
/// Python helper (with the reason), grey = not used this session. The "Copy
/// report" button yields the same paste-ready text as the pre-release
/// fallback snackbar, so soak-testing users can hand over evidence in one
/// click.
class EngineStatusCard extends StatelessWidget {
  const EngineStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: EngineHealth.instance,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Whether each AI feature ran on the built-in engine this '
                'session, or fell back to the legacy Python helper.',
                style: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              for (final entry in EngineHealth.instance.entries)
                _row(context, entry),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: EngineHealth.instance.buildReport()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Engine report copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy report'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.porchAmberOf(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, EngineHealthEntry entry) {
    final unused = entry.nativeCount == 0 && entry.fallbackCount == 0;
    final fellBack = entry.fallbackCount > 0;
    final dotColor = unused
        ? AppColors.textTertiary(context)
        : fellBack
        ? AppColors.porchAmberOf(context)
        : AppColors.resolve(context, AppColors.logReady, AppColors.bondHighLight);
    final summary = unused
        ? 'not used yet'
        : fellBack
        ? 'legacy fallback ×${entry.fallbackCount}'
              '${entry.nativeCount > 0 ? ' · native ×${entry.nativeCount}' : ''}'
        : 'native ×${entry.nativeCount}';
    final reason = entry.lastFallbackReason;

    Widget detail = Text(
      reason == null ? summary : '$summary — $reason',
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
    );
    if (reason != null) {
      detail = Tooltip(message: reason, child: detail);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              entry.name,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: detail),
        ],
      ),
    );
  }
}
