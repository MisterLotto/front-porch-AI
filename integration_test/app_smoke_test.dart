// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E smoke test. Runs the REAL app — real main(), real service init order,
// real database open, real window — through a realism-enabled chat journey:
// boot to the home layout, create a character, open its chat, send a message,
// assert the streamed reply renders, assert the realism engine evaluated the
// turn (bond/trust/emotion applied from canned eval responses), plant and
// render a Journal card, and exercise the chat sidebar. Generation and every
// eval are served by an in-process OpenAI-compatible fake backend
// (support/fake_backend.dart), so the run is deterministic and fully offline.
//
// Run it on a Mac with:
//   flutter test integration_test/app_smoke_test.dart -d macos
//
// DELIBERATELY NOT COVERED (offline constraints, documented honestly):
//  - RAG/embeddings: the nomic ONNX model is a consent-gated download; there
//    is no offline path. The memory UI's pre-consent state still renders.
//  - TTS/STT/image gen: engines need model binaries that aren't in the repo.
//    Their services are constructed at boot, which IS covered.
//  - The physical-state/scene-time eval: answered as a chat reply (its JSON
//    keys aren't modeled in the fake yet) — parses to a no-op, harmless.
//
// ISOLATION (do not weaken):
// The app under test must NEVER see the developer's real installation.
// From a source checkout appVersion has no "-rawhide" suffix, so isPreRelease
// is FALSE: without intervention the app would use ~/Documents/FrontPorchAI —
// the operator's REAL stable data — and FileConsolidationService.consolidate()
// would MOVE folders out of the real ~/Library/Application Support at boot.
// Three seams close every path:
//  1. PathProviderPlatform.instance is replaced with SandboxPathProvider, so
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:front_porch_ai/main.dart' as app;
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/ui/layout/main_layout.dart';
import 'package:front_porch_ai/ui/pages/chat_page.dart';
import 'package:front_porch_ai/utils/character_id.dart';

import 'support/e2e_sandbox.dart';
import 'support/fake_backend.dart';

