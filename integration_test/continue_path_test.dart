// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: Continue keeps the pre-continue body and appends new tokens (audit P0).
//
// Unit tests in continue_finalize_test.dart pin the merge helper; this suite
// drives ChatService.continueGeneration through a full app boot so a future
// finalize regression cannot hide behind "units still green".
//
//   flutter test integration_test/continue_path_test.dart -d macos

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

const _kGreeting = 'The porch light is on.';
const _kFirstReply = ['She waves from the steps. ', 'The evening air is warm.'];
// Continue streams a second chunk set; fake reuses replyPieces for every chat
// completion, so Continue will re-stream the same text. We still prove the
// bubble is not replaced by the continuation alone - pre-continue body stays.
const _kContinuePieces = [' And then she sits down on the rail.'];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Continue keeps pre-continue body and appends new tokens',
    (tester) async {
      try {
        final probe = await Socket.connect(
          InternetAddress.loopbackIPv4,
          5001,
          timeout: const Duration(milliseconds: 500),
        );
        probe.destroy();
        fail(
          'Something is listening on 127.0.0.1:5001 - close it before E2E.',
        );
      } on SocketException {
        // Safe.
      }

      final sandbox = Directory.systemTemp.createTempSync('fpai_continue_e2e_');
      PathProviderPlatform.instance = SandboxPathProvider(sandbox.path);

      // First completion uses full reply; after first chat we swap pieces so
      // Continue appends something visually distinct.
      final backend = await FakeBackendServer.start(replyPieces: _kFirstReply);
      addTearDown(() async => backend.close());

      SharedPreferences.setMockInitialValues({
        'update_auto_check': false,
        'import_llmerta_porch_memories': false,
        'realism_default': false,
        'backend_type': 'openRouter',
        'remote_api_url': '${backend.baseUrl}/v1',
        'remote_model_name': 'smoke-model',
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
      final character = CharacterCard(
        name: 'Mara',
        description: 'Exists only inside the Continue E2E.',
        firstMessage: _kGreeting,
        frontPorchExtensions: FrontPorchExtensions(
          realismEnabled: false,
          needsSimEnabled: false,
        ),
      );
      await Provider.of<CharacterRepository>(
        ctx,
        listen: false,
      ).addCharacter(character);
      await chatService.setActiveCharacter(character);

      // ignore: use_build_context_synchronously
      Navigator.of(ctx).push(
        MaterialPageRoute(builder: (_) => const ChatPage()),
      );
      final d = ChatDriver(tester, chatService, backend);
      await d.waitForWidget(d.input);

      await d.sendMessage('Evening. Mind if I sit?');
      await d.waitFor(
        () => backend.chatRequests >= 1,
        () => 'first reply (chat=${backend.chatRequests})',
        timeout: const Duration(seconds: 120),
      );
      await d.waitSendable();

      final beforeContinue = chatService.messages.lastWhere((m) => !m.isUser);
      final preBody = beforeContinue.text;
      expect(
        preBody.contains('waves') || preBody.contains('evening'),
        isTrue,
        reason: 'first reply must have landed (got: $preBody)',
      );

      // Point Continue at a distinct continuation fragment (list is final,
      // mutate in place).
      backend.replyPieces
        ..clear()
        ..addAll(_kContinuePieces);

      await chatService.continueGeneration();
      await d.waitFor(
        () => backend.chatRequests >= 2,
        () => 'continue completion (chat=${backend.chatRequests})',
        timeout: const Duration(seconds: 120),
      );
      await d.waitSendable();

      final after = chatService.messages.lastWhere((m) => !m.isUser);
      expect(
        after.text.contains('waves') || after.text.contains('evening'),
        isTrue,
        reason:
            'Continue must KEEP the pre-continue body - got only: ${after.text}',
      );
      expect(
        after.text.contains('sits down') || after.text.contains('rail'),
        isTrue,
        reason:
            'Continue must APPEND the new tokens - got: ${after.text}',
      );
      expect(
        after.text.length,
        greaterThan(preBody.length),
        reason: 'merged body must be longer than pre-continue alone',
      );
    },
  );
}
