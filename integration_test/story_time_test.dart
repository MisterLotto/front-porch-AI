// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: the story clock — CONTINUOUS per-turn advancement and persistence.
// StoryClock's math and TimeService's plumbing are unit-pinned
// (story_clock_test, time_service_test); what nothing proved is the
// journey: a real scored exchange moving the clock through the fused
// scene-time eval (the fake backend answers minutes_elapsed: 5), and the
// advanced clock surviving a session reload via the per-message
// realism_state (the clock is persisted and restored through message
// metadata — see CLAUDE.md's "PASSAGE OF TIME CANNOT BE DECOUPLED FROM
// REALISM" section for why realism must be on here).
//
// Weather's journey coverage lives in app_smoke (currentWeather non-null +
// seed-stable across reload) — this suite is the clock's counterpart.
//
// Run it with:
//   flutter test integration_test/story_time_test.dart -d macos
//
// Isolation contract: identical to app_smoke_test.dart — see its header.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:front_porch_ai/main.dart' as app;
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/layout/main_layout.dart';
import 'package:front_porch_ai/ui/pages/chat_page.dart';

import 'support/chat_driver.dart';
import 'support/e2e_sandbox.dart';
import 'support/fake_backend.dart';

const _kGreeting = 'Welcome to the story time porch.';
const _kReplyPieces = ['The clock ticks ', 'while the porch light burns.'];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the story clock advances on scored turns and survives a '
      'session reload — sandboxed', (tester) async {
    try {
      final probe = await Socket.connect(
        InternetAddress.loopbackIPv4,
        5001,
        timeout: const Duration(milliseconds: 500),
      );
      probe.destroy();
      fail(
        'Something is listening on 127.0.0.1:5001 (a real KoboldCpp?). '
        'Close it before running the E2E suite.',
      );
    } on SocketException {
      // Nothing there — safe to proceed.
    }

    final sandbox = Directory.systemTemp.createTempSync('fpai_time_');
    PathProviderPlatform.instance = SandboxPathProvider(sandbox.path);
    final backend = await FakeBackendServer.start(replyPieces: _kReplyPieces);
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'import_llmerta_porch_memories': false,
      'realism_default': true,
      'backend_type': 'openRouter',
      'remote_api_url': '${backend.baseUrl}/v1',
      'remote_model_name': 'smoke-model',
    });

    // ── Boot ────────────────────────────────────────────────────────────
    app.main(const []);
    await pumpUntilFound(tester, find.byType(MainLayout));
    try {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSize(const Size(1200, 800));
      await windowManager.setAlignment(Alignment.bottomRight);
      await windowManager.blur();
    } catch (e) {
      debugPrint('[e2e] window_manager placement skipped: $e');
    }
    await tester.pump(const Duration(seconds: 2));

    final ctx = tester.element(find.byType(MainLayout));
    final character = CharacterCard(
      name: 'Clock Tester',
      description: 'Exists only inside the story-time E2E.',
      firstMessage: _kGreeting,
      frontPorchExtensions: FrontPorchExtensions(
        realismEnabled: true,
        needsSimEnabled: false,
        chaosModeEnabled: false,
      ),
    );
    await Provider.of<CharacterRepository>(
      ctx,
      listen: false,
    ).addCharacter(character);
    final chatService = Provider.of<ChatService>(ctx, listen: false);
    await chatService.setActiveCharacter(character);
    // ignore: use_build_context_synchronously — root MainLayout element.
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const ChatPage()));

    final d = ChatDriver(tester, chatService, backend);
    await d.waitForWidget(find.textContaining(_kGreeting, findRichText: true));
    await d.waitForWidget(d.input);

    final clock = chatService.timeService;
    final isoAtStart = clock.storyClockIso;
    expect(clock.timeOfDay, isNotEmpty);
    expect(clock.dayCount, greaterThanOrEqualTo(1));

    // ── Two turns: the scene-time eval is PRE-GEN, so turn 2's eval scores
    //    exchange 1 and applies the canned minutes_elapsed: 5 ─────────────
    await d.sendMessage('The evening settles in around us.');
    await d.waitFor(
      () => backend.chatRequests >= 1,
      () => 'turn 1 to generate (chat=${backend.chatRequests})',
      timeout: const Duration(seconds: 120),
    );
    await d.waitForWidget(
      find.textContaining(_kReplyPieces.join(), findRichText: true),
    );
    await d.waitSendable();

    await d.sendMessage('We talk until the stars come out.');
    await d.waitFor(
      () => backend.chatRequests >= 2,
      () => 'turn 2 to generate (chat=${backend.chatRequests})',
      timeout: const Duration(seconds: 120),
    );
    await d.waitSendable();

    // The clock may only ever move FORWARD, and after a scored exchange it
    // must have moved at all — a frozen clock was the exact failure the
    // continuous-advance design (failureDriftMinutes + stall backstop)
    // exists to prevent.
    final isoAfterTurns = clock.storyClockIso;
    expect(
      isoAfterTurns,
      isNot(isoAtStart),
      reason:
          'the story clock must advance across a scored exchange '
          '(the canned scene-time eval pays minutes_elapsed: 5)',
    );
    final parsedStart = DateTime.tryParse(isoAtStart);
    final parsedAfter = DateTime.tryParse(isoAfterTurns);
    if (parsedStart != null && parsedAfter != null) {
      expect(
        parsedAfter.isAfter(parsedStart),
        isTrue,
        reason:
            'the clock must move forward, never back '
            '($isoAtStart → $isoAfterTurns)',
      );
      expect(
        parsedAfter.difference(parsedStart).inMinutes,
        greaterThanOrEqualTo(5),
        reason:
            'at least one applied scene-time eval of 5 minutes is expected '
            '($isoAtStart → $isoAfterTurns)',
      );
    }

    // ── Persistence: the clock rides realism_state through a reload ─────
    final sessionId = chatService.currentSessionId;
    expect(sessionId, isNotNull);
    // Full quiescence FIRST, then capture immediately before the reload:
    // trailing post-settle work (the realism_state patch on the last
    // message) can legitimately advance the clock after the earlier
    // capture — the first CI run compared against a stale snapshot and
    // went red by exactly one 5-minute tick (Linux leg, attempt 1). The
    // persistence contract is "reload preserves the clock", not "nothing
    // advanced it since an arbitrary earlier moment".
    await d.waitSendable();
    await tester.pump(const Duration(seconds: 1));
    await d.waitSendable();
    final isoBeforeReload = chatService.timeService.storyClockIso;
    await chatService.loadSession(sessionId!);
    await d.waitFor(
      () => chatService.messages.length >= 5,
      () =>
          'the conversation to come back after reload '
          '(messages=${chatService.messages.length})',
    );
    expect(
      chatService.timeService.storyClockIso,
      isoBeforeReload,
      reason:
          'the story clock must be restored from the last message\'s '
          'realism_state on reload — a reset here is the frozen-timestamp '
          'class CLAUDE.md\'s time section warns about',
    );

    expect(backend.unexpectedPaths, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await backend.close();
    try {
      sandbox.deleteSync(recursive: true);
    } on FileSystemException {
      // A straggler may still be writing; not a failure.
    }
  });
}
