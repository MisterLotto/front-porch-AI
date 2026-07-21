import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:front_porch_ai/database/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      });

  SharedPreferences.setMockInitialValues({});

  group('Database — theme_overrides column', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting();
      await db.ensureSchemaIsRepaired();
    });

    tearDown(() async {
      await db.close();
    });

    test('defaults to null when session has no theme override', () async {
      final sessionId = 'theme-null-${DateTime.now().millisecondsSinceEpoch}';
      await db.insertSession(SessionsCompanion.insert(id: sessionId));

      final result = await db.getThemeOverrides(sessionId);
      expect(result, equals(null));
    });

    test('round-trips theme_overrides JSON', () async {
      final sessionId = 'theme-rt-${DateTime.now().millisecondsSinceEpoch}';
      await db.insertSession(SessionsCompanion.insert(id: sessionId));

      const themeJson = '{"themeId":"ocean","fontFamily":"serif"}';
      await db.setThemeOverrides(sessionId, themeJson);

      final result = await db.getThemeOverrides(sessionId);
      expect(result, themeJson);
    });

    test('can update existing theme_overrides', () async {
      final sessionId = 'theme-upd-${DateTime.now().millisecondsSinceEpoch}';
      await db.insertSession(SessionsCompanion.insert(id: sessionId));

      await db.setThemeOverrides(sessionId, '{"themeId":"ocean"}');
      await db.setThemeOverrides(
        sessionId,
        '{"themeId":"forest","userBubbleColor":"#1a1a2e"}',
      );

      final result = await db.getThemeOverrides(sessionId);
      final parsed = jsonDecode(result!) as Map<String, dynamic>;
      expect(parsed['themeId'], 'forest');
      expect(parsed['userBubbleColor'], '#1a1a2e');
    });

    test('can clear theme_overrides by setting to null', () async {
      final sessionId = 'theme-clr-${DateTime.now().millisecondsSinceEpoch}';
      await db.insertSession(SessionsCompanion.insert(id: sessionId));

      await db.setThemeOverrides(sessionId, '{"themeId":"ocean"}');
      await db.setThemeOverrides(sessionId, null);

      final result = await db.getThemeOverrides(sessionId);
      expect(result, equals(null));
    });

    test('retrieves last theme from previous sessions', () async {
      final base = 'theme-last-${DateTime.now().millisecondsSinceEpoch}';
      final charId = 'char-for-last-theme';

      final oldSessionId = '$base-old';
      await db.insertSession(
        SessionsCompanion.insert(
          id: oldSessionId,
          characterId: Value<String?>(charId),
        ),
      );
      await db.setThemeOverrides(oldSessionId, '{"themeId":"ocean"}');

      final newSessionId = '$base-new';
      await db.insertSession(
        SessionsCompanion.insert(
          id: newSessionId,
          characterId: Value<String?>(charId),
        ),
      );

      final inherited =
          await db.getLastSessionThemeOverrides(characterId: charId);
      expect(inherited, '{"themeId":"ocean"}');
    });
  });
}
