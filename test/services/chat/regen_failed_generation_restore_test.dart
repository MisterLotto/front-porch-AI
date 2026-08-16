// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A FAILED REGEN MUST NOT EAT THE MESSAGE (1.3 sweep, 2026-08-15).
//
// _regenerateLastMessageHeld pops the target reply into a local
// (`final lastMsg = _messages.removeLast()`), regenerates, and merges the new
// text back as a swipe. The merge guard used to read `_messages.last` alone:
// when _generateResponse came back empty-handed (group realism cancel) or
// appended a System error banner (backend down, any phase-1..4 throw), the
// guard was false, the popped reply — with every alternate swipe it held —
// was silently dropped, and the shortened transcript was already persisted.
// In a group whose previous entry was another member's reply, the guard was
// TRUE and merged that member's message into the regen target instead.
//
// The merge is now count-aware: no new reply appended -> the popped message
// is restored at its original position and the transcript force-saved.
//
// Harness: the same FakeBackendServer full-turn rig as
// regen_chip_attach_test.dart, with failChatCompletionContaining injecting a
// 500 on the regen's conversation call only (evals are never failed by it).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';

import '../../../integration_test/support/fake_backend.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_docs_').path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  late AppDatabase db;
  late ChatService chat;
  late FakeBackendServer backend;

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'realism_default': false,
    });
    db = AppDatabase.forTesting();
    backend = await FakeBackendServer.start(
      replyPieces: ['A reply worth keeping, ', 'swipes and all.'],
    );
    final storage = StorageService();
    final personas = UserPersonaService(db);
    final worlds = WorldRepository(storage, db);
    chat = ChatService(KoboldService(storage), personas, storage, worlds)
      ..setDatabase(db)
      ..testLlmServiceOverride = OpenRouterService(
        apiUrl: '${backend.baseUrl}/v1',
        modelName: 'smoke-model',
      );
    await chat.setActiveCharacter(
      CharacterCard(
        name: 'Keeper',
        description: 'Exists only inside the failed-regen unit test.',
        firstMessage: 'The porch light hums.',
        frontPorchExtensions: FrontPorchExtensions(
          realismEnabled: false,
          needsSimEnabled: false,
          chaosModeEnabled: false,
        ),
      )..dbId = 'char-keeper',
    );
  });

  tearDown(() async {
    chat.dispose();
    await backend.close();
    await db.close();
  });

  test('a regen whose generation fails restores the popped reply intact',
      () async {
    await chat.sendMessage('The lanterns sway in the evening wind.');
    final original = chat.messages.last;
    expect(original.isUser, isFalse);
    final originalText = original.text;
    final replyCountBefore =
        chat.messages.where((m) => !m.isUser && m.sender == 'Keeper').length;

    // Fail ONLY the regen's conversation call (the marker rides the user
    // prompt, which the regen re-sends; evals are exempt by the fake).
    backend.failChatCompletionContaining = 'lanterns sway';
    await chat.regenerateLastMessage();

    final survivors =
        chat.messages.where((m) => !m.isUser && m.sender == 'Keeper').toList();
    expect(
      survivors.length,
      replyCountBefore,
      reason: 'the popped reply must be restored when no new reply arrived — '
          'dropping it (old behavior) loses the message and all its swipes',
    );
    final restored = survivors.last;
    expect(restored.text, originalText,
        reason: 'the restored reply keeps its accepted swipe text');
    expect(restored.swipes.length, original.swipes.length,
        reason: 'no swipe may be lost or grafted by a failed regen');

    // And the restore must be durable: reload the session from the DB.
    final rows = await db.getMessagesForSession(chat.currentSessionId!);
    expect(
      rows.where((r) => r.sender == 'Keeper').length,
      greaterThanOrEqualTo(replyCountBefore),
      reason: 'the force-save must heal the shortened transcript the '
          'in-generation abort already persisted',
    );
  });
}
