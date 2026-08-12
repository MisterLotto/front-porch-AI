// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/reasoning_effort.dart';

void main() {
  setUp(kLearnedReasoningEffortsByModel.clear);

  test('app levels have titles and blurbs', () {
    for (final id in kAppReasoningEfforts) {
      expect(reasoningEffortTitle(id), isNotEmpty);
      expect(reasoningEffortBlurb(id), isNotEmpty);
    }
  });

  test(':thinking models map low/medium to high on the wire', () {
    const model = 'deepseek/deepseek-v4-flash:thinking';
    expect(wireReasoningEffort(model, 'low'), 'high');
    expect(wireReasoningEffort(model, 'medium'), 'high');
    expect(wireReasoningEffort(model, 'high'), 'high');
    expect(wireReasoningEffort(model, 'max'), 'max');
    expect(reasoningEffortIsRemapped(model, 'low'), isTrue);
    expect(reasoningEffortIsRemapped(model, 'high'), isFalse);
  });

  test('mapping caption names the accepted tiers and the wire value', () {
    const model = 'deepseek/deepseek-v4-flash:thinking';
    final cap = reasoningEffortMappingCaption(model, 'low');
    expect(cap, contains('High'));
    expect(cap.toLowerCase(), contains('sent as'));
    expect(cap, contains('Low'));
  });

  test('plain models pass the user pick through until a 400 teaches them', () {
    expect(wireReasoningEffort('acme/gpt-lite', 'low'), 'low');
    rememberReasoningEffortsForModel(
      'acme/gpt-lite',
      {'none', 'high', 'max'},
    );
    expect(wireReasoningEffort('acme/gpt-lite', 'low'), 'high');
  });
}
