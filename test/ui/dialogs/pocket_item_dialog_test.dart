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

// THE ADD-ITEM DIALOG'S CONTRACT — interaction-tested, not golden-tested,
// because the 10-theme dead-button bug taught that pixels can be perfect
// while nothing is pressable. What matters here is which record comes back:
//
//  * "Add quietly" (Carrying / Set aside) → gift:false + the chosen
//    section (the Easter egg). Hidden on Wearing — a magic sundress is
//    the wrong fiction;
//  * "Hand to <name>" (Carrying / Set aside) → gift:true (the core
//    forces carrying — the dialog reports the chosen section, the
//    service owns the rule). Hidden on Wearing;
//  * "They're wearing this" (Wearing) → correction:true, worn, no gift;
//  * empty input → neither button pops the dialog.
//
// Proven to fail: with the two buttons' gift flags swapped, the first two
// tests go red. Wearing + Add quietly used to stay the Easter egg; that
// test is now the hide assertion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart' show PocketSection;
import 'package:front_porch_ai/ui/dialogs/dialogs.dart';

void main() {
  Future<Future<PocketItemAdd?>> openDialog(WidgetTester tester) async {
    late Future<PocketItemAdd?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                result = showPocketItemDialog(context, characterName: 'Mara');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Add quietly returns gift:false with the chosen section', (
    tester,
  ) async {
    final result = await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'brass key (scuffed)');
    await tester.tap(find.text('Set aside'));
    await tester.pump();
    await tester.tap(find.text('Add quietly'));
    await tester.pumpAndSettle();

    final add = await result;
    expect(add, isNotNull);
    expect(add!.name, 'brass key (scuffed)');
    expect(add.section, PocketSection.setAside);
    expect(
      add.gift,
      isFalse,
      reason: 'quiet add is the Easter egg — she must be surprised',
    );
    expect(
      add.correction,
      isFalse,
      reason: 'quiet add is still the surprise fiction, not a record fix',
    );
  });

  testWidgets('Hand to <name> returns gift:true', (tester) async {
    final result = await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'pocket watch');
    await tester.tap(find.text('Hand to Mara'));
    await tester.pumpAndSettle();

    final add = await result;
    expect(add, isNotNull);
    expect(
      add!.gift,
      isTrue,
      reason: 'handing over is the in-fiction path — she must know',
    );
    expect(
      add.correction,
      isFalse,
      reason: 'Hand must not ride the dress-correction path',
    );
  });

  testWidgets('empty input pops nothing', (tester) async {
    final result = await openDialog(tester);

    await tester.tap(find.text('Add quietly'));
    await tester.pump();
    expect(
      find.text('Add an item'),
      findsOneWidget,
      reason: 'a blank name must not submit',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('Wearing + They\'re wearing this is a record correction', (
    tester,
  ) async {
    final result = await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'coat (buttoned)');
    await tester.tap(find.text('Wearing'));
    await tester.pump();
    expect(
      find.text('Hand to Mara'),
      findsNothing,
      reason: 'Hand still forces pockets — it must not be the Wearing primary',
    );
    expect(find.text("They're wearing this"), findsOneWidget);

    await tester.tap(find.text("They're wearing this"));
    await tester.pumpAndSettle();

    final add = await result;
    expect(add, isNotNull);
    expect(add!.name, 'coat (buttoned)');
    expect(add.section, PocketSection.worn);
    expect(add.gift, isFalse);
    expect(
      add.correction,
      isTrue,
      reason: 'this is the dress-them path — no gift, no surprise',
    );
  });

  testWidgets('Wearing hides Add quietly; dress is a correction', (
    tester,
  ) async {
    final result = await openDialog(tester);

    await tester.enterText(
      find.byType(TextField),
      'Pink sundress (freshly washed)',
    );
    await tester.tap(find.text('Wearing'));
    await tester.pump();

    expect(
      find.text('Add quietly'),
      findsNothing,
      reason: 'quiet-add is a pocket Easter egg — nonsense on clothes',
    );
    expect(
      find.textContaining('Add quietly'),
      findsNothing,
      reason: 'Wearing copy must not advertise the surprise fiction',
    );
    expect(find.textContaining('Easter'), findsNothing);
    expect(find.textContaining('surpris'), findsNothing);
    expect(find.text('Hand to Mara'), findsNothing);
    expect(find.text("They're wearing this"), findsOneWidget);

    await tester.tap(find.text("They're wearing this"));
    await tester.pumpAndSettle();

    final add = await result;
    expect(add, isNotNull);
    expect(add!.name, 'Pink sundress (freshly washed)');
    expect(add.section, PocketSection.worn);
    expect(add.gift, isFalse);
    expect(
      add.correction,
      isTrue,
      reason: 'the one Wearing button is the dress-them path',
    );
  });

  testWidgets('empty input on They\'re wearing this pops nothing', (
    tester,
  ) async {
    final result = await openDialog(tester);

    await tester.tap(find.text('Wearing'));
    await tester.pump();
    await tester.tap(find.text("They're wearing this"));
    await tester.pump();
    expect(
      find.text('Add an item'),
      findsOneWidget,
      reason: 'a blank name must not submit the correction either',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}
