// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// POST /api/remote/tailscale/login must demand the same password/TOTP
// step-up as enable-serve. A stolen session cookie must not bind this
// machine to an attacker's tailnet (audit P1.6).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/web/auth/auth_service.dart';
import 'package:front_porch_ai/services/web/routes/remote_routes.dart';
import 'package:front_porch_ai/services/web/tunnels/tunnels.dart';
import 'package:front_porch_ai/services/web/web_server_deps.dart';

void _mockPathProvider() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_tslogin_').path;
        }
        return null;
      });
}

class _FakeTailscale extends TailscaleProvider {
  _FakeTailscale() : super(executable: '/nonexistent-tailscale');

  int loginCalls = 0;

  @override
  Future<String?> login() async {
    loginCalls++;
    return 'https://login.tailscale.com/a/test';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _mockPathProvider();
  SharedPreferences.setMockInitialValues({});

  late AppDatabase db;
  late AuthService auth;
  late StorageService storage;
  late Router router;
  late _FakeTailscale ts;

  setUp(() async {
    db = AppDatabase.forTesting();
    auth = AuthService(db);
    storage = StorageService();
    await storage.initialized;
    ts = _FakeTailscale();
    router = Router();
    WebRemoteRoutes(
      WebServerDeps(storage: storage, db: db, auth: auth),
      TunnelManager(8080, tailscale: ts),
      router,
    );
    expect(
      await auth.setupAccount(
        'admin',
        'password123',
        isDirectLoopbackClient: true,
      ),
      SetupStatus.success,
    );
  });

  tearDown(() => db.close());

  Future<shelf.Response> post(Map<String, dynamic> body) {
    return router.call(
      shelf.Request(
        'POST',
        Uri.parse('http://localhost/api/remote/tailscale/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
  }

  test(
    'login without a password is refused and never starts Tailscale',
    () async {
      final res = await post({});
      expect(res.statusCode, 401);
      expect(
        jsonDecode(await res.readAsString())['error'],
        'Current password is incorrect',
      );
      expect(ts.loginCalls, 0);
    },
  );

  test('login proceeds after password step-up', () async {
    final res = await post({'currentPassword': 'password123'});
    expect(res.statusCode, 200);
    expect(
      jsonDecode(await res.readAsString())['url'],
      'https://login.tailscale.com/a/test',
    );
    expect(ts.loginCalls, 1);
  });
}
