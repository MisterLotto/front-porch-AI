// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Duplicating a character must keep the copy in the source's folder.
// Folder membership is keyed by image filename, so a fresh duplicate starts
// unfoldered — the reported bug was the copy landing on the home screen's
// top level no matter where its source lived. inheritFolder is the ONE
// shared rule (desktop context menu + web facade duplicate endpoint).

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/folder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FolderService folders;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.insertCharacterReturningId(
      CharactersCompanion(
        name: const Value('Misty'),
        imagePath: const Value('/library/Misty_1.png'),
      ),
    );
    await db.insertCharacterReturningId(
      CharactersCompanion(
        name: const Value('Misty (duplicate)'),
        imagePath: const Value('/library/Misty_duplicate_2.png'),
      ),
    );
    folders = FolderService(db);
    await Future<void>.delayed(Duration.zero); // let _init settle
  });

  tearDown(() async {
    await db.close();
  });

  test('inheritFolder puts the copy in the source\'s folder', () async {
    final folder = await folders.createFolder('Meteorologists');
    await folders.addToFolder(folder.id, '/library/Misty_1.png');

    await folders.inheritFolder(
      '/library/Misty_1.png',
      '/library/Misty_duplicate_2.png',
    );

    final copyFolder = folders.getFolderForCharacter(
      '/library/Misty_duplicate_2.png',
    );
    expect(copyFolder?.id, folder.id);
    // The source stays where it was.
    expect(
      folders.getFolderForCharacter('/library/Misty_1.png')?.id,
      folder.id,
    );
  });

  test('inheritFolder is a no-op for unfoldered sources and null paths',
      () async {
    await folders.inheritFolder(
      '/library/Misty_1.png',
      '/library/Misty_duplicate_2.png',
    );
    expect(
      folders.getFolderForCharacter('/library/Misty_duplicate_2.png'),
      isNull,
    );
    // Null-safe on both sides.
    await folders.inheritFolder(null, '/library/Misty_duplicate_2.png');
    await folders.inheritFolder('/library/Misty_1.png', null);
  });

  test('a null folder id removes a character from whatever folder holds it',
      () async {
    // The move picker's "Home (no folder)" entry is the always-reachable way
    // OUT of a folder (the card menu's "Remove from Folder" only shows while
    // browsing inside that folder), and it cannot know which folder the card
    // is in — so it passes null.
    final parent = await folders.createFolder('Meteorologists');
    final child = await folders.createFolder('Interns', parentId: parent.id);
    await folders.addToFolder(child.id, '/library/Misty_1.png');

    await folders.removeFromFolder(null, '/library/Misty_1.png');

    expect(folders.getFolderForCharacter('/library/Misty_1.png'), isNull);
    // A non-null id still guards against a stale card yanking the character
    // out of a folder it has since been moved to.
    await folders.addToFolder(parent.id, '/library/Misty_1.png');
    await folders.removeFromFolder(child.id, '/library/Misty_1.png');
    expect(
      folders.getFolderForCharacter('/library/Misty_1.png')?.id,
      parent.id,
    );
  });
}
