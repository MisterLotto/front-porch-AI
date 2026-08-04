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
import 'package:front_porch_ai/ui/chat_components/chat_components.dart'
    show MessageBubble;
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

    /// The MessageBubble that renders [text] — ancestor-addressed so bubble
    /// order in the (reversed) list never matters.
    Finder bubbleWith(String text) => find
        .ancestor(
          of: find.textContaining(text, findRichText: true).first,
          matching: find.byType(MessageBubble),
        )
        .first;

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

    // ── EDIT: greeting text changes through the dialog and sticks ───────
    final editBtn = find.descendant(
      of: bubbleWith(_kGreeting),
      matching: find.byTooltip('Edit message'),
    );
    await tester.ensureVisible(editBtn);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(editBtn);
    await d.waitForWidget(
      find.text('Save'),
      timeout: const Duration(seconds: 15),
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

    // ── DELETE: the last reply, through the confirm dialog, with refund ──
    await d.waitSendable();
    final target = chatService.messages.last;
    final deltas = _deltasOf(
      (target.activeMetadata?['needs_deltas'] as Map?)?.cast<String, dynamic>(),
    );
    final needsBefore = Map<String, int>.from(
      chatService.needsSimulation.vector,
    );
    final targetText = _kReplyPieces.join();

    final deleteBtn = find.descendant(
      of: bubbleWith(targetText),
      matching: find.byIcon(Icons.delete_outline),
    );
    await tester.ensureVisible(deleteBtn.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(deleteBtn.first);
    await d.waitForWidget(
      find.text('Delete Message'),
      timeout: const Duration(seconds: 15),
    );
    await tester.tap(find.text('Delete'));
    await d.waitFor(
      () => chatService.messages.length == messagesBeforeRegen - 1,
      () =>
          'the delete to land '
          '(messages=${chatService.messages.length})',
      timeout: const Duration(seconds: 15),
    );
    expect(chatService.messages.last.isUser, isTrue);

    // The refund contract (unit-pinned arithmetic; this asserts the JOURNEY
    // delivers it): every nonzero chip on the deleted message is subtracted
    // from the needs the character holds now.
    expect(
      deltas,
      isNotEmpty,
      reason:
          'the canned needs eval pays nonzero deltas — an empty chip map '
          'means the needs-impact pipeline never ran on the deleted reply, '
          'and the refund below would be vacuously green',
    );
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

    // The deleted turn's realism metadata is gone from the timeline.
    expect(
      find.textContaining(targetText, findRichText: true),
      findsNothing,
      reason: 'the deleted reply must leave the visible transcript',
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
