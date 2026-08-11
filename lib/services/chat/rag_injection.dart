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

/// Pure helpers for the RAG injection block and its per-turn receipt
/// (story_clock.dart / journal_ops.dart analog: no I/O, no state — the god's
/// retrieval phase in chat_service_generation_rag.dart is the only caller,
/// and the dedicated test suite drives these directly).
///
/// Two jobs, both from the 2026-08-10 memory-systems review:
///
/// 1. **Temporal grounding.** A retrieved line used to be injected naked —
///    "Nia: I never want to see you again" from the Day-2 fight read exactly
///    like the scene's present, and where the recap's compressed chronology
///    said otherwise the model was handed a contradiction to argue with.
///    Every line now carries its story day (or "another chat"), and the
///    block is rendered oldest → newest so the lines agree with the recap's
///    timeline instead of competing with it. Budget PACKING stays in
///    relevance order — chronology decides how survivors are SHOWN, never
///    which memories survive.
///
/// 2. **The receipt.** Every decision the retrieval makes — found, deduped
///    against the journal, trimmed for budget, injected — was a debugPrint
///    and nothing else. [buildRagReceipt] compresses those decisions into a
///    metadata map stamped on the turn's message, which is what the sidebar
///    Memory panel and the web facade render. Keys are a WIRE FORMAT (they
///    persist in message metadata and cross the web relay): 'found',
///    'journal_deduped', 'budget_trimmed', 'injected' [{'pos', 'day',
///    'other_chat', 'preview'}].
library;

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/memory_service.dart'
    show RetrievedMemory;

/// How many chars of a memory ride the receipt as its preview. Receipts live
/// in every stamped message's metadata forever — store a glance, not a copy.
const int kRagReceiptPreviewChars = 140;

/// How far [storyDayAt] walks backward for a day stamp before giving up.
/// Day only moves forward, so the nearest earlier realism_state is correct;
/// the cap keeps a metadata-sparse history from costing a full scan.
const int kStoryDayLookbackCap = 200;

/// The story day at message span [positionStart..positionEnd] of [messages]:
/// the first `realism_state.dayCount` found inside the span, else the
/// nearest one strictly before it (day only moves forward), else null
/// (realism was off — the line simply goes unstamped).
int? storyDayAt(
  List<ChatMessage> messages,
  int positionStart,
  int positionEnd,
) {
  if (messages.isEmpty) return null;

  int? dayOf(int i) {
    final meta = messages[i].activeMetadata;
    final state = meta?['realism_state'];
    if (state is Map) {
      final d = (state['dayCount'] as num?)?.toInt();
      if (d != null) return d;
    }
    // Standalone clock / partial snapshots: day may ride the top-level
    // stamp written when the engine is off (release audit 2026-08-11).
    final top = meta?['story_day'] ?? meta?['storyDay'] ?? meta?['dayCount'];
    if (top is num) return top.toInt();
    return null;
  }

  final start = positionStart.clamp(0, messages.length - 1);
  final end = positionEnd.clamp(0, messages.length - 1);
  if (start > end) return null;
  for (var i = start; i <= end; i++) {
    final d = dayOf(i);
    if (d != null) return d;
  }
  final floor = (start - kStoryDayLookbackCap).clamp(0, start);
  for (var i = start - 1; i >= floor; i--) {
    final d = dayOf(i);
    if (d != null) return d;
  }
  return null;
}

/// The display order for a set of budget-surviving memories: cross-chat
/// lines first (their events predate this story's timeline; relative order
/// kept as given, i.e. by relevance), then this chat's own lines oldest →
/// newest. Pure reordering — call it on the survivors AFTER budget packing,
/// never before, or chronology starts deciding which memories fit.
List<RetrievedMemory> chronologicalRagOrder(
  List<RetrievedMemory> memories,
  String currentSessionId,
) {
  final others = <RetrievedMemory>[];
  final own = <RetrievedMemory>[];
  for (final m in memories) {
    (m.sessionId == currentSessionId ? own : others).add(m);
  }
  own.sort((a, b) => a.positionStart.compareTo(b.positionStart));
  return [...others, ...own];
}

/// One injection line: `- (Day 3) Nia: …` / `- (another chat) Nia: …`, or
/// unstamped when the day is unknowable (realism off — no false precision).
String formatRagLine(String content, {int? day, required bool otherChat}) {
  final stamp = otherChat
      ? '(another chat) '
      : day != null
      ? '(Day $day) '
      : '';
  return '- $stamp$content';
}

/// The receipt for one turn's retrieval, stamped into the generated
/// message's metadata as `rag_receipt`. [injected] is the FINAL set in
/// display order; [days] carries the stamp each line was rendered with.
Map<String, dynamic> buildRagReceipt({
  required int found,
  required int journalDeduped,
  required int budgetTrimmed,
  required List<RetrievedMemory> injected,
  required Map<RetrievedMemory, int?> days,
  required String currentSessionId,
}) {
  return {
    'found': found,
    'journal_deduped': journalDeduped,
    'budget_trimmed': budgetTrimmed,
    'injected': [
      for (final m in injected)
        {
          'pos': m.positionStart,
          'day': days[m],
          'other_chat': m.sessionId != currentSessionId,
          'preview': m.content.length <= kRagReceiptPreviewChars
              ? m.content
              : '${m.content.substring(0, kRagReceiptPreviewChars)}…',
        },
    ],
  };
}
