# Groups in Folders — implementation handoff

*2026-07-30. Maintainer request: group-chat cards are dumped on the Home
Screen top level and cannot be moved through the folder hierarchy at all.
They must be movable exactly like characters. Written as an executable spec
for the next session; nothing here is implemented yet.*

## How character foldering works today (mirror it)

- Membership lives on the ROW: `Characters.folderId` (nullable). Folder
  objects derive `characterPaths` (image-filename keys) by scanning the DB
  (`FolderService._load`). `addToFolder`/`removeFromFolder` update the
  character row's `folderId`.
- The grid (`character_card_grid.dart`) filters characters by
  `_activeFolderId`; groups are ALWAYS shown regardless (that's the bug —
  find the group bucket in `_buildGrid` and its callers).

## Work items (in order)

1. **Schema (additive):** nullable `folder_id` TEXT column on `group_chats`.
   `group_chats` is NOT one of the Character-Card-Forge-written tables
   (characters/sessions/messages/avatar_images/sync_meta), so an additive
   nullable column is allowed — but it still needs the drift migration:
   bump `schemaVersion`, add the `onUpgrade` step, run
   `dart run build_runner build`, and extend `_repairMissingSchemaColumns`
   if that helper covers group_chats. NO other shape of change.
2. **FolderService:** generalize membership to groups, keyed by GROUP ID
   (groups have no image filename): `groupIdsInFolder(folderId)`,
   `getFolderForGroup(groupId)`, `addGroupToFolder`/`removeGroupFromFolder`
   writing `group_chats.folder_id`, all loaded in `_load()` alongside
   characters. Extend `inheritFolder` thinking to groups later (duplicate
   group is still "not yet implemented" — when it lands, it inherits).
3. **Grid filtering:** groups render only when their `folderId` matches the
   active folder (null → top level), same as characters. Folder cards'
   counts/previews should include groups (folder_grid_card count line).
4. **Context menu:** group card right-click gains "Move to folder" using
   the same warm folder-picker dialog characters use
   (`_showMoveToFolderDialog`) — generalize it to accept a move callback
   rather than duplicating the dialog.
5. **Multi-select:** `_selectedCharacterIds` is imagePath-keyed; groups need
   selection too. Cleanest: a parallel `_selectedGroupIds` set + group tiles
   selectable in the same mode; the toolbar's Move/Delete act on both sets
   (`bulkMove` chars + groups; delete already has a group path via the
   context menu — reuse its confirm flow).
6. **Web parity (mandatory):** the web library (`CharactersPage.tsx` +
   `useLibrary.ts` + `character_library_facade.dart`) shows groups; its
   drag-to-folder + `moveToFolder`/`bulkMove` must accept group ids
   (additive: facade gains group handling keyed by a `group_` prefix or a
   separate endpoint — prefer extending `bulkMove` to resolve either kind).
7. **Search/sort:** foldered groups follow the same search-scope rules as
   foldered characters (`folderedFilenames` filtering has a group-shaped
   hole — audit `_buildGrid`'s unfoldered filter).
8. **Tests:** FolderService group membership unit tests (mirror
   `folder_service_inherit_test.dart`), plus a grid-filter test if the
   harness allows. Full `flutter test` suite green before ANY push
   (standing maintainer rule this session).

## Related queued item (same area, not started)

The group-chat creation wizard's character picker (and the Scene Guest
picker + Stoop share Pick step, which share the flat-grid pattern) ignores
the folder hierarchy — needs a folder-aware picker on desktop AND the web
`CreateGroupChatPage`. Design both together so the picker component is
shared, not duplicated.
