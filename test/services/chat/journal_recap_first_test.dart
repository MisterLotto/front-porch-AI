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

// THE RECAP COMES FIRST (2026-08-10). The journal pass instructed memories
// first and the recap LAST, so whenever a busy pass hit its response budget
// the truncation decapitated exactly the recap — ops landed, "Where we are"
// stayed stale, and the maintenance warning fired, live in the maintainer's
// own log. Truncation must cost something; ordering picks the cheaper
// casualty: a lost trailing memory is one one-sentence beat, the lost recap
// is the per-turn context block the prompt and the growth pass read.
//
// Both parsers were already order-independent (pinned below with a
// recap-first reply), so only the instructions moved — in BOTH transports,
// which must never drift (the prompt file's own contract).
//
// Guards proven to fail before passing: reverting either transport's
// instruction to the old memories-first wording sends its ordering test
// red; restored, green.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/services/llm_service.dart' show LlmToolCall;

String _prompt({required bool toolsMode, bool includeRecap = true}) =>
    buildJournalPrompt(
      ownerName: 'Nia',
      userName: 'User',
      recap: 'Things stand well.',
      cards: const [],
      window: [
        ChatMessage(text: 'a recent turn', sender: 'User', isUser: true),
      ],
      windowStart: 0,
      includeRecap: includeRecap,
      toolsMode: toolsMode,
    );

void main() {
  group('recap-first instruction ordering', () {
    test('XML transport: the recap instruction leads the format section', () {
      final p = _prompt(toolsMode: false);
      expect(p, contains('Open with exactly one <recap> tag'));
      expect(
        p.indexOf('<recap>Where things stand now'),
        lessThan(p.indexOf('<memory action="add"')),
        reason:
            'THE FIX. With the recap example/instruction after the memory '
            'tags, a response-budget truncation decapitates exactly the '
            'recap, every busy pass.',
      );
    });

    test('tools transport: write_recap is instructed first', () {
      final p = _prompt(toolsMode: true);
      expect(p, contains('Start with exactly one write_recap call'));
      expect(p, contains('Then add your memories with add_memory'));
      expect(
        p.indexOf('Start with exactly one write_recap call'),
        lessThan(p.indexOf('Then add your memories')),
      );
    });

    test('recap-less passes still forbid the recap in both transports', () {
      expect(
        _prompt(toolsMode: false, includeRecap: false),
        contains('Do not write a <recap> tag'),
      );
      expect(
        _prompt(toolsMode: true, includeRecap: false),
        contains('Do not call write_recap'),
      );
    });
  });

  group('parsers accept recap-first replies (order independence)', () {
    test('XML: a reply that opens with the recap parses fully', () {
      const reply =
          '<recap>We grew closer tonight.</recap>\n'
          '<memory action="add" category="moment" msgs="3">the porch swing '
          'creaked while we talked</memory>';
      expect(parseRecap(reply), 'We grew closer tonight.');
      final ops = parseJournalOps(reply);
      expect(ops, hasLength(1));
      expect(ops.single.text, contains('porch swing'));
    });

    test('tools: a call sequence that leads with write_recap parses fully', () {
      final (ops, recap) = parseJournalToolCalls([
        const LlmToolCall(
          name: 'write_recap',
          arguments: {'text': 'We grew closer tonight.'},
        ),
        const LlmToolCall(
          name: 'add_memory',
          arguments: {
            'category': 'moment',
            'content': 'the porch swing creaked while we talked',
            'msgs': '3',
          },
        ),
      ]);
      expect(recap, 'We grew closer tonight.');
      expect(ops, hasLength(1));
    });
  });
}
