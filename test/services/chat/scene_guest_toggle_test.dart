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

// "Notice new characters" — the switch for Scene Guest cast detection
// (maintainer, 2026-08-08: "we also need a toggle for disabling detection of
// scene guests. Some users find it annoying").
//
// Every few turns the app reads the narration, spots a newly-introduced named
// side character, and offers to bring them in. There was no way to stop it.
// What there WAS: `ChatService.sceneDetectionEnabled`, an in-memory bool,
// default true, that no code ever wrote and no surface ever exposed —
// scaffolding for a setting nobody built. It is deleted here rather than wired
// up beside the real one, because two switches for one behaviour is how the two
// end up disagreeing.
//
// Default TRUE: this is what the app has always done, and the switch exists to
// turn it off, not to make people opt back in to something they already have.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/services/storage/settings/realism_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<RealismSettings> settings() async {
    final s = RealismSettings();
    s.initializeBase(await SharedPreferences.getInstance(), () {});
    s.load();
    return s;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('detection is ON by default', () async {
    final s = await settings();

    expect(
      s.sceneGuestDetectionEnabled,
      isTrue,
      reason: 'this is existing behaviour — a default of false would silently '
          'remove a feature from every install that never asked for that',
    );
  });

  test('turning it off persists', () async {
    final s = await settings();
    await s.setSceneGuestDetectionEnabled(false);

    expect(s.sceneGuestDetectionEnabled, isFalse);

    // And a fresh settings object reads the stored value rather than the
    // default — the whole point of persisting it.
    final reloaded = await settings();
    expect(reloaded.sceneGuestDetectionEnabled, isFalse);
  });

  test('a stored false survives, a missing key means on', () async {
    SharedPreferences.setMockInitialValues({
      'scene_guest_detection_enabled': false,
    });
    expect((await settings()).sceneGuestDetectionEnabled, isFalse);

    SharedPreferences.setMockInitialValues({});
    expect((await settings()).sceneGuestDetectionEnabled, isTrue);
  });

  test('the old in-memory stand-in is gone, not left beside it', () {
    // A source check, because the failure mode is two switches drifting apart
    // rather than either one misbehaving. `ChatService.sceneDetectionEnabled`
    // was a public field with no writer and no UI; if it comes back, the gate
    // has two answers and only one of them is the user's.
    final hub = _read('lib/services/chat_service.dart');
    expect(
      hub,
      isNot(contains('bool sceneDetectionEnabled')),
      reason: 'the dead stand-in must stay deleted — the persisted setting is '
          'the only switch',
    );

    // And the ONE gate reads the setting.
    final flow = _read('lib/services/chat/chat_service_turn_flow.dart');
    expect(
      flow,
      contains('realismSettings.sceneGuestDetectionEnabled'),
      reason: 'the automatic scan must consult the switch, or it is decoration',
    );
  });
}

String _read(String p) => File(p).readAsStringSync();
