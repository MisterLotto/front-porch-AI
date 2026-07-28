// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E cold-boot smoke test. Runs the REAL app — real main(), real service
// init order, real database open, real window — and asserts it reaches the
// home layout without an unhandled exception. Its job is to catch the class
// of regression unit tests can't: service-init-order breakage, plugin/native
// library failures after a Flutter or dependency bump, and DB-open failures.
//
// Run it on a Mac with:
//   flutter test integration_test/app_smoke_test.dart -d macos
//
// ISOLATION (do not weaken):
// The app under test must NEVER see the developer's real installation.
// From a source checkout appVersion has no "-rawhide" suffix, so isPreRelease
// is FALSE: without intervention the app would use ~/Documents/FrontPorchAI —
// the operator's REAL stable data — and FileConsolidationService.consolidate()
// would MOVE folders out of the real ~/Library/Application Support at boot.
// Two seams close every path:
//  1. PathProviderPlatform.instance is replaced with _SandboxPathProvider, so
//     every path_provider lookup (Documents, Application Support, caches...)
//     resolves inside one throwaway temp directory.
//  2. SharedPreferences.setMockInitialValues gives an in-memory prefs store —
//     the real plist is never read or written; 'update_auto_check': false also
//     keeps boot deterministic (no GitHub release poll, no UpdateDialog).
//
// SCOPE CONSTRAINT for future test authors: keep this test at boot + home
// layout. Do NOT open a character chat from here without first sandboxing
// PorchMemoryMailbox: it scans hard-coded REAL paths under
// $HOME/Documents/FrontPorchAI*/KoboldManager/llmerta_porch_memories
// (deliberately, so LLMerta imports work with custom roots), and the Journal
// import that runs on chat open would consume the operator's real pending
// game bundles.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/main.dart' as app;
import 'package:front_porch_ai/ui/layout/main_layout.dart';

/// Redirects every path_provider lookup into [root] so the app cannot touch
/// the real installation. Extends (not implements) PathProviderPlatform so
/// the platform-interface token check accepts it.
class _SandboxPathProvider extends PathProviderPlatform {
  _SandboxPathProvider(this.root);

  final String root;

  String _dir(String name) =>
      (Directory(p.join(root, name))..createSync(recursive: true)).path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir('Documents');

  @override
  Future<String?> getApplicationSupportPath() async =>
      _dir('ApplicationSupport');

  @override
  Future<String?> getLibraryPath() async => _dir('Library');

  @override
  Future<String?> getApplicationCachePath() async => _dir('Caches');

  @override
  Future<String?> getTemporaryPath() async => _dir('tmp');

  @override
  Future<String?> getDownloadsPath() async => _dir('Downloads');
}

/// Real-async equivalent of pumpAndSettle for a booting app: the home layout
/// appears only after main()'s awaits (consolidation, DB open, window show)
/// complete, and the app keeps periodic animations running afterwards, so
/// pumpAndSettle would never settle. Pump until [finder] matches or fail.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(minutes: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      // Post-mortem hint: distinguishes "runApp never happened" (tree empty —
      // main() died before runApp) from "app stuck before home" (tree has
      // widgets but never mounted the target).
      fail(
        'Timed out after $timeout waiting for $finder. '
        'Widget tree currently holds ${tester.allWidgets.length} widgets.',
      );
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold boot reaches the home layout on a pristine sandbox', (
    tester,
  ) async {
    final sandbox = Directory.systemTemp.createTempSync('fpai_smoke_');
    PathProviderPlatform.instance = _SandboxPathProvider(sandbox.path);
    SharedPreferences.setMockInitialValues({'update_auto_check': false});

    app.main(const []);
    await _pumpUntilFound(tester, find.byType(MainLayout));

    // Let the post-frame wiring (update/web-server gates, ChatService ↔ TTS ↔
    // expression-classifier hookup, auto-backup timer start) run; an unhandled
    // exception in it fails the test here.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MainLayout), findsOneWidget);

    // Success → remove the sandbox. On failure this is skipped deliberately so
    // the directory survives for post-mortem (OS temp cleanup reaps it later).
    try {
      sandbox.deleteSync(recursive: true);
    } on FileSystemException {
      // A straggler (auto-backup tick) may still be writing; not a failure.
    }
  });
}
