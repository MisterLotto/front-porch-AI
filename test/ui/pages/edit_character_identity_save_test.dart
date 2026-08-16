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

// SILENT DATA LOSS in the character editor — reported 2026-08-08:
// "When you edit characters to wear things or have things in their pockets it
// doesn't save the PNG and everything is lost."
//
// What happened. `_saveCharacter` writes frontPorchExtensions under a guard:
//
//     if (showRealismTab && (_realismEnabled || _realismSettingsModified ||
//                            character.frontPorchExtensions != null))
//
// The identity chips — Ambitions, Likes & Dislikes, the 18+ pair and Pockets &
// Wardrobe — all write INTO frontPorchExtensions, but they live outside the
// realism section and not one of them sets `_realismSettingsModified` (only the
// controls in edit_character_page.realism_section.dart do). So for the most
// ordinary character there is — Realism Engine off, no realism control touched,
// no extensions on the card yet — every one of those three conditions was
// false, the block was skipped, and everything the author had typed was thrown
// away before the PNG was even written. The reporter's log is the block simply
// not running: the "Saving realism:" line is absent, and the next line reads
//   About to save PNG with extensions: false
//   PNG saved successfully for Malumbra the Oblivian to …
//   ✗ PNG verification FAILED: no extensions in saved file!
// A successful save, a written file, and the work gone. No error to react to.
//
// WHY THIS TEST DRIVES THE REAL UI rather than calling a helper. The bug was
// never in the wardrobe code — `Pockets.cardJsonFrom` was correct, and its own
// unit tests (wardrobe_authoring_test.dart) were green throughout. It was in
// whether the correct code was REACHED. Only a test that types into the actual
// chip field and presses the actual Save button can tell those apart, which is
// the same lesson the 10-theme dead-button bug taught: a green suite proves
// nothing about a path nothing ever walks.
//
// The card here deliberately has no imagePath, so the PNG write is skipped and
// this stays a fast widget test. That costs nothing: the extensions block runs
// BEFORE the PNG is written and hands it the card, so if the block runs, the
// PNG gets the data — as the reporter's own log shows in reverse.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/chat.dart' show Pockets;
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/pages/edit_character_page.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart' show ChipListEditor;

import '../../golden/support/fakes.dart';
import '../../golden/support/fakes_storage.dart';

/// The Details tab calls [coverImageFileFor]; the shared golden fake answers
/// unknown members by throwing. Same shim the sibling interaction suite uses.
class _RepoWithCover extends FakeCharacterRepository {
  @override
  File? coverImageFileFor(CharacterCard card) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps the editor over a card in the exact state the report describes:
  /// no extensions at all, so `_realismEnabled` initialises false and nothing
  /// has set the modified flag. Returns the card the page hands to save.
  Future<CharacterCard? Function()> pumpAndCapture(WidgetTester tester) async {
    CharacterCard? saved;

    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _RepoWithCover();
    final chat = FakeChatService();
    final storage = FakeStorageService();
    final worlds = FakeWorldRepository();
    addTearDown(repo.dispose);
    addTearDown(chat.dispose);
    addTearDown(storage.dispose);
    addTearDown(worlds.dispose);

    final card = CharacterCard(
      name: 'Malumbra the Oblivian',
      description: 'Wears things. Carries things.',
      // No frontPorchExtensions, and no imagePath: the PNG branch is skipped
      // and the guard under test is the only thing between the chips and the
      // saved card.
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CharacterRepository>.value(value: repo),
          ChangeNotifierProvider<ChatService>.value(value: chat),
          ChangeNotifierProvider<StorageService>.value(value: storage),
          ChangeNotifierProvider<WorldRepository>.value(value: worlds),
        ],
        child: MaterialApp(
          home: EditCharacterPage(
            character: card,
            // Intercepts persistence: the field updates and the extensions
            // block have already run on the card by the time this fires, so
            // what arrives here is precisely what would have been written.
            onSaveOverride: (c) async => saved = c,
          ),
        ),
      ),
    );

    return () => saved;
  }

  /// Types [text] into the chip editor labelled [label] and commits it, the
  /// way a user does: press "+ add", type, press enter.
  Future<void> addChip(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    final editor = find.byWidgetPredicate(
      (w) => w is ChipListEditor && w.label == label,
    );
    expect(
      editor,
      findsOneWidget,
      reason: 'the "$label" chip editor must be on the Details tab — if this '
          'fails the authoring surface moved, not the save guard',
    );

    final add = find.descendant(of: editor, matching: find.text('+ add'));
    await tester.scrollUntilVisible(add, 120, scrollable: find.byType(Scrollable).first);
    await tester.tap(add);
    await tester.pumpAndSettle();

    final field = find.descendant(of: editor, matching: find.byType(TextField));
    await tester.enterText(field, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: editor, matching: find.text(text)),
      findsOneWidget,
      reason: 'the chip did not commit, so the save assertion below would be '
          'vacuous',
    );
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('wardrobe typed on an ordinary card survives Save', (
    tester,
  ) async {
    final captured = await pumpAndCapture(tester);
    await tester.pumpAndSettle();

    await addChip(tester, 'Wearing', 'red sundress');
    await addChip(tester, 'Carrying', 'candy bar');
    await save(tester);

    final ext = captured()?.frontPorchExtensions;
    expect(
      ext,
      isNotNull,
      reason: 'THE BUG: with realism off and no prior extensions the whole '
          'block was skipped, so the card reached the PNG writer with '
          'frontPorchExtensions still null — "About to save PNG with '
          'extensions: false" in the report',
    );

    // Read it back the way the runtime does rather than poking at raw JSON:
    // if the shape were wrong, the chat that seeds from this card would be the
    // one to find out.
    final pockets = Pockets.fromJson(ext!.inventory);
    expect(pockets.worn.map((i) => i.name), contains('red sundress'));
    expect(pockets.carrying.map((i) => i.name), contains('candy bar'));
  });

  testWidgets('so do the other identity chips saved through the same guard', (
    tester,
  ) async {
    // Ambitions, Likes and Dislikes ride the identical condition, so they were
    // lost in identical silence. Pinning one of each means a future edit to the
    // guard cannot fix wardrobe alone and leave the others broken.
    final captured = await pumpAndCapture(tester);
    await tester.pumpAndSettle();

    await addChip(tester, 'Long-term goals', 'open her own bakery');
    await addChip(tester, 'Drawn to', 'thunderstorms');
    await addChip(tester, 'Put off by', 'being interrupted');
    await save(tester);

    final ext = captured()?.frontPorchExtensions;
    expect(ext, isNotNull);
    expect(ext!.ambitions, contains('open her own bakery'));
    expect(ext.likes, contains('thunderstorms'));
    expect(ext.dislikes, contains('being interrupted'));
  });

  testWidgets('an untouched card is still left alone', (tester) async {
    // The guard must stay a guard. Opening the editor, changing nothing about
    // identity or realism, and saving should not mint an extensions block on a
    // card that never had one — that would rewrite every plain card in a
    // library the first time it was opened, and stamp a stableId on cards that
    // deliberately carry none.
    final captured = await pumpAndCapture(tester);
    await tester.pumpAndSettle();

    await save(tester);

    expect(captured()?.frontPorchExtensions, isNull);
  });
}
