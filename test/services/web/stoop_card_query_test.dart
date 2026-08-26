// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// GET /api/stoop/cards/<id> must forward the query string (type=GROUP|WORLD)
// the way browse already does. A dropped type query is how group/world
// detail came back as a solo blob.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/backporch/backporch_api.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/web/facade/stoop_facade.dart';
import 'package:front_porch_ai/services/web/routes/stoop_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_stoop_q_').path;
        }
        return null;
      });
  SharedPreferences.setMockInitialValues({});
  setUpAll(() => HttpOverrides.global = null);

  test('card GET forwards type=WORLD to upstream', () async {
    String? seenQuery;
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    upstream.listen((req) async {
      seenQuery = req.uri.query;
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('{"id":"c1","type":"WORLD","card":{}}');
      await req.response.close();
    });

    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final router = Router();
    WebStoopRoutes(
      StoopFacade(
        StorageService(),
        db,
        api: BackporchApi(baseUrl: 'http://127.0.0.1:${upstream.port}'),
      ),
      router,
    );

    final res = await router.call(
      shelf.Request(
        'GET',
        Uri.parse('http://localhost/api/stoop/cards/c1?type=WORLD'),
        headers: {'x-stoop-token': 'tok-1'},
      ),
    );
    expect(res.statusCode, 200);
    expect(seenQuery, contains('type=WORLD'));
    expect(jsonDecode(await res.readAsString()), isA<Map>());
  });
}
