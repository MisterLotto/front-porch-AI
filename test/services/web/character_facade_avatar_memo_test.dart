// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// `/api/characters` builds a cache-busting `avatarVersion` for every row, and
// resolving one costs an existsSync + statSync. That endpoint is re-fetched by
// every connected browser on every `library_changed` AND on every keystroke in
// the web search box, so a 300-card library meant hundreds of synchronous
// filesystem calls on the Flutter UI isolate per refresh — the canonical
// "cheap-once-per-event helper reused in a hot loop" regression (10-100x worse
// on Windows under Defender than on the dev Mac).
//
// The version is now memoized, with an explicit invalidation the web server
// fires on library changes so a swapped portrait still gets a fresh `v=` token.
// This test proves BOTH halves: the second list() must not re-stat, and
// invalidateAvatarVersions() must make it re-stat.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/web/facade/character_facade.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_avmemo_').path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StorageService storage;
  late CharacterFacade facade;
  late File portrait;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    _setupPathProviderMock();
    db = AppDatabase.forTesting();
    storage = StorageService();
    await storage.initialized;
    facade = CharacterFacade(db, storage, null, null, null);

    final dir = storage.charactersDir;
    if (!dir.existsSync()) dir.createSync(recursive: true);
    portrait = File('${dir.path}${Platform.pathSeparator}alice.png')
      ..writeAsBytesSync(const [0x89, 0x50, 0x4E, 0x47]);
    portrait.setLastModifiedSync(DateTime(2026, 1, 1));

    await db.insertCharacter(
      CharactersCompanion(
        id: const Value('c1'),
        name: const Value('Alice'),
        imagePath: const Value('alice.png'),
      ),
    );
  });

  tearDown(() => db.close());

  Future<int> versionOf() async =>
      (await facade.list()).single['avatarVersion'] as int;

  test('the avatar version is memoized, and invalidation refreshes it',
      () async {
    final first = await versionOf();
    expect(
      first,
      DateTime(2026, 1, 1).millisecondsSinceEpoch,
      reason: 'the version is the resolved portrait mtime',
    );

    // Move the file's mtime WITHOUT telling the facade. A memoized version must
    // not notice — that is the proof the stat was skipped this time round.
    portrait.setLastModifiedSync(DateTime(2026, 6, 1));
    expect(
      await versionOf(),
      first,
      reason: 'a second /api/characters re-stat every portrait — this is the '
          'per-keystroke synchronous filesystem work on the UI isolate',
    );

    // The web server calls this on every library change, so a real portrait
    // swap still produces a new URL and busts the browser cache.
    facade.invalidateAvatarVersions();
    expect(await versionOf(), DateTime(2026, 6, 1).millisecondsSinceEpoch);
  });

  test('a character with no portrait on disk reports version 0', () async {
    await db.insertCharacter(
      CharactersCompanion(
        id: const Value('c2'),
        name: const Value('Bob'),
        imagePath: const Value('missing.png'),
      ),
    );
    final rows = await facade.list();
    final bob = rows.firstWhere((r) => r['name'] == 'Bob');
    expect(bob['avatarVersion'], 0);
  });
}
