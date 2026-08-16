// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// POST /api/auth/setup is the one state-changing endpoint that runs with no
// session AND no setup token (a loopback peer is trusted as "the user at the
// keyboard"). But the victim's own browser IS a loopback peer no matter which
// site told it to send the request, so without an Origin/Sec-Fetch-Site check
// any page open while setup is pending could claim the web account with
// credentials of the attacker's choosing — and on a LAN/Tailscale bind that
// account reaches the whole library.
//
// These pins drive the REAL WebAuthRoutes handler over a shelf Router with a
// loopback connection info in the request context (exactly what shelf_io
// supplies in production), so the token-free branch is genuinely open.

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
import 'package:front_porch_ai/services/web/routes/auth_routes.dart';
import 'package:front_porch_ai/services/web/web_server_deps.dart';

/// The loopback peer shelf_io puts in `request.context` for a browser running
/// on the host machine — the state this endpoint deliberately trusts.
class _LoopbackConnectionInfo implements HttpConnectionInfo {
  @override
  int get localPort => 8085;
  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;
  @override
  int get remotePort => 54321;
}

void _mockPathProvider() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_test_').path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _mockPathProvider();
  SharedPreferences.setMockInitialValues({});

  late AppDatabase db;
  late AuthService auth;
  late Router router;

  setUp(() {
    db = AppDatabase.forTesting();
    auth = AuthService(db);
    router = Router();
    WebAuthRoutes(
      WebServerDeps(storage: StorageService(), db: db, auth: auth),
      router,
    );
  });

  tearDown(() => db.close());

  Future<shelf.Response> setup({Map<String, String> headers = const {}}) {
    return router.call(
      shelf.Request(
        'POST',
        Uri.parse('http://localhost:8085/api/auth/setup'),
        headers: headers,
        body: jsonEncode({'username': 'claimed', 'password': 'attacker1'}),
        context: {'shelf.io.connection_info': _LoopbackConnectionInfo()},
      ),
    );
  }

  test('a cross-site POST from the host browser cannot claim the account',
      () async {
    final res = await setup(
      headers: {
        'origin': 'https://evil.example',
        'sec-fetch-site': 'cross-site',
        'content-type': 'text/plain',
      },
    );

    expect(res.statusCode, 403);
    expect(
      await auth.isSetupRequired(),
      isTrue,
      reason: 'the refused request must not have created the account',
    );
  });

  test('an old browser with no Sec-Fetch-Site is judged by Origin', () async {
    final res = await setup(headers: {'origin': 'https://evil.example'});

    expect(res.statusCode, 403);
    expect(await auth.isSetupRequired(), isTrue);
  });

  test('the real first-run page (same-origin) still completes setup', () async {
    final res = await setup(
      headers: {
        'origin': 'http://localhost:8085',
        'sec-fetch-site': 'same-origin',
        'content-type': 'application/json',
      },
    );

    expect(res.statusCode, 200);
    expect(res.headers['set-cookie'], isNotNull);
    expect(await auth.isSetupRequired(), isFalse);
  });

  test('the Vite dev proxy (browser same-origin, rewritten Host) still works',
      () async {
    // changeOrigin rewrites Host to localhost:8085 but forwards the browser's
    // original Origin — which on a phone over Tailscale is a .ts.net host.
    final res = await setup(
      headers: {
        'origin': 'http://my-mac.ts.net:5173',
        'sec-fetch-site': 'same-origin',
      },
    );

    expect(res.statusCode, 200);
    expect(await auth.isSetupRequired(), isFalse);
  });

  test('a header-less client (curl, the desktop app, tests) is unaffected',
      () async {
    final res = await setup();

    expect(res.statusCode, 200);
    expect(await auth.isSetupRequired(), isFalse);
  });
}
