// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: the web/mobile companion server actually LAUNCHES inside the real
// app and serves real HTTP. The facade layer has thorough unit tests
// (test/services/web/), but nothing ever proved the journey: WebServerHost
// starting against the live service graph, binding a port, serving the
// built PWA bundle from assets, enforcing auth on the API, and completing
// the setup→login→authenticated-request loop over a genuine socket. The
// "web server on = app vanishes" SIGPIPE class and the closed-DB-handle
// class both lived on this seam.
//
// Run it with:
//   flutter test integration_test/web_server_test.dart -d macos
//
// Isolation contract: identical to app_smoke_test.dart — see its header.
// The server binds an EPHEMERAL port (0) on loopback only: LAN exposure
// stays off, nothing touches Tailscale (autoRemote off skips the probe),
// and nothing collides with a real Front Porch AI on 8080.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:front_porch_ai/main.dart' as app;
import 'package:front_porch_ai/services/web/web_server_host.dart';
import 'package:front_porch_ai/ui/layout/main_layout.dart';

import 'support/e2e_sandbox.dart';
import 'support/fake_backend.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web server launches, serves the PWA, gates the API, and '
      'completes setup→login→state — sandboxed', (tester) async {
    try {
      final probe = await Socket.connect(
        InternetAddress.loopbackIPv4,
        5001,
        timeout: const Duration(milliseconds: 500),
      );
      probe.destroy();
      fail(
        'Something is listening on 127.0.0.1:5001 (a real KoboldCpp?). '
        'Close it before running the E2E suite.',
      );
    } on SocketException {
      // Nothing there — safe to proceed.
    }

    final sandbox = Directory.systemTemp.createTempSync('fpai_web_');
    PathProviderPlatform.instance = SandboxPathProvider(sandbox.path);
    final backend = await FakeBackendServer.start(
      replyPieces: const ['web server suite is not chatting'],
    );
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'import_llmerta_porch_memories': false,
      'backend_type': 'openRouter',
      'remote_api_url': '${backend.baseUrl}/v1',
      'remote_model_name': 'smoke-model',
      // The server is started EXPLICITLY below on an ephemeral port; the
      // app's own auto-start (gated on web_server_enabled, default off) is
      // pinned off so the run owns exactly one server.
      'web_server_enabled': false,
    });

    // ── Boot ────────────────────────────────────────────────────────────
    app.main(const []);
    await pumpUntilFound(tester, find.byType(MainLayout));
    try {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSize(const Size(1200, 800));
      await windowManager.setAlignment(Alignment.bottomRight);
      await windowManager.blur();
    } catch (e) {
      debugPrint('[e2e] window_manager placement skipped: $e');
    }
    await tester.pump(const Duration(seconds: 2));

    final ctx = tester.element(find.byType(MainLayout));
    final host = Provider.of<WebServerHost>(ctx, listen: false);

    // ── Launch on an ephemeral loopback port ────────────────────────────
    await host.start(0);
    await pumpUntilTrue(
      tester,
      () => host.isRunning,
      describe: () => 'the web server to report running',
    );
    final port = host.port;
    expect(port, greaterThan(0), reason: 'ephemeral bind must yield a port');
    final base = Uri.parse('http://127.0.0.1:$port');
    final http = HttpClient();

    Future<(int, String, HttpHeaders)> get(
      String path, {
      String? cookie,
    }) async {
      final req = await http.getUrl(base.replace(path: path));
      if (cookie != null) req.headers.set(HttpHeaders.cookieHeader, cookie);
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      return (res.statusCode, body, res.headers);
    }

    Future<(int, String, HttpHeaders)> post(
      String path,
      Map<String, Object?> jsonBody,
    ) async {
      final req = await http.postUrl(base.replace(path: path));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(jsonBody));
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      return (res.statusCode, body, res.headers);
    }

    // ── Health + PWA shell ──────────────────────────────────────────────
    final (healthCode, healthBody, _) = await get('/api/health');
    expect(healthCode, 200, reason: 'GET /api/health body: $healthBody');

    final (shellCode, shellBody, _) = await get('/');
    expect(shellCode, 200);
    expect(
      shellBody.toLowerCase(),
      contains('<html'),
      reason:
          'GET / must serve the built PWA shell from assets/web_app — an '
          'empty or JSON body means the bundle is missing from the build',
    );

    // ── Auth gate: the API refuses anonymous state reads ────────────────
    final (anonCode, anonBody, _) = await get('/api/chat/state');
    expect(
      anonCode,
      401,
      reason:
          'GET /api/chat/state without a session must be rejected '
          '(got $anonCode: $anonBody)',
    );

    // ── Setup → cookie → authenticated state ────────────────────────────
    final (setupCode, setupBody, setupHeaders) = await post('/api/auth/setup', {
      'username': 'porchtester',
      'password': 'porch-password-123',
    });
    expect(setupCode, 200, reason: 'POST /api/auth/setup body: $setupBody');
    final setCookie = setupHeaders[HttpHeaders.setCookieHeader]?.join('; ');
    expect(
      setCookie,
      isNotNull,
      reason: 'a successful setup must issue a session cookie',
    );
    // Send back just the name=value pair of the session cookie.
    final cookiePair = setCookie!.split(';').first;

    final (stateCode, stateBody, _) = await get(
      '/api/chat/state',
      cookie: cookiePair,
    );
    expect(
      stateCode,
      200,
      reason: 'authenticated GET /api/chat/state body: $stateBody',
    );
    expect(
      () => jsonDecode(stateBody),
      returnsNormally,
      reason: 'chat state must be JSON',
    );

    // ── Clean stop ──────────────────────────────────────────────────────
    await host.stop();
    await pumpUntilTrue(
      tester,
      () => !host.isRunning,
      describe: () => 'the web server to stop',
    );

    http.close(force: true);
    await tester.pump(const Duration(seconds: 1));
    await backend.close();
    try {
      sandbox.deleteSync(recursive: true);
    } on FileSystemException {
      // A straggler may still be writing; not a failure.
    }
  });
}
