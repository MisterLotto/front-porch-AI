// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards for the --jinja system-message drop (SystemRoleProbe).
//
// The defect, reproduced on the maintainer's own machine with KoboldCpp
// 1.117.1 and the app's own launch flags: a GGUF whose embedded chat template
// has no branch for the system role (intervitens-mini-magnum-12b-v1.1 ends its
// role loop with raise_exception('Only user and assistant roles are
// supported!')) makes KoboldCpp discard the ENTIRE leading system message —
// HTTP 200, plausible reply, no warning. A 266-token system block arrived as 0
// tokens. Front Porch AI puts the character card, persona, scenario and
// examples in that message, so those users were chatting with no character at
// all.
//
// The loopback server below is a KoboldCpp stand-in with a switchable
// template. It does NOT only subtract the system message — that was the gap
// that let a false-positive ship. It can also ADD a default preamble when no
// system message is supplied, truncate rather than drop, pad every request,
// and report constant usage numbers. Those are the four ways a server can
// fool a naive present-vs-absent A/B, and every one of them is measured
// against the real decision rule here.
//
// Ground truth for the bands, measured live against KoboldCpp 1.117.1:
//   gemma-4-31B                          delivered 211/212 = 0.995 -> honored
//   gemma-4-31B + 120-token preamble     delivered 211/212 = 0.995 -> honored
//   mini-magnum-12b-v1.1                 delivered   0/222 = 0.000 -> dropped
//   mini-magnum + preamble               delivered   0/222 = 0.000 -> dropped

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
// GenerationParams. openai_chat_stream.dart and system_role_probe.dart are
// deliberately NOT on this curated barrel — both are transport internals whose
// only production importers are their own siblings in lib/services/.
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/services/openai_chat_stream.dart';
import 'package:front_porch_ai/services/system_role_probe.dart';

/// Which chat-template behaviour the fake backend emulates.
enum FakeTemplate {
  /// Healthy: every message contributes its own tokens (gemma-4-31B).
  honorsSystem,

  /// The measured defect: the template has no system branch, so the whole
  /// message contributes nothing (mini-magnum-12b-v1.1).
  dropsSystem,

  /// The FALSE-POSITIVE shape, and the reason this file exists in its current
  /// form. Delivers every byte of a supplied system message, but bakes in its
  /// own preamble when none is sent — `{%- if not system_message %}…{%- endif
  /// %}`, which Cohere Command-R and several Llama-3/Mistral roleplay
  /// conversions ship. A present-vs-absent A/B reads that added preamble as
  /// evidence of a drop and folds the card into the user turn on a backend
  /// that never needed it.
  defaultPreambleWhenNoSystem,

  /// Drops yours AND always bakes its own — both effects at once.
  dropsSystemAlwaysPreamble,

  /// Keeps only the first [truncateSystemAt] words of the system message.
  truncatesSystem,
}

/// How the fake server answers: normally, or in one of the broken shapes the
/// probe has to fail OPEN on.
enum FakeFault {
  none,
  serverError,
  noUsage,

  /// Reports the same prompt_tokens for every request — a server whose usage
  /// numbers are not a measurement at all.
  constantUsage,
}

/// Size of the fake template's baked-in preamble, in fake tokens. Chosen to
/// exceed the old rule's 100-token decision margin, exactly as Command-R's
/// ~110-token preamble does.
const int kFakePreambleWords = 120;

