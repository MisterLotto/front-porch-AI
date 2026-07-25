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

// Regression tests for the PR #162 session-load fixes, against the REAL
// ChatService + an in-memory Drift database (no fakes on the load path):
//
//  1. Per-chat generation settings must not bleed between chats — including
//     the two holes the first fix missed: entering a character with ZERO
//     sessions, and startNewChat. (Both used to keep the previous chat's
//     overrides in memory, and a fresh chat's first save could persist them.)
//  2. Retroactive sanitize ("Sanitise Existing History") rewrites MODEL
//     messages only — user and System rows must load byte-identical.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/chat_generation_settings.dart';
import 'package:front_porch_ai/models/output_sanitizer_rule.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';
import 'package:front_porch_ai/services/world_repository.dart';

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

CharacterCard _card(String name, String dbId) =>
    CharacterCard(name: name)..dbId = dbId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  late AppDatabase db;
  late StorageService storage;
  late ChatService chat;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting();
    storage = StorageService();
    final personas = UserPersonaService(db);
    final worlds = WorldRepository(storage, db);
    chat = ChatService(KoboldService(storage), personas, storage, worlds)
      ..setDatabase(db);
  });

  tearDown(() async {
    chat.dispose();
    await db.close();
  });

  /// Seeds a session for [characterId] whose stored generation_settings
  /// carry a temperature override — the marker the tests watch for bleed.
  Future<void> seedSessionWithOverride(
    String sessionId,
    String characterId, {
    double temperature = 1.5,
  }) async {
    await db.insertSession(
      SessionsCompanion.insert(
        id: sessionId,
        characterId: Value(characterId),
        generationSettings: Value(
          ChatGenerationSettings(temperature: temperature).toJsonString(),
        ),
      ),
    );
  }

  group('per-chat generation settings bleed (PR #162 + Grok holes)', () {
    test('loading a session applies its stored overrides', () async {
      await seedSessionWithOverride('sess-a', 'char-a');
      await chat.setActiveCharacter(_card('Alice', 'char-a'));
      expect(chat.sessionGenSettings.temperature, 1.5,
          reason: 'chat A must load its own stored override');
    });

    test('switching to a character with ZERO sessions clears overrides',
        () async {
      await seedSessionWithOverride('sess-a', 'char-a');
      await chat.setActiveCharacter(_card('Alice', 'char-a'));
      expect(chat.sessionGenSettings.temperature, 1.5);

      // Bob has never been chatted with — the 0-session early return used
      // to keep Alice's overrides live (and Bob's first save persisted them).
      await chat.setActiveCharacter(_card('Bob', 'char-b'));
      expect(chat.sessionGenSettings.temperature, isNull,
          reason: 'fresh character must not inherit the prior chat\'s '
              'per-chat generation overrides');
    });

    test('startNewChat clears the previous session\'s overrides', () async {
      await seedSessionWithOverride('sess-a', 'char-a');
      await chat.setActiveCharacter(_card('Alice', 'char-a'));
      expect(chat.sessionGenSettings.temperature, 1.5);

      await chat.startNewChat();
      expect(chat.sessionGenSettings.temperature, isNull,
          reason: 'a new chat with the same character starts from global '
              'defaults; only forkSession inherits overrides (by design)');
    });
  });

  group('retroactive sanitize scope (model output only)', () {
    Future<void> seedMessage({
      required String sessionId,
      required String id,
      required int position,
      required String sender,
      required bool isUser,
      required String text,
    }) async {
      await db.insertMessage(
        MessagesCompanion.insert(
          id: id,
          sessionId: sessionId,
          position: position,
          sender: sender,
          isUser: isUser,
          swipes: Value('["${text.replaceAll('"', r'\"')}"]'),
        ),
      );
    }

    test('hydrate rewrites AI rows, never user or System rows', () async {
      await storage.generationSettings.setOutputSanitizerEnabled(true);
      await storage.generationSettings.setSanitiseExistingHistory(true);
      await storage.generationSettings.setOutputSanitizerRules(const [
        OutputSanitizerRule(id: 0, find: 'foo', replace: 'bar'),
      ]);

      await db.insertSession(
        SessionsCompanion.insert(
          id: 'sess-s',
          characterId: const Value('char-a'),
        ),
      );
      await seedMessage(
        sessionId: 'sess-s', id: 'm1', position: 0,
        sender: 'You', isUser: true, text: 'user says foo',
      );
      await seedMessage(
        sessionId: 'sess-s', id: 'm2', position: 1,
        sender: 'Alice', isUser: false, text: 'model says foo',
      );
      await seedMessage(
        sessionId: 'sess-s', id: 'm3', position: 2,
        sender: 'System', isUser: false, text: 'system says foo',
      );

      await chat.setActiveCharacter(_card('Alice', 'char-a'));

      expect(chat.messages, hasLength(3));
      expect(chat.messages[0].text, 'user says foo',
          reason: 'the user\'s own words must never be rewritten');
      expect(chat.messages[1].text, 'model says bar',
          reason: 'model output is exactly what the feature sanitizes');
      expect(chat.messages[2].text, 'system says foo',
          reason: 'System rows (backend notices) must load untouched');
    });

    test('retroactive OFF leaves even AI rows untouched on load', () async {
      await storage.generationSettings.setOutputSanitizerEnabled(true);
      await storage.generationSettings.setSanitiseExistingHistory(false);
      await storage.generationSettings.setOutputSanitizerRules(const [
        OutputSanitizerRule(id: 0, find: 'foo', replace: 'bar'),
      ]);

      await db.insertSession(
        SessionsCompanion.insert(
          id: 'sess-t',
          characterId: const Value('char-a'),
        ),
      );
      await seedMessage(
        sessionId: 'sess-t', id: 'm1', position: 0,
        sender: 'Alice', isUser: false, text: 'model says foo',
      );

      await chat.setActiveCharacter(_card('Alice', 'char-a'));
      expect(chat.messages.single.text, 'model says foo',
          reason: 'sanitizer-on but retroactive-off must not rewrite '
              'already-saved history');
    });
  });
}
