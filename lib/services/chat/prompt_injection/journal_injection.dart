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

import 'package:front_porch_ai/database/database.dart';
import '../journal_store.dart';

/// The Journal — prompt injection builder (docs/design/journal-memory.md
/// §4.5). Tenth sibling of the prompt_injection builders: renders the
/// upcoming speaker's pinned + hot memory cards (with their felt emotions)
/// into a token-budgeted block injected right after the recap (summaryBlock)
/// in transcript assembly.
///
/// Requires NO embeddings — the Journal works without the RAG sidecar
/// (design invariant: local-model/no-setup floor). Strictly per-chat: loads
/// cards for the current session + speaker only.
///
/// Phase 1 heat is uniform (1.0), so the "hot set" is simply all cards under
/// the budget — pinned first, then newest first. Phase 2 adds the heat
/// threshold and mood-congruent boost.
class JournalInjection {
  final JournalStore store;
  final String? Function() getSessionId;

  JournalInjection({required this.store, required this.getSessionId});

  /// ~600 tokens at the shared chars/4 heuristic (same estimator the
  /// memoriesBlock budget uses).
  static const int kHotSetTokenBudget = 600;

  Future<String> buildJournalBlock({
    required String characterId,
    required String characterName,
    required String userName,
  }) async {
    final sessionId = getSessionId();
    if (sessionId == null || characterId.isEmpty) return '';

    final cards = await store.cardsFor(sessionId, characterId);
    if (cards.isEmpty) return '';

    // Pinned first (store order), then unpinned newest-first so recent
    // memories win the budget race.
    final pinned = cards.where((c) => c.pinned).toList();
    final unpinned = cards.where((c) => !c.pinned).toList().reversed;

    final lines = <String>[];
    var usedChars = 0;
    const budgetChars = kHotSetTokenBudget * 4;
    for (final card in [...pinned, ...unpinned]) {
      final line = '- (${_label(card, userName)}) ${card.content}';
      if (usedChars + line.length > budgetChars && lines.isNotEmpty) break;
      usedChars += line.length;
      lines.add(line);
    }
    if (lines.isEmpty) return '';

    return "[$characterName's private journal — personal memories from this "
        'chat, in their own words. These shape how they feel and behave:\n'
        '${lines.join('\n')}\n]\n';
  }

  /// "(a promise, felt hopeful)" / "(about Sam, once felt sad — now feels
  /// proud)" — category + emotional imprint, including the healed-feeling arc.
  String _label(JournalMemoryData card, String userName) {
    final category = switch (card.category) {
      'about_user' => 'about $userName',
      'about_us' => 'about us',
      'promise' => 'a promise',
      _ => 'a moment',
    };
    final emotion = card.emotionLabel;
    if (emotion == null || emotion.isEmpty) return category;
    if (card.originalEmotionLabel != null &&
        card.originalEmotionLabel != emotion) {
      return '$category, once felt ${card.originalEmotionLabel} — now feels '
          '$emotion';
    }
    final intensity = switch (card.emotionIntensity) {
      'strong' => ' (strongly)',
      'mild' => ' (mildly)',
      _ => '',
    };
    return '$category, felt $emotion$intensity';
  }
}
