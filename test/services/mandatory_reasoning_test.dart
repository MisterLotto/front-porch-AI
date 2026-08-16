// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A MANDATORY-REASONING MODEL MUST NOT SILENTLY KILL EVERY EVAL.
//
// Reported by the maintainer on 2026-08-08, from real use:
//
//     "something is legit broken with realism at the moment in the current
//      tree, no deltas emotion is sticking across messages."
//
// Their console showed the whole Realism Engine failing on one error, repeated
// for every judge and both retry attempts:
//
//     API error: Kimi K2 Thinking is a mandatory-reasoning model.
//     Use reasoning.exclude=true to hide reasoning output.
//
// Cause: every eval suppresses reasoning (they want flat JSON, not think
// blocks), and suppression sent `reasoning:{enabled:false, exclude:true}`.
// `exclude:true` is fine on any model; `enabled:false` is a hard "stop
// thinking" that a mandatory-reasoning model rejects outright. So on such a
// model the relationship, emotional, narrative, needs-impact and objective
// judges ALL 400 — bond_delta comes out null on every turn, needs fall back to
// plain decay, and the emotion the user sees is the local ONNX classifier's,
// not the engine's. The chat looks alive and is running on nothing.
//
// The fix keeps `enabled:false` for models that honour it (it is what actually
// saves reasoning tokens) and drops it only for models that have rejected it,
// learned once per model from the provider's own error.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/open_router_service.dart';
import 'package:front_porch_ai/services/reasoning_effort.dart';

/// Stands in for Nano-GPT hosting a mandatory-reasoning model: 400s any request
/// carrying `reasoning.enabled == false`, answers anything else.
Future<HttpServer> _startFakeProvider({
  required List<Map<String, dynamic>> seenReasoning,
  bool jsonInReasoningOnly = false,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((HttpRequest req) async {
    final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
    final reasoning = (body['reasoning'] as Map?)?.cast<String, dynamic>();
    seenReasoning.add(reasoning ?? <String, dynamic>{});

    if (reasoning != null && reasoning['enabled'] == false) {
      req.response
        ..statusCode = 400
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': {
            'message': 'Kimi K2 Thinking is a mandatory-reasoning model. '
                'Use reasoning.exclude=true to hide reasoning output.',
          }
        }));
      await req.response.close();
      return;
    }

    final wantTools = body['tools'] is List;
    if (wantTools) {
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': null,
                'tool_calls': [
                  {
                    'id': 'c1',
                    'type': 'function',
                    'function': {
                      'name': 'report_realism',
                      'arguments': '{"relationship_delta":6,"trust_delta":3}',
                    },
                  }
                ],
              }
            }
          ]
        }));
      await req.response.close();
      return;
    }

    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType('text', 'event-stream');
    if (jsonInReasoningOnly) {
      // Live Kimi 2.6 shape: JSON lives in the reasoning channel, content
      // is a newline (or empty) after a long think.
      req.response.write('data: ${jsonEncode({
            'choices': [
              {
                'delta': {
                  'reasoning': '{"relationship_delta":6,"trust_delta":3}',
                }
              }
            ]
          })}\n\n');
      req.response.write('data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': '\n'}
              }
            ]
          })}\n\n');
    } else {
      req.response.write('data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': '{"relationship_delta":6,"trust_delta":3}'}
              }
            ]
          })}\n\n');
    }
    req.response.write('data: [DONE]\n\n');
    await req.response.close();
  });
  return server;
}

