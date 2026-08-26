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

// Empty Wearing must stay visible when the user can add — a naked / model-
// stripped character used to look like "pockets only" because PocketsRow
// hid the group when worn was empty. Interaction-tested, not golden-tested.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart'
    show PocketItem, PocketSection, Pockets;
import 'package:front_porch_ai/ui/chat_components/sidebar/character_state/character_state.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Pockets? pockets,
    void Function({PocketSection? section})? onAdd,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PocketsRow(pockets: pockets ?? Pockets(), day: 1, onAdd: onAdd),
      ),
    ),
  );

  testWidgets('empty worn still shows Wearing when onAdd is set', (
    tester,
  ) async {
    PocketSection? requested;
    await pump(
      tester,
      pockets: Pockets(carrying: [PocketItem('brass key')]),
      onAdd: ({section}) => requested = section,
    );

    expect(
      find.text('WEARING'),
      findsOneWidget,
      reason: 'naked-with-keys must not look like pockets-only',
    );
    expect(find.text('Put clothes on'), findsOneWidget);

    await tester.tap(find.text('Put clothes on'));
    await tester.pump();
    expect(
      requested,
      PocketSection.worn,
      reason: 'the empty wearing control opens the dress path, not carrying',
    );
  });

  testWidgets('empty record with no onAdd hides the panel', (tester) async {
    await pump(tester);
    expect(find.text('Pockets & Wardrobe'), findsNothing);
    expect(find.text('WEARING'), findsNothing);
  });

  testWidgets('worn items still render as chips', (tester) async {
    await pump(
      tester,
      pockets: Pockets(worn: [PocketItem('coat', state: 'buttoned')]),
      onAdd: ({section}) {},
    );
    expect(find.text('coat (buttoned)'), findsOneWidget);
    expect(find.text('Put clothes on'), findsNothing);
  });
}
