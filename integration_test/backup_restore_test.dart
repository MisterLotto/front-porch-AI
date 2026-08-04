// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: backups & restore — the journey the v1.2 release blocker shipped
// broken. Restore used to close the live database, copy the snapshot over
// it, and tell the user to restart: every repository, ChatService and the
// web server kept the CLOSED handle and threw "database was closed" on the
// very next query, and cleanOrphanedPngs deleted the portraits of any
// character newer than the snapshot. This suite drives the REAL Backups
// page — create button, list row, confirm dialog — and then proves the
// app is fully usable afterwards with no restart:
//   * a character created AFTER the backup is gone from the reloaded
//     library (the restore actually restored),
//   * a NEW chat generates a reply end-to-end on the rebound handle,
//   * the folder service accepts writes on the rebound handle,
//   * the post-backup character's portrait PNG survives on disk (restore
//     must NOT run image cleanup).
//
// Run it with:
//   flutter test integration_test/backup_restore_test.dart -d macos
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

import 'package:front_porch_ai/app_version.dart';
import 'package:front_porch_ai/main.dart' as app;
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/layout/main_layout.dart';
import 'package:front_porch_ai/ui/pages/backups_page.dart';
import 'package:front_porch_ai/ui/pages/chat_page.dart';

import 'support/chat_driver.dart';
import 'support/e2e_sandbox.dart';
import 'support/fake_backend.dart';

const _kGreeting = 'Welcome to the backup porch.';
const _kReplyPieces = ['The fake backend replies ', 'about backups.'];

