// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// CallOverlay lifecycle ownership (2026-08-14 voice call overhaul).
//
// The class of bug this file guards: teardown that only HIDES the call UI.
// Before the overhaul, a TTS error mid-call set `_isCallActive = false` on
// the chat page and nothing else — the overlay vanished, but the call
// session kept listening, transcriptions kept auto-sending messages into
// the chat headlessly, and `callMode` stayed latched on ChatService (short
// "phone call" replies + reasoning-off in the TEXT chat afterwards).
//
// The fix: the overlay's presence in the tree IS the call. dispose() runs
// the one idempotent teardown — so removing the overlay for ANY reason
// (End button, TTS error, chat switch, page pop) releases the mic, ends
// the session, detaches the transcription callback, and clears callMode.
// These tests exercise exactly that contract: mount = call up, unmount =
// call fully down.
//
// Red-proven: with the `_teardown()` call removed from dispose(), the
// removal test fails on `call.isInCall` (still true — the headless-call
// state users hit) and the framework additionally reports the session's
// leaked periodic timer. Restored, the suite is green.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

import '../../golden/support/fakes.dart';

/// Real [CallSession] over no-op audio I/O with instant timings, so the
/// state machine runs genuinely (calibrate → listen) without a recorder.
class _CallStt extends FakeSttService {
  _CallStt() {
    // The real SttService surfaces the session's changes as its own — the
    // overlay's Consumer rebuilds through this wiring.
    call.addListener(notifyListeners);
  }

  late final CallSession _call = CallSession(
    startRecording: () async {},
    cancelRecording: () async {},
    stopAndTranscribe: () async => null,
    calibrationDuration: Duration.zero,
    silenceDuration: const Duration(milliseconds: 50),
    settleDelay: Duration.zero,
  );

  @override
  CallSession get call => _call;

  @override
  double get currentAmplitude => 0.0;
  @override
  String? get lastTranscription => null;
  @override
  bool get isRecording => false;
}

class _CallTts extends FakeTtsService {
  int stopCalls = 0;
  @override
  String? get nowSpeaking => null;
  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

class _CallChat extends FakeChatService {
  _CallChat() : super(activeCharacter: CharacterCard(name: 'Ember'));
  @override
  bool callMode = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness({
    required _CallStt stt,
    required _CallTts tts,
    required _CallChat chat,
    required bool overlayUp,
    VoidCallback? onEndCall,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SttService>.value(value: stt),
        ChangeNotifierProvider<TtsService>.value(value: tts),
        ChangeNotifierProvider<ChatService>.value(value: chat),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: overlayUp
              ? CallOverlay(
                  character: chat.activeCharacter!,
                  onEndCall: onEndCall ?? () {},
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets(
    'unmounting the overlay — for ANY reason — tears the whole call down',
    (tester) async {
      final stt = _CallStt();
      final tts = _CallTts();
      final chat = _CallChat();

      await tester.pumpWidget(
        harness(stt: stt, tts: tts, chat: chat, overlayUp: true),
      );
      await tester.pump(); // post-frame: _initCall wires and starts the call
      expect(chat.callMode, isTrue, reason: 'mount enters call mode');
      expect(stt.call.isInCall, isTrue);
      expect(stt.call.onTranscription, isNotNull);

      // Let calibration (zero-length) finish and the first listen begin.
      await tester.pump(const Duration(milliseconds: 100));
      expect(stt.call.status, CallStatus.listening);

      // Remove the overlay WITHOUT the End button — this is the TTS-error /
      // chat-switch / page-pop shape that used to leave a headless call.
      await tester.pumpWidget(
        harness(stt: stt, tts: tts, chat: chat, overlayUp: false),
      );
      await tester.pump();

      expect(
        stt.call.isInCall,
        isFalse,
        reason: 'dispose must END the session, not just hide the UI — a '
            'live session here is the headless-call bug (mic hot, '
            'auto-sending, no UI)',
      );
      expect(
        chat.callMode,
        isFalse,
        reason: 'callMode latched after the overlay is gone means the TEXT '
            'chat keeps the call prompt and reasoning-off',
      );
      expect(
        stt.call.onTranscription,
        isNull,
        reason: 'a late transcription must have nowhere to send',
      );
      expect(tts.stopCalls, greaterThan(0), reason: 'speech is cut, not '
          'left to finish into an empty room');
    },
  );

  testWidgets('the End button tears down AND hands control back', (
    tester,
  ) async {
    final stt = _CallStt();
    final tts = _CallTts();
    final chat = _CallChat();
    var ended = 0;

    await tester.pumpWidget(
      harness(
        stt: stt,
        tts: tts,
        chat: chat,
        overlayUp: true,
        onEndCall: () => ended++,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(stt.call.status, CallStatus.listening);

    await tester.tap(find.byIcon(Icons.call_end));
    await tester.pump();

    expect(ended, 1, reason: 'the page is told to drop the overlay');
    expect(stt.call.isInCall, isFalse);
    expect(chat.callMode, isFalse);

    // The page removes the overlay in response; dispose's second teardown
    // must be a harmless no-op (idempotence).
    await tester.pumpWidget(
      harness(stt: stt, tts: tts, chat: chat, overlayUp: false),
    );
    await tester.pump();
    expect(stt.call.isInCall, isFalse);
    expect(chat.callMode, isFalse);
  });

  testWidgets('the warm-porch overlay surfaces status and identity', (
    tester,
  ) async {
    final stt = _CallStt();
    final tts = _CallTts();
    final chat = _CallChat();

    await tester.pumpWidget(
      harness(stt: stt, tts: tts, chat: chat, overlayUp: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Let the status chip's AnimatedSwitcher finish its 300ms cross-fade.
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('VOICE CALL'), findsOneWidget);
    expect(find.text('Ember'), findsOneWidget);
    expect(find.text('Listening…'), findsOneWidget);
    // The realism strip shows the character's current emotion (the fake
    // seeds 'neutral') — realism is no longer invisible during a call.
    expect(find.text('Neutral'), findsOneWidget);

    // Teardown via unmount so no timers leak into the test summary.
    await tester.pumpWidget(
      harness(stt: stt, tts: tts, chat: chat, overlayUp: false),
    );
    await tester.pump();
  });
}
