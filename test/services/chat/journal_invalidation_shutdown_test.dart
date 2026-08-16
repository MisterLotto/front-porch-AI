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

// THE SHUTDOWN RACE THAT TURNED ec82f27's H3 GUARD RED ON CI (2026-08-11).
//
// deleteMessage fires _invalidateJournalFrom, whose card purge is an
// UNAWAITED select+delete chain. Delete a message and then close the app
// (or a test teardown closing the Drift isolate) while that select is in
// flight, and pre-fix the "Channel was closed before receiving a response"
// error escaped as an unhandled zone error — every assertion in the H3
// pockets test passed, and the test still failed with [E]. Locally the
// timing usually let the error land elsewhere, so the flake only showed
// on CI.
//
// This guard forces the race deterministically by inverting the order:
// the database is closed BEFORE the delete, so the purge's request is
// GUARANTEED to hit a dead channel ("Tried to send Request … but the
// connection was closed" — the request-after-close twin of CI's
// killed-mid-flight variant; both flow through the same unawaited chain).
// Closing after the delete is not reliable: drift serializes the pending
// select ahead of the close, so that ordering only fails on CI-shaped
// timing. The test zone fails on any unhandled async error, so the body
// needs no assertion beyond draining the microtask queue afterwards.
//
// Guard proven to fail before passing: with the chain's .catchError
// removed (the pre-fix shape), this test goes red with the exact CI error;
// green with it restored.

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
          return Directory.systemTemp.createTempSync('fpai_shutdown_').path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  late AppDatabase db;
  late StorageService storage;
  late ChatService chat;
  var dbClosed = false;

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'realism_default': false,
    });
    db = AppDatabase.forTesting();
    dbClosed = false;
    storage = StorageService();
    chat = ChatService(
      KoboldService(storage),
      UserPersonaService(db),
      storage,
      WorldRepository(storage, db),
    )..setDatabase(db)..setCharacterRepository(CharacterRepository(db, storage));
    await storage.initialized;
  });

  tearDown(() async {
    chat.dispose();
    if (!dbClosed) await db.close();
  });

  test('deleteMessage then immediate DB close must not throw into the zone',
      () async {
    final card = CharacterCard(
      name: 'Mara',
      description: 'Exists only inside the shutdown-race test.',
      firstMessage: 'The porch light hums.',
    )..dbId = 'char-shutdown-1';
    await chat.setActiveCharacter(card);
    expect(chat.messages, isNotEmpty);

    // The race, forced: with the database already closed, the card-purge
    // request inside deleteMessage cannot get a response — the exact state
    // a mid-shutdown delete (or CI's teardown timing) puts it in.
    dbClosed = true;
    await db.close();
    chat.deleteMessage(chat.messages.length - 1);

    // Drain so the in-flight chain settles inside this test's zone — an
    // escaped error fails the test here, not wherever CI timing drops it.
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  });
}
