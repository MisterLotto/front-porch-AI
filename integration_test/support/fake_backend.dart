// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// In-process stand-in for an unmanaged OpenAI-compatible local backend (the
// PseudoRemote path: LM Studio / llama.cpp servers). Serves the endpoints
// observed during a realism-enabled chat turn plus the KoboldCpp extras a
// managed-mode run would use (kept modeled; unused paths cost nothing and
// unmodeled ones fail the traffic audit by name):
//
//   GET  /api/extra/version      health probe
//   GET  /api/extra/perf         perf poll (idle/queue/speeds)
//   POST /api/extra/tokencount   real-tokenizer prompt counts
//   POST /v1/chat/completions    OpenAI-compatible SSE (the protocol
//                                KoboldService.generateStream actually speaks
//                                via streamOpenAiChat)
//
// Completion routing: a request whose body contains a "tools" array is the
// tool-transport probe — it is refused with 404 so the app falls back to the
// text eval path (the fallback is itself production code worth exercising).
// A text request is classified by the JSON keys its prompt asks the model to
// produce: realism eval prompts name their keys (relationship_delta,
// emotion_intensity, fixation_topic, ...), so the fake answers with a valid
// canned payload for exactly the keys requested. Anything else is the user
// chat turn and streams [replyPieces] as multiple SSE chunks (proving the
// incremental decode path).

import 'dart:convert';
import 'dart:io';

class FakeBackendServer {
  FakeBackendServer._(this._server, this.replyPieces);

  final HttpServer _server;

  /// The chat reply, streamed one SSE chunk per element.
  final List<String> replyPieces;

  /// Non-eval chat completions served (the actual conversation turns).
  int chatRequests = 0;

  /// Realism/eval completions served (classified by requested JSON keys).
  int evalRequests = 0;

  /// Tool-transport probes refused (forces the text eval fallback).
  int toolProbeRequests = 0;

  /// Body of the most recent NON-eval chat completion — lets the test prove
  /// the user's message actually reached the outbound prompt.
  String lastChatBody = '';

  /// Paths the app hit that this fake doesn't model. Asserted empty: if a
  /// future change adds backend traffic to a chat turn, the failure names
  /// the endpoint instead of a silent 404 skewing behavior.
  final List<String> unexpectedPaths = [];

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<FakeBackendServer> start({
    required List<String> replyPieces,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeBackendServer._(server, replyPieces);
    server.listen(fake._handle);
    return fake;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      switch (req.uri.path) {
        case '/api/extra/version':
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({'result': 'KoboldCpp', 'version': '1.100'}),
          );
        case '/api/extra/perf':
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'last_process_speed': 100.0,
              'last_eval_speed': 50.0,
              'last_input_count': 32,
              'last_token_count': 16,
              'total_gens': chatRequests + evalRequests,
              'queue': 0,
              'idle': 1,
            }),
          );
        case '/v1/models':
          // OpenAI-compatible model listing — the remote backend service
          // fetches this to populate/validate the model picker.
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'data': [
                {'id': 'smoke-model'},
              ],
            }),
          );
        case '/api/extra/tokencount':
          final body = await utf8.decodeStream(req);
          final prompt = (jsonDecode(body)['prompt'] as String?) ?? '';
          req.response.headers.contentType = ContentType.json;
          // Deterministic pseudo-tokenizer: close enough for prefill math.
          req.response.write(jsonEncode({'value': (prompt.length / 4).ceil()}));
        case '/v1/chat/completions':
          await _handleCompletion(req);
        // Capability probes where 404 IS the correct answer: the remote
        // backend sniffs LM Studio's native API to detect what it's talking
        // to, and answering it would misidentify this fake as LM Studio.
        case '/api/v0/models':
          req.response.statusCode = HttpStatus.notFound;
        default:
          unexpectedPaths.add(req.uri.path);
          req.response.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      // Usually a request racing test teardown (closed socket) — but logged,
      // so a genuine handler bug (bad JSON, write failure) can't hide here.
      // ignore: avoid_print — test support; print reaches the suite log.
      print('[FakeBackendServer] handler error on ${req.uri.path}: $e');
    } finally {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleCompletion(HttpRequest req) async {
    final body = await utf8.decodeStream(req);

    // Real JSON field check, not a substring test: a quoted "tools" inside
    // message content must not trip the probe branch.
    Map<String, dynamic> decoded = const {};
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      // Malformed body → key routing below still works on the raw text.
    }
    if (decoded['tools'] != null) {
      toolProbeRequests++;
      req.response.statusCode = HttpStatus.notFound;
      req.response.write(
        jsonEncode({
          'error': {'message': 'tools transport not supported by this fake'},
        }),
      );
      return;
    }

    // Classify on the LAST message's content only. Eval prompts end with
    // instructions naming the JSON keys to emit; a realism-enabled CHAT
    // request carries realism-state injection text in its SYSTEM prompt
    // (posture, bond words...) that would false-match a whole-body search —
    // that exact misroute happened: turn 2's generation was answered with
    // eval JSON. The last message is the typed user text for chat and the
    // instruction block for evals.
    String lastContent = body;
    final messages = decoded['messages'];
    if (messages is List && messages.isNotEmpty) {
      final last = messages.last;
      if (last is Map && last['content'] is String) {
        lastContent = last['content'] as String;
      }
    }
    final eval = <String, dynamic>{};
    if (lastContent.contains('relationship_delta')) {
      eval['relationship_delta'] = 2;
      eval['trust_delta'] = 1;
      eval['bond_reason'] = 'smoke-test warmth';
      eval['trust_reason'] = 'smoke-test honesty';
    }
    if (lastContent.contains('emotion_intensity')) {
      eval['emotion'] = 'happy';
      eval['emotion_intensity'] = 'moderate';
    }
    if (lastContent.contains('fixation_topic')) {
      eval['fixation_topic'] = 'none';
      eval['proposed_objective'] = 'none';
    }
    // Scene-time / physical-state eval. Modeled so it can never misroute
    // into the chat branch — chatRequests and lastChatBody stay trustworthy.
    if (lastContent.contains('minutes_elapsed') ||
        lastContent.contains('"posture"')) {
      eval['posture'] = 'standing';
      eval['minutes_elapsed'] = 5;
      eval['new_day'] = false;
    }

    // One line per completion so a misclassification is visible in the suite
    // log without any debugger. ignore: avoid_print — test support.
    print(
      '[FakeBackendServer] completion: ${eval.isEmpty ? 'CHAT' : 'EVAL(${eval.keys.join('+')})'} '
      'last="${lastContent.length > 70 ? lastContent.substring(lastContent.length - 70) : lastContent}"',
    );

    req.response.headers.set('Content-Type', 'text/event-stream');
    final pieces = <String>[];
    if (eval.isNotEmpty) {
      evalRequests++;
      // The whole eval JSON rides one content delta — the parser regex/JSON
      // extraction works on the assembled text either way.
      pieces.add(jsonEncode(eval));
    } else {
      chatRequests++;
      lastChatBody = body;
      pieces.addAll(replyPieces);
    }
    for (final piece in pieces) {
      req.response.write(
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': piece},
            },
          ],
        })}\n\n',
      );
      await req.response.flush();
    }
    req.response.write('data: [DONE]\n\n');
    await req.response.flush();
  }

  Future<void> close() => _server.close(force: true);
}
