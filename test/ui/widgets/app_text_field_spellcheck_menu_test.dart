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

// The spell-check context menu against text that MOVED.
//
// Spell-check results are produced asynchronously and Flutter never
// invalidates them when the text changes, so the suggestion spans a menu is
// built from routinely describe an older, longer string. The menu used to take
// the captured range on faith: it offered corrections for words that were no
// longer there, and applying one ran `String.replaceRange` past the end of the
// live text — a RangeError thrown out of a button press, with the field left
// uncorrected.
//
// These pin the real call site (AppTextField installs this builder on every
// field it renders), not just the arithmetic.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SpellCheckResults, SuggestionSpan;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/widgets/widgets.dart'
    show AppTextField, SpellCheckResultsProvider;

/// Supplies spell-check results the way StyledTextController does, so the
/// menu can be exercised without a native checker answering.
class _FakeSpellCheckController extends TextEditingController
    implements SpellCheckResultsProvider {
  @override
  SpellCheckResults? spellCheckResults;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // "hello worldd" as it was when the checker last answered: "worldd" at 6..12.
  SpellCheckResults staleResults() => const SpellCheckResults(
    'hello worldd',
    <SuggestionSpan>[
      SuggestionSpan(TextRange(start: 6, end: 12), <String>['world']),
    ],
  );

  /// Pumps a real AppTextField and returns its EditableTextState — the object
  /// the builder reads and writes through.
  Future<EditableTextState> pumpField(
    WidgetTester tester,
    TextEditingController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AppTextField(controller: controller))),
    );
    await tester.tap(find.byType(AppTextField));
    await tester.pump();
    return tester.state<EditableTextState>(find.byType(EditableText));
  }

  /// Builds the menu the way a right-click does and returns its button items.
  List<ContextMenuButtonItem> menuItems(
    WidgetTester tester,
    EditableTextState state,
  ) {
    final toolbar =
        AppTextField.spellCheckContextMenuBuilder(
              tester.element(find.byType(EditableText)),
              state,
            )
            as AdaptiveTextSelectionToolbar;
    return toolbar.buttonItems ?? const <ContextMenuButtonItem>[];
  }

  void setValue(TextEditingController controller, String text, int caret) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  testWidgets('a suggestion still on the live text is applied', (tester) async {
    final controller = _FakeSpellCheckController()
      ..spellCheckResults = staleResults();
    addTearDown(controller.dispose);

    final state = await pumpField(tester, controller);
    setValue(controller, 'hello worldd', 9);
    await tester.pump();

    final items = menuItems(tester, state);
    final fix = items.firstWhere((i) => i.label == 'world');
    fix.onPressed!();
    await tester.pump();

    expect(
      controller.text,
      'hello world',
      reason: 'the guard must not disable ordinary corrections',
    );
  });

  testWidgets('a span past the end of the live text is not offered', (
    tester,
  ) async {
    final controller = _FakeSpellCheckController()
      ..spellCheckResults = staleResults();
    addTearDown(controller.dispose);

    final state = await pumpField(tester, controller);
    // The user backspaced to "hello wor" before the next check came back; the
    // cached span still claims 6..12 of a string that is now 9 long.
    setValue(controller, 'hello wor', 9);
    await tester.pump();

    expect(
      menuItems(tester, state).map((i) => i.label),
      isNot(contains('world')),
      reason:
          'offering a correction for a word that is no longer there means '
          'pressing it rewrites whatever moved into that range — or throws',
    );
  });

  testWidgets('the field changing after the menu opens cancels the fix', (
    tester,
  ) async {
    final controller = _FakeSpellCheckController()
      ..spellCheckResults = staleResults();
    addTearDown(controller.dispose);

    final state = await pumpField(tester, controller);
    setValue(controller, 'hello worldd', 9);
    await tester.pump();

    // Menu built against the long text…
    final fix = menuItems(
      tester,
      state,
    ).firstWhere((i) => i.label == 'world');

    // …then the text shrinks under it (an undo, a paste, a programmatic
    // rewrite) before the user's click lands.
    setValue(controller, 'hello wor', 9);
    await tester.pump();

    fix.onPressed!();
    await tester.pump();

    expect(
      controller.text,
      'hello wor',
      reason:
          'the stale range must be dropped, not applied to the new text — '
          'replaceRange(6, 12) on a 9-character string throws RangeError',
    );
    expect(tester.takeException(), isNull);
  });
}