const _kGreeting = 'Welcome to the smoke test porch.';
const _kUserMessage = 'Hello there, smoke test calling.';
const _kReplyPieces = [
  'The porch light is on ',
  'and the fake backend is answering.',
];
const _kJournalCard = 'Planted by the smoke test: the porch swing creaked.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boot, realism chat round-trip, journal, sidebar — sandboxed', (
    tester,
  ) async {
    // Pre-flight: refuse to run while anything answers on 127.0.0.1:5001.
    // KoboldService's default base URL stays 5001 even in remote mode, and
    // its zombie-cleanup path pkills any KoboldCpp it didn't spawn if a
    // probe ever fires. Never risk the operator's real KoboldCpp.
    try {
      final probe = await Socket.connect(
        InternetAddress.loopbackIPv4,
        5001,
        timeout: const Duration(milliseconds: 500),
      );
      probe.destroy();
      fail(
        'Something is listening on 127.0.0.1:5001 (a real KoboldCpp?). '
        'The app under test could kill it as a "zombie". Close it (or quit '
        'the real Front Porch AI) before running the E2E suite.',
      );
    } on SocketException {
      // Nothing there — safe to proceed.
    }

    final sandbox = Directory.systemTemp.createTempSync('fpai_smoke_');
    PathProviderPlatform.instance = SandboxPathProvider(sandbox.path);
    final backend = await FakeBackendServer.start(replyPieces: _kReplyPieces);
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'import_llmerta_porch_memories': false,
      // Realism ON for new chats — the fake backend answers the eval calls.
      'realism_default': true,
      // Connect to the fake the way a real user connects an unmanaged local
      // server (LM Studio, llama.cpp — the PseudoRemote path): as a remote
      // OpenAI-compatible backend. Managed-kobold mode is NOT usable here:
      // its zombie cleanup pkills any KoboldCpp it didn't spawn (including,
      // if you pointed it at one, the operator's real backend), and its eval
      // gate requires a managed child process. A localhost URL needs no API
      // key (isReady treats local URLs as keyless).
      'backend_type': 'openRouter',
      'remote_api_url': '${backend.baseUrl}/v1',
      'remote_model_name': 'smoke-model',
    });

    // ── Phase 1: cold boot ──────────────────────────────────────────────
    app.main(const []);
    await pumpUntilFound(tester, find.byType(MainLayout));

    // The test window must stay VISIBLE: macOS pauses frame delivery to
    // fully occluded windows, and the live test binding's pump waits on real
    // vsync — if the operator's other windows cover this one, every pump
    // hangs. Stay out of the operator's way instead of taking the screen:
    // shrink into the bottom-right corner, keep on-top so nothing occludes
    // it, and immediately give keyboard focus back (synthetic test taps and
    // text entry don't need OS key focus).
    await windowManager.setAlwaysOnTop(true);
    // 1200x800, not smaller: some app rows overflow below ~1100px width and
    // the resulting RenderFlex exception would fail the test as noise.
    await windowManager.setSize(const Size(1200, 800));
    await windowManager.setAlignment(Alignment.bottomRight);
    await windowManager.blur();

    // Let the post-frame wiring (update/web-server gates, ChatService ↔ TTS ↔
    // expression-classifier hookup, auto-backup timer start) run; an unhandled
    // exception in it fails the test here.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MainLayout), findsOneWidget);

    // A REAL mouse hover over the live test window trips a framework-internal
    // hit-test bookkeeping assert (flutter#146201-class issue) that is pure
    // noise for this suite: it reflects physical input colliding with the
    // synthetic test pointer, not app behavior. Downgrade exactly that one
    // error; everything else still fails the test through the prior handler.
    final previousOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = previousOnError);
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(
        'unexpectedly has a HitTestResult',
      )) {
        debugPrint(
          '[e2e] Ignored real-mouse hover collision with the test pointer '
          '(keep hands off the test window).',
        );
        return;
      }
      // Never null-drop: if the test framework handler is somehow absent,
      // errors still surface instead of vanishing.
      (previousOnError ?? FlutterError.presentError)(details);
    };

    // ── Phase 2: chat round-trip ────────────────────────────────────────
    final ctx = tester.element(find.byType(MainLayout));

    final character = CharacterCard(
      name: 'Smoke Tester',
      description: 'A character that exists only inside the E2E smoke test.',
      firstMessage: _kGreeting,
      // Realism seeding only runs for cards that CARRY extensions (the
      // realism_default OR lives inside that branch) — a bare card keeps
      // realism off no matter what the global default says.
      frontPorchExtensions: FrontPorchExtensions(realismEnabled: true),
    );
    await Provider.of<CharacterRepository>(
      ctx,
      listen: false,
    ).addCharacter(character);

    // Open the chat exactly the way _handleTapCharacter (home_page_chrome)
    // does on a card tap: activate, then push the real ChatPage. (The tap
    // itself is skipped because the home grid doesn't rebuild on background
    // repository inserts.)
    final chatService = Provider.of<ChatService>(ctx, listen: false);
    await chatService.setActiveCharacter(character);
    // ignore: use_build_context_synchronously — ctx is the root MainLayout element, alive for the whole test.
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const ChatPage()));
    await pumpUntilFound(
      tester,
      find.textContaining(_kGreeting, findRichText: true),
    );

    // The send button mirrors sendMessage's SILENT early-returns
    // (isGenerating / isGuestBusy / photo turn / entrances in flight) — a tap
    // during any of them is consumed into the void with no error. Realism
    // chats keep more of that machinery in flight, so wait out all of it
    // before every send.
    Future<void> waitSendable() => pumpUntilTrue(
      tester,
      () =>
          !chatService.isGenerating &&
          !chatService.isGuestBusy &&
          !chatService.isPhotoTurnInFlight &&
          !chatService.entrancesInFlight,
      describe: () =>
          'chat sendable (gen=${chatService.isGenerating} '
          'guest=${chatService.isGuestBusy} '
          'photo=${chatService.isPhotoTurnInFlight} '
          'entrances=${chatService.entrancesInFlight})',
    );

    // Type into the real message input and tap the real send button.
    final input = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.contains('Type a message') ?? false),
    );
    await pumpUntilFound(tester, input);

    // A one-shot tap is not enough: the guards can flip in the gap between
    // the sendable check and the tap (post-turn async work), and the app
    // deliberately swallows such sends (text preserved for retry). Retry
    // until the message provably lands in the chat service.
    Future<void> sendRobustly(String text) async {
      bool delivered() =>
          chatService.messages.any((m) => m.text.contains(text));
      for (var attempt = 0; attempt < 8; attempt++) {
        await waitSendable();
        await tester.enterText(input, text);
        // The live binding's fake keyboard connection can go stale after the
        // app's own post-send IME churn — enterText then writes into the
        // void (observed: works for turn 1, silently dead for turn 2). Real
        // typing is already covered by the first successful enterText;
        // self-heal by setting the controller directly when it happens.
        final controller = tester.widget<TextField>(input).controller;
        if (controller != null && controller.text != text) {
          controller.text = text;
        }
        await tester.pump();
        await tester.tap(find.byTooltip('Send message'));
        for (var i = 0; i < 8 && !delivered(); i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        if (delivered()) return;
      }
      fail('"$text" was never accepted by sendMessage after 8 attempts');
    }

    await sendRobustly(_kUserMessage);

    // The user bubble appears immediately; the reply streams from the fake
    // backend through the full KoboldService → streamOpenAiChat → ChatService
    // → bubble-render pipeline.
    await pumpUntilFound(
      tester,
      find.textContaining(_kUserMessage, findRichText: true),
    );
    await pumpUntilFound(
      tester,
      find.textContaining(_kReplyPieces.join(), findRichText: true),
      timeout: const Duration(seconds: 60),
    );
    // The outbound prompt must carry the user's message — proves the send
    // path assembled a real request, not just that a bubble rendered.
    expect(backend.lastChatBody, contains(_kUserMessage));

    // ── Phase 3: realism engine ─────────────────────────────────────────
    // Realism evals are PRE-GEN: sending message N evaluates exchange N-1
    // (the "[Realism:Metadata] PRE-GEN attach" path), so one exchange alone
    // never yields deltas. Send a second message; its pre-gen evals score
    // the first exchange against the fake backend (tool probe refused →
    // text fallback → canned JSON) and the deltas land as chip metadata.
    await sendRobustly('And how is the weather on the porch?');
    await pumpUntilTrue(
      tester,
      () => chatService.messages.any(
        (m) => (m.activeMetadata?['bond_delta'] as int?) == 2,
      ),
      describe: () =>
          'bond_delta=2 chip metadata from the canned relationship eval '
          '(realism pre-gen pipeline). Server saw: '
          '${backend.chatRequests} chat, ${backend.evalRequests} eval, '
          '${backend.toolProbeRequests} tool-probe requests.',
    );
    expect(backend.evalRequests, greaterThanOrEqualTo(1));
    expect(backend.toolProbeRequests, greaterThanOrEqualTo(1));
    // The second turn's generation must actually reach the backend — with
    // every eval modeled, chatRequests counts real conversation turns only.
    await pumpUntilTrue(
      tester,
      () => backend.chatRequests >= 2,
      describe: () =>
          'the second turn generating (chatRequests='
          '${backend.chatRequests}, messages=${chatService.messages.length}, '
          'msg2InList=${chatService.messages.any((m) => m.text.contains('weather on the porch'))}, '
          'sendable: gen=${chatService.isGenerating} '
          'guest=${chatService.isGuestBusy} '
          'photo=${chatService.isPhotoTurnInFlight} '
          'entrances=${chatService.entrancesInFlight})',
    );

    // ── Phase 4: journal card plant + render ────────────────────────────
    // Plant through the SAME store the app's plant/edit editor uses, then
    // reopen the sidebar so the journal panel reloads from the DB.
    await chatService.journalStore.addCard(
      sessionId: chatService.currentSessionId!,
      characterId: character.stableGroupId,
      content: _kJournalCard,
      category: 'moment',
      maxCards: 20,
    );
    // The Journal & Memory accordion is collapsed by default and builds its
    // panel lazily — expand it the way a user would, AFTER planting, so the
    // freshly built panel loads the card from the DB. Its subtitle is also
    // the honest RAG surface this offline suite can verify: the journal is
    // on, and RAG is off (the embedding model is a consent-gated download).
    await pumpUntilFound(
      tester,
      find.textContaining('Journal on · RAG off', findRichText: true),
    );
    await tester.tap(find.text('Journal & Memory'));
    await pumpUntilFound(
      tester,
      find.textContaining('porch swing creaked', findRichText: true),
      timeout: const Duration(seconds: 30),
    );

    // ── Phase 5: backend traffic audit ──────────────────────────────────
    // Any endpoint the fake doesn't model would have 404'd silently and
    // skewed behavior; surface it by name instead.
    expect(backend.unexpectedPaths, isEmpty);

    // Let any trailing eval traffic land before the server goes away, so
    // teardown never races an in-flight request.
    await tester.pump(const Duration(seconds: 1));

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
