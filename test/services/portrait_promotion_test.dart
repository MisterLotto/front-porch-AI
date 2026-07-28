// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/services/portrait_promotion.dart';
import 'package:front_porch_ai/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late StorageService storage;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('fpai_portrait_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return tmp.path;
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.initialized;
  });

  tearDown(() async {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('hasUsablePortrait', () {
    test('false when imagePath is null or empty', () {
      final card = CharacterCard(name: 'NoPath');
      expect(hasUsablePortrait(card, storage), isFalse);
      card.imagePath = '';
      expect(hasUsablePortrait(card, storage), isFalse);
    });

    test('false when the resolved file is missing', () {
      final card = CharacterCard(
        name: 'Missing',
        imagePath: '${storage.charactersDir.path}/ghost.png',
      );
      expect(hasUsablePortrait(card, storage), isFalse);
    });

    test('true when the portrait file exists', () {
      final file = File('${storage.charactersDir.path}/real.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final card = CharacterCard(name: 'Real', imagePath: file.path);
      expect(hasUsablePortrait(card, storage), isTrue);
    });
  });

  group('bootstrapPortraitIfMissing', () {
    test('writes a portrait and updates imagePath when none exists', () async {
      final card = CharacterCard(name: 'Boot Me');
      var updates = 0;
      final wrote = await bootstrapPortraitIfMissing(
        card: card,
        storage: storage,
        bytes: List<int>.filled(64, 7),
        updateCharacter: (c) async {
          updates++;
          expect(c.imagePath, isNotNull);
          expect(File(c.imagePath!).existsSync(), isTrue);
        },
      );
      expect(wrote, isTrue);
      expect(updates, 1);
      expect(hasUsablePortrait(card, storage), isTrue);
    });

    test('is a no-op when a usable portrait already exists', () async {
      final existing = File('${storage.charactersDir.path}/keep.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync([9, 9, 9]);
      final card = CharacterCard(name: 'Keep', imagePath: existing.path);
      var updates = 0;
      final wrote = await bootstrapPortraitIfMissing(
        card: card,
        storage: storage,
        bytes: List<int>.filled(8, 1),
        updateCharacter: (_) async => updates++,
      );
      expect(wrote, isFalse);
      expect(updates, 0);
      expect(card.imagePath, existing.path);
      expect(existing.readAsBytesSync(), [9, 9, 9]);
    });

    test('is a no-op for empty bytes', () async {
      final card = CharacterCard(name: 'Empty');
      final wrote = await bootstrapPortraitIfMissing(
        card: card,
        storage: storage,
        bytes: const [],
        updateCharacter: (_) async => fail('should not update'),
      );
      expect(wrote, isFalse);
      expect(card.imagePath, isNull);
    });
  });
}
