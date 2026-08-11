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

// Belongings cards in the journal UI (maintainer-found gap, 2026-08-11).
// Item cards are ordinary journal cards, and the whole point of riding the
// existing Journal is that its surfaces show them — but the diary dialog
// grouped by a FIXED category list that omitted 'item', so every placement
// memory was silently invisible in exactly the view named "the diary". And
// the editor's category dropdown, built from the authoring enum, would have
// CRASHED on an item card (a Dropdown whose value is not among its items is
// an assertion failure, not a fallback).
//
// Guards proven to fail before passing: dropping 'item' from
// kJournalDisplayCategories sends the display-list test red; reverting the
// dropdown's conditional entry sends the editor pump test red.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart'
    show kJournalCategories;
import 'package:front_porch_ai/ui/dialogs/dialogs.dart'
    show JournalCardEditorDialog, journalCategoryLabel, kJournalDisplayCategories;

void main() {
  test('the display list carries every category a stored card can hold', () {
    expect(
      kJournalDisplayCategories,
      containsAll([...kJournalCategories, 'item']),
      reason:
          'a category missing here is a card silently invisible in the diary',
    );
    expect(
      kJournalCategories,
      isNot(contains('item')),
      reason:
          'belongings cards are deterministic-only — offering the category '
          'to the LLM pass would break that guarantee',
    );
    expect(journalCategoryLabel('item', 'You'), 'Belongings');
  });

  testWidgets('editing a belongings card does not crash the category '
      'dropdown', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JournalCardEditorDialog(
            title: 'Edit memory',
            userName: 'You',
            initialContent: 'I set my car keys down — on the hallway table.',
            initialCategory: 'item',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Belongings'),
      findsOneWidget,
      reason: 'the dropdown must show the card\'s real category',
    );
  });
}
