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

// "Import lore from a character" used to stat the avatar file inside every
// row's build(), and that list rebuilds on every search keystroke (and on
// every hover, via the row's own MouseRegion). N blocking existsSync per
// keypress is the io-lint bug class — invisible on APFS, felt typing lag on
// Windows under Defender. The avatar resolution is memoized per open dialog
// now; this pins that the second rebuild costs zero filesystem calls.
//
// The stat count is observed for real through IOOverrides: every File built
// inside the zone reports its existsSync calls.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/ui/dialogs/import_character_lore_dialog.dart';

class _CountingFile implements File {
  _CountingFile(this.path, this._counts);

  @override
  final String path;
  final Map<String, int> _counts;

  @override
  bool existsSync() {
    _counts[path] = (_counts[path] ?? 0) + 1;
    return false; // nothing on disk — the row draws its initial instead
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CharacterCard _card(String name) => CharacterCard(
      name: name,
      imagePath: '/fpai-test-avatars/$name.png',
      lorebook: Lorebook(entries: [LorebookEntry(key: name, content: 'x')]),
    );

void main() {
  testWidgets('the character-lore picker stats each avatar once, not per '
      'keystroke', (tester) async {
    final counts = <String, int>{};
    final cards = [_card('Amara'), _card('Marisol'), _card('Valentina')];

    await IOOverrides.runZoned(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showImportCharacterLoreDialog(
                      context: ctx,
                      characters: cards,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Amara'), findsOneWidget);
        final firstPass = Map<String, int>.from(counts);
        expect(
          firstPass.length,
          3,
          reason: 'every candidate row should have resolved its avatar once',
        );

        // Typing rebuilds the whole list — the memo must absorb it.
        await tester.enterText(find.byType(TextField), 'a');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'ar');
        await tester.pumpAndSettle();

        expect(
          counts,
          firstPass,
          reason: 'searching re-stat()ed the avatar files — the per-dialog '
              'avatar memo is gone, so every keystroke costs N blocking '
              'filesystem calls on the UI thread again',
        );
      },
      createFile: (p) => _CountingFile(p, counts),
    );
  });
}
