// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: the chat lorebook journey — an entry authored through the REAL
// "This Chat" add dialog, previewed by the WOULD TRIGGER NEXT strip as the
// user types its keyword, and then actually injected into the outbound
// prompt when the message sends. Import-wizard note: step 0 is a native
// file picker no test can drive, so the DIALECT layer the wizard rides
// (decodeLorebook + detectLorebookFormat) is proven here programmatically
// against one fixture per dialect — the same functions, no picker.
//
// Run it with:
//   flutter test integration_test/lorebook_chat_test.dart -d macos
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
import 'package:front_porch_ai/ui/chat_components/sidebar/story_tools/lorebook_chat_book.dart';
import 'package:front_porch_ai/ui/layout/main_layout.dart';
import 'package:front_porch_ai/ui/pages/chat_page.dart';

import 'support/chat_driver.dart';
import 'support/e2e_sandbox.dart';
import 'support/fake_backend.dart';

const _kGreeting = 'Welcome to the lorebook porch.';
const _kReplyPieces = ['The fake backend replies ', 'about lorebooks.'];
const _kLoreContent = 'The creaky third step hides a brass key.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a chat lorebook entry authored in the real dialog previews '
      'and injects — and every import dialect decodes — sandboxed', (
    tester,
  ) async {
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

    final sandbox = Directory.systemTemp.createTempSync('fpai_lore_');
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
      name: 'Lore Tester',
      description: 'Exists only inside the lorebook E2E.',
      firstMessage: _kGreeting,
      frontPorchExtensions: FrontPorchExtensions(
        realismEnabled: false,
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
    // A session must exist before the This Chat book accepts entries.
    await d.sendMessage('Settling in for lore tonight.');
    await d.waitFor(
      () => backend.chatRequests >= 1,
      () => 'the seeding turn to generate (chat=${backend.chatRequests})',
      timeout: const Duration(seconds: 120),
    );
    await d.waitSendable();

    // ── Author an entry through the REAL This Chat dialog ───────────────
    final sidebarScrollable = find
        .ancestor(
          of: find.text("Author's Note"),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Story Tools'),
      200,
      scrollable: sidebarScrollable,
    );
    await tester.tap(find.text('Story Tools'), warnIfMissed: false);
    await d.waitForWidget(find.text('This Chat'));
    await tester.scrollUntilVisible(
      find.text('This Chat'),
      200,
      scrollable: sidebarScrollable,
    );
    final addIcon = find.descendant(
      of: find.byType(ChatLorebookSection),
      matching: find.byIcon(Icons.add),
    );
    await d.waitForWidget(addIcon);
    await tester.tap(addIcon.first, warnIfMissed: false);
    await d.waitForWidget(find.text('Add Lorebook Entry'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Name (optional)').first,
      'The Creaky Step',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Keywords (comma separated)').first,
      'creaky step',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Content').first,
      _kLoreContent,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add').last);
    await d.waitFor(
      () => chatService.chatLorebook.entries.isNotEmpty,
      () =>
          'the entry to land in the chat book '
          '(entries=${chatService.chatLorebook.entries.length})',
    );
    await d.waitForWidget(find.text('The Creaky Step'));

    // ── The WOULD TRIGGER NEXT strip previews the live draft ────────────
    await tester.enterText(d.input, 'What is under the creaky step?');
    await tester.pump(const Duration(milliseconds: 600));
    await d.waitForWidget(find.text('WOULD TRIGGER NEXT'));

    // ── And sending actually injects the content into the prompt ────────
    await d.sendMessage('What is under the creaky step?');
    await d.waitFor(
      () => backend.lastChatBody.contains('brass key'),
      () => 'the lore content to reach the outbound prompt',
      timeout: const Duration(seconds: 120),
    );
    await d.waitSendable();

    // ── Every import dialect decodes (the wizard's parsing layer) ───────
    // The wizard's step 0 is a native file picker no test can reach; the
    // decode + detect functions ARE its parsing layer, driven directly.
    final fixtures = <LorebookFormat, Map<String, dynamic>>{
      LorebookFormat.novelAi: {
        'lorebookVersion': 1,
        'entries': [
          {
            'text': 'NovelAI lore body',
            'displayName': 'NAI Entry',
            'keys': ['porch'],
            'enabled': true,
          },
        ],
      },
      LorebookFormat.agnai: {
        'kind': 'memory',
        'name': 'AgnAI book',
        'entries': [
          {
            'name': 'Agn Entry',
            'entry': 'AgnAI lore body',
            'keywords': ['porch'],
            'enabled': true,
          },
        ],
      },
      LorebookFormat.risu: {
        'type': 'risu',
        'data': [
          {
            'key': 'porch',
            'comment': 'Risu Entry',
            'content': 'RisuAI lore body',
          },
        ],
      },
      LorebookFormat.fpaiOrSt: {
        'entries': {
          '0': {
            'key': ['porch'],
            'comment': 'ST Entry',
            'content': 'SillyTavern lore body',
          },
        },
      },
    };
    fixtures.forEach((expected, raw) {
      expect(
        detectLorebookFormat(raw),
        expected,
        reason: 'dialect detection must recognize $expected',
      );
      final book = decodeLorebook(raw);
      expect(
        book.entries,
        isNotEmpty,
        reason: '$expected must decode to at least one entry',
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
