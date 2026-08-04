// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: The Stoop against a fake backporch server (BackporchApi's
// overrideBaseUrl seam — the desktop UI constructs bare BackporchApi()
// everywhere, so without the seam this journey would hit the LIVE hub).
// The whole gated path is driven through the real UI:
//   sign-in form → the 18+ Acceptable Use Policy gate (checkbox + Agree) →
//   browse grid renders the fake's card → detail panel → Download to
//   library actually imports the V2 card into CharacterRepository →
//   the @you tab's Share wizard (pick → details → standards ack → submit)
//   posts the upload and reports "Submitted for review."
//
// Run it with:
//   flutter test integration_test/stoop_test.dart -d macos
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
import 'package:front_porch_ai/services/backporch/backporch.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/layout/main_layout.dart';
import 'package:front_porch_ai/ui/pages/repository/repository_auth_view.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_glass.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_pick_step.dart';

import 'support/e2e_sandbox.dart';
import 'support/fake_backend.dart';
import 'support/fake_stoop.dart';

const _kReplyPieces = ['The fake backend replies ', 'about the stoop.'];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign-in, the AUP gate, browse, download-to-library, and the '
      'share wizard against a fake backporch server — sandboxed', (
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

    final sandbox = Directory.systemTemp.createTempSync('fpai_stoop_');
    PathProviderPlatform.instance = SandboxPathProvider(sandbox.path);
    final backend = await FakeBackendServer.start(replyPieces: _kReplyPieces);
    final stoop = await FakeStoopServer.start();
    BackporchApi.overrideBaseUrl = stoop.baseUrl;
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
    final repo = Provider.of<CharacterRepository>(ctx, listen: false);

    // ── Enter The Stoop from the sidebar ────────────────────────────────
    await tester.tap(find.text('The Stoop').first);
    await pumpUntilFound(
      tester,
      find.text('Pull up a chair — sign in to browse and share.'),
    );

    // ── Sign in through the REAL form ───────────────────────────────────
    // The labels are standalone Texts above bare TextFields (the lorebook
    // dialog lesson) — address the fields positionally inside the view:
    // sign-in mode renders exactly Email then Password.
    final authFields = find.descendant(
      of: find.byType(RepositoryAuthView),
      matching: find.byType(TextField),
    );
    await pumpUntilFound(tester, authFields);
    await tester.enterText(authFields.at(0), 'porch@example.com');
    await tester.enterText(authFields.at(1), 'porchporch');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(StoopAmberButton, 'Sign in'));

    // ── The 18+ AUP gate: checkbox required, Agree routes the accept ────
    await pumpUntilFound(tester, find.text('Welcome to The Stoop'));
    final ackRow = find.textContaining('I am 18 or older');
    await tester.ensureVisible(ackRow.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(ackRow.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.widgetWithText(StoopAmberButton, 'Agree & continue'),
      warnIfMissed: false,
    );
    await pumpUntilTrue(
      tester,
      () => stoop.policyAccepted,
      describe: () => 'the accept-policy POST to reach the fake server',
    );

    // ── Browse renders the fake's card ──────────────────────────────────
    await pumpUntilFound(tester, find.text('Misty'));
    expect(stoop.browseRequests, greaterThanOrEqualTo(1));

    // ── Detail panel → Download to library → real import ────────────────
    await tester.tap(find.text('Misty').first);
    await pumpUntilFound(tester, find.text('Download to library'));
    expect(stoop.detailRequests, greaterThanOrEqualTo(1));
    await tester.tap(find.text('Download to library'));
    await pumpUntilFound(
      tester,
      find.text('“Misty” added to your library.'),
      timeout: const Duration(seconds: 60),
    );
    expect(stoop.downloadRequests, 1);
    await pumpUntilTrue(
      tester,
      () => repo.characters.any((c) => c.name == 'Misty'),
      describe: () =>
          'the downloaded card to land in the repository '
          '(have: ${repo.characters.map((c) => c.name).toList()})',
    );

    // Close the detail panel so later taps aren't over its barrier.
    await tester.tap(find.byIcon(Icons.close).first, warnIfMissed: false);
    await pumpUntilTrue(
      tester,
      () => find.text('Download to library').evaluate().isEmpty,
      describe: () => 'the detail panel to close',
    );

    // ── Share wizard: pick → details → standards ack → submit ───────────
    await tester.tap(find.text('@PorchFriend'));
    await pumpUntilFound(tester, find.text('Share to The Stoop'));
    await tester.tap(
      find.widgetWithText(StoopAmberButton, 'Share to The Stoop').first,
    );
    // Step 0 — pick the just-downloaded Misty (scoped to the pick step:
    // the browse grid beneath this route also renders a 'Misty' text).
    final pickMisty = find.descendant(
      of: find.byType(StoopPickStep),
      matching: find.text('Misty'),
    );
    await pumpUntilFound(tester, pickMisty);
    await tester.tap(pickMisty.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(StoopAmberButton, 'Next'));
    // Step 1 — details (name + summary, positional for the same reason).
    await pumpUntilFound(tester, find.text('Display name on The Stoop'));
    final detailFields = find.descendant(
      of: find.byType(Scaffold).last,
      matching: find.byType(TextField),
    );
    await tester.enterText(detailFields.at(0), 'Misty of the Porch');
    await tester.enterText(
      detailFields.at(1),
      'A gentle porch spirit, shared by the E2E suite.',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(StoopAmberButton, 'Next'));
    // Step 2 — the content-standards acknowledgement gates advancing.
    final ack = find.text('This card meets the Stoop content standards');
    await pumpUntilFound(tester, ack);
    await tester.ensureVisible(ack.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(ack.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(StoopAmberButton, 'Next'));
    // Step 3 — review → submit → the fake accepts the multipart POST.
    final submit = find.widgetWithText(StoopAmberButton, 'Submit for review');
    await pumpUntilFound(tester, submit);
    await tester.tap(submit);
    await pumpUntilFound(
      tester,
      find.text('Submitted for review.'),
      timeout: const Duration(seconds: 60),
    );
    expect(stoop.uploadRequests, 1);

    expect(stoop.unexpectedPaths, isEmpty);
    expect(backend.unexpectedPaths, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await backend.close();
    await stoop.close();
    try {
      sandbox.deleteSync(recursive: true);
    } on FileSystemException {
      // A straggler may still be writing; not a failure.
    }
  });
}
