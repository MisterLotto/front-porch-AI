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

// ONE KEYSTROKE USED TO COST ~70 PREFERENCE WRITES.
//
// `CreatorHintField.onChanged` called `CreatorState.saveState()` directly, and
// saveState persists EVERY field in the wizard — ~70 sequential
// `prefs.set*` calls. On Windows and Linux the shared_preferences store
// re-encodes the whole preference map and does a SYNCHRONOUS whole-file write
// per setter, so typing a sentence was thousands of blocking file writes on
// the UI thread. (Invisible on macOS, which routes to NSUserDefaults — the
// same platform-asymmetric cost class as the `coverImageFileFor` regression.)
//
// The field now debounces the save and flushes any pending one on dispose, so
// nothing typed is ever lost. `notify()` deliberately stays immediate: the
// Generate button's enabled state rides on it.
//
// Proven to fail first: putting `state.saveState()` back in `onChanged` reds
// the "does not save on every keystroke" expectation below.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/character_creator/creator_state.dart';
import 'package:front_porch_ai/ui/character_creator/widgets/creator_hint_field.dart';

/// Counts persists instead of performing them — the real `saveState()` needs
/// a SharedPreferences binding and would hide the call count behind async I/O.
class _CountingCreatorState extends CreatorState {
  int saves = 0;
  int notifies = 0;

  @override
  Future<void> saveState() async {
    saves++;
  }

  @override
  void notify() {
    notifies++;
    super.notify();
  }
}

void main() {
  Future<void> pumpField(
    WidgetTester tester,
    _CountingCreatorState state,
    TextEditingController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreatorHintField(
            state: state,
            controller: controller,
            hint: 'Describe them',
          ),
        ),
      ),
    );
  }

  testWidgets(
    'typing does not persist the whole wizard on every keystroke, and one '
    'debounced save lands after the user stops',
    (tester) async {
      final state = _CountingCreatorState();
      addTearDown(state.dispose);
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, state, controller);

      for (final text in ['a', 'ab', 'abc', 'abcd', 'abcde']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 40));
      }

      expect(
        state.saves,
        0,
        reason: 'no whole-wizard persist may run while the user is still typing',
      );
      expect(
        state.notifies,
        5,
        reason: 'notify() must stay immediate — the Generate button reacts to it',
      );

      await tester.pump(const Duration(milliseconds: 600));

      expect(
        state.saves,
        1,
        reason: 'exactly one save should land once typing settles',
      );
    },
  );

  testWidgets(
    'a pending save is flushed when the field goes away, so the last '
    'keystrokes are never the ones dropped',
    (tester) async {
      final state = _CountingCreatorState();
      addTearDown(state.dispose);
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, state, controller);
      await tester.enterText(find.byType(TextField), 'open a bakery');
      expect(state.saves, 0);

      // The user hits Back / the wizard moves to the next step.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      expect(
        state.saves,
        1,
        reason: 'the debounced save must be flushed on dispose, not cancelled',
      );

      // And the flushed timer must not fire a second time afterwards.
      await tester.pump(const Duration(milliseconds: 600));
      expect(state.saves, 1);
    },
  );
}
