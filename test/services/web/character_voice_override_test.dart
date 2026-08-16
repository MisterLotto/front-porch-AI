// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// The per-character TTS voice override, end to end through the web facade
// (2026-08-14). A character's own voice beats the global Settings voice —
// that is by design, but until now it could arrive from an imported card's
// `tts_voice` and there was NO way to see or clear it, which is the residual
// half of the Discord "I picked Adam and she still sounds female" report.
//
// What must hold: the override round-trips, an explicit EMPTY value clears
// it back to null (= follow the global voice), and a partial edit that never
// mentions the key leaves it alone.
//
// Red-proven: with the `fields.containsKey('ttsVoice')` block removed from
// CharacterFacade.update, 'an explicit empty value clears the override' fails
// (the voice stays assigned — exactly the unclearable state users were in).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/services/web/facade/character_facade.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_voice_').path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  late AppDatabase db;
  late CharacterFacade chars;
  late String id;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting();
    await db.select(db.characters).get();
    final storage = StorageService();
    await storage.setRootPath(
      Directory.systemTemp.createTempSync('fpai_root_').path,
    );
    chars = CharacterFacade(
      db,
      storage,
      null,
      null,
      CharacterRepository(db, storage),
    );
    final created = await chars.create({'name': 'Vox'});
    id = created!['id'] as String;
  });

  tearDown(() => db.close());

  test('a character with no voice follows the global one (null, not empty)',
      () async {
    final detail = await chars.detail(id);
    expect(detail!['ttsVoice'], isNull);
  });

  test('assigning a voice round-trips through detail', () async {
    expect(await chars.update(id, {'ttsVoice': 'am_adam'}), isTrue);
    final detail = await chars.detail(id);
    expect(detail!['ttsVoice'], 'am_adam');
  });

  test('an explicit empty value clears the override back to the global voice',
      () async {
    await chars.update(id, {'ttsVoice': 'af_heart'});
    expect((await chars.detail(id))!['ttsVoice'], 'af_heart');

    expect(await chars.update(id, {'ttsVoice': ''}), isTrue);
    expect(
      (await chars.detail(id))!['ttsVoice'],
      isNull,
      reason: 'clearing must store null so the character follows the global '
          'voice — an unclearable override is the reported bug',
    );
  });

  test('whitespace counts as clearing, not as a voice id', () async {
    await chars.update(id, {'ttsVoice': 'am_adam'});
    await chars.update(id, {'ttsVoice': '   '});
    expect((await chars.detail(id))!['ttsVoice'], isNull);
  });

  test('a partial edit that omits the key leaves the voice untouched',
      () async {
    await chars.update(id, {'ttsVoice': 'bm_george'});
    expect(await chars.update(id, {'description': 'edited elsewhere'}), isTrue);
    final detail = await chars.detail(id);
    expect(detail!['ttsVoice'], 'bm_george');
    expect(detail['description'], 'edited elsewhere');
  });
}
