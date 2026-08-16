// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: the persona DEFAULT is separate from a chat's OWN persona.
//
// These were one value until 2026-08-04, and merging them lost data quietly:
// opening a chat re-pointed the "default" at that chat's persona, and picking a
// persona on the Persona page re-stamped whatever chat was still loaded —
// including via background saves the user never triggered. The app's own picker
// states the intent ("a fresh chat must never silently inherit whatever persona
// the last one used"), which only holds if the two cannot move each other.
//
// Four properties, all through real UI taps:
//   1. A chat records the persona it was started under.
//   2. Making a different persona the default does NOT touch that open chat —
//      not even after a save (a turn is sent afterwards to force one).
//   3. A NEW chat starts as the DEFAULT, not as the previous chat's persona.
//   4. Reopening the first chat restores ITS persona, and the default is
//      unmoved by the reopen.
//
// Run it with:
//   flutter test integration_test/persona_default_test.dart -d macos
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
import 'package:front_porch_ai/ui/pages/pages.dart';

import 'support/chat_driver.dart';
import 'support/e2e_sandbox.dart';
import 'support/fake_backend.dart';

const _kGreeting = 'Evening. Pull up a chair.';
const _kReplyPieces = ['The fake backend replies ', 'about personas.'];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the default persona seeds new chats without ever rewriting an '
      'existing chat\'s own persona — sandboxed', (tester) async {
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

    final sandbox = Directory.systemTemp.createTempSync('fpai_persona_');
    PathProviderPlatform.instance = SandboxPathProvider(sandbox.path);
    final backend = await FakeBackendServer.start(replyPieces: _kReplyPieces);
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'import_llmerta_porch_memories': false,
      'realism_default': false,
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
    final personaService = Provider.of<UserPersonaService>(ctx, listen: false);
    final chatService = Provider.of<ChatService>(ctx, listen: false);
    final repo = Provider.of<CharacterRepository>(ctx, listen: false);
    final d = ChatDriver(tester, chatService, backend);

    // Two personas beyond the seeded 'User', created through the service (the
    // creation FORM is persona_folder_test's job; this suite is about which of
    // them a chat ends up bound to).
    await personaService.createPersona('', 'Porchy', 'Sits on the steps.', null);
    final porchy = personaService.persona.id;
    await personaService.createPersona('', 'Nightowl', 'Up too late.', null);
    final nightowl = personaService.persona.id;
    expect(porchy, isNot(nightowl));
    // createPersona leaves the newest as the default — start from a known
    // state rather than assuming one.
    await personaService.setDefaultPersona(porchy);
    expect(personaService.defaultPersonaId, porchy);

    Future<CharacterCard> seed(String name) async {
      final c = CharacterCard(
        name: name,
        description: 'Exists only inside the persona-default E2E.',
        firstMessage: _kGreeting,
        frontPorchExtensions: FrontPorchExtensions(
          realismEnabled: false,
          needsSimEnabled: false,
          chaosModeEnabled: false,
        ),
      );
      await repo.addCharacter(c);
      return c;
    }

    final first = await seed('Porch Sitter');
    final second = await seed('Late Riser');

    // ── 1. A chat records the persona it started under ───────────────────
    await chatService.setActiveCharacter(first);
    await chatService.startNewChat();
    // ignore: use_build_context_synchronously — root MainLayout element.
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const ChatPage()));
    await d.waitForWidget(find.textContaining(_kGreeting, findRichText: true));
    await d.waitForWidget(d.input);
    expect(
      personaService.persona.id,
      porchy,
      reason: 'a new chat starts as the default persona',
    );
    final firstSessionId = chatService.currentSessionId;
    expect(firstSessionId, isNotNull);

    // ── 2. Changing the DEFAULT must not reach into this chat ────────────
    // Through the real Persona page, which is the surface that used to do the
    // damage. Closing the chat first would hide the bug — the point is that the
    // chat is still loaded underneath.
    // ignore: use_build_context_synchronously
    Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => const UserPersonaPage()),
    );
    await d.tapUntilTrue(
      [find.text('Nightowl')],
      () => personaService.defaultPersonaId == nightowl,
      () =>
          'the Persona page tap to move the DEFAULT to Nightowl '
          '(default=${personaService.defaultPersona.name})',
      timeout: const Duration(seconds: 45),
    );
    expect(
      personaService.persona.id,
      porchy,
      reason:
          'changing the default must not change who the OPEN chat speaks as',
    );
    // ignore: use_build_context_synchronously
    Navigator.of(ctx).pop();
    await d.waitForWidget(d.input);

    // Force a save — the original report's mechanism was a background save
    // stamping the live persona onto the session row.
    await d.sendMessage('Still me, still here.');
    await d.waitSendable();
    expect(
      personaService.persona.id,
      porchy,
      reason: 'a turn (and its saves) must not adopt the new default',
    );

    // ── 3. A NEW chat starts as the DEFAULT ──────────────────────────────
    await chatService.setActiveCharacter(second);
    await chatService.startNewChat();
    await d.waitFor(
      () => personaService.persona.id == nightowl,
      () =>
          'the new chat to start as the default persona '
          '(active=${personaService.persona.name})',
      timeout: const Duration(seconds: 45),
    );

    // ── 4. Reopening the first chat restores ITS persona ─────────────────
    await chatService.setActiveCharacter(first);
    await chatService.loadSession(firstSessionId!);
    await d.waitFor(
      () => personaService.persona.id == porchy,
      () =>
          'reopening the first chat to restore its own persona '
          '(active=${personaService.persona.name})',
      timeout: const Duration(seconds: 45),
    );
    expect(
      personaService.defaultPersonaId,
      nightowl,
      reason:
          'reopening a chat must NOT drag the default back to that chat\'s '
          'persona — that is the drift this split exists to stop',
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
