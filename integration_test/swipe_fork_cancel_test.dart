// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: the message-branching journeys message_actions deliberately left to
// P3 — swipe navigation, cancel-mid-regenerate, and fork — now drivable
// because the fake backend can pace its chat stream (chatChunkDelay), which
// turns the cancel window from a race into a ~5-second door:
//   * SWIPES: a regenerate grafts swipe 2/2; the bubble's chevrons navigate
//     back to 1/2 and forward again WITHOUT firing a new generation, and
//     the rejected swipe keeps its preserved chip metadata;
//   * CANCEL: stopping a regenerate mid-stream keeps the partial as a new
//     swipe, keeps the ORIGINAL text as swipe 1 (the 124b8ff put-back
//     class — cancelling used to destroy the message being regenerated),
//     and releases every guard so the composer stays usable;
//   * FORK: the real bubble button + confirm dialog branch a new session
//     that carries the multi-swipe message intact, records its parent and
//     fork index, and leaves the old session untouched.
//
// Run it with:
//   flutter test integration_test/swipe_fork_cancel_test.dart -d macos
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

const _kGreeting = 'Welcome to the branching porch.';

/// Many small pieces on purpose: with chatChunkDelay each piece is one paced
/// SSE chunk, so the stream takes pieces × delay — the cancel phase taps
/// Stop inside that window and must land well before the final chunk.
const _kReplyPieces = [
  'The fake ', 'backend ', 'replies ', 'about ', 'branching ', 'porches ', //
  'tonight, ', 'slowly, ', 'one ', 'warm ', 'word ', 'at ', 'a ', 'time.',
];

