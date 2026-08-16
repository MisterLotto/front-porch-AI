// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/context_viewer_snapshot.dart';

void main() {
  test('round-trip last-send snapshot JSON', () {
    final snap = ContextViewerSnapshot(
      budget: const {'System Prompt': 40, 'Chat History': 120},
      sections: const {
        'System Prompt': 'You are Misty.',
        'Chat History': 'User: hi\nMisty: hello',
      },
      source: ContextBudgetSource.lastSend,
      assembledAt: DateTime.utc(2026, 8, 6, 12, 0),
      contextLimit: 8192,
    );
    final restored = ContextViewerSnapshot.fromJsonString(snap.toJsonString());
    expect(restored, isNotNull);
    expect(restored!.budget['Chat History'], 120);
    expect(restored.sections['System Prompt'], 'You are Misty.');
    expect(restored.source, ContextBudgetSource.lastSend);
    expect(restored.contextLimit, 8192);
  });

  test('store sticky last-send survives estimate overlay', () {
    final store = ContextBudgetStore();
    store.recordLastSend(
      budgetMap: const {'Chat History': 50},
      sectionMap: const {'Chat History': 'a: b'},
      contextLimit: 4096,
    );
    store.apply(
      ContextViewerSnapshot(
        budget: const {'Chat History': 80, 'Persona': 10},
        sections: const {'Chat History': 'longer', 'Persona': 'me'},
        source: ContextBudgetSource.estimate,
      ),
    );
    expect(store.source, ContextBudgetSource.estimate);
    final json = store.persistJson(contextLimit: 4096);
    expect(json, isNotNull);
    final again = ContextBudgetStore()..loadFromJson(json);
    expect(again.budget['Chat History'], 50);
    expect(again.source, ContextBudgetSource.lastSend);
  });

  test('estimate builder counts history and system', () {
    final snap = buildContextBudgetEstimate(
      const ContextBudgetEstimateInput(
        systemPrompt: 'SYS', // 3 chars -> 1 token
        historyLines: ['User: hello there'],
        contextLimit: 2048,
      ),
    );
    expect(snap.source, ContextBudgetSource.estimate);
    expect(snap.budget.containsKey('System Prompt'), isTrue);
    expect(snap.budget.containsKey('Chat History'), isTrue);
    expect(snap.isEmpty, isFalse);
  });
}
