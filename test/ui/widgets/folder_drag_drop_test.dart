// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Home-grid drag-to-folder. Two reported bugs are locked down here:
//   1. Group casts could not be dragged into folders at all — the folder drop
//      target was typed DragTarget<CharacterCard>, and group cards weren't
//      draggable in the first place.
//   2. The press-and-hold before a drag began was Flutter's stock 500 ms,
//      which felt unresponsive; it is now half that (kFolderDragHoldDelay).
// The hold assertions deliberately use a duration BETWEEN the new and old
// values, so restoring the stock delay fails these tests.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:provider/provider.dart';

import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/group_chat.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/folder_service.dart';
import 'package:front_porch_ai/services/group_chat_repository.dart';
import 'package:front_porch_ai/ui/pages/home/cards/character_grid_card.dart';
import 'package:front_porch_ai/ui/pages/home/cards/folder_grid_card.dart';
import 'package:front_porch_ai/ui/pages/home/cards/group_grid_card.dart';
import 'package:front_porch_ai/ui/widgets/character_card_grid.dart'
    show FolderDialogAction, kFolderDragHoldDelay;

/// Empty character store — the folder card reads it for preview art only.
class _FakeCharacterRepository extends ChangeNotifier
    implements CharacterRepository {
  @override
  List<CharacterCard> get characters => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Group store whose avatar lookup resolves to "no avatars" (the montage then
/// falls back to its glyph — no file I/O in the test).
class _FakeGroupChatRepository extends ChangeNotifier
    implements GroupChatRepository {
  @override
  Future<List<File>> getMemberAvatarFiles(String groupId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final folder = CharacterFolder(id: 'f1', name: 'Ensembles');
  final group = GroupChat(id: 'group_1', name: 'Porch Crew');

  /// A folder tile beside a group tile, both wired to record drops.
  Widget host({required void Function(Object item) onDrop}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CharacterRepository>.value(
          value: _FakeCharacterRepository(),
        ),
        ChangeNotifierProvider<GroupChatRepository>.value(
          value: _FakeGroupChatRepository(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 200,
                height: 260,
                child: FolderGridCard(
                  folder: folder,
                  onAcceptFolderDrop: (item, _) => onDrop(item),
                  onFolderTap: (_) {},
                  onFolderDialogAction:
                      (FolderDialogAction _, {folder, parentId}) {},
                  onResolveCharImage: (c) => File('/nonexistent.png'),
                ),
              ),
              SizedBox(
                width: 200,
                height: 260,
                child: CharacterGridCard(
                  character: CharacterCard(name: 'Misty'),
                  activeFolderId: null,
                  messageCountCache: const {},
                  isSelecting: false,
                  isOrganizing: false,
                  selectedCharacterIds: const {},
                  onTapCharacter: (_) async {},
                  onToggleSelect: (_) {},
                  onContextMenuAction: (_, _) {},
                  onResolveCharImage: (c) => File('/nonexistent.png'),
                ),
              ),
              SizedBox(
                width: 200,
                height: 260,
                child: GroupGridCard(
                  group: group,
                  groupRepo: _FakeGroupChatRepository(),
                  activeFolderId: null,
                  isSelecting: false,
                  isOrganizing: false,
                  selectedGroupIds: const {},
                  onTapGroup: (_) async {},
                  onToggleSelectGroup: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('a group cast drags onto a folder (was impossible)', (
    tester,
  ) async {
    Object? dropped;
    await tester.pumpWidget(host(onDrop: (item) => dropped = item));
    await tester.pump(); // let the avatar future resolve

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Porch Crew')),
    );
    // Held longer than the new delay but SHORTER than Flutter's stock 500 ms.
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(tester.getCenter(find.text('Ensembles')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dropped, isA<GroupChat>());
    expect((dropped as GroupChat).id, 'group_1');
  });

  testWidgets('a press shorter than the hold delay does not drag', (
    tester,
  ) async {
    Object? dropped;
    await tester.pumpWidget(host(onDrop: (item) => dropped = item));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Porch Crew')),
    );
    await tester.pump(const Duration(milliseconds: 100)); // under 250 ms
    await gesture.moveTo(tester.getCenter(find.text('Ensembles')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dropped, isNull);
  });

  testWidgets('characters still drop on folders (drop target went generic)', (
    tester,
  ) async {
    Object? dropped;
    await tester.pumpWidget(host(onDrop: (item) => dropped = item));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Misty')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(tester.getCenter(find.text('Ensembles')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dropped, isA<CharacterCard>());
    expect((dropped as CharacterCard).name, 'Misty');
  });

  test('the folder-drag hold is half Flutter\'s stock long-press timeout', () {
    expect(kFolderDragHoldDelay.inMilliseconds, kLongPressTimeout.inMilliseconds ~/ 2);
    expect(kFolderDragHoldDelay, const Duration(milliseconds: 250));
  });
}
