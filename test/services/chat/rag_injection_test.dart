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

// THE RAG INJECTION LEAF (rag_injection.dart, 2026-08-10 memory review).
//
// Temporal grounding + the retrieval receipt: a retrieved line used to be
// injected naked, so a Day-2 "I never want to see you again" read exactly
// like the scene's present and contradicted the recap's chronology. These
// pin the pure pieces: the story-day resolver, the display order (cross-chat
// first, then own-chat oldest → newest — display ONLY; packing stays by
// relevance), the line stamps, and the receipt wire shape.
//
// Guards proven to fail before passing:
//   * make storyDayAt read only the span (drop the backward walk) → the
//     nearest-earlier test goes red
//   * make chronologicalRagOrder return its input → the ordering tests go red
//   * drop the stamp from formatRagLine → the stamp tests go red
//   * truncate nothing in buildRagReceipt → the preview-cap test goes red

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/services/memory_service.dart'
    show RetrievedMemory;

ChatMessage _msg(String text, {int? day}) => ChatMessage(
  text: text,
  sender: 'Nia',
  isUser: false,
  metadata: day == null
      ? null
      : {
          'realism_state': {'dayCount': day},
        },
);

RetrievedMemory _mem(
  String content, {
  required String sessionId,
  required int pos,
  int? end,
  double score = 0.9,
}) => RetrievedMemory(
  content: content,
  characterId: 'c1',
  sessionId: sessionId,
  positionStart: pos,
  positionEnd: end ?? pos,
  score: score,
);

void main() {
  group('storyDayAt', () {
    test('reads the first day inside the span', () {
      final msgs = [_msg('a'), _msg('b', day: 2), _msg('c', day: 3)];
      expect(storyDayAt(msgs, 1, 2), 2);
    });

    test('falls back to the nearest EARLIER day when the span has none', () {
      final msgs = [_msg('a', day: 4), _msg('b'), _msg('c')];
      expect(
        storyDayAt(msgs, 1, 2),
        4,
        reason:
            'day only moves forward, so the nearest realism_state before the '
            'span is the day the span happened on — a span-only read leaves '
            'metadata-sparse histories unstamped for no reason',
      );
    });

    test('no realism_state anywhere → null (no false precision)', () {
      expect(storyDayAt([_msg('a'), _msg('b')], 0, 1), isNull);
    });

    test('out-of-range spans clamp instead of throwing', () {
      final msgs = [_msg('a', day: 1)];
      expect(storyDayAt(msgs, 0, 99), 1);
      expect(storyDayAt(const [], 0, 0), isNull);
    });
  });

  group('chronologicalRagOrder', () {
    test('cross-chat lines lead; own-chat lines run oldest → newest', () {
      final ordered = chronologicalRagOrder([
        _mem('own-new', sessionId: 's1', pos: 50, score: 0.95),
        _mem('other', sessionId: 's2', pos: 7, score: 0.9),
        _mem('own-old', sessionId: 's1', pos: 3, score: 0.85),
      ], 's1');
      expect(ordered.map((m) => m.content).toList(), [
        'other',
        'own-old',
        'own-new',
      ]);
    });

    test('is display-only: the input list is not mutated', () {
      final input = [
        _mem('b', sessionId: 's1', pos: 9),
        _mem('a', sessionId: 's1', pos: 1),
      ];
      chronologicalRagOrder(input, 's1');
      expect(
        input.first.content,
        'b',
        reason:
            'packing trims by relevance from the ORIGINAL order — a sort '
            'that mutated its input would make chronology decide which '
            'memories survive the budget',
      );
    });
  });

  group('formatRagLine', () {
    test('own-chat line carries its story day', () {
      expect(
        formatRagLine('Nia: the swing creaked', day: 3, otherChat: false),
        '- (Day 3) Nia: the swing creaked',
      );
    });

    test('cross-chat line says so instead of borrowing this story\'s days', () {
      expect(
        formatRagLine('You: the red kite', day: null, otherChat: true),
        '- (another chat) You: the red kite',
      );
    });

    test('unknown day → unstamped, not a guess', () {
      expect(
        formatRagLine('Nia: hm', day: null, otherChat: false),
        '- Nia: hm',
      );
    });
  });

  group('buildRagReceipt', () {
    test('wire shape: counts + per-line pos/day/other_chat/preview', () {
      final own = _mem('short own line', sessionId: 's1', pos: 12);
      final other = _mem('other chat line', sessionId: 's2', pos: 4);
      final r = buildRagReceipt(
        found: 5,
        journalDeduped: 2,
        budgetTrimmed: 1,
        injected: [other, own],
        days: {own: 3, other: null},
        currentSessionId: 's1',
      );
      expect(r['found'], 5);
      expect(r['journal_deduped'], 2);
      expect(r['budget_trimmed'], 1);
      // audit P2.17 — successful search is status ok (never null/missing lie)
      expect(r['status'], kRagReceiptOk);
      final lines = r['injected'] as List;
      expect(lines, hasLength(2));
      expect(lines[0], {
        'pos': 4,
        'day': null,
        'other_chat': true,
        'preview': 'other chat line',
      });
      expect(lines[1], {
        'pos': 12,
        'day': 3,
        'other_chat': false,
        'preview': 'short own line',
      });
    });

    test('previews are capped — receipts are a glance, not a copy', () {
      final long = _mem('x' * 500, sessionId: 's1', pos: 0);
      final r = buildRagReceipt(
        found: 1,
        journalDeduped: 0,
        budgetTrimmed: 0,
        injected: [long],
        days: {long: 1},
        currentSessionId: 's1',
      );
      final preview =
          ((r['injected'] as List).single as Map)['preview'] as String;
      expect(preview.length, kRagReceiptPreviewChars + 1); // +1 for the '…'
      expect(preview.endsWith('…'), isTrue);
    });

    test('error and not_operational statuses are distinct wire values', () {
      // audit P2.17 — panel must never say "no lookup needed" after a failed
      // or non-operational attempt; status is what distinguishes them.
      final err = buildRagReceipt(
        found: 0,
        journalDeduped: 0,
        budgetTrimmed: 0,
        injected: const [],
        days: const {},
        currentSessionId: 's1',
        status: kRagReceiptError,
      );
      final dead = buildRagReceipt(
        found: 0,
        journalDeduped: 0,
        budgetTrimmed: 0,
        injected: const [],
        days: const {},
        currentSessionId: 's1',
        status: kRagReceiptNotOperational,
      );
      expect(err['status'], kRagReceiptError);
      expect(dead['status'], kRagReceiptNotOperational);
      expect(err['status'], isNot(dead['status']));
    });
  });
}
