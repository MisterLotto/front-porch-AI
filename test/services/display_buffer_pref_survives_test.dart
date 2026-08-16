// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// "SMOOTH OUTPUT BUFFER" MUST SURVIVE A RESTART (1.3 sweep, 2026-08-15).
//
// df57bb0d turned the token throttle off for everyone by REMOVING the pref in
// UiSettings.load() — but unconditionally, on every launch, so the Settings
// switch wrote a value the very next startup deleted. The reset is now
// one-time (display_buffer_reset_done latch): a legacy 'true' is cleared
// exactly once, and a value the user sets after that sticks.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // StorageService.init resolves (and probes) the documents dir; without the
  // platform-channel mock the init completer never resolves in a test.
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_docs_').path;
        }
        return null;
      });

  test('a legacy pre-reset "true" is cleared exactly once', () async {
    SharedPreferences.setMockInitialValues({
      'display_buffer_enabled': true, // pre-df57bb0d leftover
    });
    final storage = StorageService();
    await storage.initialized;
    expect(storage.uiSettings.displayBufferEnabled, isFalse,
        reason: 'the one-time reset must still fire for legacy users');
  });

  test('a value the user sets AFTER the reset survives the next load',
      () async {
    SharedPreferences.setMockInitialValues({});
    final first = StorageService();
    await first.initialized;
    await first.uiSettings.setDisplayBufferEnabled(true);

    // "Restart": a fresh service over the same prefs store.
    final second = StorageService();
    await second.initialized;
    expect(second.uiSettings.displayBufferEnabled, isTrue,
        reason: 'load() used to delete the pref on every launch, so the '
            'Settings switch could never survive a restart');
  });
}
