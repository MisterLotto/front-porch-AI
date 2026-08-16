// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: switching between different characters' chats — including while more
// than one chat screen is alive — must never corrupt the widget tree.
//
// WHY THIS EXISTS. On 2026-08-10 the maintainer switched from one
// character's chat to another's and the app flooded with "Multiple widgets
// used the same GlobalKey ([GlobalObjectKey ChatMessage])" followed by
// cascading render-tree corruption. The cause: the journal tap-to-jump
// feature keyed bubbles with `GlobalObjectKey(msg)` — app-global identity —
// and two ChatPage routes alive in the same frame (a push over a live page,
// or the frames of a route transition) both listen to the same ChatService,
// so a chat switch had both building bubbles for the same message objects.
//
// It shipped green because NOTHING in CI had ever opened chat A, left, and
// opened chat B — the single most common navigation in the app. This is the
// themes-bug lesson (512e4803, "nothing in CI had ever pressed a button")
// wearing navigation clothes. This file closes the class, not the instance:
// any future change that breaks under route stacking or chat switching —
// keys, providers, controllers, lifecycle — fails here before it ships.
//
// What this file pins:
//   1. The overlap case, deterministically: TWO ChatPage routes stacked
//      while the active chat switches character. (More aggressive than the
//      transition race that bit the maintainer, and not timing-dependent.)
//   2. The everyday journey: A → home → B → home → A, several times, fast.
//   3. The app still WORKS afterwards — greeting shown, a real send/reply
//      round-trip completes on the final page.
//
// The widget-level reproduction of the original crash (old key scheme
// throwing in a two-list harness) lives in
// test/ui/chat_components/message_key_scope_test.dart; this suite is the
// full-app coverage that was missing.
//
// Boot/sandbox contract is identical to app_smoke_test.dart; see its header.

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
import 'package:front_porch_ai/ui/pages/pages.dart';

import 'support/chat_driver.dart';
import 'support/e2e_sandbox.dart';
import 'support/fake_backend.dart';

const _kGreetingA = 'Ada waves from the porch swing, unbothered.';
const _kGreetingB = 'Bea looks up from her book and smiles.';
const _kReplyPieces = ['Still here, ', 'still standing.'];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat switching survives stacked routes and rapid A/B churn', (
    tester,
  ) async {
    try {
      final probe = await Socket.connect(
        InternetAddress.loopbackIPv4,
        5001,
        timeout: const Duration(milliseconds: 500),
      );
      probe.destroy();
      fail('Something is listening on 127.0.0.1:5001 — close it first.');
    } on SocketException {
      // Nothing there — safe.
    }

    final sandbox = Directory.systemTemp.createTempSync('fpai_chat_switch_');
    PathProviderPlatform.instance = SandboxPathProvider(sandbox.path);
    final backend = await FakeBackendServer.start(replyPieces: _kReplyPieces);
    addTearDown(() async => backend.close());
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'import_llmerta_porch_memories': false,
      'backend_type': 'openRouter',
      'remote_api_url': '${backend.baseUrl}/v1',
      'remote_model_name': 'smoke-model',
      // Navigation smoke, not an engine test: realism off keeps every switch
      // free of eval traffic so the churn below is pure route/build work.
      'realism_default': false,
    });

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
    final chatService = Provider.of<ChatService>(ctx, listen: false);
    final repo = Provider.of<CharacterRepository>(ctx, listen: false);

    final ada = CharacterCard(
      name: 'Ada',
      description: 'Exists only inside the chat-switch smoke test.',
      firstMessage: _kGreetingA,
    );
    final bea = CharacterCard(
      name: 'Bea',
      description: 'Exists only inside the chat-switch smoke test.',
      firstMessage: _kGreetingB,
    );
    await repo.addCharacter(ada);
    await repo.addCharacter(bea);

    final navigator = Navigator.of(ctx);
    // ignore: use_build_context_synchronously — ctx is the root MainLayout element.

    // ── 1. The overlap case, deterministically ──────────────────────────
    // Two live ChatPage routes, then a character switch: both pages rebuild
    // with the SAME new message objects in the same frame. Under the old
    // GlobalObjectKey(msg) bubble keys this is one duplicate-key exception
    // per visible message — the maintainer's crash, without the race.
    await chatService.setActiveCharacter(ada);
    navigator.push(MaterialPageRoute(builder: (_) => const ChatPage()));
    await pumpUntilFound(
      tester,
      find.textContaining(_kGreetingA, findRichText: true),
    );

    navigator.push(MaterialPageRoute(builder: (_) => const ChatPage()));
    await tester.pump(const Duration(milliseconds: 400));

    await chatService.setActiveCharacter(bea);
    // Several plain pumps, no settle: the corruption cascade shows up across
    // the frames FOLLOWING the switch, and pumpAndSettle would swallow the
    // intermediate frames where it happens.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      final e = tester.takeException();
      expect(
        e,
        isNull,
        reason:
            'frame $i after switching characters under two live chat routes '
            'threw: $e — bubble keys (or some newer per-message state) are '
            'colliding across simultaneously-mounted chat screens again',
      );
    }
    expect(
      find.textContaining(_kGreetingB, findRichText: true),
      findsWidgets,
      reason: 'the top page must actually show the new character\'s chat',
    );
    navigator.pop();
    await tester.pump(const Duration(milliseconds: 400));

    // ── 2. The everyday journey: A → home → B → home → …, fast ──────────
    // Pops and pushes in quick succession keep landing inside the previous
    // route's transition frames — the realistic version of the overlap.
    for (var round = 0; round < 3; round++) {
      navigator.pop();
      await tester.pump(const Duration(milliseconds: 120));

      final next = round.isEven ? ada : bea;
      await chatService.setActiveCharacter(next);
      navigator.push(MaterialPageRoute(builder: (_) => const ChatPage()));
      await tester.pump(const Duration(milliseconds: 120));
      final e = tester.takeException();
      expect(
        e,
        isNull,
        reason: 'round $round of rapid chat switching threw: $e',
      );
    }
    await pumpUntilFound(
      tester,
      find.textContaining(_kGreetingA, findRichText: true),
    );

    // ── 3. The app still works after all of that ────────────────────────
    final d = ChatDriver(tester, chatService, backend);
    await d.waitForWidget(d.input);
    await d.sendMessage('Did we survive the shuffle?');
    await d.waitForWidget(
      find.textContaining(_kReplyPieces.join(), findRichText: true),
    );
    await d.waitSendable();
    expect(
      chatService.messages.length,
      greaterThanOrEqualTo(3),
      reason:
          'greeting + user turn + reply — a chat reached through heavy '
          'switching must still hold a normal conversation',
    );
  });
}
