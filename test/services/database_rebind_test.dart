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

// Regression tests for what happens when the database file is swapped under a
// running app — importing a stable DB, moving the storage root, and restoring
// a backup all do it.
//
// Restoring a backup used to close the live database, copy the snapshot over
// it, reopen the singleton, and then tell the user to restart: not one service
// was re-pointed, so every repository, ChatService and the web server kept a
// handle to the closed database and threw on the next query. These tests pin
// the three traps that made that bug survive review:
//
//   1. `close()` does NOT clear the static singleton — only `closeAndReset()`
//      does. Code that closed its own handle and then called `instance()` was
//      handed back the very object it had just closed.
//   2. ChatService owns a MemoryService that caches its own handle, so
//      re-pointing ChatService alone left RAG memory on the dead database.
//   3. `Provider<AppDatabase>` is a startup snapshot that can never be updated
//      (the provider tree is built inside runApp, not inside a State), so
//      widgets must read through liveDatabase().

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/embedding_service.dart';
import 'package:front_porch_ai/services/memory_service.dart';
import 'package:front_porch_ai/services/services.dart';

/// A STABLE documents directory. The shared mock in other suites hands out a
/// fresh temp dir per call, which would make every `instance()` open a
/// different file and quietly hide the singleton behaviour under test.
void _setupPathProviderMock(String docsDir) {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') return docsDir;
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docsDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    docsDir = Directory.systemTemp.createTempSync('fpai_rebind_');
    _setupPathProviderMock(docsDir.path);
    await AppDatabase.closeAndReset();
  });

  tearDown(() async {
    await AppDatabase.closeAndReset();
    try {
      docsDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('AppDatabase singleton lifecycle', () {
    test('current tracks the open instance and is null once reset', () async {
      expect(
        AppDatabase.current,
        isNull,
        reason: 'nothing is open before instance() is called',
      );

      final db = await AppDatabase.instance();
      expect(AppDatabase.current, same(db));

      await AppDatabase.closeAndReset();
      expect(AppDatabase.current, isNull);
    });

    test(
      'close() alone leaves the singleton in place — closeAndReset is what '
      'lets instance() hand back a NEW database',
      () async {
        final first = await AppDatabase.instance();

        // THE TRAP. The stable-DB import closed its own handle and then called
        // instance() expecting a fresh database; it got the closed one back,
        // rebound every service to it, and the integrity check threw.
        await first.close();
        expect(
          await AppDatabase.instance(),
          same(first),
          reason: 'close() must not be mistaken for a reset',
        );

        await AppDatabase.closeAndReset();
        final second = await AppDatabase.instance();
        expect(
          second,
          isNot(same(first)),
          reason: 'only closeAndReset gives a genuinely reopened database',
        );
      },
    );
  });

  group('ChatService database rebind', () {
    late StorageService storage;
    late AppDatabase oldDb;
    late AppDatabase newDb;
    late MemoryService memory;
    late ChatService chat;

    setUp(() {
      storage = StorageService();
      oldDb = AppDatabase.forTesting(sameIsolate: true);
      newDb = AppDatabase.forTesting(sameIsolate: true);
      memory = MemoryService(EmbeddingService(storage), storage, oldDb);
      chat =
          ChatService(
            KoboldService(storage),
            UserPersonaService(oldDb),
            storage,
            WorldRepository(storage, oldDb),
          )..setDatabase(oldDb);
      chat.setMemoryService(memory);
    });

    tearDown(() async {
      chat.dispose();
      await oldDb.close();
      await newDb.close();
    });

    test('updateDatabase carries the owned MemoryService across the swap', () async {
      chat.updateDatabase(newDb);
      // The swap closes the file the MemoryService was built against. If it
      // still held that handle this throws instead of returning a result.
      await oldDb.close();

      await expectLater(
        memory.getAllContentForCharacters(const ['Aerin_1782587668376']),
        completion(isEmpty),
      );
    });

    test('setDatabase is a true alias, so startup wiring cannot drift', () async {
      chat.setDatabase(newDb);
      await oldDb.close();

      await expectLater(
        memory.getAllContentForCharacters(const ['Aerin_1782587668376']),
        completion(isEmpty),
        reason: 'setDatabase must rebind exactly what updateDatabase rebinds',
      );
    });
  });

  group('liveDatabase', () {
    testWidgets('falls back to the provided database when nothing is open', (
      tester,
    ) async {
      final provided = AppDatabase.forTesting(sameIsolate: true);
      addTearDown(() async => provided.close());

      late AppDatabase resolved;
      await tester.pumpWidget(
        Provider<AppDatabase>.value(
          value: provided,
          child: Builder(
            builder: (context) {
              resolved = liveDatabase(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        resolved,
        same(provided),
        reason: 'widget tests pump a provider without ever opening a singleton',
      );
    });

    testWidgets('prefers the live singleton over a stale provided snapshot', (
      tester,
    ) async {
      // The provider value is what main.dart captured at startup; after a
      // restore it is closed, and every widget still reading it was throwing.
      final stale = AppDatabase.forTesting(sameIsolate: true);
      addTearDown(() async => stale.close());
      // MUST escape the fake-async zone: AppDatabase.instance() opens the real
      // cross-isolate database, and inside testWidgets the zone never yields to
      // the event loop, so the open would deadlock the run (see the note on
      // AppDatabase.forTesting's sameIsolate flag).
      late final AppDatabase live;
      await tester.runAsync(() async => live = await AppDatabase.instance());

      late AppDatabase resolved;
      await tester.pumpWidget(
        Provider<AppDatabase>.value(
          value: stale,
          child: Builder(
            builder: (context) {
              resolved = liveDatabase(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, same(live));
      expect(resolved, isNot(same(stale)));
    });
  });
}
