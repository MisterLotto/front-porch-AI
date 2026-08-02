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

// Phase 2 test gate, item 1 of the Realism engine audit: EVERY realism scalar
// stored on a session must survive a round trip, and both load paths must agree.
//
// Why this file exists, in one sentence: a `required` parameter was accepted by
// TimeService.loadTimeScalars and then never assigned, so a chat's saved
// "Automatic Passage of Time" setting was read out of the database, handed to
// the loader, and dropped — and because entering a chat resets that flag to
// true first, the next save wrote `true` back over the user's choice. The
// setting could not be made to stick, and nothing in a 2,800-test suite noticed.
//
// The pre-existing session_load_regression_test.dart already compares the two
// load paths, but only for four fields — and its own fixture seeds an emotion it
// never checks. This covers the rest. The audit called it "the cheapest and
// highest value" test available, precisely because a field being silently
// dropped is invisible until a user complains.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/services/services.dart';

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

  /// Every realism scalar the session row carries, read off the live services.
  /// Recorded as a map so a failure names the field that drifted rather than
  /// just reporting that two opaque records differ.
  Map<String, Object?> liveScalars() => {
    'affection': chat.relationshipService.affectionScore,
    'longTerm': chat.relationshipService.longTermScore,
    'trust': chat.relationshipService.trustLevel,
    'fixation': chat.relationshipService.activeFixation,
    'emotion': chat.characterEmotion,
    'emotionIntensity': chat.emotionIntensity,
    'arousal': chat.nsfwService.arousalLevel,
    'chaosEnabled': chat.chaosModeService.chaosModeEnabled,
    'chaosPressure': chat.chaosModeService.chaosPressure,
    'passageOfTime': chat.timeService.passageOfTimeEnabled,
    'dayCount': chat.timeService.dayCount,
  };

  Future<void> seedRichSession(
    String sessionId,
    String characterId, {
    required bool passageOfTime,
  }) async {
    await db.insertSession(
      SessionsCompanion.insert(
        id: sessionId,
        characterId: Value(characterId),
        affectionScore: const Value(77),
        longTermScore: const Value(41),
        trustLevel: const Value(33),
        characterEmotion: const Value('joy'),
        emotionIntensity: const Value('strong'),
        arousalLevel: const Value(25),
        chaosModeEnabled: const Value(true),
        chaosPressure: const Value(9),
        passageOfTimeEnabled: Value(passageOfTime),
        dayCount: const Value(4),
      ),
    );
  }

  group('every stored realism scalar survives a load', () {
    test('a saved passage-of-time OFF is still off after reopening the chat',
        () async {
      // THE REGRESSION. Everything else in this file is scaffolding around it.
      await seedRichSession('sess-off', 'char-a', passageOfTime: false);

      await chat.setActiveCharacter(_card('Alice', 'char-a'));

      expect(
        chat.timeService.passageOfTimeEnabled,
        isFalse,
        reason:
            'the session stored passageOfTimeEnabled=false. Entering a chat '
            'calls resetForFreshChat() first, which forces it TRUE, so the '
            'hydrate step is the only thing that can restore the user\'s '
            'choice. When loadTimeScalars ignored its own parameter this '
            'silently read back as true and the next save destroyed the row.',
      );
    });

    test('a saved passage-of-time ON stays on', () async {
      await seedRichSession('sess-on', 'char-b', passageOfTime: true);
      await chat.setActiveCharacter(_card('Bob', 'char-b'));
      expect(chat.timeService.passageOfTimeEnabled, isTrue);
    });

    test('the global default does not override a saved per-chat choice',
        () async {
      // The load path used to AND the stored value with the global default.
      // That global is a seed-time ceiling applied when a chat is CREATED, not
      // a runtime master — applying it again on every load let switching the
      // global off retroactively disable time in chats it was turned on for.
      await storage.setPassageOfTimeDefault(false);
      await seedRichSession('sess-vs-global', 'char-c', passageOfTime: true);

      await chat.setActiveCharacter(_card('Cleo', 'char-c'));

      expect(
        chat.timeService.passageOfTimeEnabled,
        isTrue,
        reason:
            'the chat says on and the row is what was saved; the app-wide '
            'default must not reach back into an existing chat',
      );
    });

    test('both load paths hydrate identical values for EVERY scalar', () async {
      await seedRichSession('sess-full', 'char-a', passageOfTime: false);

      await chat.setActiveCharacter(_card('Alice', 'char-a'));
      final viaLibrary = liveScalars();

      // Perturb live state by visiting another character, come back, and load
      // the same session through the picker instead.
      await chat.setActiveCharacter(_card('Bob', 'char-b'));
      await chat.setActiveCharacter(_card('Alice', 'char-a'));
      await chat.loadSession('sess-full');
      final viaPicker = liveScalars();

      // Compare field by field so a failure says WHICH scalar drifted.
      for (final key in viaLibrary.keys) {
        expect(
          viaPicker[key],
          viaLibrary[key],
          reason:
              '"$key" differs between the two load paths — they must go '
              'through the same hydrate. library=${viaLibrary[key]} '
              'picker=${viaPicker[key]}',
        );
      }
    });

    test('the values that come back are the values that were stored', () async {
      await seedRichSession('sess-values', 'char-a', passageOfTime: false);
      await chat.setActiveCharacter(_card('Alice', 'char-a'));

      // Not a tautology against liveScalars(): these are the literals the row
      // was seeded with, so a loader that quietly substitutes a default fails
      // here even if both load paths agree with each other.
      expect(chat.relationshipService.affectionScore, 77);
      expect(chat.relationshipService.longTermScore, 41);
      expect(chat.relationshipService.trustLevel, 33);
      expect(chat.characterEmotion, 'joy');
      expect(chat.emotionIntensity, 'strong');
      expect(chat.nsfwService.arousalLevel, 25);
      expect(chat.chaosModeService.chaosModeEnabled, isTrue);
      expect(chat.chaosModeService.chaosPressure, 9);
      expect(chat.timeService.passageOfTimeEnabled, isFalse);
    });
  });
}