/// A 1x1 transparent PNG — enough for a portrait file the cleanup pass
/// would delete if it ran.
final _kTinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0xE9, 0xFA, 0xDC, 0xD8, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a backup restores through the real page and every service '
      'survives on the rebound database — sandboxed', (tester) async {
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

    // The whole Backups page renders "Backups Disabled" on pre-release
    // builds — this suite only means anything against the stable surface.
    expect(
      isPreRelease,
      isFalse,
      reason: 'source checkouts must present the real Backups page',
    );

    final sandbox = Directory.systemTemp.createTempSync('fpai_backup_');
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
    final repo = Provider.of<CharacterRepository>(ctx, listen: false);
    final chatService = Provider.of<ChatService>(ctx, listen: false);
    final d = ChatDriver(tester, chatService, backend);

    // ── Seed pre-backup state: one character, one scored exchange ───────
    // Realism off keeps the turn to a single chat call — the engine's own
    // journey is app_smoke's job; this suite is about the database handle.
    final keeper = CharacterCard(
      name: 'Backup Keeper',
      description: 'Exists before the snapshot.',
      firstMessage: _kGreeting,
      frontPorchExtensions: FrontPorchExtensions(
        realismEnabled: false,
        needsSimEnabled: false,
        chaosModeEnabled: false,
      ),
    );
    await repo.addCharacter(keeper);
    await chatService.setActiveCharacter(keeper);
    // ignore: use_build_context_synchronously — root MainLayout element.
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const ChatPage()));
    await d.waitForWidget(find.textContaining(_kGreeting, findRichText: true));
    await d.sendMessage('Remember this porch before the snapshot.');
    await d.waitFor(
      () => backend.chatRequests >= 1,
      () => 'the pre-backup turn to generate (chat=${backend.chatRequests})',
      timeout: const Duration(seconds: 120),
    );
    await d.waitSendable();
    // ignore: use_build_context_synchronously
    Navigator.of(ctx).pop();
    await pumpUntilTrue(
      tester,
      () => find.byType(ChatPage).evaluate().isEmpty,
      describe: () => 'the chat page to close before the backup',
    );

    // ── Create the backup through the REAL page ─────────────────────────
    // ignore: use_build_context_synchronously
    Navigator.of(
      ctx,
    ).push(MaterialPageRoute(builder: (_) => const BackupsPage()));
    await pumpUntilFound(tester, find.text('Database Backups'));
    await tester.tap(find.text('Create Backup Now'));
    await d.waitForWidget(
      find.text('Backup created successfully'),
      timeout: const Duration(seconds: 30),
    );
    await d.waitForWidget(find.byIcon(Icons.storage));
    final backupsOnDisk = await BackupService.listBackups();
    expect(backupsOnDisk, hasLength(1), reason: 'exactly one snapshot exists');

    // ── Mutate AFTER the snapshot: a character with a real portrait ─────
    // Latecomer's row must vanish on restore; the PNG must NOT (restore
    // never image-cleans — an older snapshot legitimately lacks newer
    // characters, and v1.2's cleanup deleted their portraits permanently).
    final portrait = File('${sandbox.path}/latecomer_portrait.png')
      ..writeAsBytesSync(_kTinyPng);
    final latecomer = CharacterCard(
      name: 'Backup Latecomer',
      description: 'Created after the snapshot — must vanish on restore.',
      firstMessage: 'Too late for the snapshot.',
    )..imagePath = portrait.path;
    await repo.addCharacter(latecomer);
    await repo.loadCharacters();
    expect(
      repo.characters.any((c) => c.name == 'Backup Latecomer'),
      isTrue,
      reason: 'the latecomer must exist before the restore proves anything',
    );

    // ── Restore through the row button + confirm dialog ─────────────────
    await tester.tap(find.widgetWithText(TextButton, 'Restore').first);
    await d.waitForWidget(find.text('Restore Backup?'));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Restore'),
      ),
    );
    await d.waitForWidget(
      find.text('Backup restored. Your library is back to that snapshot.'),
      timeout: const Duration(seconds: 60),
    );

    // ── The restore actually restored: latecomer's row is gone ──────────
    await d.waitFor(
      () => !repo.characters.any((c) => c.name == 'Backup Latecomer'),
      () =>
          'the reloaded library to drop the post-snapshot character '
          '(have: ${repo.characters.map((c) => c.name).toList()})',
    );
    expect(
      repo.characters.any((c) => c.name == 'Backup Keeper'),
      isTrue,
      reason: 'the pre-snapshot character must come back',
    );

    // ── No image cleanup: the latecomer's portrait file survives ────────
    expect(
      portrait.existsSync(),
      isTrue,
      reason:
          'restore must never delete portraits of characters newer than '
          'the snapshot (the v1.2 cleanOrphanedPngs regression)',
    );

    // ── Every service lives on the rebound handle, no restart ───────────
    // Folder write on the new handle:
    final folderService = Provider.of<FolderService>(ctx, listen: false);
    final folder = await folderService.createFolder('Post-Restore Folder');
    expect(
      folderService.folders.any((f) => f.id == folder.id),
      isTrue,
      reason: 'the folder service must accept writes after the rebind',
    );
    // Persona read on the new handle:
    final personaService = Provider.of<UserPersonaService>(ctx, listen: false);
    expect(
      personaService.persona.name,
      isNotEmpty,
      reason: 'the persona service must serve reads after the rebind',
    );
    // And the load-bearing one — a full chat turn on the new handle:
    // ignore: use_build_context_synchronously
    Navigator.of(ctx).pop(); // leave the Backups page
    await pumpUntilTrue(
      tester,
      () => find.byType(BackupsPage).evaluate().isEmpty,
      describe: () => 'the Backups page to close after the restore',
    );
    final restoredKeeper = repo.characters.firstWhere(
      (c) => c.name == 'Backup Keeper',
    );
    await chatService.setActiveCharacter(restoredKeeper);
    // ignore: use_build_context_synchronously
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const ChatPage()));
    await d.waitForWidget(d.input);
    final chatCallsBeforePostRestoreTurn = backend.chatRequests;
    await d.sendMessage('Prove the porch still answers after the restore.');
    await d.waitFor(
      () => backend.chatRequests > chatCallsBeforePostRestoreTurn,
      () =>
          'the post-restore turn to generate '
          '(chat=${backend.chatRequests})',
      timeout: const Duration(seconds: 120),
    );
    await d.waitSendable();
    expect(
      chatService.messages.last.isUser,
      isFalse,
      reason:
          'a full reply must stream on the rebound database — the v1.2 '
          'closed-handle class made this exact step throw',
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
