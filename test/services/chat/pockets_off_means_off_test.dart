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

// "Off means off" for Pockets & Wardrobe — one gate, in one place.
//
// The rule is the design doc's, in as many words: "With the switch off: no eval
// fires, no injection block is built, and the sidebar panel is absent — not
// greyed, absent."
//
// THE BUG. The gate was written at the CALL SITES. Two of them remembered to
// ask — the injection wiring and the web facade — and the sidebar did not. Its
// comment even claimed it "answers to its own switch"; the code never read one.
// So a chat that had run with Pockets ON kept showing its Wardrobe row after the
// user switched Pockets off: a panel for a disabled feature, and a
// desktop-vs-web split, because the web facade hid it correctly.
//
// It now lives in `pocketsFor`, the ONE read every surface goes through, which
// is what makes "off means off" true by construction instead of by three
// callers each remembering.
//
// Structural, and labelled as such. `pocketsFor` is an instance method on
// ChatService, and no suite anywhere constructs a real one — the fakes next door
// hardcode `pocketsFor` to null, so a widget test built on them would prove the
// fake returns null, not that the gate exists. These assertions are anchored on
// the exact expressions rather than loose substrings so that MOVING the gate
// fails, not just deleting it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  final hub = _read('lib/services/chat_service.dart');

  group('the gate exists, and it is in the one read', () {
    test('pocketsFor returns nothing when the switch is down', () {
      // The body, not just the file: a check anywhere else in chat_service.dart
      // would satisfy a substring match while leaving every reader ungated.
      final start = hub.indexOf('Pockets? pocketsFor(String characterId) {');
      expect(start, greaterThan(-1), reason: 'pocketsFor was renamed or moved');
      final body = hub.substring(start, hub.indexOf('\n  }', start));

      expect(
        body,
        contains('realismSettings.pocketsEnabled'),
        reason: 'without this the record is handed to every surface — sidebar '
            'included — no matter what the user set',
      );
      expect(
        body.indexOf('pocketsEnabled') < body.indexOf('_activeGroup'),
        isTrue,
        reason: 'the switch has to be checked BEFORE either mode returns, or '
            'one of 1:1 and group is gated and the other is not',
      );
    });

    test('the sidebar does not carry a second, private copy of the gate', () {
      // Not style. Two gates drift: the sidebar spent its whole life with a
      // comment saying it answered to the switch and no code that did.
      final sidebar = _read(
        'lib/ui/chat_components/sidebar/character_state/character_state_group.dart',
      );
      expect(sidebar, contains('chat.pocketsFor('));
      expect(
        sidebar.contains('pocketsEnabled'),
        isFalse,
        reason: 'the sidebar must rely on pocketsFor returning null, so there '
            'is exactly one place the feature is switched off for readers',
      );
    });

    test('the injection wiring relies on it too', () {
      expect(
        _read('lib/services/chat/chat_service_wiring_injection.dart'),
        contains('getPockets: pocketsFor'),
        reason: 'it used to re-check the switch itself; that copy is now the '
            'gate in pocketsFor and must not come back',
      );
    });

    test('the web facade relies on it too, so desktop and web agree', () {
      final facade = _read('lib/services/web/facade/chat_tools_facade.dart');
      final start = facade.indexOf("'pockets':");
      expect(start, greaterThan(-1));

      expect(
        facade.substring(start, start + 220).contains('pocketsEnabled'),
        isFalse,
        reason: 'the facade hid the panel correctly while the desktop sidebar '
            'showed it — one gate is what stops the two drifting again',
      );
    });
  });

  group('hiding is not erasing', () {
    // The dangerous way to implement "off means off" is to clear the record.
    // Then switching Pockets off for one scene and back on loses everything she
    // was carrying — worse than the bug being fixed. These pin that the
    // persistence path deliberately does NOT go through the gated read.

    test('the save wire writes the field, not the gated read', () {
      final save = _read('lib/services/chat/chat_service_session_state.dart');
      final start = save.indexOf('pockets: drift.Value(');
      expect(start, greaterThan(-1));

      final expr = save.substring(start, start + 200);
      expect(
        expr,
        contains('_pockets'),
        reason: 'it must read the field directly',
      );
      expect(
        expr.contains('pocketsFor('),
        isFalse,
        reason: 'saving through the gated read would write NULL the moment the '
            'switch went down — turning a feature off would delete her things',
      );
    });

    test('the load wire restores regardless of the switch', () {
      final load = _read('lib/services/chat/chat_service_session_load.dart');
      expect(load, contains('_pockets = (pj is String && pj.isNotEmpty)'));
      expect(
        load.contains('pocketsEnabled ? Pockets.fromJson'),
        isFalse,
        reason: 'a record exists only because the feature was on when it was '
            'written; refusing to load it would strand it permanently',
      );
    });

    test('the swipe/regen rewind writes through the setter, not the read', () {
      expect(
        _read('lib/services/chat/chat_service_speaker_objectives.dart'),
        contains('setPocketsFor('),
        reason: 'restoring a snapshot must put the record back even while the '
            'switch is down, or rolling the timeline back would drop it',
      );
    });
  });

  group('the eval keeps its own gate, and should', () {
    test('the pass still checks the switch itself', () {
      // Deliberately NOT folded into pocketsFor. That gate answers "should a
      // reader see the record"; this one answers "should we spend an LLM call",
      // which is the user's money and a different question with a different
      // blast radius.
      final pockets = _read('lib/services/chat/chat_service_pockets.dart');
      expect(
        pockets,
        contains('if (!_storageService.realismSettings.pocketsEnabled) return;'),
      );
    });

    test('seeding is gated too, so an off switch stores nothing new', () {
      final pockets = _read('lib/services/chat/chat_service_pockets.dart');
      final start = pockets.indexOf('void seedPocketsFromCards() {');
      expect(start, greaterThan(-1));

      expect(
        pockets.substring(start, pockets.indexOf('\n  }', start)),
        contains('pocketsEnabled'),
        reason: 'seeding while off would let the v47 save wire persist a record '
            'for a feature the user never switched on',
      );
    });
  });
}
