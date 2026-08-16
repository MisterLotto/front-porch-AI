// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: message-action journeys — edit, regenerate, delete-with-needs-refund —
// driven through the real bubbles' buttons and dialogs. Three shipped bugs
// live on this surface and none had a journey guard:
//   * deleting a message left its needs cost applied forever (fixed by the
//     arithmetic refund; unit-pinned in delete_message_needs_rollback_test,
//     but nothing ever TAPPED the delete button through the confirm dialog);
//   * regenerating replayed realism side effects (regen rewind);
//   * the themed-overlay bug ate these exact buttons silently.
// This suite asserts the tap→dialog→service→UI loop for each action.
//
// DELIBERATELY NOT COVERED here: cancelling a regenerate mid-stream. The
// fake backend streams its reply immediately, so the cancel window would be
// a race — precisely the flake class this suite exists to avoid. The
// cancel-restores-the-message behavior is unit-pinned (reprocess/rewind
// tests); an E2E version needs a delay-capable fake first (see the
// coverage map, P3).
//
// Run it with:
//   flutter test integration_test/message_actions_test.dart -d macos
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

const _kGreeting = 'Welcome to the message actions porch.';
const _kReplyPieces = ['The fake backend replies ', 'about message actions.'];
const _kEditedGreeting = 'This greeting was edited by the E2E suite.';

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

  testWidgets('edit, regenerate, and delete-with-refund through the real '
      'bubble controls — sandboxed', (tester) async {
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

    final sandbox = Directory.systemTemp.createTempSync('fpai_msgact_');
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
      name: 'Action Tester',
      description: 'Exists only inside the message-actions E2E.',
      firstMessage: _kGreeting,
      // Chaos deliberately OFF: the wheel is covered by app_smoke, and this
      // suite's delete/regen phases want the fewest concurrent modals. The
      // driver still guards against one anyway.
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

    // Bubble lookup lives on the driver since 2026-08-10 (d.bubbleFor /
    // d.revealBubbleFor): the page-owned-GlobalKey crash fix removed the
    // GlobalObjectKey(msg) key scheme this suite's local finder depended
    // on, and the shared finder now matches on MessageBubble.message
    // identity — same virtualization workaround, key-scheme-independent.

    // ── Seed two turns so realism + needs have scored an exchange ───────
    await d.sendMessage('The porch swing creaks as I sit down.');
    await d.waitFor(
      () => backend.chatRequests >= 1,
      () => 'turn 1 to generate (chat=${backend.chatRequests})',
      timeout: const Duration(seconds: 120),
    );
    await d.waitForWidget(
      find.textContaining(_kReplyPieces.join(), findRichText: true),
    );
    await d.waitSendable();

    await d.sendMessage('Tell me about your evening out here.');
    await d.waitFor(
      () => backend.chatRequests >= 2,
      () => 'turn 2 to generate (chat=${backend.chatRequests})',
      timeout: const Duration(seconds: 120),
    );
    await d.waitSendable();

    /// Reveal [msg]'s bubble, tap the control [control] resolves inside it,
    /// and require [confirmation] to appear — retrying the WHOLE
    /// reveal→tap loop until it does. One reveal + one tap is not enough:
    /// a background rebuild can re-virtualize the just-revealed bubble in
    /// the gap between ensureVisible and the tap (the macOS round-2
    /// failure), so delivery is confirmed the same way the driver
    /// confirms sends.
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

    // ── EDIT: greeting text changes through the dialog and sticks ───────
    await tapBubbleControl(
      chatService.messages.first,
      (bubble) =>
          find.descendant(of: bubble, matching: find.byTooltip('Edit message')),
      find.text('Save'),
    );

    final dialogField = find.descendant(
      of: find.byType(Dialog).last,
      matching: find.byType(TextField),
    );
    expect(dialogField, findsWidgets);
    await tester.enterText(dialogField.first, _kEditedGreeting);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Save'));
    await d.waitFor(
      () => chatService.messages.any((m) => m.text == _kEditedGreeting),
      () => 'the edited greeting to land in the message list',
      timeout: const Duration(seconds: 15),
    );
    await d.waitForWidget(
      find.textContaining(_kEditedGreeting, findRichText: true),
    );
    expect(
      chatService.messages.any((m) => m.text.contains(_kGreeting)),
      isFalse,
      reason: 'the pre-edit greeting text must be fully replaced',
    );

    // ── REGENERATE: last bot reply is redone, count stays coherent ──────
    await d.waitSendable();
    final messagesBeforeRegen = chatService.messages.length;
    final chatRequestsBeforeRegen = backend.chatRequests;

    final regenBtn = find.byTooltip('Regenerate');
    await tester.ensureVisible(regenBtn.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(regenBtn.first);
    await d.waitFor(
      () => backend.chatRequests > chatRequestsBeforeRegen,
      () =>
          'the regenerate to reach the backend '
          '(chat=${backend.chatRequests}, before=$chatRequestsBeforeRegen)',
      timeout: const Duration(seconds: 120),
    );
    await d.waitSendable();
    expect(
      chatService.messages.length,
      messagesBeforeRegen,
      reason:
          'a regenerate must replace the last reply in place — a changed '
          'count means it stacked or deleted messages',
    );
    expect(chatService.messages.last.isUser, isFalse);

    // ── DELETE: a CHIP-CARRYING reply, through the confirm dialog, with
    //    refund. The target is found by its chips, not by position: the
    //    first CI run targeted the just-regenerated reply, whose chip map is
    //    legitimately empty on some paths (Linux leg) — the message the
    //    needs-impact pipeline actually charged is the one whose deletion
    //    must refund.
    await d.waitSendable();
    final target = chatService.messages.lastWhere(
      (m) =>
          !m.isUser &&
          m.sender != 'System' &&
          _deltasOf(
            (m.activeMetadata?['needs_deltas'] as Map?)
                ?.cast<String, dynamic>(),
          ).isNotEmpty,
      orElse: () => fail(
        'no bot message carries nonzero needs_deltas — the needs-impact '
        'pipeline attached no chips anywhere. Metadata keys per message: '
        '${chatService.messages.map((m) => m.activeMetadata?.keys.toList()).toList()}',
      ),
    );
    final deltas = _deltasOf(
      (target.activeMetadata?['needs_deltas'] as Map?)?.cast<String, dynamic>(),
    );
    final needsBefore = Map<String, int>.from(
      chatService.needsSimulation.vector,
    );
    final countBeforeDelete = chatService.messages.length;

    await tapBubbleControl(
      target,
      (bubble) => find.descendant(
        of: bubble,
        matching: find.byIcon(Icons.delete_outline),
      ),
      find.text('Delete Message'),
    );
    await tester.tap(find.text('Delete'));
    await d.waitFor(
      () => chatService.messages.length == countBeforeDelete - 1,
      () =>
          'the delete to land '
          '(messages=${chatService.messages.length})',
      timeout: const Duration(seconds: 15),
    );
    expect(
      chatService.messages.contains(target),
      isFalse,
      reason: 'the deleted message instance must leave the list',
    );
    // The bubble leaves the TREE one frame after it leaves the list — the
    // round-2 Linux red asserted findsNothing in the same instant the list
    // updated and caught the not-yet-rebuilt frame. Bounded wait: if the
    // bubble genuinely lingers, this still fails — as it should.
    await d.waitFor(
      () => d.bubbleFor(target).evaluate().isEmpty,
      () => 'the deleted message\'s bubble to leave the tree',
      timeout: const Duration(seconds: 10),
    );

    // The refund contract (unit-pinned arithmetic; this asserts the JOURNEY
    // delivers it): every nonzero chip on the deleted message is subtracted
    // from the needs the character holds now.
    final needsAfter = chatService.needsSimulation.vector;
    deltas.forEach((need, delta) {
      expect(
        needsAfter[need],
        (needsBefore[need]! - delta).clamp(0, 100),
        reason:
            'deleting the reply must refund its "$need" chip of $delta '
            '(before=${needsBefore[need]}, after=${needsAfter[need]})',
      );
    });

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
