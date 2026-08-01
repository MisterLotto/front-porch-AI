// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: every chat theme preset must leave the message-bubble controls TAPPABLE.
//
// WHY THIS EXISTS — commit 512e4803, shipped to users:
//
//   "all 10 theme presets made every message-bubble button dead"
//
// With any preset active, edit / fork / delete / speak / thought-toggle stopped
// responding. The decorative border is a Positioned.fill CustomPaint drawn as
// the LAST child of the bubble Stack; a CustomPainter whose hitTest returns the
// default null is hit-test OPAQUE over its whole rect, and Stack hit-tests
// last-to-first — so the invisible border claimed every tap before the buttons
// underneath saw it.
//
// The critical detail, and the reason this file is an E2E and not a golden:
// THE UI LOOKED PERFECT. Pixels were unchanged, so a golden could never fail.
// Every CI check was green because nothing in CI ever pressed a button. It
// shipped because it needed a human to notice, and one human does not scale.
//
// The fix commit added test/ui/border_painters_hit_test_test.dart, which pins
// those specific painters. That is necessary but narrow: the next
// Positioned.fill over a different surface reintroduces the same CLASS of bug
// somewhere else and CI goes green again. So this test asserts the property
// rather than the painter — for every preset, every interactive control in a
// real rendered bubble must actually receive a hit at its own centre.
//
// Boot/sandbox contract is identical to app_smoke_test.dart; see its header.

import 'dart:io';

import 'package:flutter/gestures.dart';
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
import 'package:front_porch_ai/ui/chat_components/chat_components.dart';
import 'package:front_porch_ai/ui/layout/main_layout.dart';
import 'package:front_porch_ai/ui/pages/pages.dart';

import 'support/chat_driver.dart';
import 'support/e2e_sandbox.dart';
import 'support/fake_backend.dart';

const _kGreeting = 'The porch is themed today.';
const _kReplyPieces = ['Buttons must still ', 'answer under every skin.'];

/// True when a real tap at [finder]'s centre actually reaches [finder]'s own
/// render object.
///
/// This is the whole point of the file. `find.byTooltip(...)` succeeding only
/// proves the widget EXISTS; the themes bug had every button present, laid
/// out, and painted — and unreachable. Hit-testing the binding at the button's
/// centre and requiring the button in the resulting path is what distinguishes
/// "rendered" from "usable": an opaque overlay above it absorbs the hit and
/// the button never appears in the path at all.
bool _tapReaches(WidgetTester tester, Finder finder) {
  final target = tester.renderObject(finder);
  final HitTestResult result = tester.hitTestOnBinding(
    tester.getCenter(finder),
  );
  return result.path.any((entry) => identical(entry.target, target));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every theme preset leaves bubble controls tappable', (
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

    final sandbox = Directory.systemTemp.createTempSync('fpai_theme_');
    PathProviderPlatform.instance = SandboxPathProvider(sandbox.path);
    final backend = await FakeBackendServer.start(replyPieces: _kReplyPieces);
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'import_llmerta_porch_memories': false,
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

    final previousOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = previousOnError);
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(
        'unexpectedly has a HitTestResult',
      )) {
        return;
      }
      (previousOnError ?? FlutterError.presentError)(details);
    };

    final ctx = tester.element(find.byType(MainLayout));
    final chatService = Provider.of<ChatService>(ctx, listen: false);

    final character = CharacterCard(
      name: 'Theme Tester',
      description: 'Exists only inside the theme interaction test.',
      firstMessage: _kGreeting,
    );
    await Provider.of<CharacterRepository>(
      ctx,
      listen: false,
    ).addCharacter(character);
    await chatService.setActiveCharacter(character);
    // ignore: use_build_context_synchronously — ctx is the root MainLayout element.
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const ChatPage()));

    final d = ChatDriver(tester, chatService, backend);
    await d.waitForWidget(find.textContaining(_kGreeting, findRichText: true));
    await d.waitForWidget(d.input);

    // A real exchange, so both a user bubble and a character bubble exist with
    // their full control rows rendered.
    await d.sendMessage('Show me the buttons.');
    await d.waitForWidget(
      find.textContaining(_kReplyPieces.join(), findRichText: true),
    );
    await d.waitSendable();

    // Controls the themes bug killed. Tooltip-addressed because that is the
    // user-visible contract, and a rename should make this test speak up.
    const targets = ['Edit message', 'Fork from here'];

    // Sanity: the unthemed baseline must pass, otherwise a green run below
    // would prove nothing (a test that cannot fail is not a test).
    chatService.sessionThemeOverrides = ChatThemeOverrides();
    await tester.pump(const Duration(milliseconds: 300));
    for (final tip in targets) {
      final f = find.byTooltip(tip).first;
      expect(
        f.evaluate(),
        isNotEmpty,
        reason: '"$tip" must exist with no theme applied',
      );
      expect(
        _tapReaches(tester, f),
        isTrue,
        reason: '"$tip" is unreachable even with NO theme — baseline broken',
      );
    }

    // ── The matrix ──────────────────────────────────────────────────────
    final dead = <String>[];
    for (final preset in ChatThemePreset.presets) {
      chatService.sessionThemeOverrides = ChatThemeOverrides(
        themeId: preset.id,
      );
      await tester.pump(const Duration(milliseconds: 300));

      for (final tip in targets) {
        final f = find.byTooltip(tip).first;
        if (f.evaluate().isEmpty) {
          dead.add('${preset.id}: "$tip" vanished from the tree');
          continue;
        }
        if (!_tapReaches(tester, f)) {
          dead.add('${preset.id}: "$tip" rendered but NOT tappable');
        }
      }

      // Class-level sweep: every IconButton anywhere in a themed bubble, not
      // just the two named above. This is what catches the NEXT overlay over
      // some other control, including buttons added long after this was
      // written — the coverage that does not depend on anyone remembering to
      // extend a list.
      final bubbles = find.byType(MessageBubble);
      if (bubbles.evaluate().isNotEmpty) {
        final buttons = find.descendant(
          of: bubbles.last,
          matching: find.byType(IconButton),
        );
        for (var i = 0; i < buttons.evaluate().length; i++) {
          final b = buttons.at(i);
          final rect = tester.getRect(b);
          // Skip anything scrolled out of the view: an offscreen control
          // legitimately receives no hit and is not what this test is about.
          if (rect.width <= 0 || rect.height <= 0) continue;
          final size = tester.view.physicalSize / tester.view.devicePixelRatio;
          if (!Rect.fromLTWH(0, 0, size.width, size.height).contains(
            rect.center,
          )) {
            continue;
          }
          if (!_tapReaches(tester, b)) {
            final icon = tester.widget<IconButton>(b).tooltip ?? 'icon #$i';
            dead.add('${preset.id}: bubble control "$icon" NOT tappable');
          }
        }
      }
    }

    expect(
      dead,
      isEmpty,
      reason:
          'These controls render but cannot be tapped under a theme — the '
          'exact failure shipped in 512e4803, where an invisible '
          'Positioned.fill overlay ate every tap while the UI looked '
          'perfect:\n  ${dead.join('\n  ')}',
    );

    // Leave the chat unthemed so teardown/save does not persist a preset.
    chatService.sessionThemeOverrides = ChatThemeOverrides();
    await tester.pump(const Duration(seconds: 1));

    await backend.close();
    try {
      sandbox.deleteSync(recursive: true);
    } on FileSystemException {
      // A straggler may still be writing; not a failure.
    }
  });
}
