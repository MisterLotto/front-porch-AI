// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards PromptPlan.sectionTexts() — the source of the Context Viewer's
// per-section "what the model actually saw" text (which replaced the dead
// "(Tap to view full prompt)" placeholder). Its contract: keys line up
// 1:1 with budgetEstimates() so every counted row has its text, same-label
// sections concatenate in insertion order, and unlabeled/empty sections
// are skipped identically in both maps.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  test('sectionTexts keys line up exactly with budgetEstimates', () {
    final plan = PromptPlan()
      ..add(id: 'sys', text: 'You are Jennifer.', label: 'System Prompt')
      ..add(id: 'persona', text: 'The user is Sam.', label: 'Persona')
      ..add(id: 'unlabeled', text: 'invisible glue')
      ..add(id: 'empty', text: '', label: 'Scenario')
      ..add(id: 'history', text: 'Sam: hi\nJennifer: hey\n',
          label: 'Chat History');

    final budget = plan.budgetEstimates();
    final texts = plan.sectionTexts();

    expect(
      texts.keys.toList(),
      budget.keys.toList(),
      reason: 'every counted budget row must have its text (and only those) '
          'or the viewer shows counts with no content behind them',
    );
    expect(texts.containsKey('Scenario'), isFalse,
        reason: 'empty sections are skipped in both maps');
    expect(texts['System Prompt'], 'You are Jennifer.');
  });

  test('same-label sections concatenate in insertion order', () {
    final plan = PromptPlan()
      ..add(id: 'lore1', text: 'The porch. ', label: 'Lorebook')
      ..add(id: 'lore2', text: 'The swing.', label: 'Lorebook');

    expect(plan.sectionTexts()['Lorebook'], 'The porch. The swing.');
    // And the count covers the combined text, matching the estimator.
    expect(
      plan.budgetEstimates()['Lorebook'],
      ('The porch. The swing.'.length / 4).ceil(),
    );
  });
}
