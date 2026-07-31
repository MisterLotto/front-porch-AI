// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The shared folder-aware character picker (group-creation wizard's Members
// browser; docs/design/folder-groups.md queued item). Verifies the home-grid
// folder rules it mirrors: top level = unfoldered characters + navigable
// folder tiles (hidden when they hold no eligible candidates), entering a
// folder shows its members, search reaches nested characters, and taps
// surface the picked card.
//
// All FolderService/drift work runs inside tester.runAsync — real database
// I/O never completes under the widget test's fake-async zone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/services/folder_service.dart';
import 'package:front_porch_ai/ui/widgets/folder_character_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FolderService folders;

  /// Seeds the DB with 'Misty' inside [folderName] (membership is keyed by
  /// image basename, so the row + folder assignment are what matter).
  Future<void> seedFolderedMisty(WidgetTester tester, String folderName) {
    return tester.runAsync(() async {
      db = AppDatabase.forTesting();
      folders = FolderService(db);
      await db.insertCharacterReturningId(
        const CharactersCompanion(
          name: Value('Misty'),
          imagePath: Value('/lib/Misty_1.png'),
        ),
      );
      final folder = await folders.createFolder(folderName);
      await folders.addToFolder(folder.id, '/lib/Misty_1.png');
    });
  }

  Widget host(
    List<CharacterCard> characters,
    void Function(CharacterCard) onTap,
  ) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FolderCharacterPicker(
            characters: characters,
            folderService: folders,
            onTapCharacter: onTap,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'top level shows unfoldered characters and folder tiles; '
    'entering a folder shows its members',
    (tester) async {
      await seedFolderedMisty(tester, 'Meteorologists');
      final characters = [
        CharacterCard(name: 'Misty', imagePath: '/lib/Misty_1.png'),
        CharacterCard(name: 'Porch Cat'),
      ];

      await tester.pumpWidget(host(characters, (_) {}));

      // Root: only the unfoldered character + the folder tile.
      expect(find.text('Porch Cat'), findsOneWidget);
      expect(find.text('Misty'), findsNothing);
      expect(find.text('Meteorologists'), findsOneWidget);

      await tester.tap(find.text('Meteorologists'));
      await tester.pump();

      // Inside: the foldered character appears; the outsider doesn't.
      expect(find.text('Misty'), findsOneWidget);
      expect(find.text('Porch Cat'), findsNothing);

      // Back returns to the top level.
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.text('Porch Cat'), findsOneWidget);
      expect(find.text('Misty'), findsNothing);

      await tester.runAsync(() => db.close());
    },
  );

  testWidgets('folders with no eligible characters are hidden', (tester) async {
    // 'Misty' lives in the folder but is NOT eligible (already a member).
    await seedFolderedMisty(tester, 'Meteorologists');
    final characters = [CharacterCard(name: 'Porch Cat')];

    await tester.pumpWidget(host(characters, (_) {}));

    expect(find.text('Meteorologists'), findsNothing);
    expect(find.text('Porch Cat'), findsOneWidget);

    await tester.runAsync(() => db.close());
  });

  testWidgets('search reaches characters nested inside folders', (
    tester,
  ) async {
    await seedFolderedMisty(tester, 'Meteorologists');
    CharacterCard? picked;
    final characters = [
      CharacterCard(name: 'Misty', imagePath: '/lib/Misty_1.png'),
      CharacterCard(name: 'Porch Cat'),
    ];

    await tester.pumpWidget(host(characters, (c) => picked = c));

    await tester.enterText(find.byType(TextField), 'mist');
    await tester.pump();

    // Folder tiles hide while searching; the nested character is findable.
    expect(find.text('Meteorologists'), findsNothing);
    expect(find.text('Misty'), findsOneWidget);
    expect(find.text('Porch Cat'), findsNothing);

    await tester.tap(find.text('Misty'));
    expect(picked?.name, 'Misty');

    await tester.runAsync(() => db.close());
  });
}