/// Reads a needs_deltas chip map ({need: {delta, reason}} — or a bare int,
/// parsed defensively like the bubbles do) into {need: delta}.
Map<String, int> _deltasOf(Map<String, dynamic>? needsDeltas) {
  final out = <String, int>{};
  if (needsDeltas == null) return out;
  needsDeltas.forEach((need, chip) {
    if (chip is Map) {
      final d = chip['delta'];
      if (d is int && d != 0) out[need] = d;
    } else if (chip is int && chip != 0) {
      out[need] = chip;
    }
  });
  return out;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('swipe navigation, cancel-mid-regenerate put-back, and fork '
      'through the real bubble controls — sandboxed', (tester) async {
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

    final sandbox = Directory.systemTemp.createTempSync('fpai_branch_');
    PathProviderPlatform.instance = SandboxPathProvider(sandbox.path);
    final backend = await FakeBackendServer.start(
      replyPieces: _kReplyPieces,
      chatChunkDelay: const Duration(milliseconds: 400),
    );
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
    // Single firstMessage on purpose: the greeting-swipe row reuses the same
    // chevron icons and 'n/m' counter shape as the message-swipe row and
    // only builds when a character has alternate greetings — one greeting
    // keeps the finders unambiguous.
    final character = CharacterCard(
      name: 'Branch Tester',
      description: 'Exists only inside the swipe/fork/cancel E2E.',
      firstMessage: _kGreeting,
      frontPorchExtensions: FrontPorchExtensions(
        realismEnabled: true,
        needsSimEnabled: true,
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

    // Bubble lookup lives on the driver since 2026-08-10 (d.revealBubbleFor):
    // the page-owned-GlobalKey crash fix removed the GlobalObjectKey(msg)
    // key scheme this suite's local finder depended on, and the shared
    // finder now matches on MessageBubble.message identity — same
    // virtualization workaround, key-scheme-independent.

    /// Reveal [msg]'s bubble, tap [control] inside it, require
    /// [confirmation] — retrying the whole loop (message_actions' pattern:
    /// a background rebuild can re-virtualize the bubble mid-flight).
    Future<void> tapBubbleControl(
      ChatMessage msg,
      Finder Function(Finder bubble) control,
      Finder confirmation,
    ) async {
      for (
        var attempt = 0;
        attempt < 6 && confirmation.evaluate().isEmpty;
        attempt++
      ) {
        final bubble = await d.revealBubbleFor(msg);
        final btn = control(bubble);
        if (btn.evaluate().isEmpty) {
          await tester.pump(const Duration(milliseconds: 250));
          continue;
        }
        try {
          await tester.ensureVisible(btn.first);
        } on StateError {
          continue; // re-virtualized mid-flight — reveal again
        }
        await tester.pump(const Duration(milliseconds: 200));
        if (btn.evaluate().isEmpty) continue;
        await tester.tap(btn.first, warnIfMissed: false);
        for (var i = 0; i < 6 && confirmation.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      }
      await d.waitForWidget(confirmation, timeout: const Duration(seconds: 15));
    }

    // ── Seed one scored turn ────────────────────────────────────────────
    final fullReply = _kReplyPieces.join();
    await d.sendMessage('The porch swing creaks as I sit down.');
    await d.waitFor(
      () =>
          chatService.messages.isNotEmpty &&
          !chatService.messages.last.isUser &&
          chatService.messages.last.text == fullReply,
      () => 'turn 1 to stream fully (chat=${backend.chatRequests})',
      timeout: const Duration(seconds: 120),
    );
    await d.waitSendable();

    // ── SWIPES: regenerate grafts 2/2, chevrons navigate without firing ─
    final reply = chatService.messages.last;
    final originalText = reply.text;
    final originalDeltas = _deltasOf(
      reply.activeMetadata?['needs_deltas'] as Map<String, dynamic>?,
    );
    expect(originalDeltas, isNotEmpty, reason: 'turn 1 must carry chips');

    var chatBefore = backend.chatRequests;
    final regenBtn = find.byTooltip('Regenerate');
    await d.waitForWidget(regenBtn);
    await d.tapUntilTrue(
      [regenBtn],
      () => backend.chatRequests > chatBefore,
      () => 'the regenerate to fire (chat=${backend.chatRequests})',
      timeout: const Duration(seconds: 120),
    );
    await d.waitSendable();
    expect(reply.swipes.length, 2, reason: 'regen grafts the reply as 2/2');
    expect(reply.swipeIndex, 1);
    await d.waitForWidget(find.text('2/2'));

    // Left chevron → back on the ORIGINAL swipe, chips preserved.
    final bubble = await d.revealBubbleFor(reply);
    final leftArrow = find.descendant(
      of: bubble,
      matching: find.byIcon(Icons.chevron_left),
    );
    await d.waitForWidget(leftArrow);
    chatBefore = backend.chatRequests;
    await d.tapUntilTrue(
      [leftArrow],
      () => reply.swipeIndex == 0,
      () => 'the left chevron to select swipe 1 (index ${reply.swipeIndex})',
    );
    await d.waitForWidget(find.text('1/2'));
    expect(reply.swipes[0], originalText);
    expect(
      _deltasOf(reply.activeMetadata?['needs_deltas'] as Map<String, dynamic>?),
      originalDeltas,
      reason: 'the rejected swipe must keep its preserved chip metadata',
    );

    // Right chevron → 2/2 again, and NO new generation fired (navigation
    // within range never regenerates; only right-past-the-end does).
    final rightArrow = find.descendant(
      of: await d.revealBubbleFor(reply),
      matching: find.byIcon(Icons.chevron_right),
    );
    await d.waitForWidget(rightArrow);
    await d.tapUntilTrue(
      [rightArrow],
      () => reply.swipeIndex == 1,
      () => 'the right chevron to select swipe 2 (index ${reply.swipeIndex})',
    );
    await d.waitForWidget(find.text('2/2'));
    expect(
      backend.chatRequests,
      chatBefore,
      reason: 'swiping between existing swipes must never fire a generation',
    );

    // ── CANCEL-MID-REGENERATE: partial kept, original kept, guards clear ─
    await d.waitSendable();
    chatBefore = backend.chatRequests;
    final msgCountBefore = chatService.messages.length;
    // Wait for the stream to actually be flowing: the composer swaps to the
    // Stop button while generating, and the paced fake means the reply text
    // is still mid-assembly when we see the first content.
    await d.tapUntilTrue(
      [regenBtn],
      () =>
          chatService.isGenerating &&
          chatService.messages.isNotEmpty &&
          !chatService.messages.last.isUser &&
          chatService.messages.last.text.isNotEmpty,
      () =>
          'the paced regenerate to start streaming '
          '(gen=${chatService.isGenerating})',
      timeout: const Duration(seconds: 120),
    );
    // Delivery-confirmed stop: keep tapping while the generation lives.
    final stopBtn = find.byTooltip('Stop Generation');
    final stopDeadline = DateTime.now().add(
      const Duration(seconds: 30) * kCiTimeoutScale,
    );
    while (chatService.isGenerating && DateTime.now().isBefore(stopDeadline)) {
      if (stopBtn.evaluate().isNotEmpty) {
        await tester.tap(stopBtn.first, warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    await d.waitSendable();

    // The put-back contract: same message instance, original text intact as
    // swipe 1, the partial grafted as a NEW swipe, nothing destroyed.
    expect(chatService.messages.length, msgCountBefore);
    expect(
      identical(chatService.messages.last, reply),
      isTrue,
      reason: 'cancel must put the SAME message object back',
    );
    expect(reply.swipes.length, 3, reason: 'the partial joins as swipe 3');
    expect(reply.swipeIndex, 2);
    expect(reply.swipes[0], originalText, reason: 'swipe 1 survives cancel');
    expect(
      fullReply.startsWith(reply.swipes[2]),
      isTrue,
      reason: 'the kept partial is a prefix of the paced reply',
    );
    expect(
      reply.swipes[2].length,
      lessThan(fullReply.length),
      reason:
          'Stop landed mid-stream, so the kept swipe must be a strict '
          'partial — a full-length swipe means the cancel window was missed',
    );
    expect(backend.chatRequests, chatBefore + 1);
    await d.waitForWidget(find.text('3/3'));

    // ── FORK: branch a new session carrying the multi-swipe message ─────
    final oldSession = chatService.currentSessionId;
    expect(oldSession, isNotNull);
    final forkIndex = chatService.messages.length - 1;
    await tapBubbleControl(
      reply,
      (b) => find.descendant(of: b, matching: find.byTooltip('Fork from here')),
      find.text('Fork Conversation'),
    );
    await d.tapUntilTrue(
      [find.widgetWithText(ElevatedButton, 'Fork')],
      () => chatService.currentSessionId != oldSession,
      () => 'the fork to swap in a new session id',
      timeout: const Duration(seconds: 30),
    );
    expect(chatService.parentSessionId, oldSession);
    expect(chatService.forkIndex, forkIndex);
    expect(chatService.messages.length, forkIndex + 1);
    expect(
      chatService.messages.last.swipes.length,
      3,
      reason: 'a fork carries every swipe of the branch point message',
    );
    await d.waitForWidget(
      find.text('Conversation forked! You are now on the new branch.'),
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
