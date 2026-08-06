// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Completeness checklist panel for the Stoop share wizard.

import 'package:flutter/material.dart';
import 'package:front_porch_ai/services/backporch/stoop_card_completeness.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_glass.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Shows required/optional field presence for a card about to be shared.
class StoopCompletenessPanel extends StatelessWidget {
  final StoopCompleteness completeness;

  const StoopCompletenessPanel({super.key, required this.completeness});

  @override
  Widget build(BuildContext context) {
    final hot = completeness.incomplete;
    final border = hot
        ? AppColors.stoopEmber.withValues(alpha: 0.55)
        : const Color(0xFF3ECF8E).withValues(alpha: 0.4);
    final bg = hot
        ? AppColors.stoopEmber.withValues(alpha: 0.1)
        : const Color(0xFF3ECF8E).withValues(alpha: 0.08);
    final accent = hot ? AppColors.stoopEmber : const Color(0xFF3ECF8E);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: accent, width: 3),
          top: BorderSide(color: border),
          right: BorderSide(color: border),
          bottom: BorderSide(color: border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hot
                ? 'Incomplete card — can’t submit yet'
                : 'Looks complete',
            style: TextStyle(
              color: stoopCream(context),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hot
                ? 'Missing required fields: '
                    '${completeness.missingCritical.join(', ')}. '
                    'Open the character (or group) editor, fill those fields, '
                    'save, then come back to share.'
                : 'Core greeting and identity fields are present. Double-check '
                    'the text and art before sending.',
            style: TextStyle(
              color: stoopCream2(context),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          ...completeness.fields.map((f) {
            final mark = f.present
                ? '✓'
                : f.critical
                    ? '✕'
                    : '·';
            final markColor = f.present
                ? const Color(0xFF3ECF8E)
                : f.critical
                    ? AppColors.stoopEmber
                    : stoopMute(context);
            final meta = f.present
                ? '${f.chars} chars'
                : f.critical
                    ? 'required'
                    : 'optional';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text(
                        mark,
                        style: TextStyle(
                          color: markColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        f.label,
                        style: TextStyle(
                          color: stoopCream2(context),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      meta,
                      style: TextStyle(
                        color: stoopMute(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          ...completeness.notes.map(
            (n) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                n,
                style: TextStyle(color: stoopMute(context), fontSize: 11.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
