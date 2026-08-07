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

// ChipListEditor — the widget that replaced the newline-encoded Ambitions
// TextField (approved Porch Life sketch §4), and which Likes & Dislikes will
// reuse.
//
// The old field's failure modes are what these tests pin: a list encoded as
// text accepted blank lines, untrimmed whitespace and silent duplicates, and
// showed no count, so an author could not tell what they had actually saved.
// Each test below is one of those, made impossible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/widgets/chip_list_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps a self-managing host so the widget is exercised the way callers use
  /// it: values in, onChanged out, parent re-renders with the new list.
  Future<List<String> Function()> pumpEditor(
    WidgetTester tester, {
    List<String> initial = const [],
    int maxItems = 8,
  }) async {
    var current = initial;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ChipListEditor(
              label: 'Ambitions',
              values: current,
              maxItems: maxItems,
              onChanged: (v) => setState(() => current = v),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => current;
  }

  Future<void> addPhrase(WidgetTester tester, String text) async {
    await tester.tap(find.text('+ add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('adds a phrase and shows it as a chip', (tester) async {
    final read = await pumpEditor(tester);

    await addPhrase(tester, 'open her own bakery');

    expect(read(), ['open her own bakery']);
    expect(find.text('open her own bakery'), findsOneWidget);
  });

  testWidgets('trims whitespace and refuses a blank entry', (tester) async {
    final read = await pumpEditor(tester);

    await addPhrase(tester, '   reconcile with her sister   ');
    expect(
      read(),
      ['reconcile with her sister'],
      reason: 'the old textarea stored the padding verbatim, so the phrase '
          'reached the prompt with its whitespace intact',
    );

    await addPhrase(tester, '     ');
    expect(
      read(),
      ['reconcile with her sister'],
      reason: 'a blank line was a real entry in the newline-encoded field',
    );
  });

  testWidgets('refuses a duplicate regardless of case', (tester) async {
    final read = await pumpEditor(tester, initial: const ['Open a bakery']);

    await addPhrase(tester, 'open a bakery');

    expect(
      read(),
      ['Open a bakery'],
      reason: 'two spellings of one ambition would be injected into the '
          'prompt twice and counted twice against the cap',
    );
  });

  testWidgets('removing a chip drops exactly that entry', (tester) async {
    final read = await pumpEditor(
      tester,
      initial: const ['first goal', 'second goal'],
    );

    // The × sits inside the chip, so target the one belonging to 'first goal'.
    final firstChipRow = find
        .ancestor(of: find.text('first goal'), matching: find.byType(Row))
        .first;
    await tester.tap(
      find.descendant(of: firstChipRow, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();

    expect(read(), ['second goal']);
  });

  testWidgets('the cap is enforced and explains itself', (tester) async {
    final read = await pumpEditor(
      tester,
      initial: const ['a', 'b'],
      maxItems: 2,
    );

    expect(
      find.text('+ add'),
      findsNothing,
      reason: 'at the cap there is nothing to add with — the old field let an '
          'author paste twenty lines and silently kept them all',
    );
    expect(find.textContaining('remove one to add another'), findsOneWidget);
    expect(
      find.text('2 of 2'),
      findsOneWidget,
      reason: 'the count is the thing a textarea could never show',
    );
    expect(read(), ['a', 'b']);
  });
}
