// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import 'package:flutter/material.dart';

import 'package:front_porch_ai/ui/pages/repository/stoop_glass.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// The share wizard's top-bar step indicator — the horizontal dots + labels +
/// connecting lines every "Create X" flow in the app wears (CLAUDE.md's wizard
/// rule), in Stoop colours.
///
/// Lifted out of stoop_upload_page.dart, which is chrome the page rebuilt from
/// three private builders and nothing else on that page needed. The page was
/// nine lines from the 1,000-line ratchet; this is presentation with no state
/// of its own, so it moves cleanly.
class StoopWizardSteps extends StatelessWidget {
  /// One label per step, in order.
  final List<String> steps;

  /// The zero-based step the wizard is on. Earlier steps render as done.
  final int current;

  const StoopWizardSteps({
    super.key,
    required this.steps,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      children.add(_dot(context, i, steps[i]));
      if (i < steps.length - 1) children.add(_line(context));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
  }

  Widget _dot(BuildContext context, int step, String label) {
    final isActive = current >= step;
    final isCurrent = current == step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isActive ? stoopAmberGradient : null,
            color: isActive ? null : stoopBg1(context),
            border: isCurrent
                ? Border.all(color: stoopCream(context), width: 2)
                : isActive
                ? null
                : Border.all(color: stoopBorderHi(context)),
          ),
          child: Center(
            child: isActive && !isCurrent
                ? const Icon(
                    Icons.check,
                    size: 14,
                    color: AppColors.stoopAmberInk,
                  )
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? AppColors.stoopAmberInk
                          : stoopMute(context),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isCurrent ? stoopAmberText(context) : stoopFaint(context),
          ),
        ),
      ],
    );
  }

  Widget _line(BuildContext context) => Container(
    width: 24,
    height: 2,
    margin: const EdgeInsets.only(bottom: 14),
    color: stoopBorder(context),
  );
}
