// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Web fork: the route requires an index; ChatSessionFacade.fork is a no-op
// (null, no broadcast) when ChatService has no open session.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';
import 'package:front_porch_ai/services/web/facade/chat_facade.dart';
import 'package:front_porch_ai/services/web/facade/chat_session_facade.dart';
import 'package:front_porch_ai/services/web/routes/chat_routes.dart';
import 'package:front_porch_ai/services/world_repository.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_fork_').path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  test('POST /api/chat/fork without index is 400', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final storage = StorageService();
    final chat = ChatService(
      KoboldService(storage),
      UserPersonaService(db),
      storage,
      WorldRepository(storage, db),
    )..setDatabase(db);
    addTearDown(chat.dispose);
    final router = Router();
    WebChatRoutes(
      ChatFacade(chat, CharacterRepository(db, storage), null, null, null),
      router,
    );
    final res = await router.call(
      shelf.Request(
        'POST',
        Uri.parse('http://localhost/api/chat/fork'),
        headers: {'content-type': 'application/json'},
        body: '{}',
      ),
    );
    expect(res.statusCode, 400);
    expect(jsonDecode(await res.readAsString()), {
      'error': 'index is required',
    });
  });

  test('fork with no open session returns null and does not notify', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final storage = StorageService();
    final chat = ChatService(
      KoboldService(storage),
      UserPersonaService(db),
      storage,
      WorldRepository(storage, db),
    )..setDatabase(db);
    addTearDown(chat.dispose);
    var notified = 0;
    final facade = ChatSessionFacade(
      chat,
      CharacterRepository(db, storage),
      () => notified++,
    );
    expect(await facade.fork(0), isNull);
    expect(notified, 0);
  });
}
