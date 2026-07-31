// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Groups must move through the home-screen folder hierarchy exactly like
// characters (docs/design/folder-groups.md). Membership is keyed by GROUP ID
// (groups have no image filename) and stored on the row: groups.folder_id.
// Mirrors folder_service_inherit_test.dart's harness.

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
    await db.insertGroup(
      GroupsCompanion.insert(id: 'group_1', name: 'Porch Crew'),
    );
    await db.insertGroup(
      GroupsCompanion.insert(id: 'group_2', name: 'Night Shift'),
    );
    folders = FolderService(db);
    await Future<void>.delayed(Duration.zero); // let _init settle
  });

  tearDown(() async {
    await db.close();
  });

  test('addGroupToFolder writes groups.folder_id and buckets by group id',
      () async {
    final folder = await folders.createFolder('Ensembles');
    await folders.addGroupToFolder(folder.id, 'group_1');

    expect(folders.getFolderForGroup('group_1')?.id, folder.id);
    expect(folders.groupIdsInFolder(folder.id), contains('group_1'));
    // The other group stays at the top level.
    expect(folders.getFolderForGroup('group_2'), isNull);
    // The membership is on the DB row itself.
    final row = await db.getGroupById('group_1');
    expect(row?.folderId, folder.id);
  });

  test('removeGroupFromFolder returns the group to the top level', () async {
    final folder = await folders.createFolder('Ensembles');
    await folders.addGroupToFolder(folder.id, 'group_1');

    // Wrong folder id is a no-op.
    await folders.removeGroupFromFolder('not-the-folder', 'group_1');
    expect(folders.getFolderForGroup('group_1')?.id, folder.id);

    await folders.removeGroupFromFolder(folder.id, 'group_1');
    expect(folders.getFolderForGroup('group_1'), isNull);
    expect((await db.getGroupById('group_1'))?.folderId, isNull);
  });

  test('deleteFolder unassigns its groups back to the top level', () async {
    final folder = await folders.createFolder('Ensembles');
    await folders.addGroupToFolder(folder.id, 'group_1');

    await folders.deleteFolder(folder.id);

    expect(folders.getFolderForGroup('group_1'), isNull);
    // The group definition itself survives — only the membership is cleared.
    final row = await db.getGroupById('group_1');
    expect(row, isNotNull);
    expect(row?.folderId, isNull);
  });

  test('groupIdsInFolderRecursive walks subfolders (search parity)', () async {
    final parent = await folders.createFolder('Ensembles');
    final child = await folders.createFolder('Duos', parentId: parent.id);
    await folders.addGroupToFolder(parent.id, 'group_1');
    await folders.addGroupToFolder(child.id, 'group_2');

    expect(folders.groupIdsInFolder(parent.id), ['group_1']);
    expect(
      folders.groupIdsInFolderRecursive(parent.id).toSet(),
      {'group_1', 'group_2'},
    );
  });

  test('a normal group save (partial write) keeps folder membership',
      () async {
    // Regression guard for the updateGroup .replace() → .write() change: a
    // repository save whose companion has no folderId must NOT reset the
    // folder the user filed the group into.
    final folder = await folders.createFolder('Ensembles');
    await folders.addGroupToFolder(folder.id, 'group_1');

    await db.updateGroup(
      const GroupsCompanion(
        id: Value('group_1'),
        name: Value('Porch Crew (renamed)'),
      ),
    );

    final row = await db.getGroupById('group_1');
    expect(row?.name, 'Porch Crew (renamed)');
    expect(row?.folderId, folder.id);
  });
}
