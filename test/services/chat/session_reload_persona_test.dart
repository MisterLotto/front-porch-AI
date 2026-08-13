// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

// A SAME-session reload must READ the row, never write it first (2026-08-13).
//
// 6192ddc's per-turn-persist work put an unconditional flushPendingSaves()
// at the top of loadSession. flush is a FULL save, so reloading the session
// that is already open stamped the live scalars — the active persona above
// all — onto the row before the restore read it back: switch persona, reopen
// the chat, and it "restores" the persona you just switched to, durably
// rewriting the session's binding. That is exactly the flow of the
// persona_default / persona_folder E2Es (red on every platform since
// 6192ddc) — this is their fast unit twin, red before the gate and green
// with it.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_perload_').path;
        }
        return null;
      });
}

class _InertLlm extends LLMService {
  @override
  Stream<String> generateStream(GenerationParams params) async* {
    yield '';
  }

  @override
  bool get isReady => true;

  @override
  String get backendName => 'InertLlm';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  late AppDatabase db;
  late StorageService storage;
  late CharacterRepository repo;
  late UserPersonaService personas;
  late ChatService chat;

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'realism_default': false,
    });
    db = AppDatabase.forTesting();
    storage = StorageService();
    repo = CharacterRepository(db, storage);
    personas = UserPersonaService(db);
    chat =
        ChatService(KoboldService(storage), personas, storage,
            WorldRepository(storage, db))
          ..setDatabase(db)
          ..setCharacterRepository(repo)
          ..testLlmServiceOverride = _InertLlm();
    await storage.initialized;
  });

  tearDown(() async {
    chat.dispose();
    await db.close();
  });

  test('reloading the OPEN session restores its persona instead of stamping '
      'the live one onto the row', () async {
    // Two personas; creating one makes it active+default, so Porchy first —
    // the chat is seeded under Porchy — then Nightowl takes over as the
    // live persona, exactly like the E2E's "move the default" step.
    await personas.createPersona('Porchy', 'Porchy', 'porch tester', null);
    final porchy = personas.persona.id;
    // Persona ids are epoch-millis — space the second one out.
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final card = CharacterCard(
      name: 'Sitter',
      description: 'Persona-reload test card.',
      firstMessage: 'The porch light hums.',
    );
    await repo.addCharacter(card);
    await chat.setActiveCharacter(card);
    await chat.sendMessage('hold my persona');
    final sessionId = chat.currentSessionId!;

    // The row is bound to Porchy.
    expect((await db.getSessionById(sessionId))!.userPersonaId, porchy);

    await personas.createPersona('Nightowl', 'Nightowl', 'late shift', null);
    final nightowl = personas.persona.id;
    expect(nightowl, isNot(porchy));

    // Reopen the SAME session — the picker flow. The row must win.
    await chat.loadSession(sessionId);

    expect(
      personas.persona.id,
      porchy,
      reason: 'reopening a chat restores the persona it was chatted under',
    );
    expect(
      (await db.getSessionById(sessionId))!.userPersonaId,
      porchy,
      reason: 'the reload must not have rewritten the row binding first — '
          'that is the write-before-read bug this suite pins',
    );
  });
}
