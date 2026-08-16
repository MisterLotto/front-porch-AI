// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// KIMI 2.6 "SOMETIMES DELTAS ARE NOT EMITTED" — the second round (2026-08-15).
//
// The 55918806 fix stopped the mandatory-reasoning 400 from killing every
// judge, but the maintainer's next session still saw intermittent empty
// deltas: `[Realism:RawEval] len=17348` opening with un-tagged reasoning
// prose, bond_delta=null, "Reason: unknown". Two stacked causes:
//
// 1. TOKEN STARVATION. Evals send max_tokens:4000 and mandatory reasoning
//    counts against it. 17,348 chars of think ≈ the 4000-token cap exactly:
//    the stream was cut mid-think (finish_reason=length) and the final JSON /
//    tool call never got generated. Whether a turn worked depended purely on
//    how long Kimi happened to deliberate. The tools lane failed the same
//    way, silently: a cut tool call is a clean 200 with no tool_calls →
//    "inconclusive" → text fallback → cut again.
//    Fix: `_chatPayload` adds kMandatoryReasoningThinkHeadroomTokens to
//    max_tokens when salvageReasoning && reasoningCannotDisable.
//
// 2. UNTAGGED SALVAGE POLLUTED THE PARSE. The first salvage cut emitted raw
//    reasoning deltas, so stripThinkBlocks could not separate 15k chars of
//    deliberation from the answer and every firstMatch extractor scanned the
//    drafts first — a mid-think '"relationship_delta": 99' beat the final
//    JSON. Fix: salvage now emits the same <think>…</think> framing as wrap,
//    which the whole eval pipeline already knows how to strip; every eval
//    call site already falls back to raw when the strip leaves nothing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/open_router_service.dart';
import 'package:front_porch_ai/services/reasoning_effort.dart';

import 'llm_eval_engine_test.dart' show createTestLlmEvalEngine;

/// Loopback provider that records each request's max_tokens and streams a
/// Kimi-shaped reply: draft deltas inside the reasoning channel, the real
/// answer in content.
Future<HttpServer> _startProvider(List<int?> seenMaxTokens) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((HttpRequest req) async {
    final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
    seenMaxTokens.add(body['max_tokens'] as int?);

    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType('text', 'event-stream');
    // Deliberation first — carries a DECOY draft value.
    req.response.write('data: ${jsonEncode({
          'choices': [
            {
              'delta': {
                'reasoning': 'Let me weigh this. Maybe '
                    '"relationship_delta": 99? No, too strong. ',
              }
            }
          ]
        })}\n\n');
    // The final answer rides content.
    req.response.write('data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': '{"relationship_delta": 2}'}
            }
          ]
        })}\n\n');
    req.response.write('data: [DONE]\n\n');
    await req.response.close();
  });
  return server;
}

void main() {
  // Real loopback sockets (same pattern as reasoning_stream_test.dart's
  // SSE group): the test binding's fake HttpClient 400s everything.
  setUp(() => HttpOverrides.global = null);

  test('eval calls on a cannot-disable thinking model get think headroom '
      'in max_tokens; chat/Continue keep the caller cap', () async {
    final seen = <int?>[];
    final server = await _startProvider(seen);
    addTearDown(() => server.close(force: true));

    final svc = OpenRouterService(
      apiUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
      modelName: 'moonshotai/kimi-k2.6:thinking',
    );

    // Eval shape: salvage on → headroom.
    await svc
        .generateStream(GenerationParams(
          prompt: 'judge',
          maxLength: 128,
          reasoningEnabled: false,
          reasoningMaxTokens: 0,
          salvageReasoning: true,
        ))
        .drain<void>();
    // Continue shape: salvage off → the user's cap, untouched.
    await svc
        .generateStream(GenerationParams(
          prompt: 'continue the reply',
          maxLength: 128,
          reasoningEnabled: false,
          reasoningMaxTokens: 0,
        ))
        .drain<void>();

    expect(seen.first, 128 + kMandatoryReasoningThinkHeadroomTokens,
        reason: 'mandatory thinking counts against max_tokens; without '
            'headroom the eval is cut mid-think and no deltas arrive');
    expect(seen.last, 128,
        reason: 'chat/Continue reply length stays the user setting');
  });

  test('the final content JSON beats draft deltas in the think channel',
      () async {
    final seen = <int?>[];
    final server = await _startProvider(seen);
    addTearDown(() => server.close(force: true));

    final svc = OpenRouterService(
      apiUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
      modelName: 'moonshotai/kimi-k2.6:thinking',
    );

    final out = StringBuffer();
    await for (final chunk in svc.generateStream(GenerationParams(
      prompt: 'judge',
      maxLength: 128,
      reasoningEnabled: false,
      reasoningMaxTokens: 0,
      salvageReasoning: true,
    ))) {
      out.write(chunk);
    }

    // The exact pipeline the realism evals run: strip the think framing,
    // then regex-extract. Raw (untagged) salvage made the strip a no-op and
    // firstMatch found the decoy 99 from mid-think.
    final engine = createTestLlmEvalEngine();
    final stripped = engine.stripThinkBlocks(out.toString());
    expect(engine.extractJsonInt(stripped, 'relationship_delta'), 2,
        reason: 'the model\'s final answer, not its draft, must win');
  });

  test('needs impact eval falls back to raw when the answer only exists '
      'inside the think channel', () async {
    final engine = createTestLlmEvalEngine(
      activeChar: CharacterCard(name: 'Kara', personality: 'steady'),
      getLlmJson: () =>
          '<think>{"hunger_delta": -5, "energy_delta": 0, "hygiene_delta": 0,'
          ' "fun_delta": 0, "social_delta": 0, "bladder_delta": 0,'
          ' "comfort_delta": 0, "reason": "long walk"}</think>',
    );
    final res = await engine.evaluateNeedsImpactCall('scene text');
    expect(res, isNotNull,
        reason: 'a think-only reply must reach the regex parse (the four '
            'realism calls already fall back to raw); returning null '
            'silently skipped the needs turn');
    expect(res, contains('hunger_delta'));
  });
}
