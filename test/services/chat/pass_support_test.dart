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

// fireStructuredEval verdict rules — the ONE tools-vs-text negotiation for
// realism/needs/scene-time/expression/cast evals. Pins the "empty answer is
// never a capability verdict" rule: a KoboldCpp server-side abort completes
// an in-flight tool call as a clean empty 200, and branding on that shape is
// what made the tool-calling pill fall to "not supported" after a Scene
// Guest joined (long mint generation + concurrent eval burst + abort/idle
// traffic on the single-slot backend).

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/pass_support.dart';
import 'package:front_porch_ai/services/llm_service.dart'
    show LlmToolCall, LlmToolResponse, LlmToolTransportException;

void main() {
  group('fireStructuredEval verdicts', () {
    const id = 'Kobold|model-a';

    Future<({String? result, ToolTransportProbe probe, int textCalls})> run({
      required Future<LlmToolResponse?> Function() toolAnswer,
      ToolTransportProbe? probe,
    }) async {
      final p = probe ?? ToolTransportProbe();
      var textCalls = 0;
      final result = await fireStructuredEval(
        probe: p,
        backendIdentity: id,
        debugLabel: 'test',
        tools: const [
          {
            'type': 'function',
            'function': {'name': 'report', 'parameters': {}},
          },
        ],
        buildPrompt: ({required bool toolsMode}) =>
            toolsMode ? 'TOOLS' : 'TEXT',
        callToText: (resp) => resp.calls.isEmpty ? null : 'CONVERTED',
        fireToolEval: (_, _) => toolAnswer(),
        fireTextEval: (prompt, {onChunk}) async {
          textCalls++;
          return 'TEXT-RESULT';
        },
      );
      return (result: result, probe: p, textCalls: textCalls);
    }

    test('a real tool call → supported, converted text returned', () async {
      final r = await run(
        toolAnswer: () async => const LlmToolResponse(
          calls: [LlmToolCall(name: 'report', arguments: {})],
          text: '',
        ),
      );
      expect(r.result, 'CONVERTED');
      expect(r.probe.supportFor(id), ToolCallSupport.supported);
      expect(r.textCalls, 0);
    });

    test('EMPTY answer (server-side abort shape) → text fallback, NO verdict',
        () async {
      final r = await run(
        toolAnswer: () async => const LlmToolResponse(calls: [], text: ''),
      );
      expect(r.result, 'TEXT-RESULT');
      expect(r.textCalls, 1);
      expect(
        r.probe.supportFor(id),
        ToolCallSupport.untested,
        reason: 'an aborted call answers as a clean empty 200 — never brand',
      );
    });

    test('null answer → text fallback, NO verdict', () async {
      final r = await run(toolAnswer: () async => null);
      expect(r.result, 'TEXT-RESULT');
      expect(r.probe.supportFor(id), ToolCallSupport.untested);
    });

    test('prose answer is salvaged without branding (tester is the oracle)',
        () async {
      final r = await run(
        toolAnswer: () async =>
            const LlmToolResponse(calls: [], text: 'bond_delta: 3'),
      );
      expect(r.result, 'bond_delta: 3');
      expect(r.probe.supportFor(id), ToolCallSupport.untested);
      expect(r.textCalls, 0);
    });

    test('transport failure → text fallback, NO verdict', () async {
      final r = await run(
        toolAnswer: () async =>
            throw LlmToolTransportException('server busy 503'),
      );
      expect(r.result, 'TEXT-RESULT');
      expect(r.probe.supportFor(id), ToolCallSupport.untested);
    });

    test('non-transport rejection still brands XML-only', () async {
      final r = await run(
        toolAnswer: () async => throw StateError('tools field rejected'),
      );
      expect(r.result, 'TEXT-RESULT');
      expect(r.probe.supportFor(id), ToolCallSupport.unsupported);
    });

    test('an XML-only verdict skips the tools attempt entirely', () async {
      var toolCalls = 0;
      final r = await run(
        probe: ToolTransportProbe()..markXmlOnly(id),
        toolAnswer: () async {
          toolCalls++;
          return null;
        },
      );
      expect(r.result, 'TEXT-RESULT');
      expect(toolCalls, 0);
    });
  });
}
