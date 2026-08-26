// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A poke (or catalog seed) must survive process restart so we do not
// re-ask Nano for Kimi 2.6's menu every launch.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_porch_ai/services/reasoning_effort.dart';
import 'package:front_porch_ai/services/reasoning_effort_probe.dart';
import 'package:front_porch_ai/services/reasoning_effort_store.dart';

void main() {
  setUp(() async {
    clearReasoningEffortCatalog();
    clearReasoningEffortProbes();
    persistReasoningEffortMenuHook = null;
    SharedPreferences.setMockInitialValues({});
  });

  test('remembered menu reloads from prefs after a catalog clear', () async {
    final prefs = await SharedPreferences.getInstance();
    attachReasoningEffortMenuStore(prefs);
    rememberReasoningEffortsForModel('moonshotai/kimi-k2.6:thinking', {
      'none',
      'low',
      'high',
      'max',
    });

    clearReasoningEffortCatalog();
    clearReasoningEffortProbes();
    expect(
      kLearnedReasoningEffortsByModel.containsKey(
        'moonshotai/kimi-k2.6:thinking',
      ),
      isFalse,
    );

    attachReasoningEffortMenuStore(prefs);
    expect(reasoningEffortChipsFor('moonshotai/kimi-k2.6:thinking'), [
      'low',
      'high',
      'max',
    ]);
    expect(
      reasoningEffortMenuPending('moonshotai/kimi-k2.6:thinking'),
      isFalse,
    );
  });

  test('a stored LMS host enum hydrates as toggle-only', () async {
    final prefs = await SharedPreferences.getInstance();
    attachReasoningEffortMenuStore(prefs);
    rememberReasoningEffortsForModel('google/gemma-4-26B-A4B', {
      'none',
      'minimal',
      'low',
      'medium',
      'high',
      'xhigh',
    });

    clearReasoningEffortCatalog();
    clearReasoningEffortProbes();
    attachReasoningEffortMenuStore(prefs);
    expect(reasoningEffortIsToggleOnly('google/gemma-4-26B-A4B'), isTrue);
    expect(reasoningEffortChipsFor('google/gemma-4-26B-A4B'), isEmpty);
  });
}
