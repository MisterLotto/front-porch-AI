// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Credentialed CORS / WS must only reflect known Vite loopback ports.
// A page on an arbitrary localhost port must not ride the session cookie.

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'package:front_porch_ai/services/web/middleware/cors_middleware.dart';
import 'package:front_porch_ai/services/web/util/util.dart';

void main() {
  group('isAllowedViteDevOrigin', () {
    test('allows Vite 5173 / 5174 / preview 4173 on loopback', () {
      expect(isAllowedViteDevOrigin('http://localhost:5173'), isTrue);
      expect(isAllowedViteDevOrigin('http://127.0.0.1:5174'), isTrue);
      expect(isAllowedViteDevOrigin('https://localhost:4173'), isTrue);
    });

    test('refuses an arbitrary localhost port', () {
      expect(isAllowedViteDevOrigin('http://localhost:9999'), isFalse);
      expect(isAllowedViteDevOrigin('http://127.0.0.1:8085'), isFalse);
      expect(isAllowedViteDevOrigin('http://localhost'), isFalse);
    });
  });

  group('CorsMiddleware', () {
    late shelf.Handler handler;

    setUp(() {
      handler = const CorsMiddleware().middleware(
        (request) async => shelf.Response.ok('ok'),
      );
    });

    Future<shelf.Response> get(String origin) async => handler(
      shelf.Request(
        'GET',
        Uri.parse('http://127.0.0.1:8085/api/x'),
        headers: {'origin': origin},
      ),
    );

    test('reflects Vite origin with credentials', () async {
      final res = await get('http://localhost:5173');
      expect(
        res.headers['access-control-allow-origin'],
        'http://localhost:5173',
      );
      expect(res.headers['access-control-allow-credentials'], 'true');
    });

    test('does not reflect a random localhost origin', () async {
      final res = await get('http://localhost:9999');
      expect(res.headers['access-control-allow-origin'], isNull);
      expect(res.headers['access-control-allow-credentials'], isNull);
    });
  });

  group('wsOriginAllowed', () {
    shelf.Request req() =>
        shelf.Request('GET', Uri.parse('http://host.ts.net:8085/api/ws'));

    test('same-origin host+port is allowed', () {
      expect(wsOriginAllowed(req(), 'http://host.ts.net:8085'), isTrue);
    });

    test('same host on another port is refused', () {
      expect(wsOriginAllowed(req(), 'http://host.ts.net:9999'), isFalse);
    });

    test('Vite loopback is allowed', () {
      expect(wsOriginAllowed(req(), 'http://localhost:5173'), isTrue);
    });

    test('arbitrary localhost port is refused', () {
      expect(wsOriginAllowed(req(), 'http://localhost:9999'), isFalse);
    });
  });
}
