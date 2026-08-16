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

// The Pockets & Wardrobe section of the shared identity editor.
//
// Interaction coverage, not pixels: a golden would have shown this section
// perfectly while its text fields did nothing, which is the precise shape of
// the 10-theme dead-button bug that shipped green.
//
// The optional-pair convention this exercises is load-bearing rather than
// stylistic. Two surfaces — create_group_chat_page.member_realism_card.dart and
// group_member_realism_editor.dart — mount this widget with NO identity params
// and rely on "absent means the section is not rendered". A required param
// breaks them at compile time; a non-null default gives them a dead empty
// section. Both failures are silent in a pixel test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/widgets/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester, {
    List<String>? worn,
    List<String>? carrying,
    ValueChanged<List<String>>? onWornChanged,
    ValueChanged<List<String>>? onCarryingChanged,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: IdentityChipLists(
            worn: worn,
            carrying: carrying,
            onWornChanged: onWornChanged ?? (_) {},
            onCarryingChanged: onCarryingChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );

  group('the section appears only when the caller wires it', () {
    testWidgets('both pairs present renders Wearing and Carrying', (t) async {
      await pump(t, worn: const [], carrying: const []);

      expect(find.text('Pockets & Wardrobe'), findsOneWidget);
      expect(find.text('WEARING'), findsOneWidget);
      expect(find.text('CARRYING'), findsOneWidget);
    });

    testWidgets('no values at all renders nothing', (t) async {
      // The group-member editors' case exactly.
      await pump(t, worn: null, carrying: null);

      expect(find.text('Pockets & Wardrobe'), findsNothing);
      expect(find.byType(ChipListEditor), findsNothing);
    });

    testWidgets('half a pair is not enough', (t) async {
      // A caller that wires the values but forgets a callback must get no
      // section rather than one whose chips silently do nothing.
      await pump(t, worn: const [], carrying: null);

      expect(find.text('Pockets & Wardrobe'), findsNothing);
    });
  });

  group('existing items show as the text the author typed', () {
    testWidgets('condition is rendered inline, not dropped', (t) async {
      await pump(
        t,
        worn: const ['sundress (rain-soaked)'],
        carrying: const ['car keys'],
      );

      expect(
        find.text('sundress (rain-soaked)'),
        findsOneWidget,
        reason: 'the chip IS the display string — showing "sundress" alone '
            'would make the condition look lost even though the card kept it',
      );
      expect(find.text('car keys'), findsOneWidget);
    });
  });

  group('the chips actually work', () {
    testWidgets('typing an item reports it back to the caller', (t) async {
      // The whole point of the feature: a golden proves the box is drawn, only
      // this proves an author can put something in it.
      List<String>? reported;
      await pump(
        t,
        worn: const [],
        carrying: const [],
        onWornChanged: (v) => reported = v,
      );

      // The field only exists once "+ add" is pressed, so this walks the real
      // path an author walks. There are two such buttons — Wearing first.
      await t.tap(find.text('+ add').first);
      await t.pumpAndSettle();
      await t.enterText(
        find.byType(TextField),
        'flour-dusted apron (well-worn)',
      );
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();

      expect(reported, ['flour-dusted apron (well-worn)']);
    });

    testWidgets('the Carrying box is wired to its own callback', (t) async {
      // Two boxes in one card is exactly where a copy-paste sends both to the
      // same list, which would look right and silently merge worn + carried.
      List<String>? wornReported;
      List<String>? carryingReported;
      await pump(
        t,
        worn: const [],
        carrying: const [],
        onWornChanged: (v) => wornReported = v,
        onCarryingChanged: (v) => carryingReported = v,
      );

      await t.tap(find.text('+ add').last);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'car keys');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();

      expect(carryingReported, ['car keys']);
      expect(
        wornReported,
        isNull,
        reason: 'typing into Carrying must not also report a Wearing change',
      );
    });
  });
}
