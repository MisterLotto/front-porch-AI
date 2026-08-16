// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// duplicateCharacter's newNameOverride (added for AI Enhance's
// "<Name> (Enhanced)" copies): the override names both the card and its PNG,
// and the DEFAULT path still says "(duplicate)" byte-for-byte — the pin that
// keeps the home-screen Duplicate action untouched.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          final tmp = Directory.systemTemp.createTempSync('fpai_test_');
          return tmp.path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUp(() async {
    _setupPathProviderMock();
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.initialized;
    db = AppDatabase.forTesting();
    repo = CharacterRepository(db, storage);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await db.close();
  });

  Future<CharacterCard> seed(String name) async {
    final card = CharacterCard(name: name, description: 'desc');
    final tmpDir = Directory.systemTemp.createTempSync('dup_name_test_');
    final pngPath = '${tmpDir.path}/$name.png';
    await V2CardService().saveCardAsPng(card, pngPath, null);
    card.imagePath = pngPath;
    await repo.addCharacter(card);
    return card;
  }

  test('newNameOverride names the card AND its PNG file', () async {
    final card = await seed('Nina');
    final copy = await repo.duplicateCharacter(
      card,
      newNameOverride: 'Nina (Enhanced)',
    );
    expect(copy, isNotNull);
    expect(copy!.name, 'Nina (Enhanced)');
    expect(p.basename(copy.imagePath!), startsWith('Nina_Enhanced_'));
    expect(File(copy.imagePath!).existsSync(), isTrue);
  });

  test('default (no override) still says "(duplicate)" byte-for-byte',
      () async {
    final card = await seed('Nina');
    final copy = await repo.duplicateCharacter(card);
    expect(copy!.name, 'Nina (duplicate)');
  });
}
