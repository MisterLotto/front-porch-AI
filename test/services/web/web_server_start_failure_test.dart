// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards the web-server start FAILURE path — the one the E2E launch suite
// deliberately never exercises (it binds an ephemeral port on a clean
// loopback, so it can never collide). Prod reports ("Web server failed to
// start and was turned off", with no reason shown) proved the failure path
// was flying blind: startSafely swallowed the exception and release builds
// have no visible logs. These tests pin down (a) the classified, actionable
// messages and (b) that a real port conflict surfaces through
// WebServerHost.lastStartError instead of vanishing.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/services/web/web_server_host.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_webstart_test_').path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('describeStartFailure', () {
    test('classifies EADDRINUSE on all three platforms', () {
      for (final code in [48, 98, 10048]) {
        final msg = WebServerHost.describeStartFailure(
          SocketException(
            'bind failed',
            osError: OSError('Address already in use', code),
          ),
          8085,
        );
        expect(msg, contains('already in use'), reason: 'errno $code');
        expect(msg, contains('8085'));
        expect(msg, contains('second running copy'));
      }
    });

    test('classifies access-denied (Windows reserved port ranges)', () {
      final msg = WebServerHost.describeStartFailure(
        SocketException(
          'bind failed',
          osError: OSError('An attempt was made to access a socket in a way '
              'forbidden by its access permissions', 10013),
        ),
        8085,
      );
      expect(msg, contains('refused access'));
      expect(msg, contains('8085'));
    });

    test('classifies the 25s time-box distinctly', () {
      final msg = WebServerHost.describeStartFailure(
        TimeoutException('start', const Duration(seconds: 25)),
        8085,
      );
      expect(msg.toLowerCase(), contains('timed out'));
    });

    test('falls back to the raw error for everything else', () {
      final msg = WebServerHost.describeStartFailure(
        StateError('WebServerHost.start() called before setDatabase()'),
        8085,
      );
      expect(msg, contains('setDatabase'));
    });
  });

  group('startSafely on a real port conflict', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
      _setupPathProviderMock();
    });

    test('returns false, disables the server, and surfaces the reason',
        () async {
      // Camp an ephemeral loopback port so the host's bind must collide.
      final squatter = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final db = AppDatabase.forTesting();
      final storage = StorageService();
      final host = WebServerHost(storage);
      host.setDatabase(db);
      addTearDown(() async {
        await host.stop();
        await squatter.close();
        await db.close();
      });

      final ok = await host.startSafely(squatter.port);

      expect(ok, isFalse);
      expect(host.isRunning, isFalse);
      expect(
        storage.webServerSettings.webServerEnabled,
        isFalse,
        reason: 'a failed start must flip the persisted toggle back off '
            'so the app cannot crash-loop on the next launch',
      );
      expect(
        host.lastStartError,
        isNotNull,
        reason: 'the failure reason must survive for the Settings toast',
      );
      expect(host.lastStartError, contains('already in use'));
      expect(host.lastStartError, contains('${squatter.port}'));
    });

    test('a successful start clears lastStartError', () async {
      final db = AppDatabase.forTesting();
      final storage = StorageService();
      final host = WebServerHost(storage);
      host.setDatabase(db);
      addTearDown(() async {
        await host.stop();
        await db.close();
      });

      // Ephemeral port on loopback — same isolation contract as the E2E.
      final ok = await host.startSafely(0);

      expect(ok, isTrue);
      expect(host.isRunning, isTrue);
      expect(host.lastStartError, isNull);
    });
  });
}