void main() {
  late HttpServer server;
  late List<Map<String, dynamic>> received;
  late FakeTemplate template;
  late FakeFault fault;

  /// Fixed extra tokens the fake server charges on EVERY request — a server
  /// that pads. Must cancel out of every difference the probe takes.
  late int pad;

  /// Word budget for [FakeTemplate.truncatesSystem].
  late int truncateSystemAt;

  /// How many requests fail with 503 before the server starts answering — a
  /// backend that is still finishing its warm-up when the probe is armed,
  /// which is the whole reason there is a retry at all.
  late int failFirstRequests;

  /// Held before answering, so a probe can be cancelled while genuinely on
  /// the wire rather than merely "about to be".
  late Duration responseDelay;

  String baseUrl() => 'http://127.0.0.1:${server.port}';

  /// Stand-in tokenizer: one "token" per whitespace-separated word. The
  /// absolute numbers don't matter — what matters is that the fake charges
  /// for text the same way in the system slot and the user slot, exactly as
  /// a real tokenizer does.
  int wordsIn(Object? content) {
    if (content is String) {
      final trimmed = content.trim();
      if (trimmed.isEmpty) return 0;
      return trimmed.split(RegExp(r'\s+')).length;
    }
    if (content is List) {
      var n = 0;
      for (final part in content) {
        if (part is Map && part['type'] == 'text') n += wordsIn(part['text']);
      }
      return n;
    }
    return 0;
  }

  /// What this template charges for a system message's content.
  int systemCost(Object? content) => switch (template) {
    FakeTemplate.dropsSystem || FakeTemplate.dropsSystemAlwaysPreamble => 0,
    FakeTemplate.truncatesSystem => min(wordsIn(content), truncateSystemAt),
    FakeTemplate.honorsSystem ||
    FakeTemplate.defaultPreambleWhenNoSystem => wordsIn(content),
  };

  setUp(() async {
    HttpOverrides.global = null;
    received = [];
    template = FakeTemplate.honorsSystem;
    fault = FakeFault.none;
    pad = 0;
    truncateSystemAt = 0;
    failFirstRequests = 0;
    responseDelay = Duration.zero;
    SystemRoleProbe.instance.resetForTest();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      received.add(payload);
      if (responseDelay > Duration.zero) {
        await Future<void>.delayed(responseDelay);
      }
      // A cancelled probe closes its socket mid-request; writing to it throws,
      // and an unhandled throw in this handler would poison later tests.
      try {
        if (fault == FakeFault.serverError || failFirstRequests-- > 0) {
          req.response.statusCode = 503;
          await req.response.close();
          return;
        }
        var prompt = 6 + pad; // per-request template overhead + padding
        var sawSystem = false;
        for (final m in (payload['messages'] as List).cast<Map>()) {
          if (m['role'] == 'system') {
            sawSystem = true;
            prompt += systemCost(m['content']);
          } else {
            prompt += wordsIn(m['content']);
          }
        }
        // `{%- if not system_message %}` — and the always-on variant.
        if (template == FakeTemplate.dropsSystemAlwaysPreamble ||
            (template == FakeTemplate.defaultPreambleWhenNoSystem &&
                !sawSystem)) {
          prompt += kFakePreambleWords;
        }
        if (fault == FakeFault.constantUsage) prompt = 999;
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType('application', 'json');
        req.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'ok'},
                'finish_reason': 'length',
              },
            ],
            if (fault != FakeFault.noUsage)
              'usage': {'prompt_tokens': prompt, 'completion_tokens': 1},
          }),
        );
        await req.response.close();
      } catch (_) {
        // Socket already gone — the client cancelled. Nothing to report.
      }
    });
  });

  tearDown(() async {
    SystemRoleProbe.instance.resetForTest();
    await server.close(force: true);
  });

  /// Production settings in every respect except the retry gap. The budget is
  /// spent INSIDE one [SystemRoleProbe.ensureProbed] call, so every fail-open
  /// case below really does run all three attempts — at the shipped 3s/6s
  /// backoff that would add nine seconds per test to the suite.
  SystemRoleProbe newProbe() =>
      SystemRoleProbe(retryBackoff: const Duration(milliseconds: 5));

  Future<void> probe(SystemRoleProbe p, String identity) =>
      p.ensureProbed(baseUrl: baseUrl(), identity: identity);

  group('detection', () {
    test('a template that drops the system message is caught', () async {
      template = FakeTemplate.dropsSystem;
      final p = newProbe();
      await probe(p, 'KoboldCPP||mini-magnum.gguf');

      expect(p.verdictFor('KoboldCPP||mini-magnum.gguf'), isFalse);
      expect(p.isSystemDropped('KoboldCPP||mini-magnum.gguf'), isTrue);
      // The differential is three cheap requests, never a generation.
      expect(received.length, 3);
      for (final r in received) {
        expect(r['max_tokens'], 1);
      }
    });

    test('a healthy template is not false-positived', () async {
      template = FakeTemplate.honorsSystem;
      final p = newProbe();
      await probe(p, 'KoboldCPP||gemma-4-31B.gguf');

      expect(p.verdictFor('KoboldCPP||gemma-4-31B.gguf'), isTrue);
      expect(p.isSystemDropped('KoboldCPP||gemma-4-31B.gguf'), isFalse);
    });
  });

  // ── The differential, and the four ways a server can fool a naive A/B ──
  //
  // Every test in this group would have passed against the old
  // present-vs-absent rule EXCEPT the first two, which are the whole point:
  // a template that merely ADDS content when the system role is absent is not
  // dropping anything, and must not be treated as if it were.
  group('the control keeps a system message in every arm', () {
    test(
      'a template that only bakes a DEFAULT PREAMBLE is not called a drop',
      () async {
        // Delivers every byte of the system message; adds ~120 tokens of its
        // own only when none is supplied. Verified live: gemma-4-31B behind
        // exactly this shape measured old-delta +114 (-> "dropped", wrong)
        // and new-delivered 0.995 (-> honored, right).
        template = FakeTemplate.defaultPreambleWhenNoSystem;
        final p = newProbe();
        await probe(p, 'id');

        expect(p.verdictFor('id'), isTrue, reason: 'honored, not dropped');
        expect(p.isSystemDropped('id'), isFalse);
      },
    );

    test('every arm sends a system message AND a user message', () async {
      // The structural invariant the verdict rests on: because a system
      // message is present in all three arms, any content a template adds
      // when one is ABSENT cancels out instead of being counted as a drop.
      // An arm that omits the system role re-opens the false positive.
      template = FakeTemplate.honorsSystem;
      await probe(newProbe(), 'id');

      expect(received.length, 3);
      for (final r in received) {
        final roles = (r['messages'] as List)
            .cast<Map>()
            .map((m) => m['role'])
            .toList();
        expect(roles, contains('system'));
        expect(roles, contains('user'));
      }
    });

    test('a template that drops AND bakes a preamble is still caught', () async {
      template = FakeTemplate.dropsSystemAlwaysPreamble;
      final p = newProbe();
      await probe(p, 'id');

      expect(p.isSystemDropped('id'), isTrue);
    });

    test('fixed per-request padding cannot change either verdict', () async {
      // A server that charges a constant extra on every request cancels in
      // both differences the probe takes.
      pad = 137;
      template = FakeTemplate.honorsSystem;
      final healthy = newProbe();
      await probe(healthy, 'id');
      expect(healthy.verdictFor('id'), isTrue);

      template = FakeTemplate.dropsSystem;
      final broken = newProbe();
      await probe(broken, 'id');
      expect(broken.verdictFor('id'), isFalse);
    });

    test('a template that TRUNCATES the system message reads as a drop',
        () async {
      // Keeping fewer words than the marker means the character card would be
      // cut off just as completely as if it were discarded, so folding it
      // into the user turn is the correct remedy.
      template = FakeTemplate.truncatesSystem;
      truncateSystemAt = 10;
      final p = newProbe();
      await probe(p, 'id');

      expect(p.isSystemDropped('id'), isTrue);
    });

    test('a HALF-delivering template is reported inconclusive, not guessed',
        () async {
      // Lands in the dead zone between the bands. Fail open: keep today's
      // behaviour rather than fold a card into the user turn on a backend
      // that mostly works.
      template = FakeTemplate.truncatesSystem;
      truncateSystemAt =
          kSystemRoleProbeMarker.trim().split(RegExp(r'\s+')).length +
          (kSystemRoleProbeFiller.trim().split(RegExp(r'\s+')).length ~/ 2);
      final p = newProbe();
      await probe(p, 'id');

      expect(p.verdictFor('id'), isNull);
      expect(p.isSystemDropped('id'), isFalse);
    });

    test('a server whose usage never moves is reported inconclusive', () async {
      // The calibration arm is what catches this: refCost collapses to 0, so
      // the ratio would be a division by noise. Without arm C, sysCost would
      // also be 0 and the probe would confidently say "dropped".
      fault = FakeFault.constantUsage;
      template = FakeTemplate.honorsSystem;
      final p = newProbe();
      await probe(p, 'id');

      expect(p.verdictFor('id'), isNull);
      expect(p.isSystemDropped('id'), isFalse);
    });

    test('the filler clears the calibration floor with room to spare', () {
      // A filler that ever shrank below the floor would make every probe
      // report "unusable prompt_tokens" while every other test still passed.
      final words = kSystemRoleProbeFiller.trim().split(RegExp(r'\s+')).length;
      expect(words, greaterThan(kSystemRoleProbeMinRefTokens * 3));
    });
  });

  group('fails open', () {
    test('a 5xx server leaves the backend untested, not degraded', () async {
      fault = FakeFault.serverError;
      final p = newProbe();
      await probe(p, 'id');
      expect(p.verdictFor('id'), isNull);
      expect(p.isSystemDropped('id'), isFalse);
    });

    test('a reply with no usage block leaves it untested', () async {
      template = FakeTemplate.dropsSystem;
      fault = FakeFault.noUsage;
      final p = newProbe();
      await probe(p, 'id');
      expect(p.verdictFor('id'), isNull);
      expect(p.isSystemDropped('id'), isFalse);
    });

    test('an unreachable backend leaves it untested', () async {
      final p = newProbe();
      // Port 1 has nothing listening; the connection is refused.
      await p.ensureProbed(baseUrl: 'http://127.0.0.1:1', identity: 'id');
      expect(p.verdictFor('id'), isNull);
    });
  });

  group('cost', () {
    test('a settled verdict is never re-probed', () async {
      template = FakeTemplate.dropsSystem;
      final p = newProbe();
      await probe(p, 'id');
      final after = received.length;
      await probe(p, 'id');
      await probe(p, 'id');
      expect(received.length, after);
    });

    test('a broken backend is retried but never per-turn', () async {
      fault = FakeFault.serverError;
      final p = newProbe();
      await probe(p, 'id');
      // ONE call spends the whole budget. It has to: the production call site
      // is the model-ready transition, which fires once per load, so a budget
      // spread across calls would never be spent at all.
      // The arms short-circuit on the first failure, so a dead server costs
      // one request per attempt, not three.
      expect(received.length, kSystemRoleProbeMaxAttempts);

      for (var turn = 0; turn < 25; turn++) {
        await probe(p, 'id');
      }
      // ...and once spent, it stays spent. The model-ready transition is
      // driven by a regex over the backend's console output and can fire more
      // than once per load; without the exhausted marker each of those would
      // restart the whole chain against a server that is never going to
      // answer.
      expect(received.length, kSystemRoleProbeMaxAttempts);
    });

    test('a backend still warming up at load is measured on the retry',
        () async {
      // The reason the budget exists, and the case it could never reach
      // before: KoboldCpp prints "please connect" the moment it binds the
      // port, so the probe can be armed while the model is still settling.
      // One 503 used to leave the identity unmeasured for the whole run —
      // every reply card-less — with no recovery short of the user stopping
      // and restarting the backend, which nothing told them to do.
      failFirstRequests = 1;
      template = FakeTemplate.dropsSystem;
      final p = newProbe();

      await probe(p, 'id'); // a single call, exactly as production makes it

      expect(p.verdictFor('id'), isFalse,
          reason: 'the second attempt got a real measurement');
      expect(received.length, 4, reason: '1 failed arm + a full 3-arm retry');
    });

    test('every arm runs through the caller\'s exclusive-access wrapper',
        () async {
      // KoboldService passes its request-slot wrapper here. If an arm ever
      // bypassed it, that arm could fire alongside the user's own generation.
      template = FakeTemplate.honorsSystem;
      var wrapped = 0;
      var insideWrapper = 0;
      await newProbe().ensureProbed(
        baseUrl: baseUrl(),
        identity: 'id',
        runExclusive: (body) async {
          wrapped++;
          insideWrapper++;
          // A single-slot engine: no two arms may overlap.
          expect(insideWrapper, 1);
          try {
            return await body();
          } finally {
            insideWrapper--;
          }
        },
      );
      expect(wrapped, 3);
      expect(received.length, 3);
    });

    test('reset re-arms an identity AND refunds its retry budget', () async {
      // The only recovery path there is: three inconclusive attempts (server
      // still settling at load) otherwise disable the workaround for that
      // model for the rest of the run. KoboldService calls this on stop.
      fault = FakeFault.serverError;
      final p = newProbe();
      for (var turn = 0; turn < 10; turn++) {
        await probe(p, 'id');
      }
      expect(received.length, kSystemRoleProbeMaxAttempts);
      expect(p.verdictFor('id'), isNull);

      p.reset('id');
      fault = FakeFault.none;
      template = FakeTemplate.dropsSystem;
      await probe(p, 'id');
      expect(p.verdictFor('id'), isFalse);
    });

    test('reset forgets a settled verdict (GGUF swapped at the same path)',
        () async {
      template = FakeTemplate.dropsSystem;
      final p = newProbe();
      await probe(p, 'id');
      expect(p.isSystemDropped('id'), isTrue);
      p.reset('id');
      expect(p.verdictFor('id'), isNull);
      template = FakeTemplate.honorsSystem;
      await probe(p, 'id');
      expect(p.verdictFor('id'), isTrue);
    });

    test('the identity key changes when EITHER model changes', () {
      // The whole point of the key: capability is per model, so switching
      // local model or remote model must re-probe rather than inherit.
      final local = systemRoleIdentityFor(
        backendName: 'KoboldCPP',
        remoteModelName: '',
        modelPath: '/m/magnum.gguf',
      );
      expect(
        local,
        isNot(systemRoleIdentityFor(
          backendName: 'KoboldCPP',
          remoteModelName: '',
          modelPath: '/m/gemma.gguf',
        )),
      );
      expect(
        local,
        isNot(systemRoleIdentityFor(
          backendName: 'KoboldCPP',
          remoteModelName: 'some/remote',
          modelPath: '/m/magnum.gguf',
        )),
      );
      // A null path must not read as a different backend than an empty one.
      expect(
        systemRoleIdentityFor(
          backendName: 'KoboldCPP',
          remoteModelName: '',
          modelPath: null,
        ),
        systemRoleIdentityFor(
          backendName: 'KoboldCPP',
          remoteModelName: '',
          modelPath: '',
        ),
      );
    });

    test('verdicts are per backend+model identity', () async {
      template = FakeTemplate.dropsSystem;
      final p = newProbe();
      await probe(p, 'KoboldCPP||magnum.gguf');
      expect(p.isSystemDropped('KoboldCPP||magnum.gguf'), isTrue);
      // Switching model must not inherit the previous model's verdict.
      expect(p.isSystemDropped('KoboldCPP||gemma.gguf'), isFalse);
    });
  });

  // ── Lifecycle: a probe measures ONE server, and a reset ends it ────────
  //
  // reset() is called from stopKobold(). Everything below is about the window
  // where the measurement outlives the thing it was measuring.
  group('a reset really ends the probe it disowns', () {
    test('a probe already on the wire is cancelled, not merely forgotten',
        () async {
      // Closing the socket is the load-bearing part. Without it the arm sits
      // there for kSystemRoleProbeTimeout — 60 seconds — and because every arm
      // runs inside the backend's single request slot, the fresh probe AND the
      // user's first message queue behind a request to a server that is gone.
      responseDelay = const Duration(seconds: 5);
      template = FakeTemplate.dropsSystem;
      final p = newProbe();

      final running = probe(p, 'id');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(received.length, 1, reason: 'arm one is on the wire');

      p.reset('id');
      await running.timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('reset left the probe stuck on the wire'),
      );

      expect(p.verdictFor('id'), isNull,
          reason: 'a verdict measured on a server we have forgotten must not '
              'land after the reset that forgot it');
      expect(received.length, 1, reason: 'no further arms were issued');
    });

    test('the disowned probe cannot overwrite the one that replaced it',
        () async {
      // Stop, swap the GGUF at the same path, start again. The old probe is
      // still unwinding while the new one measures a DIFFERENT template; the
      // one that describes the model actually loaded has to win, whichever
      // finishes last.
      responseDelay = const Duration(seconds: 5);
      template = FakeTemplate.dropsSystem;
      final p = newProbe();
      final disowned = probe(p, 'id');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      p.reset('id');
      responseDelay = Duration.zero;
      template = FakeTemplate.honorsSystem;
      await probe(p, 'id');
      await disowned.timeout(const Duration(seconds: 2));

      expect(p.verdictFor('id'), isTrue,
          reason: 'the loaded model honours the system role; the old '
              'measurement must not fold the card into the user turn');
    });

    test('a measurement that COMPLETES after a reset is still discarded',
        () async {
      // The narrow window the disowned flag exists for, and the one the two
      // tests above cannot reach: the reset lands between the final arm
      // coming back and the verdict being written. On the last attempt there
      // is no backoff left to notice it, so without the check the stale
      // verdict is recorded on a backend that has already stopped.
      //
      // The exclusive-access wrapper is the timing hook: it is the caller's
      // own code, and it runs at exactly that boundary.
      template = FakeTemplate.dropsSystem;
      final p = newProbe();
      var arms = 0;
      await p.ensureProbed(
        baseUrl: baseUrl(),
        identity: 'id',
        runExclusive: (body) async {
          final tokens = await body();
          if (++arms == 3) p.reset('id'); // the backend stops, right here
          return tokens;
        },
      );

      expect(p.verdictFor('id'), isNull,
          reason: 'this describes a model that is no longer loaded');
    });

    test('two overlapping calls run ONE probe, never two racing ones',
        () async {
      // reset() used to drop the in-flight marker without cancelling the run,
      // which is how a second probe could start alongside the first.
      template = FakeTemplate.dropsSystem;
      final p = newProbe();
      final first = probe(p, 'id');
      final second = probe(p, 'id');
      await Future.wait([first, second]);

      expect(received.length, 3, reason: 'one probe, three arms — not six');
      expect(p.verdictFor('id'), isFalse);
    });
  });

  group('the fallback actually reaches the model', () {
    const card =
        'You are Malumbra, an old warden of the Oblivian hall.\nLinus is the '
        'human you are talking with.';

    Future<Map<String, dynamic>> stream({required bool fold}) async {
      await streamOpenAiChat(
        baseUrl(),
        const GenerationParams(prompt: 'Hello there.', systemPrompt: card),
        foldSystemIntoUser: fold,
      ).toList();
      return received.last;
    }

    test('without the fallback the card rides a system message', () async {
      final payload = await stream(fold: false);
      final messages = (payload['messages'] as List).cast<Map>();
      expect(messages.first['role'], 'system');
      expect(messages.first['content'], card);
      expect(messages.last['content'], 'Hello there.');
    });

    test('with the fallback the card rides the user message instead',
        () async {
      final payload = await stream(fold: true);
      final messages = (payload['messages'] as List).cast<Map>();
      // No system message at all — on these backends it is a black hole.
      expect(messages.any((m) => m['role'] == 'system'), isFalse);
      expect(messages.length, 1);
      final content = messages.single['content'] as String;
      expect(content, startsWith(card));
      expect(content, endsWith('Hello there.'));
    });

    test('the tools transport folds identically', () async {
      await postOpenAiChatWithTools(
        baseUrl(),
        const GenerationParams(prompt: 'Hello there.', systemPrompt: card),
        const [],
        foldSystemIntoUser: true,
      );
      final messages = (received.last['messages'] as List).cast<Map>();
      expect(messages.any((m) => m['role'] == 'system'), isFalse);
      expect(messages.single['content'], startsWith(card));
    });

    test('a multimodal turn keeps its image parts and their order', () {
      final folded = foldSystemIntoUserContent(card, const [
        {'type': 'text', 'text': 'What is this?'},
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/png;base64,AAA'},
        },
      ]);
      final parts = (folded as List).cast<Map>();
      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      expect(parts[0]['text'], '$card\n\nWhat is this?');
      expect(parts[1]['type'], 'image_url');
    });

    test('an image-only turn gains a text part rather than losing the card',
        () {
      final folded = foldSystemIntoUserContent(card, const [
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/png;base64,AAA'},
        },
      ]);
      final parts = (folded as List).cast<Map>();
      expect(parts.length, 2);
      expect(parts[0]['text'], card);
      expect(parts[1]['type'], 'image_url');
    });
  });
}
