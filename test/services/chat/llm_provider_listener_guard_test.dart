// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

// RE-WIRING THE SAME PAIR MUST NOT STACK LISTENERS.
//
// setLLMProvider is called from a ProxyProvider `update`, which re-runs on
// EVERY notification from any of its dependencies — and KoboldService notifies
// per stdout line while the managed backend generates. ChangeNotifier keeps
// duplicate registrations, so an unguarded addListener appended one callback
// per frame, forever: unbounded growth plus O(N) dispatch on a notifier that
// fires per token. Dispose removed exactly one of them.
//
// The call site carries its own re-entry guard (main.providers.dart), but the
// setter has to be safe on its own — the next call site is the leak's next
// chance. Its sibling setCharacterRepository has always done it correctly.
//
// Proven to fail: drop the identical()/removeListener lines from
// setLLMProvider in chat_service_accessors.dart and the counts go 5 / 4.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/services.dart';

/// Counts what the OUTSIDE world registers on this provider (LLMProvider adds
/// its own listeners to other services, never to itself).
class _CountingLlmProvider extends LLMProvider {
  _CountingLlmProvider(super.kobold, super.openRouter, super.storage, super.backend);

  int registered = 0;

  @override
  void addListener(VoidCallback listener) {
    registered++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    registered--;
    super.removeListener(listener);
  }

  /// ChangeNotifier.hasListeners is @protected. Surfaced here because counting
  /// calls only proves removeListener was CALLED — this proves the removal
  /// actually matched. It is not a formality: the callback is an EXTENSION
  /// method tear-off (`_onBackendIdentityMaybeChanged` lives in
  /// ChatServiceAccessors), and if those were not canonicalized the way plain
  /// instance tear-offs are, every removeListener in this service would be a
  /// silent no-op and the leak would survive the fix.
  bool get anyListeners => hasListeners;
}

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_llmlisten_').path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  test('setLLMProvider is idempotent, and swapping providers unhooks the old one',
      () async {
    SharedPreferences.setMockInitialValues({'update_auto_check': false});
    final db = AppDatabase.forTesting();
    final storage = StorageService();
    await storage.initialized;
    final kobold = KoboldService(storage);
    final backend = BackendManager(storage);

    final first = _CountingLlmProvider(
      kobold,
      OpenRouterService(),
      storage,
      backend,
    );
    final second = _CountingLlmProvider(
      kobold,
      OpenRouterService(),
      storage,
      backend,
    );

    final chat = ChatService(
      kobold,
      UserPersonaService(db),
      storage,
      WorldRepository(storage, db),
    )..setDatabase(db);

    for (var i = 0; i < 5; i++) {
      chat.setLLMProvider(first);
    }
    expect(
      first.registered,
      1,
      reason:
          'THE BUG: five ProxyProvider updates meant five copies of the same '
          'callback, and every Kobold log line then dispatched all of them',
    );

    chat.setLLMProvider(second);
    expect(
      first.registered,
      0,
      reason: 'the old provider must be unhooked, like setCharacterRepository',
    );
    expect(
      first.anyListeners,
      isFalse,
      reason: 'the removal must MATCH — not just be attempted',
    );
    expect(second.registered, 1);

    chat.dispose();
    expect(
      second.registered,
      0,
      reason: 'dispose removes the single registration it left behind',
    );
    expect(second.anyListeners, isFalse);

    first.dispose();
    second.dispose();
    // `backend` is deliberately NOT disposed: its constructor kicks an
    // unawaited checkBackendAvailability() that notifies whenever the real
    // filesystem probe finishes, and disposing first turns that into a
    // "used after being disposed" failure that has nothing to do with
    // listener identity.
    await db.close();
  });
}
