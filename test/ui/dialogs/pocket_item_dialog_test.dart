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
//  * "Add quietly" → gift:false + the chosen section (the Easter egg);
//  * "Hand to <name>" → gift:true (the core forces carrying — the dialog
//    reports the chosen section, the service owns the rule);
//  * empty input → neither button pops the dialog.
//
// Proven to fail: with the two buttons' gift flags swapped, the first two
// tests go red.

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

  testWidgets('Add quietly returns gift:false with the chosen section',
      (tester) async {
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
    expect(add.gift, isFalse,
        reason: 'quiet add is the Easter egg — she must be surprised');
  });

  testWidgets('Hand to <name> returns gift:true', (tester) async {
    final result = await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'pocket watch');
    await tester.tap(find.text('Hand to Mara'));
    await tester.pumpAndSettle();

    final add = await result;
    expect(add, isNotNull);
    expect(add!.gift, isTrue,
        reason: 'handing over is the in-fiction path — she must know');
  });

  testWidgets('empty input pops nothing', (tester) async {
    final result = await openDialog(tester);

    await tester.tap(find.text('Add quietly'));
    await tester.pump();
    expect(find.text('Add an item'), findsOneWidget,
        reason: 'a blank name must not submit');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}