void main() {
  // The Flutter test binding stubs HttpClient to return 400 for everything,
  // which would fake the very error this test exists to distinguish from.
  setUp(() {
    HttpOverrides.global = null;
    clearReasoningEffortCatalog();
  });
  tearDown(clearReasoningEffortCatalog);

  test('an eval survives a model that refuses reasoning:{enabled:false}',
      () async {
    // PRE-FIX RESULT: FAILED — the call threw
    // "API error: Kimi K2 Thinking is a mandatory-reasoning model…", which is
    // exactly what every judge did on the maintainer's machine.
    final seen = <Map<String, dynamic>>[];
    final server = await _startFakeProvider(seenReasoning: seen);
    addTearDown(() => server.close(force: true));

    final svc = OpenRouterService(
      apiUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
      modelName: 'moonshotai/kimi-k2-thinking',
    );

    final out = StringBuffer();
    await for (final chunk in svc.generateStream(
      GenerationParams(
        prompt: 'Score the relationship_delta for this exchange.',
        maxLength: 128,
        reasoningEnabled: false, // every eval does this
        reasoningMaxTokens: 0,
      ),
    )) {
      out.write(chunk);
    }

    expect(
      out.toString(),
      contains('relationship_delta'),
      reason: 'the eval must still get its JSON back — a model that cannot '
          'switch reasoning off is not a reason to lose bond and trust',
    );

    // kimi+thinking is recognized up front (2026-08-15) so we never send
    // enabled:false and never spend a 400. Chat Continue still excludes.
    expect(seen.length, 1, reason: 'no 400-retry needed for a known Kimi');
    expect(seen.single.containsKey('enabled'), isFalse);
    expect(seen.single['exclude'], true);
  });

  test('an unknown mandatory model is learned from the 400 and retried',
      () async {
    final seen = <Map<String, dynamic>>[];
    final server = await _startFakeProvider(seenReasoning: seen);
    addTearDown(() => server.close(force: true));

    final svc = OpenRouterService(
      apiUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
      modelName: 'acme/mandatory-reasoner',
    );

    final out = StringBuffer();
    await for (final chunk in svc.generateStream(
      GenerationParams(
        prompt: 'Score the relationship_delta for this exchange.',
        maxLength: 128,
        reasoningEnabled: false,
        reasoningMaxTokens: 0,
      ),
    )) {
      out.write(chunk);
    }

    expect(out.toString(), contains('relationship_delta'));
    expect(seen.length, 2, reason: 'exactly one retry, not a loop');
    expect(seen.first['enabled'], false);
    expect(seen.last.containsKey('enabled'), isFalse);
    expect(seen.last['exclude'], true);
  });

  test('eval salvage omits exclude and keeps reasoning-channel JSON', () async {
    final seen = <Map<String, dynamic>>[];
    final server = await _startFakeProvider(
      seenReasoning: seen,
      jsonInReasoningOnly: true,
    );
    addTearDown(() => server.close(force: true));

    final svc = OpenRouterService(
      apiUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
      modelName: 'moonshotai/kimi-k2.6:thinking',
    );

    final out = StringBuffer();
    await for (final chunk in svc.generateStream(
      GenerationParams(
        prompt: 'Score the relationship_delta for this exchange.',
        maxLength: 128,
        reasoningEnabled: false,
        reasoningMaxTokens: 0,
        salvageReasoning: true,
      ),
    )) {
      out.write(chunk);
    }

    expect(
      out.toString(),
      contains('relationship_delta'),
      reason: 'Kimi parks the eval JSON in reasoning; exclude would leave '
          'content empty after a long think',
    );
    expect(seen.single.containsKey('exclude'), isFalse);
    expect(seen.single.containsKey('enabled'), isFalse);
  });

  test('tool evals retry a mandatory-reasoning 400', () async {
    final seen = <Map<String, dynamic>>[];
    final server = await _startFakeProvider(seenReasoning: seen);
    addTearDown(() => server.close(force: true));

    final svc = OpenRouterService(
      apiUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
      modelName: 'acme/mandatory-reasoner',
    );

    final resp = await svc.generateWithTools(
      GenerationParams(
        prompt: 'Score the relationship_delta for this exchange.',
        maxLength: 128,
        reasoningEnabled: false,
        reasoningMaxTokens: 0,
        salvageReasoning: true,
      ),
      const [
        {
          'type': 'function',
          'function': {'name': 'report_realism', 'parameters': <String, dynamic>{}},
        },
      ],
    );

    expect(resp, isNotNull);
    expect(seen.length, 2);
    expect(seen.first['enabled'], false);
    expect(seen.last.containsKey('enabled'), isFalse);
  });
}
