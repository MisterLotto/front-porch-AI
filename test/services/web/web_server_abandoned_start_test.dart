// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// `startSafely` time-boxes start() with `Future.timeout` — which does NOT
// cancel the awaited work, it only completes the caller's future early. So a
// start that was abandoned (timed out, or stopped while it was still binding)
// used to go on and publish a LIVE socket afterwards, long after the caller had
// persisted "web server disabled" and told the user it failed. The compensating
// `stop()` in startSafely's catch could not help: it returns early while
// `_server` is still null, so it tore down nothing and the app ended up
// listening with the UI insisting it was off.
//
// These tests reproduce the abandonment deterministically by calling stop()
// while start() is in flight (start runs synchronously up to its first await,
// so the stop lands strictly before the bind), then proving the port is free.

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
          return Directory.systemTemp.createTempSync('fpai_webabandon_').path;
        }
        return null;
      });
}

/// A port nobody is on: bind ephemerally, note the number, release it.
Future<int> _freePort() async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();
  return port;
}

/// Whether [port] can be bound — i.e. the host really did not leave a socket.
Future<bool> _portIsFree(int port) async {
  try {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await s.close();
    return true;
  } on SocketException {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues(const {});
    _setupPathProviderMock();
  });

  test('a start abandoned mid-bind never publishes its socket', () async {
    final db = AppDatabase.forTesting();
    final storage = StorageService();
    await storage.initialized;
    final host = WebServerHost(storage)..setDatabase(db);
    addTearDown(() async {
      await host.stop();
      await db.close();
    });

    final port = await _freePort();

    // Start, then abandon it before it can bind — the shape of both the
    // startSafely timeout and a user toggling off during a slow start.
    final inFlight = host.start(port);
    await host.stop();
    await inFlight;

    expect(
      host.isRunning,
      isFalse,
      reason: 'the host must agree with what the caller was told: not running',
    );
    expect(
      await _portIsFree(port),
      isTrue,
      reason: 'an abandoned start left the app listening on $port with the UI '
          'reporting the web server as off',
    );
  });

  test('a normal start still binds and stop still releases the port', () async {
    final db = AppDatabase.forTesting();
    final storage = StorageService();
    await storage.initialized;
    final host = WebServerHost(storage)..setDatabase(db);
    addTearDown(() async {
      await host.stop();
      await db.close();
    });

    final port = await _freePort();
    await host.start(port);

    expect(host.isRunning, isTrue);
    expect(host.port, port);
    expect(
      await _portIsFree(port),
      isFalse,
      reason: 'the generation guard must not stop an ordinary start binding',
    );

    await host.stop();
    expect(host.isRunning, isFalse);
    expect(await _portIsFree(port), isTrue);
  });
}
