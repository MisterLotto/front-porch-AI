// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E smoke test. Runs the REAL app — real main(), real service init order,
// real database open, real window — through a full chat round-trip: boot to
// the home layout, create a character, open its chat, send a message, and
// assert the streamed reply renders. Generation is served by an in-process
// fake KoboldCpp speaking the same OpenAI-compatible SSE protocol
// streamOpenAiChat consumes, so the run is deterministic and fully offline.
// Its job is the regression class unit tests can't catch: service-init-order
// breakage, plugin/native failures after a Flutter or dependency bump,
// DB-open failures, and a dead send→stream→render pipeline.
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
// Three seams close every path:
//  1. PathProviderPlatform.instance is replaced with _SandboxPathProvider, so
//     every path_provider lookup (Documents, Application Support, caches...)
//     resolves inside one throwaway temp directory.
//  2. SharedPreferences.setMockInitialValues gives an in-memory prefs store —
//     the real plist is never read or written; 'update_auto_check': false also
//     keeps boot deterministic (no GitHub release poll, no UpdateDialog).
//  3. 'import_llmerta_porch_memories': false — PorchMemoryMailbox scans
//     hard-coded REAL paths under $HOME/Documents/FrontPorchAI* (deliberately,
//     so LLMerta imports work with custom roots). The import runs on chat
//     open and CONSUMES pending bundles, so it must stay off in this test.
//     Do not remove this preset while any part of the test opens a chat.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/main.dart' as app;
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/ui/layout/main_layout.dart';
import 'package:front_porch_ai/ui/pages/chat_page.dart';

const _kGreeting = 'Welcome to the smoke test porch.';
const _kUserMessage = 'Hello there, smoke test calling.';
const _kReply = 'The porch light is on and the fake backend is answering.';

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

/// Minimal in-process KoboldCpp stand-in. Serves the two endpoints the app
/// uses for a chat turn: GET /api/extra/version (health probe) and
/// POST /v1/chat/completions (OpenAI-compatible SSE — the protocol
/// KoboldService.generateStream actually speaks via streamOpenAiChat).
/// Every completion request streams [_kReply] regardless of the prompt.
class _FakeKoboldServer {
  _FakeKoboldServer._(this._server);

  final HttpServer _server;
  int chatRequests = 0;

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<_FakeKoboldServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeKoboldServer._(server);
    server.listen(fake._handle);
    return fake;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      if (req.uri.path == '/api/extra/version') {
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          jsonEncode({'result': 'KoboldCpp', 'version': '1.100'}),
        );
      } else if (req.uri.path == '/v1/chat/completions') {
        chatRequests++;
        await req.drain<void>();
        req.response.headers.set('Content-Type', 'text/event-stream');
        // Two chunks, not one: proves the incremental SSE decode path.
        for (final piece in const [
          'The porch light is on ',
          'and the fake backend is answering.',
        ]) {
          req.response.write(
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': piece},
                },
              ],
            })}\n\n',
          );
          await req.response.flush();
        }
        req.response.write('data: [DONE]\n\n');
      } else {
        req.response.statusCode = HttpStatus.notFound;
      }
    } catch (_) {
      // A request racing test teardown may find a closed socket; irrelevant.
    } finally {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> close() => _server.close(force: true);
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

  testWidgets('cold boot, then a full chat round-trip on a pristine sandbox', (
    tester,
  ) async {
    final sandbox = Directory.systemTemp.createTempSync('fpai_smoke_');
    PathProviderPlatform.instance = _SandboxPathProvider(sandbox.path);
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'import_llmerta_porch_memories': false,
    });
    final backend = await _FakeKoboldServer.start();

    // ── Phase 1: cold boot ──────────────────────────────────────────────
    app.main(const []);
    await _pumpUntilFound(tester, find.byType(MainLayout));

    // Let the post-frame wiring (update/web-server gates, ChatService ↔ TTS ↔
    // expression-classifier hookup, auto-backup timer start) run; an unhandled
    // exception in it fails the test here.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MainLayout), findsOneWidget);

    // ── Phase 2: chat round-trip ────────────────────────────────────────
    final ctx = tester.element(find.byType(MainLayout));
    Provider.of<KoboldService>(ctx, listen: false).setBaseUrl(backend.baseUrl);

    final character = CharacterCard(
      name: 'Smoke Tester',
      description: 'A character that exists only inside the E2E smoke test.',
      firstMessage: _kGreeting,
    );
    await Provider.of<CharacterRepository>(
      ctx,
      listen: false,
    ).addCharacter(character);

    // Open the chat exactly the way _handleTapCharacter (home_page_chrome)
    // does on a card tap: activate, then push the real ChatPage. (The tap
    // itself is skipped because the home grid doesn't rebuild on background
    // repository inserts.)
    await Provider.of<ChatService>(
      ctx,
      listen: false,
    ).setActiveCharacter(character);
    // ignore: use_build_context_synchronously — ctx is the root MainLayout element, alive for the whole test.
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const ChatPage()));
    await _pumpUntilFound(
      tester,
      find.textContaining(_kGreeting, findRichText: true),
    );

    // Type into the real message input and tap the real send button.
    final input = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText?.contains('Type a message') ?? false),
    );
    await _pumpUntilFound(tester, input);
    await tester.enterText(input, _kUserMessage);
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));

    // The user bubble appears immediately; the reply streams from the fake
    // backend through the full KoboldService → streamOpenAiChat → ChatService
    // → bubble-render pipeline.
    await _pumpUntilFound(
      tester,
      find.textContaining(_kUserMessage, findRichText: true),
    );
    await _pumpUntilFound(
      tester,
      find.textContaining(_kReply, findRichText: true),
      timeout: const Duration(seconds: 60),
    );
    expect(backend.chatRequests, greaterThanOrEqualTo(1));

    // Success → shut the fake backend and remove the sandbox. On failure
    // these are skipped deliberately so the directory survives for
    // post-mortem (OS temp cleanup reaps it later).
    await backend.close();
    try {
      sandbox.deleteSync(recursive: true);
    } on FileSystemException {
      // A straggler (auto-backup tick) may still be writing; not a failure.
    }
  });
}
