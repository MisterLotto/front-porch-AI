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

// ORPHAN `</think>` IN THE EVAL LANE (1.3 sweep, _idx 150).
//
// utils/think_tags.dart names three leak shapes; the eval strip handled two.
// The third — a bare closing tag whose opening tag the chat template or the
// transport consumed (the DeepSeek-R1 / QwQ prefill shape KoboldCpp runs with
// --jinja) — left the whole deliberation in front of the JSON. Every eval
// extractor is a firstMatch over that string, so the model's DRAFT numbers won
// over its final answer, and the same prompt at temp 0.1 could land on a
// different draft each regenerate.

import 'package:flutter_test/flutter_test.dart';

import 'llm_eval_engine_test.dart' show createTestLlmEvalEngine;

void main() {
  group('stripThinkBlocks — all three think-tag leak shapes', () {
    test('orphan closing tag: reasoning before it is dropped', () {
      final e = createTestLlmEvalEngine();
      const raw =
          'Let me weigh this. Maybe "relationship_delta": 2? No, this '
          'deserves more.\n</think>\n{"relationship_delta": 9, "trust_delta": 3}';

      final stripped = e.stripThinkBlocks(raw);

      expect(stripped, '{"relationship_delta": 9, "trust_delta": 3}');
      expect(
        e.extractJsonInt(stripped, 'relationship_delta'),
        9,
        reason: 'the final JSON must win, never the mid-think draft',
      );
    });

    test('balanced and unclosed shapes still behave as before', () {
      final e = createTestLlmEvalEngine();
      expect(
        e.stripThinkBlocks('<think>draft 2</think>{"trust_delta": 7}'),
        '{"trust_delta": 7}',
      );
      expect(
        e.stripThinkBlocks('{"trust_delta": 7}<think>still musing'),
        '{"trust_delta": 7}',
      );
    });

    test('nothing after the orphan tag leaves the text for the raw fallback',
        () {
      final e = createTestLlmEvalEngine();
      const raw = 'thinking out loud, no answer yet</think>';
      expect(
        e.stripThinkBlocks(raw),
        isNotEmpty,
        reason: 'call sites fall back to raw only when the strip empties; '
            'blanking a reply with no JSON at all would skip the eval',
      );
    });
  });
}
