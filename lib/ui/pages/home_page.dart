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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/providers/app_state.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

// Barrel imports (preferred during major refactor per project guidelines)
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/utils/character_id.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

// Specific pages, dialogs, and internal services not in barrels
import 'package:front_porch_ai/ui/pages/chat_page.dart';
import 'package:front_porch_ai/ui/pages/home/dialogs/session_picker_dialog.dart';
import 'package:front_porch_ai/ui/pages/edit_character_page.dart';
import 'package:front_porch_ai/ui/pages/edit_group_page.dart';
import 'package:front_porch_ai/services/group_card_importer.dart';
import 'package:front_porch_ai/ui/pages/character_creator_page.dart';
import 'package:front_porch_ai/ui/pages/story_home_view.dart';
import 'package:front_porch_ai/ui/dialogs/byaf_import_dialog.dart';
import 'package:front_porch_ai/ui/dialogs/tag_dialog.dart';
import 'package:front_porch_ai/services/byaf_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = '';
  String? _activeFolderId; // null = top level view
  List<String> _folderStack = []; // navigation breadcrumb for subfolder back
  SearchScope _searchScope = SearchScope.currentFolder;
  final _searchController = TextEditingController();

  // Multi-select mode (used for organizing into folders, bulk actions, etc.)
  bool _isSelecting = false;
  // Multi-select for folder organization
  bool _isOrganizing = false;
  final Set<String> _selectedCharacterIds = {}; // imagePath-based IDs

  // Sorting
  String _sortMode = 'name'; // 'name', 'recent', 'importDate', 'messages'
  final Map<String, DateTime> _lastActivityCache = {};
  final Map<String, int> _messageCountCache = {};

  // Grid scale
  double _gridScale = 300.0;

  // Porch Stories mode toggle
  bool _showStories = false;

  // Scroll controller for the character grid (visible scrollbar)
  final ScrollController _gridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final storage = Provider.of<StorageService>(context, listen: false);
    _sortMode = storage.sortMode;
    _gridScale = storage.gridScale;
    // StorageService._init() is async — settings may not be loaded yet.
    // Wait for init to complete so persisted values are reflected.
    storage.initialized.then((_) {
      if (!mounted) return;
      setState(() {
        _sortMode = storage.sortMode;
        _gridScale = storage.gridScale;
      });
    });
    Future.microtask(() => _refreshLastActivityCache());
  }

  /// Resolve a character [imagePath] (basename or full path) to a [File].
  File _resolveCharImage(String imagePath) {
    final storage = Provider.of<StorageService>(context, listen: false);
    return storage.resolveCharacterImage(imagePath);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for model-ready events from KoboldService
    try {
      final kobold = Provider.of<KoboldService>(context, listen: false);
      kobold.removeListener(_onKoboldUpdate);
      kobold.addListener(_onKoboldUpdate);
    } catch (_) {
      // KoboldService might not be in the provider tree
    }
    // Listen for CharacterRepository changes to refresh cache after characters load
    try {
      final charRepo = Provider.of<CharacterRepository>(context, listen: false);
      charRepo.removeListener(_onCharactersChanged);
      charRepo.addListener(_onCharactersChanged);
    } catch (_) {}
  }

  void _onCharactersChanged() {
    if (!mounted) return;
    _refreshLastActivityCache();
  }

  void _onKoboldUpdate() {
    if (!mounted) return;
    try {
      final kobold = Provider.of<KoboldService>(context, listen: false);
      if (kobold.consumeModelReady()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                const Text('Model loaded and ready!'),
              ],
            ),
            backgroundColor: AppColors.surfaceContainerOf(context),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      setState(() {}); // Rebuild to update status bar
    } catch (_) {}
  }

  /// Query the DB to build caches for last activity time and message count per character.
  ///
  /// Keys in the output maps are always the stableGroupId (image basename or sanitized name)
  /// so they match what the grid and sort logic use via CharacterCard.stableGroupId.
  ///
  /// We correlate via each library card's dbId because 1:1 sessions currently store the
  /// integer dbId in sessions.character_id (post group overhaul). Group sessions (with
  /// groupId set, character_id often null) do not contribute here — this is by design
  /// for the decoupled model (group activity lives with the private group members).
  Future<void> _refreshLastActivityCache() async {
    try {
      final db = await AppDatabase.instance();
      final charRepo = Provider.of<CharacterRepository>(context, listen: false);

      // Get counts and activity from DB (keys are whatever was stored in sessions.character_id,
      // currently the dbId for 1:1 sessions).
      final msgCounts = await db.getMessageCountsPerCharacter();
      final lastActivity = await db.getLastActivityPerCharacter();

      // Output maps MUST be keyed by stableGroupId (the value used for all lookups
      // in the grid for chips + 'recent'/'messages' sorting).
      final newMsgCount = <String, int>{};
      final newCache = <String, DateTime>{};

      for (final card in charRepo.characters) {
        final stableId = card.stableGroupId;
        if (card.dbId != null) {
          final dbKey =
              card.dbId!; // matches what is stored in sessions for 1:1
          if (msgCounts.containsKey(dbKey)) {
            newMsgCount[stableId] = msgCounts[dbKey]!;
          }
          if (lastActivity.containsKey(dbKey)) {
            newCache[stableId] = lastActivity[dbKey]!;
          }
        }
      }

      if (mounted) {
        setState(() {
          _lastActivityCache
            ..clear()
            ..addAll(newCache);
          _messageCountCache
            ..clear()
            ..addAll(newMsgCount);
        });
      }
    } catch (e) {
      debugPrint('Error refreshing activity cache: $e');
      if (mounted) setState(() {});
    }
  }

  /// Delegates to the canonical stable group ID.
  /// See [StableGroupId.stableGroupId] in lib/utils/character_id.dart
  String _getCharacterIdFromCard(CharacterCard card) => card.stableGroupId;

  /// Legacy alias — prefer _getCharacterIdFromCard for new code.
  @Deprecated('Use _getCharacterIdFromCard for stable group ID resolution')
  String getStableCharacterId(CharacterCard card) => card.stableGroupId;

  void _toggleSelectMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      _isOrganizing = false;
      if (!_isSelecting) _selectedCharacterIds.clear();
    });
  }

  void _toggleOrganizeMode() {
    setState(() {
      _isOrganizing = !_isOrganizing;
      _isSelecting = false;
      if (!_isOrganizing) _selectedCharacterIds.clear();
    });
  }

  void _toggleSelect(CharacterCard character) {
    final id = character.imagePath != null
        ? path.basenameWithoutExtension(character.imagePath!)
        : character.name
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .replaceAll(' ', '_');
    setState(() {
      if (_selectedCharacterIds.contains(id)) {
        _selectedCharacterIds.remove(id);
        if (_selectedCharacterIds.isEmpty) {
          _isSelecting = false;
          _isOrganizing = false;
        }
      } else {
        _selectedCharacterIds.add(id);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelecting = false;
      _isOrganizing = false;
      _selectedCharacterIds.clear();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _gridScrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<CharacterRepository, FolderService, GroupChatRepository>(
      builder: (context, repo, folderService, groupRepo, child) {
        if (repo.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (repo.characters.isEmpty && groupRepo.groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get started by creating a new character!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.titleLarge?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Provider.of<AppState>(
                        context,
                        listen: false,
                      ).setIndex(1),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create New'),
                      style: _buttonStyle(),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _importCharacter(context),
                      icon: const Icon(Icons.download),
                      label: const Text('Import Card'),
                      style: _buttonStyle(),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CharacterCreatorPage(),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('AI Create'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _folderImportCharacters(context),
                      icon: const Icon(Icons.library_add),
                      label: const Text('Bulk Import'),
                      style: _buttonStyle(),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _importByaf(context),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Import BYAF'),
                      style: _buttonStyle(),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // If Porch Stories mode is active, show the stories view
        if (_showStories) {
          return _wrapWithStatusBar(
            context,
            Column(
              children: [
                // Radio toggle
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Row(children: [_buildModeToggle(), const Spacer()]),
                ),
                const Expanded(child: StoryHomeView()),
              ],
            ),
          );
        }

        return _wrapWithStatusBar(
          context,
          CharacterCardGrid(
            searchQuery: _searchQuery,
            searchScope: _searchScope,
            activeFolderId: _activeFolderId,
            sortMode: _sortMode,
            lastActivityCache: _lastActivityCache,
            messageCountCache: _messageCountCache,
            gridScale: _gridScale,
            isSelecting: _isSelecting,
            isOrganizing: _isOrganizing,
            selectedCharacterIds: _selectedCharacterIds,
            searchController: _searchController,
            gridScrollController: _gridScrollController,
            repo: repo,
            folderService: folderService,
            groupRepo: groupRepo,
            modeToggle: _buildModeToggle(),
            onTapCharacter: _handleTapCharacter,
            onTapGroup: _handleTapGroup,
            onToggleSelect: _toggleSelect,
            onToggleSelectMode: _toggleSelectMode,
            onToggleOrganizeMode: _toggleOrganizeMode,
            onContextMenuAction: _handleContextMenuAction,
            onImport: _handleImport,
            onAcceptFolderDrop: _handleAcceptFolderDrop,
            onFolderDialogAction: _handleFolderDialogAction,
            onFolderTap: _handleFolderTap,
            onFolderNavigateBack: _handleFolderNavigateBack,
            onCancelSelection: _cancelSelection,
            // onCreateGroup no longer wired — old select-for-group path deprecated.
            onMoveToFolder: _handleMoveToFolder,
            onSortChanged: _handleSortChanged,
            onGridScaleChanged: _handleGridScaleChanged,
            onGridScaleChangeEnd: _handleGridScaleChangeEnd,
            onSearchScopeChanged: _handleSearchScopeChanged,
            onSearchQueryChanged: _handleSearchQueryChanged,
            onResolveCharImage: _resolveCharImage,
            onDeleteGroup: _handleDeleteGroup,
            onAfterNavigateBack: _refreshLastActivityCache,
            onGroupContextMenuAction: _handleGroupContextMenuAction,
          ),
        );
      },
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton(
            'Chats',
            Icons.chat_bubble_outline,
            !_showStories,
            () => setState(() => _showStories = false),
          ),
          _modeButton(
            'Porch Stories',
            Icons.auto_stories,
            _showStories,
            () => setState(() => _showStories = true),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(
    String label,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.resolve(
                  context,
                  Colors.amber.shade800.withValues(alpha: 0.25),
                  Colors.amber.withValues(alpha: 0.15),
                )
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(
                  color: AppColors.resolve(
                    context,
                    Colors.amber.shade700.withValues(alpha: 0.5),
                    Colors.amber.shade700.withValues(alpha: 0.4),
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? AppColors.resolve(
                      context,
                      Colors.amber.shade400,
                      Colors.amber.shade800,
                    )
                  : AppColors.iconSecondary(context),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? AppColors.textPrimary(context)
                    : AppColors.textSecondary(context),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapWithStatusBar(BuildContext context, Widget content) {
    String status = '';
    try {
      final kobold = Provider.of<KoboldService>(context, listen: false);
      status = kobold.modelLoadingStatus;
    } catch (_) {}

    if (status.isEmpty) return content;

    return Column(
      children: [
        Expanded(child: content),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerOf(context),
            border: Border(top: BorderSide(color: AppColors.borderOf(context))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: AppColors.resolve(
                    context,
                    const Color(0xFF333333),
                    AppColors.surfaceContainerLight,
                  ),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.greenAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Shows a dialog letting the user choose which saved session to resume.
  /// Returns the session ID, '__new__' for a new chat, or null if cancelled.

  // ─── CharacterCardGrid Callback Handlers ────────────────────────

  Future<void> _handleTapCharacter(CharacterCard character) async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final charId = character.dbId ?? _getCharacterIdFromCard(character);
    final sessions = await chatService.getSessionsForId(charId);

    if (!context.mounted) return;

    if (sessions.length > 1) {
      final selectedId = await showSessionPickerDialog(
        context,
        sessions,
        character.name,
      );
      if (selectedId == null || !context.mounted) return;
      await chatService.setActiveCharacter(character);
      if (selectedId != '__new__') {
        await chatService.loadSession(selectedId);
      }
      if (selectedId == '__new__') {
        await chatService.startNewChat();
      }
    } else {
      await chatService.setActiveCharacter(character);
    }
    if (context.mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatPage()));
      _refreshLastActivityCache();
    }
  }

  Future<void> _handleTapGroup(GroupChat group) async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final groupRepo = Provider.of<GroupChatRepository>(context, listen: false);
    final groupId = 'group_${group.id}';
    final sessions = await chatService.getSessionsForId(groupId);

    if (!context.mounted) return;

    if (sessions.length > 1) {
      final selectedId = await showSessionPickerDialog(
        context,
        sessions,
        group.name,
      );
      if (selectedId == null || !context.mounted) return;
      await chatService.setActiveGroup(group, groupRepo: groupRepo);
      if (selectedId != '__new__') {
        await chatService.loadSession(selectedId);
      }
      if (selectedId == '__new__') {
        await chatService.startNewChat();
      }
    } else {
      await chatService.setActiveGroup(group, groupRepo: groupRepo);
    }
    if (context.mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatPage()));
      _refreshLastActivityCache();
    }
  }

  void _handleContextMenuAction(String action, CharacterCard character) {
    switch (action) {
      case 'edit':
        _editCharacter(context, character);
        break;
      case 'duplicate':
        _duplicateCharacter(context, character);
        break;
      case 'export':
        _exportCharacter(context, character);
        break;
      case 'export_json':
        _exportCharacterJson(context, character);
        break;
      case 'remove_folder':
        final folderService = Provider.of<FolderService>(
          context,
          listen: false,
        );
        if (_activeFolderId != null && character.imagePath != null) {
          folderService.removeFromFolder(
            _activeFolderId!,
            character.imagePath!,
          );
        }
        break;
      case 'delete':
        _confirmDeleteCharacter(context, character);
        break;
    }
  }

  void _handleGroupContextMenuAction(String action, GroupChat group) {
    switch (action) {
      case 'edit':
        _editGroup(group);
        break;
      case 'duplicate':
        _duplicateGroup(group);
        break;
      case 'export':
        _exportGroup(group);
        break;
      case 'extract':
        _extractCharactersFromGroup(group);
        break;
      case 'delete':
        _confirmDeleteGroup(context, group);
        break;
    }
  }

  Future<void> _editGroup(GroupChat group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditGroupPage(group: group)),
    );
    // GroupChatRepository.save() already calls notifyListeners(),
    // so the home grid rebuilds automatically after edit.
  }

  void _duplicateGroup(GroupChat group) {
    // Placeholder — real implementation will copy the GroupChat definition (new id, "Copy of" name, same seeds/ lore / worlds / prompts).
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicate Group not yet implemented: ${group.name}'),
        ),
      );
    }
  }

  void _handleImport(String source) {
    switch (source) {
      case 'cards':
        _importCharacter(context);
        break;
      case 'folder':
        _folderImportCharacters(context);
        break;
      case 'byaf':
        _importByaf(context);
        break;
    }
  }


  Future<void> _handleAcceptFolderDrop(
    CharacterCard character,
    CharacterFolder folder,
  ) async {
    final folderService = Provider.of<FolderService>(context, listen: false);
    if (character.imagePath != null) {
      await folderService.addToFolder(folder.id, character.imagePath!);
    }
  }

  void _handleFolderDialogAction(
    FolderDialogAction action, {
    CharacterFolder? folder,
    String? parentId,
  }) {
    final folderService = Provider.of<FolderService>(context, listen: false);
    switch (action) {
      case FolderDialogAction.create:
        _createFolder(context, folderService, parentId: parentId);
        break;
      case FolderDialogAction.rename:
        if (folder != null) _renameFolder(context, folder, folderService);
        break;
      case FolderDialogAction.delete:
        if (folder != null) _deleteFolder(context, folder, folderService);
        break;
    }
  }

  void _handleFolderTap(CharacterFolder folder) {
    setState(() {
      if (_activeFolderId != null) {
        _folderStack.add(_activeFolderId!);
      }
      _activeFolderId = folder.id;
    });
  }

  void _handleFolderNavigateBack() {
    setState(() {
      if (_folderStack.isNotEmpty) {
        _activeFolderId = _folderStack.removeLast();
      } else {
        _activeFolderId = null;
      }
    });
  }

  void _handleMoveToFolder(Set<String> selectedIds) {
    final repo = Provider.of<CharacterRepository>(context, listen: false);
    final folderService = Provider.of<FolderService>(context, listen: false);
    _showMoveToFolderDialog(context, repo, folderService);
  }

  void _handleSortChanged(String mode) {
    setState(() => _sortMode = mode);
    Provider.of<StorageService>(context, listen: false).setSortMode(mode);
  }

  void _handleGridScaleChanged(double scale) {
    setState(() => _gridScale = scale);
  }

  void _handleGridScaleChangeEnd(double scale) {
    Provider.of<StorageService>(context, listen: false).setGridScale(scale);
  }

  void _handleSearchScopeChanged(SearchScope scope) {
    setState(() => _searchScope = scope);
  }

  void _handleSearchQueryChanged(String query) {
    setState(() => _searchQuery = query);
  }

  void _handleDeleteGroup(GroupChat group) {
    _confirmDeleteGroup(context, group);
  }

  void _confirmDeleteGroup(BuildContext context, GroupChat group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Text(
          'Delete Group',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Delete group "${group.name}"?\n\nThe characters themselves will NOT be deleted.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final groupRepo = Provider.of<GroupChatRepository>(
                context,
                listen: false,
              );
              await groupRepo.delete(group.id);
              // No post-delete snackbar for groups (character delete shows one via the outer context)
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── Group Creation Dialog ──────────────────────────────────────

  void _showMoveToFolderDialog(
    BuildContext context,
    CharacterRepository repo,
    FolderService folderService,
  ) {
    final folders = folderService.folders.toList()
      ..sort((a, b) {
        final pathA = folderService.getFolderPath(a.id).toLowerCase();
        final pathB = folderService.getFolderPath(b.id).toLowerCase();
        return pathA.compareTo(pathB);
      });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.blueAccent, width: 0.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.drive_file_move, color: Colors.blueAccent),
            const SizedBox(width: 12),
            Text(
              'Move ${_selectedCharacterIds.length} character${_selectedCharacterIds.length == 1 ? '' : 's'} to folder',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (folders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No folders yet. Create one below.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ...folders.map((folder) {
                  final folderPath = folderService.getFolderPath(folder.id);
                  final isSubfolder = folder.parentId != null;
                  return ListTile(
                    leading: Icon(
                      isSubfolder
                          ? Icons.subdirectory_arrow_right
                          : Icons.folder,
                      color: Colors.amberAccent,
                    ),
                    title: Text(
                      folderPath,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${folder.characterPaths.length} characters',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hoverColor: Colors.white10,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _moveSelectedToFolder(
                        context,
                        folder.id,
                        repo,
                        folderService,
                      );
                    },
                  );
                }),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const Icon(
                    Icons.create_new_folder,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'New Folder',
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hoverColor: Colors.white10,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final name = await _promptFolderName(context);
                    if (name != null && name.isNotEmpty && context.mounted) {
                      final folder = await folderService.createFolder(name);
                      await _moveSelectedToFolder(
                        context,
                        folder.id,
                        repo,
                        folderService,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptFolderName(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (val) => Navigator.pop(ctx, val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveSelectedToFolder(
    BuildContext context,
    String folderId,
    CharacterRepository repo,
    FolderService folderService,
  ) async {
    // Resolve selected IDs back to imagePaths
    for (final id in _selectedCharacterIds) {
      final card = repo.characters
          .where((c) => _getCharacterIdFromCard(c) == id)
          .firstOrNull;
      if (card?.imagePath != null) {
        await folderService.addToFolder(folderId, card!.imagePath!);
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Moved ${_selectedCharacterIds.length} character${_selectedCharacterIds.length == 1 ? '' : 's'} to folder',
          ),
        ),
      );
    }
    _cancelSelection();
  }

  // (old group creator dialog variables and body fully removed — 2026 overhaul)

  // ─── Folder Actions ─────────────────────────────────────────────

  void _createFolder(
    BuildContext context,
    FolderService folderService, {
    String? parentId,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: Text(
          parentId != null ? 'New Subfolder' : 'New Folder',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Folder name...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              folderService.createFolder(value.trim(), parentId: parentId);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                folderService.createFolder(
                  controller.text.trim(),
                  parentId: parentId,
                );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _renameFolder(
    BuildContext context,
    CharacterFolder folder,
    FolderService folderService,
  ) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Rename Folder',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              folderService.renameFolder(folder.id, value.trim());
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                folderService.renameFolder(folder.id, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _deleteFolder(
    BuildContext context,
    CharacterFolder folder,
    FolderService folderService,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Text(
          'Delete Folder',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Delete "${folder.name}"?\n\nCharacters inside will NOT be deleted — they\'ll return to the top level.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              folderService.deleteFolder(folder.id);
              Navigator.pop(ctx);
              if (_activeFolderId == folder.id) {
                setState(() {
                  if (_folderStack.isNotEmpty) {
                    _activeFolderId = _folderStack.removeLast();
                  } else {
                    _activeFolderId = null;
                  }
                });
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── Character Actions ──────────────────────────────────────────

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.resolve(
        context,
        Colors.white.withValues(alpha: 0.1),
        Colors.black.withValues(alpha: 0.05),
      ),
      foregroundColor: AppColors.textPrimary(context),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.resolve(context, Colors.white24, Colors.black26),
        ),
      ),
    );
  }

  void _confirmDeleteCharacter(BuildContext context, CharacterCard character) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
            SizedBox(width: 8),
            Text(
              'Delete Character',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${character.name}"?\n\nThis will permanently remove the character card and its image file. This action cannot be undone.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              final repo = Provider.of<CharacterRepository>(
                context,
                listen: false,
              );
              final worldRepo = Provider.of<WorldRepository>(
                context,
                listen: false,
              );
              final storageService = Provider.of<StorageService>(
                context,
                listen: false,
              );
              await repo.deleteCharacter(
                character,
                worldRepo: worldRepo,
                chatsDir: storageService.chatsDir,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${character.name} has been deleted.'),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _editCharacter(
    BuildContext context,
    CharacterCard character,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCharacterPage(character: character),
      ),
    );
    // No loadCharacters() needed here — updateCharacter() already updates the
    // in-memory list and calls notifyListeners(). Calling loadCharacters() was
    // re-reading outdated in-memory extensions from the cache and overwriting
    // the freshly-saved values.
  }

  Future<void> _duplicateCharacter(
    BuildContext context,
    CharacterCard character,
  ) async {
    try {
      await Provider.of<CharacterRepository>(
        context,
        listen: false,
      ).duplicateCharacter(character);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Character duplicated successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to duplicate: $e')));
      }
    }
  }

  Future<void> _importCharacter(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'json'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;
    if (!context.mounted) return;

    final files = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();

    if (files.isEmpty) return;

    // Single file: check if this is a Front Porch Group Card first (novel format)
    if (files.length == 1) {
      final file = files.first;
      try {
        final groupService = GroupCardService();
        final groupCard = await groupService.readGroupCard(file.path);

        if (groupCard != null) {
          // This is a Group Card PNG — do the special group import
          await _importGroupCard(context, file, groupCard);
          return;
        }

        // Normal character card
        final worldRepo = Provider.of<WorldRepository>(context, listen: false);
        final repo = Provider.of<CharacterRepository>(context, listen: false);
        final card = await repo.importCharacter(file, worldRepo: worldRepo);
        if (context.mounted && card != null) {
          // Show tag dialog
          final tags = await TagDialog.show(context, card);
          if (tags != null && context.mounted) {
            card.tags = List.from(tags);
            await repo.updateCharacter(card);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Character imported successfully!')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
        }
      }
      return;
    }

    // Multiple files: use bulk import with progress dialog
    _runBulkImport(context, files);
  }

  Future<void> _importByaf(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['byaf'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;
    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();
    if (paths.isEmpty || !context.mounted) return;

    // Multiple files → bulk import with a progress dialog (no per-file preview),
    // mirroring the bulk V2 PNG importer. A single file keeps the rich preview
    // dialog below.
    if (paths.length > 1) {
      await _runBulkByafImport(context, paths);
      return;
    }

    final filePath = paths.first;
    final byafService = ByafService();

    try {
      // Parse the .byaf archive
      final preview = await byafService.parseByaf(filePath);

      if (!context.mounted) return;

      // Show preview dialog
      final result2 = await showDialog<ByafImportResult>(
        context: context,
        builder: (context) => ByafImportDialog(preview: preview),
      );

      if (result2 == null || !result2.confirmed || !context.mounted) return;

      // Convert to CharacterCard
      final card = byafService.toCharacterCard(preview);

      // Save as PNG (with image if available)
      final storageService = Provider.of<StorageService>(
        context,
        listen: false,
      );
      final pngPath = await byafService.saveCharacterPng(
        card,
        charactersDirPath: storageService.charactersDir.path,
      );

      // Now use V2CardService to embed character data into the PNG
      final v2Service = V2CardService();
      await v2Service.saveCardAsPng(card, pngPath, preview.extractedImagePath);

      // Import via CharacterRepository (reads PNG metadata + inserts into DB)
      final repo = Provider.of<CharacterRepository>(context, listen: false);
      final worldRepo = Provider.of<WorldRepository>(context, listen: false);
      final importedCard = await repo.importCharacter(
        File(pngPath),
        worldRepo: worldRepo,
      );

      // Import chat history if requested
      if (result2.importChatHistory &&
          preview.messages.isNotEmpty &&
          importedCard != null) {
        final db = await AppDatabase.instance();
        await byafService.importChatHistory(db, preview, importedCard);
      }

      if (context.mounted && importedCard != null) {
        final chatNote =
            result2.importChatHistory && preview.messages.isNotEmpty
            ? ' with ${preview.messages.length} chat messages'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported "${importedCard.name}" from Backyard AI$chatNote!',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import .byaf: $e')));
      }
    }
  }

  /// Mass BYAF import: confirm once (with a chat-history choice for the whole
  /// batch), then drive the shared bulk-progress dialog over the files.
  Future<void> _runBulkByafImport(
    BuildContext context,
    List<String> paths,
  ) async {
    bool importChats = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surfaceOf(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.library_add,
                color: AppColors.resolve(
                  ctx,
                  Colors.blueAccent,
                  Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Import ${paths.length} Backyard AI characters?',
                  style: TextStyle(color: AppColors.textPrimary(ctx)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Each .byaf will be imported as a character card. (No per-file '
                'preview is shown for batch imports.)',
                style: TextStyle(
                  color: AppColors.textSecondary(ctx),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: importChats,
                onChanged: (v) => setLocal(() => importChats = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Also import chat history',
                  style: TextStyle(color: AppColors.textPrimary(ctx)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textTertiary(ctx)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Import ${paths.length}'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    _runBulkProgressImport(
      context,
      title: 'Import Backyard AI',
      totalCount: paths.length,
      runImport: ({required onProgress, required isCancelled}) =>
          _importByafFiles(
            context,
            paths,
            importChats,
            onProgress: onProgress,
            isCancelled: isCancelled,
          ),
    );
  }

  /// Per-file BYAF import loop used by the bulk progress dialog. Mirrors the
  /// single-file `_importByaf` pipeline (parse → convert → embed V2 PNG →
  /// import → optional chat history) and reports progress per file.
  Future<void> _importByafFiles(
    BuildContext context,
    List<String> paths,
    bool importChats, {
    required void Function(int current, int total, String name, String? error)
    onProgress,
    required bool Function() isCancelled,
  }) async {
    final byafService = ByafService();
    final v2Service = V2CardService();
    final repo = Provider.of<CharacterRepository>(context, listen: false);
    final worldRepo = Provider.of<WorldRepository>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);

    for (int i = 0; i < paths.length; i++) {
      if (isCancelled()) break;
      final name = paths[i].split(Platform.pathSeparator).last;
      try {
        final preview = await byafService.parseByaf(paths[i]);
        final card = byafService.toCharacterCard(preview);
        final pngPath = await byafService.saveCharacterPng(
          card,
          charactersDirPath: storage.charactersDir.path,
        );
        await v2Service.saveCardAsPng(
          card,
          pngPath,
          preview.extractedImagePath,
        );
        final imported = await repo.importCharacter(
          File(pngPath),
          worldRepo: worldRepo,
        );
        if (importChats && preview.messages.isNotEmpty && imported != null) {
          final db = await AppDatabase.instance();
          await byafService.importChatHistory(db, preview, imported);
        }
        onProgress(
          i + 1,
          paths.length,
          imported?.name ?? name,
          imported == null ? 'Import returned no character' : null,
        );
      } catch (e) {
        onProgress(i + 1, paths.length, name, '$e');
      }
    }
  }

  Future<void> _folderImportCharacters(BuildContext context) async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder containing character files',
    );

    if (dirPath == null) return;
    if (!context.mounted) return;

    // Scan for both V2 PNG cards and Backyard AI (.byaf) files.
    final pngFiles = <File>[];
    final byafFiles = <File>[];
    await for (final entity in Directory(dirPath).list(recursive: true)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (lower.endsWith('.png')) {
        pngFiles.add(entity);
      } else if (lower.endsWith('.byaf')) {
        byafFiles.add(entity);
      }
    }

    if (pngFiles.isEmpty && byafFiles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No character cards (.png) or Backyard AI files (.byaf) found in '
              'the selected folder.',
            ),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;

    // Breakdown + per-type confirm: a mixed folder never imports anything
    // unexpectedly — the user sees exactly what's there and picks.
    final sel = await _confirmFolderImport(context, pngFiles, byafFiles);
    if (sel == null || !context.mounted) return;
    final (importPng, importByaf, importChats) = sel;

    final pngs = importPng ? pngFiles : <File>[];
    final byafs = importByaf
        ? byafFiles.map((f) => f.path).toList()
        : <String>[];
    if (pngs.isEmpty && byafs.isEmpty) return;

    final total = pngs.length + byafs.length;
    _runBulkProgressImport(
      context,
      title: 'Import Folder',
      totalCount: total,
      runImport: ({required onProgress, required isCancelled}) async {
        var done = 0;
        if (pngs.isNotEmpty) {
          final repo = Provider.of<CharacterRepository>(context, listen: false);
          final worldRepo = Provider.of<WorldRepository>(
            context,
            listen: false,
          );
          await repo.importCharacters(
            pngs,
            worldRepo: worldRepo,
            isCancelled: isCancelled,
            onProgress: (current, _, name, error) =>
                onProgress(done + current, total, name, error),
          );
          done += pngs.length;
        }
        if (byafs.isNotEmpty && !isCancelled()) {
          await _importByafFiles(
            context,
            byafs,
            importChats,
            onProgress: (current, _, name, error) =>
                onProgress(done + current, total, name, error),
            isCancelled: isCancelled,
          );
        }
      },
    );
  }

  /// Per-type confirm for folder import. Shows the breakdown (PNG vs BYAF) with
  /// independent checkboxes so a mixed folder is a conscious choice, not a
  /// surprise. Returns (importPng, importByaf, importChats), or null on cancel.
  Future<(bool, bool, bool)?> _confirmFolderImport(
    BuildContext context,
    List<File> pngFiles,
    List<File> byafFiles,
  ) {
    bool importPng = pngFiles.isNotEmpty;
    bool importByaf = byafFiles.isNotEmpty;
    bool importChats = true;
    final accent = AppColors.resolve(
      context,
      Colors.blueAccent,
      Colors.blue.shade700,
    );
    return showDialog<(bool, bool, bool)>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final count =
              (importPng ? pngFiles.length : 0) +
              (importByaf ? byafFiles.length : 0);
          return AlertDialog(
            backgroundColor: AppColors.surfaceOf(ctx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.library_add, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Import from folder',
                    style: TextStyle(color: AppColors.textPrimary(ctx)),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This folder contains:',
                  style: TextStyle(
                    color: AppColors.textSecondary(ctx),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                if (pngFiles.isNotEmpty)
                  CheckboxListTile(
                    value: importPng,
                    onChanged: (v) => setLocal(() => importPng = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      '${pngFiles.length} character card${pngFiles.length == 1 ? '' : 's'} (V2 PNG)',
                      style: TextStyle(color: AppColors.textPrimary(ctx)),
                    ),
                  ),
                if (byafFiles.isNotEmpty)
                  CheckboxListTile(
                    value: importByaf,
                    onChanged: (v) => setLocal(() => importByaf = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      '${byafFiles.length} Backyard AI file${byafFiles.length == 1 ? '' : 's'} (.byaf)',
                      style: TextStyle(color: AppColors.textPrimary(ctx)),
                    ),
                  ),
                if (byafFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: CheckboxListTile(
                      value: importChats && importByaf,
                      onChanged: importByaf
                          ? (v) => setLocal(() => importChats = v ?? true)
                          : null,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        'also import their chat history',
                        style: TextStyle(
                          color: importByaf
                              ? AppColors.textSecondary(ctx)
                              : AppColors.textTertiary(ctx),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textTertiary(ctx)),
                ),
              ),
              ElevatedButton(
                onPressed: count == 0
                    ? null
                    : () => Navigator.pop(ctx, (
                        importPng,
                        importByaf,
                        importChats,
                      )),
                child: Text('Import $count'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shared bulk PNG import with progress dialog — used by both multi-select
  /// and folder import.
  void _runBulkImport(BuildContext context, List<File> files) {
    _runBulkProgressImport(
      context,
      title: 'Bulk Import',
      totalCount: files.length,
      runImport: ({required onProgress, required isCancelled}) async {
        final repo = Provider.of<CharacterRepository>(context, listen: false);
        final worldRepo = Provider.of<WorldRepository>(context, listen: false);
        await repo.importCharacters(
          files,
          worldRepo: worldRepo,
          isCancelled: isCancelled,
          onProgress: onProgress,
        );
      },
    );
  }

  /// Generic bulk-import progress dialog. Drives any import that reports
  /// (current, total, name, error) per item and honors a cancel flag — used by
  /// both the V2 PNG bulk import and the BYAF (Backyard AI) bulk import.
  void _runBulkProgressImport(
    BuildContext context, {
    required String title,
    required int totalCount,
    required Future<void> Function({
      required void Function(int current, int total, String name, String? error)
      onProgress,
      required bool Function() isCancelled,
    })
    runImport,
  }) {
    bool cancelled = false;
    bool started = false;
    int currentCount = 0;
    int importedCount = 0;
    int failedCount = 0;
    String currentName = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Start the import on first build.
            if (!started) {
              started = true;
              runImport(
                isCancelled: () => cancelled,
                onProgress: (current, total, name, error) {
                  if (ctx.mounted) {
                    setDialogState(() {
                      currentCount = current;
                      currentName = name;
                      if (error == null) {
                        importedCount++;
                      } else {
                        failedCount++;
                      }
                    });
                  }
                },
              ).then((_) {
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  final msg = failedCount > 0
                      ? 'Imported $importedCount character${importedCount == 1 ? '' : 's'} ($failedCount failed)'
                      : 'Imported $importedCount character${importedCount == 1 ? '' : 's'} successfully!';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                }
              });
            }

            final progress = totalCount > 0 ? currentCount / totalCount : 0.0;

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.blueAccent.withValues(alpha: 0.5),
                ),
              ),
              title: Row(
                children: [
                  const Icon(Icons.library_add, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(
                          Colors.blueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Status text
                    Text(
                      currentCount == 0
                          ? 'Starting import...'
                          : 'Importing $currentCount of $totalCount...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Current file name
                    if (currentName.isNotEmpty)
                      Text(
                        currentName,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 16),
                    // Counts row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _bulkStatChip(
                          Icons.check_circle,
                          Colors.green,
                          '$importedCount imported',
                        ),
                        const SizedBox(width: 16),
                        _bulkStatChip(
                          Icons.error,
                          Colors.redAccent,
                          '$failedCount failed',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelled = true;
                  },
                  child: Text(
                    cancelled ? 'Cancelling...' : 'Cancel',
                    style: TextStyle(
                      color: cancelled ? Colors.white38 : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _bulkStatChip(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }

  Future<void> _exportCharacter(BuildContext context, character) async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Character Card',
      fileName: '${character.name}.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (outputFile != null) {
      if (!outputFile.endsWith('.png')) {
        outputFile += '.png';
      }

      try {
        final v2Service = V2CardService();
        await v2Service.saveCardAsPng(
          character,
          outputFile,
          character.imagePath,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Exported to $outputFile')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
        }
      }
    }
  }

  /// Export a character as a standalone Character Card V2 `.json` file.
  /// This is the same JSON embedded in exported PNGs and what the importer
  /// accepts, just without the avatar image.
  Future<void> _exportCharacterJson(BuildContext context, character) async {
    final safeName = character.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Character Card (JSON)',
      fileName: '$safeName.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputFile == null) return;
    if (!outputFile.toLowerCase().endsWith('.json')) {
      outputFile += '.json';
    }

    try {
      await V2CardService().saveCardAsJson(character, outputFile);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported to $outputFile')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  /// Import a Group Card PNG (the novel Front Porch format).
  /// Creates all member characters (with full collision handling) + the group.
  Future<void> _importGroupCard(
    BuildContext context,
    File file,
    GroupCard groupCard,
  ) async {
    final groups = Provider.of<GroupChatRepository>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);
    final db = Provider.of<AppDatabase>(context, listen: false);
    final result = await GroupCardImporter(
      groups,
      storage,
      db,
    ).importCard(groupCard);
    if (!context.mounted) return;
    if (!result.created) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group import failed — no members could be created.'),
        ),
      );
      return;
    }
    final msg = result.failCount > 0
        ? 'Partially imported group "${result.groupName}": ${result.successCount} member(s) succeeded, ${result.failCount} failed. The group shell was created with the successful members only (their data + private avatars are fully usable; use "Separate to my library" to extract any as solo characters).'
        : 'Imported group "${result.groupName}" with ${result.successCount} members!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: result.failCount > 0
            ? Colors.orange.shade700
            : Colors.purpleAccent.shade700,
      ),
    );
  }

  Future<void> _extractCharactersFromGroup(GroupChat group) async {
    final charRepo = Provider.of<CharacterRepository>(context, listen: false);

    // Real members from decoupled table + private avatars (extends this existing method; "Separate to my library" now functional).
    final groupRepo = Provider.of<GroupChatRepository>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);
    final members = await groupRepo.getMembersForGroup(group.id);

    if (members.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No characters found in this group.')),
        );
      }
      return;
    }

    int extracted = 0;
    for (final m in members) {
      try {
        final resolvedPath = m.avatarFilename != null
            ? path.join(
                storage.groupsDir.path,
                group.id,
                'avatars',
                m.avatarFilename!,
              )
            : null;
        if (resolvedPath == null || !await File(resolvedPath).exists()) {
          continue;
        }
        final card = m.toCharacterCard(resolvedImagePath: resolvedPath);
        await charRepo.duplicateCharacter(
          card,
        ); // library copy is the intended "Separate to my library" action
        extracted++;
      } catch (e) {
        debugPrint('Failed to extract ${m.name}: $e');
      }
    }

    if (context.mounted) {
      final msg = extracted == 1
          ? 'Extracted 1 character as an individual.'
          : 'Extracted $extracted characters as individuals.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.teal.shade700),
      );
    }
  }

  /// Export a group as a single self-contained PNG "Group Card".
  /// This is a Front Porch novel format (fpa_group chunk) that bundles every
  /// member character (full data + lorebooks + extensions) plus group settings.
  ///
  /// Zero-compromise fidelity: every member is always included, even if the
  /// private avatar file is missing on disk. For those, a full V2 PNG with
  /// placeholder image + embedded metadata is synthesized on the fly so the
  /// recipient can import the complete group and later "Separate to my library"
  /// any or all members as independent characters.
  Future<void> _exportGroup(GroupChat group) async {
    final context = this.context; // capture from StatefulWidget

    final groupRepo = Provider.of<GroupChatRepository>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);
    final db = Provider.of<AppDatabase>(context, listen: false);

    final members = await groupRepo.getMembersForGroup(group.id);

    if (members.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot export empty group')),
        );
      }
      return;
    }

    final safeName = group.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Group Card',
      fileName: '$safeName.group.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (outputFile != null) {
      if (!outputFile.endsWith('.png')) {
        outputFile += '.png';
      }

      try {
        // Fidelity logic (member avatar embedding, objectives snapshot,
        // stable-id remap, GroupCard assembly) lives in the shared
        // GroupCardExporter so the desktop and web export paths can't diverge.
        await GroupCardExporter(
          groupRepo,
          storage,
          db,
        ).exportToFile(group, outputFile);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Group card exported to $outputFile')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Group export failed: $e')));
        }
      }
    }
  }

}
