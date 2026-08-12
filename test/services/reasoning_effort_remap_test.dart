// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A PROVIDER RE-TIERING reasoning.effort MUST NOT KILL GENERATION.
//
// Reported on Discord 2026-07-18 (adv997, via Nano-GPT):
//
//     API error: Invalid value for reasoning.effort on model
//     "deepseek/deepseek-v4-flash:thinking": "low".
//     Supported values are: none, high, max.
//
// DeepSeek dropped low/medium overnight; the app offers low/medium/high, so
// two of the three choices simply stopped generating — the user's workaround
// was "choose high, since that is one of the still valid options". Providers
// do this per model without notice, so a hardcoded table would be stale on
// arrival; the fix learns the supported set from the provider's own 400
// (which lists it) and substitutes the closest supported value, exactly like
// the mandatory-reasoning learn-once-and-retry beside it.
//
// :thinking-suffixed ids (Nano convention) are pre-hinted to {none,high,max}
// so the FIRST turn never 400s either — the Discord System-bubble failure
// mode.
//
// Guard proven to fail before passing: with the learn+retry block removed
// from generateStream, the non-:thinking case throws the exact production
// error; with the :thinking hint removed, the DeepSeek-shaped id would send
// "low" first.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/open_router_service.dart';

const _thinkingModel = 'deepseek/deepseek-v4-flash:thinking';
const _plainModel = 'acme/custom-reasoner-v2';

/// Stands in for Nano-GPT hosting a re-tiered effort set: 400s any request
/// whose reasoning.effort is not one of [allowed], with the exact production
/// error text; answers anything else.
Future<HttpServer> _startFakeProvider({
  required List<String?> seenEfforts,
  required Set<String> allowed,
  required String modelId,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((HttpRequest req) async {
    final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
    final reasoning = (body['reasoning'] as Map?)?.cast<String, dynamic>();
    final effort = reasoning?['effort'] as String?;
    seenEfforts.add(effort);

    if (effort != null && !allowed.contains(effort)) {
      req.response
        ..statusCode = 400
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': {
            'message': 'Invalid value for reasoning.effort on model '
                '"$modelId": "$effort". Supported values are: '
                '${allowed.join(', ')}.',
          }
        }));
      await req.response.close();
      return;
    }

    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType('text', 'event-stream');
    req.response.write('data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'The porch light hums, unhurried.'}
            }
          ]
        })}\n\n');
    req.response.write('data: [DONE]\n\n');
    await req.response.close();
  });
  return server;
}

void main() {
  // The Flutter test binding stubs HttpClient to return 400 for everything,
  // which would fake the very error this test exists to distinguish from.
  setUp(() => HttpOverrides.global = null);

  test(
    ':thinking model never sends low/medium on the wire (no System error bubble)',
    () async {
      // THE DISCORD BUG. Pre-fix (no :thinking hint, no learn): first
      // request carried "low", 400, and the turn died as a System message.
      final seen = <String?>[];
      final server = await _startFakeProvider(
        seenEfforts: seen,
        allowed: const {'none', 'high', 'max'},
        modelId: _thinkingModel,
      );
      addTearDown(() => server.close(force: true));

      final svc = OpenRouterService(
        apiUrl: 'http://127.0.0.1:${server.port}',
        apiKey: 'test-key',
        modelName: _thinkingModel,
      );

      Future<String> generate(String effort) async {
        final out = StringBuffer();
        await for (final chunk in svc.generateStream(
          GenerationParams(
            prompt: 'Say something about the porch.',
            maxLength: 128,
            reasoningEnabled: true,
            reasoningEffort: effort,
          ),
        )) {
          out.write(chunk);
        }
        return out.toString();
      }

      expect(await generate('low'), contains('porch light'));
      expect(
        seen,
        ['high'],
        reason: 'first wire value must already be remapped — a failed first '
            'trip is what put the API error in the chat as a System bubble',
      );

      seen.clear();
      expect(await generate('medium'), contains('porch light'));
      expect(seen, ['high']);

      seen.clear();
      expect(await generate('max'), contains('porch light'));
      expect(seen, ['max'], reason: 'supported values pass through');
    },
  );

  test(
    'non-:thinking model learns from 400 then remaps on later turns',
    () async {
      final seen = <String?>[];
      final server = await _startFakeProvider(
        seenEfforts: seen,
        allowed: const {'none', 'high', 'max'},
        modelId: _plainModel,
      );
      addTearDown(() => server.close(force: true));

      final svc = OpenRouterService(
        apiUrl: 'http://127.0.0.1:${server.port}',
        apiKey: 'test-key',
        modelName: _plainModel,
      );

      Future<String> generate(String effort) async {
        final out = StringBuffer();
        await for (final chunk in svc.generateStream(
          GenerationParams(
            prompt: 'Say something about the porch.',
            maxLength: 128,
            reasoningEnabled: true,
            reasoningEffort: effort,
          ),
        )) {
          out.write(chunk);
        }
        return out.toString();
      }

      // Phase 1: user "low" rejected; retry with closest thinking effort.
      expect(await generate('low'), contains('porch light'));
      expect(
        seen,
        ['low', 'high'],
        reason: 'first attempt sends the user choice; exactly one retry',
      );

      // Phase 2: remembered — no failed round trip.
      seen.clear();
      expect(await generate('medium'), contains('porch light'));
      expect(seen, ['high']);

      // Phase 3: accepted values untouched.
      seen.clear();
      expect(await generate('max'), contains('porch light'));
      expect(seen, ['max']);
    },
  );

  test(
    'effort rejection in a non-JSON body still teaches and retries',
    () async {
      final seen = <String?>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((HttpRequest req) async {
        final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
        final effort =
            ((body['reasoning'] as Map?)?['effort'] as String?) ?? '';
        seen.add(effort);
        if (effort == 'low') {
          // Plain text — no JSON envelope. Old parser left errorMsg as
          // "HTTP 400" and skipped the learn path.
          req.response
            ..statusCode = 400
            ..headers.contentType = ContentType.text
            ..write(
              'Invalid value for reasoning.effort on model "x": "low". '
              'Supported values are: none, high, max.',
            );
          await req.response.close();
          return;
        }
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType('text', 'event-stream');
        req.response.write(
          'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'content': 'ok'}
                  }
                ]
              })}\n\n',
        );
        req.response.write('data: [DONE]\n\n');
        await req.response.close();
      });

      final svc = OpenRouterService(
        apiUrl: 'http://127.0.0.1:${server.port}',
        apiKey: 'test-key',
        modelName: 'vendor/plain-text-errors',
      );
      final out = StringBuffer();
      await for (final c in svc.generateStream(
        GenerationParams(
          prompt: 'hi',
          maxLength: 32,
          reasoningEnabled: true,
          reasoningEffort: 'low',
        ),
      )) {
        out.write(c);
      }
      expect(out.toString(), 'ok');
      expect(seen, ['low', 'high']);
    },
  );
}
