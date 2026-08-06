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

import 'support/chat_driver.dart';
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
    final d = ChatDriver(
      tester,
      Provider.of<ChatService>(ctx, listen: false),
      backend,
    );

    // ── Enter The Stoop from the sidebar ────────────────────────────────
    // Every tap here is delivery-confirmed: this page is panels and dialogs
    // inside scrollables, where a plain tap lands on a barrier or a stale
    // position and fails SILENTLY (round 3 died four minutes later at the
    // download snackbar, with a hit-test warning as the only clue).
    await d.tapUntil([
      find.text('The Stoop'),
    ], find.text('Pull up a chair — sign in to browse and share.'));

    // ── Sign in through the REAL form ───────────────────────────────────
    // The labels are standalone Texts above bare TextFields (the lorebook
    // dialog lesson) — address the fields positionally inside the view:
    // sign-in mode renders exactly Email then Password.
    final authFields = find.descendant(
      of: find.byType(RepositoryAuthView),
      matching: find.byType(TextField),
    );
    await pumpUntilFound(
      tester,
      authFields,
      timeout: const Duration(seconds: 45),
    );
    await tester.enterText(authFields.at(0), 'porch@example.com');
    await tester.enterText(authFields.at(1), 'porchporch');
    await tester.pump(const Duration(milliseconds: 200));

    // ── The 18+ AUP gate: checkbox required, Agree routes the accept ────
    await d.tapUntil(
      [find.widgetWithText(StoopAmberButton, 'Sign in')],
      find.text('Welcome to The Stoop'),
      timeout: const Duration(seconds: 60),
    );
    // Agree stays DISABLED until the box is ticked, so the two taps are ONE
    // retry unit — and the confirmation is the server actually recording the
    // acceptance, not either tap landing.
    await d.tapUntilTrue(
      [
        find.textContaining('I am 18 or older'),
        find.widgetWithText(StoopAmberButton, 'Agree & continue'),
      ],
      () => stoop.policyAccepted,
      () => 'the accept-policy POST to reach the fake server',
    );

    // ── Browse renders the fake's card ──────────────────────────────────
    await pumpUntilFound(
      tester,
      find.text('Misty'),
      timeout: const Duration(seconds: 45),
    );
    expect(stoop.browseRequests, greaterThanOrEqualTo(1));

    // ── Detail panel → Download to library → real import ────────────────
    await d.tapUntil([find.text('Misty')], find.text('Download to library'));
    expect(stoop.detailRequests, greaterThanOrEqualTo(1));
    // The download button sits low in a right-side panel — the exact tap
    // that missed in round 3, costing a four-minute silent wait.
    await d.tapUntil(
      [find.text('Download to library')],
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
    await d.tapUntilTrue(
      [find.byIcon(Icons.close)],
      () => find.text('Download to library').evaluate().isEmpty,
      () => 'the detail panel to close',
    );

    // ── Share wizard: pick → details → standards ack → submit ───────────
    await d.tapUntil([
      find.text('@PorchFriend'),
    ], find.widgetWithText(StoopAmberButton, 'Share to The Stoop'));
    // Step 0 — pick the just-downloaded Misty (scoped to the pick step:
    // the browse grid beneath this route also renders a 'Misty' text).
    final pickMisty = find.descendant(
      of: find.byType(StoopPickStep),
      matching: find.text('Misty'),
    );
    await d.tapUntil(
      [find.widgetWithText(StoopAmberButton, 'Share to The Stoop')],
      pickMisty,
      timeout: const Duration(seconds: 60),
    );
    // Step 1 — selecting the card only ENABLES Next; the pick and the
    // advance are one retry unit.
    await d.tapUntil([
      pickMisty,
      find.widgetWithText(StoopAmberButton, 'Next'),
    ], find.text('Display name on The Stoop'));
    // The wizard is ONE Scaffold wrapping a 250ms AnimatedSwitcher, so the
    // outgoing step stays mounted while the incoming one fades in — and
    // tapUntil returns the instant its target text appears, which is the START
    // of that window. StoopPickStep owns a search TextField, so during those
    // 250ms `find.byType(TextField)` under the Scaffold yields five fields,
    // not four, and every index is off by one: the display name went into the
    // pick step's search box and the summary into the name box. _summary
    // stayed empty, Next stayed disabled, and the NEXT step's wait timed out
    // two minutes later pointing at the standards text — nowhere near the
    // actual mistake. Whether the poll landed inside the window was pure
    // timing, which is why this passed on Linux and Windows and failed on
    // macOS.
    //
    // Waiting for the outgoing step to leave removes the race; addressing the
    // fields by their hint text removes the index arithmetic that made the
    // race harmful. Either alone would fix it; together the step cannot come
    // back in a different shape and quietly type into the wrong box again.
    // The wizard is ONE Scaffold wrapping a 250ms AnimatedSwitcher, so the
    // outgoing step stays mounted while the incoming one fades in — and
    // tapUntil returns the instant its target text appears, which is the START
    // of that window. StoopPickStep owns a search TextField, so the field set
    // under that Scaffold is 5 widgets mid-transition and 4 once it settles
    // (measured, both values observed on the same machine). Addressing fields
    // by index across that boundary is a coin flip: step 1's Next is gated on
    // `_name` AND `_summary` both being non-empty, so landing one character
    // off leaves _summary blank, Next disabled, and the failure surfaces two
    // minutes later at the NEXT step's wait for the standards text — nowhere
    // near the actual mistake. That is precisely how it failed on macOS, and
    // it reproduces here about twice in twenty runs.
    //
    // Waiting for the outgoing step to leave removes the race; addressing the
    // fields by their hint text removes the index arithmetic that made the
    // race harmful.
    await d.waitFor(
      () => find.byType(StoopPickStep).evaluate().isEmpty,
      () => 'the pick step to finish animating out of the wizard',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Name shown on The Stoop'),
      'Misty of the Porch',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'A one-line hook shown on the card'),
      'A gentle porch spirit, shared by the E2E suite.',
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Fail HERE, on the real cause, if either box was missed again. Without
    // this the only symptom is a two-minute timeout pointing at the standards
    // text on the following step, which is what made the macOS failure so
    // slow to read.
    final nextButton = tester.widget<StoopAmberButton>(
      find.widgetWithText(StoopAmberButton, 'Next'),
    );
    expect(
      nextButton.onPressed,
      isNotNull,
      reason:
          'Next is still disabled, so the name/summary boxes did not both '
          'receive text — check the wizard field hints before blaming the '
          'standards step below.',
    );
    // Step 2 — name+summary are filled, so Next alone advances.
    await d.tapUntil([
      find.widgetWithText(StoopAmberButton, 'Next'),
    ], find.text('This card meets the Stoop content standards'));
    // Step 3 — the standards acknowledgement gates Next, so again one unit.
    await d.tapUntil([
      find.text('This card meets the Stoop content standards'),
      find.widgetWithText(StoopAmberButton, 'Next'),
    ], find.widgetWithText(StoopAmberButton, 'Submit for review'));
    // Submit → the fake accepts the multipart POST.
    await d.tapUntilTrue(
      [find.widgetWithText(StoopAmberButton, 'Submit for review')],
      () => stoop.uploadRequests >= 1,
      () => 'the multipart upload to reach the fake server',
      timeout: const Duration(seconds: 60),
    );
    await d.waitForWidget(find.text('Submitted for review.'));
    expect(stoop.uploadRequests, 1);

    expect(stoop.unexpectedPaths, isEmpty);
    expect(
      stoop.handlerErrors,
      isEmpty,
      reason: 'a crashed fake handler answers nothing and reads as a timeout',
    );
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
