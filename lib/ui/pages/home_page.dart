import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/providers/app_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:kobold_character_card_manager/services/character_repository.dart';
import 'package:kobold_character_card_manager/services/world_repository.dart';
import 'package:kobold_character_card_manager/services/folder_service.dart';
import 'package:kobold_character_card_manager/ui/pages/chat_page.dart';
import 'package:kobold_character_card_manager/services/chat_service.dart';
import 'package:kobold_character_card_manager/services/v2_card_service.dart';
import 'package:kobold_character_card_manager/ui/pages/edit_character_page.dart';
import 'package:kobold_character_card_manager/ui/dialogs/tag_dialog.dart';
import 'package:kobold_character_card_manager/models/character_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = '';
  String? _activeFolderId; // null = top level view
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CharacterRepository, FolderService>(
      builder: (context, repo, folderService, child) {
        if (repo.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (repo.characters.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get started by creating a new character!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Provider.of<AppState>(context, listen: false).setIndex(1),
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openBrowser(context),
                      icon: const Icon(Icons.public, color: Colors.blueAccent),
                      label: const Text('AI Character Cards', style: TextStyle(color: Colors.blueAccent)),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () => _showChubWarning(context),
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                      label: const Text('Chub.ai', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Filter characters based on search and active folder
        final filteredCharacters = _getFilteredCharacters(repo, folderService);

        return Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  if (_activeFolderId != null) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back to all characters',
                      onPressed: () => setState(() => _activeFolderId = null),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getActiveFolderName(folderService),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ] else
                    Text('My Characters', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_activeFolderId == null)
                    IconButton(
                      tooltip: 'New Folder',
                      icon: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () => _createFolder(context, folderService),
                    ),
                  IconButton(
                    tooltip: 'Import Card',
                    icon: const Icon(Icons.download),
                    onPressed: () => _importCharacter(context),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openBrowser(context),
                    icon: const Icon(Icons.public),
                    label: const Text('AI Cards'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showChubWarning(context),
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('Chub.ai'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name or tag...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            const SizedBox(height: 12),

            // Grid with folders and characters
            Expanded(
              child: _buildGrid(context, repo, folderService, filteredCharacters),
            ),
          ],
        );
      },
    );
  }

  List<CharacterCard> _getFilteredCharacters(CharacterRepository repo, FolderService folderService) {
    List<CharacterCard> characters;

    if (_activeFolderId != null) {
      // Show only characters in this folder
      final folderPaths = folderService.getCharactersInFolder(_activeFolderId!);
      characters = repo.characters.where((c) => folderPaths.contains(c.imagePath)).toList();
    } else {
      characters = repo.characters.toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      characters = characters.where((c) {
        if (c.name.toLowerCase().contains(query)) return true;
        if (c.tags.any((t) => t.toLowerCase().contains(query))) return true;
        return false;
      }).toList();
    }

    return characters;
  }

  String _getActiveFolderName(FolderService folderService) {
    if (_activeFolderId == null) return 'My Characters';
    final folder = folderService.folders.where((f) => f.id == _activeFolderId).firstOrNull;
    return folder?.name ?? 'Folder';
  }

  Widget _buildGrid(BuildContext context, CharacterRepository repo, FolderService folderService, List<CharacterCard> filteredCharacters) {
    // At top level and not searching, show folder cards + unfoldered characters
    final showFolders = _activeFolderId == null && _searchQuery.isEmpty;
    final folders = showFolders ? folderService.folders : <CharacterFolder>[];

    // At top level, show unfoldered characters only (unless searching)
    List<CharacterCard> displayCharacters;
    if (showFolders) {
      final folderedPaths = folderService.getUnfolderedCharacterPaths();
      displayCharacters = filteredCharacters.where((c) => !folderedPaths.contains(c.imagePath)).toList();
    } else {
      displayCharacters = filteredCharacters;
    }

    final totalItems = folders.length + displayCharacters.length;
    if (totalItems == 0) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? 'No characters match "$_searchQuery"' : 'This folder is empty',
          style: const TextStyle(color: Colors.white38, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 0.7,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Render folder cards first
        if (index < folders.length) {
          return _buildFolderCard(context, folders[index], folderService, repo);
        }
        // Then character cards
        final character = displayCharacters[index - folders.length];
        return _buildCharacterCard(context, character, folderService);
      },
    );
  }

  Widget _buildFolderCard(BuildContext context, CharacterFolder folder, FolderService folderService, CharacterRepository repo) {
    final charCount = folder.characterPaths.length;

    return DragTarget<CharacterCard>(
      onAcceptWithDetails: (details) async {
        await folderService.addToFolder(folder.id, details.data.imagePath!);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Card(
          color: isHovering ? Colors.amber.shade900.withOpacity(0.4) : const Color(0xFF1E293B),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isHovering ? Colors.amber : Colors.white.withOpacity(0.1),
              width: isHovering ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => setState(() => _activeFolderId = folder.id),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder,
                  size: 72,
                  color: isHovering ? Colors.amber : Colors.amber.shade700,
                ),
                const SizedBox(height: 16),
                Text(
                  folder.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '$charCount character${charCount == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                // Folder action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                      tooltip: 'Rename',
                      onPressed: () => _renameFolder(context, folder, folderService),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                      tooltip: 'Delete folder',
                      onPressed: () => _deleteFolder(context, folder, folderService),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCharacterCard(BuildContext context, CharacterCard character, FolderService folderService) {
    return LongPressDraggable<CharacterCard>(
      data: character,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 150,
          height: 200,
          child: Card(
            color: const Color(0xFF1E293B),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: character.imagePath != null
                ? Image.file(File(character.imagePath!), fit: BoxFit.cover)
                : const Icon(Icons.person, size: 64, color: Colors.white24),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCharacterCardInner(context, character, folderService),
      ),
      child: _buildCharacterCardInner(context, character, folderService),
    );
  }

  Widget _buildCharacterCardInner(BuildContext context, CharacterCard character, FolderService folderService) {
    return Card(
      color: Theme.of(context).cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: () async {
              final chatService = Provider.of<ChatService>(context, listen: false);
              await chatService.setActiveCharacter(character);
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatPage()),
                );
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: character.imagePath != null
                      ? Image.file(
                          File(character.imagePath!),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.person, size: 64, color: Colors.white24),
                        ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          character.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Tag chips (show first 3 tags)
                        if (character.tags.isNotEmpty)
                          Flexible(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: character.tags.take(3).map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade900.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(color: Colors.amber.shade300, fontSize: 10),
                                ),
                              )).toList(),
                            ),
                          )
                        else
                          Flexible(
                            child: Text(
                              character.formattedDescription,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _editCharacter(context, character),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _exportCharacter(context, character),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.upload, color: Colors.white, size: 20),
                    ),
                  ),
                  // Remove from folder button (only when inside a folder)
                  if (_activeFolderId != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        await folderService.removeFromFolder(_activeFolderId!, character.imagePath!);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.folder_off, color: Colors.amber, size: 20),
                      ),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _confirmDeleteCharacter(context, character),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Folder Actions ─────────────────────────────────────────────

  void _createFolder(BuildContext context, FolderService folderService) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('New Folder', style: TextStyle(color: Colors.white)),
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
              folderService.createFolder(value.trim());
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                folderService.createFolder(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _renameFolder(BuildContext context, CharacterFolder folder, FolderService folderService) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Rename Folder', style: TextStyle(color: Colors.white)),
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
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                folderService.renameFolder(folder.id, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _deleteFolder(BuildContext context, CharacterFolder folder, FolderService folderService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Text('Delete Folder', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          'Delete "${folder.name}"?\n\nCharacters inside will NOT be deleted — they\'ll return to the top level.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              folderService.deleteFolder(folder.id);
              Navigator.pop(ctx);
              if (_activeFolderId == folder.id) {
                setState(() => _activeFolderId = null);
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
      backgroundColor: Colors.white.withOpacity(0.1),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white24),
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
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text(
              'Delete Character',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
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
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              final repo = Provider.of<CharacterRepository>(context, listen: false);
              final worldRepo = Provider.of<WorldRepository>(context, listen: false);
              await repo.deleteCharacter(character, worldRepo: worldRepo);
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

  Future<void> _editCharacter(BuildContext context, CharacterCard character) async {
     await Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => EditCharacterPage(character: character)),
     );
     if (context.mounted) {
       Provider.of<CharacterRepository>(context, listen: false).loadCharacters();
     }
  }

  Future<void> _importCharacter(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'json'],
    );
    
    if (result != null && result.files.single.path != null) {
      if (!context.mounted) return;
      final file = File(result.files.single.path!);
      try {
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Character imported successfully!')));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
        }
      }
    }
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
         final v2Service = Provider.of<V2CardService>(context, listen: false);
         await v2Service.saveCardAsPng(character, outputFile, character.imagePath);

         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $outputFile')));
         }
       } catch (e) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
         }
       }
    }
  }

  // ─── Browser Integrations ──────────────────────────────────────

  Future<void> _openBrowser(BuildContext context) async {
    final repo = Provider.of<CharacterRepository>(context, listen: false);
    final worldRepo = Provider.of<WorldRepository>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: 'Browse Character Cards',
        titleBarTopPadding: Platform.isMacOS ? 20 : 0,
      ),
    );
    
    Future<void> handleDownloadUrl(String url) async {
      debugPrint('AG_DEBUG: Download card intercepted: $url');
      
      try {
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(url));
        final httpResponse = await request.close();
        
        final bytes = <int>[];
        await for (final chunk in httpResponse) {
          bytes.addAll(chunk);
        }
        
        httpClient.close();
        
        final directory = await getApplicationDocumentsDirectory();
        final charDir = Directory('${directory.path}/KoboldManager/Characters');
        if (!await charDir.exists()) {
          await charDir.create(recursive: true);
        }
        
        final uri = Uri.parse(url);
        String fileName;
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.endsWith('.png')) {
          fileName = uri.pathSegments.last;
        } else {
          fileName = 'card_${DateTime.now().millisecondsSinceEpoch}.png';
        }
        final tempFile = File('${charDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);
        
        final card = await repo.importCharacter(tempFile, worldRepo: worldRepo);
        
        webview.close();
        
        // Show tag dialog after webview closes
        if (card != null && context.mounted) {
          final tags = await TagDialog.show(context, card);
          if (tags != null && context.mounted) {
            card.tags = List.from(tags);
            await repo.updateCharacter(card);
          }
        }

        messenger.showSnackBar(
          SnackBar(
            content: const Text('Character card downloaded and imported!'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      } catch (e) {
        debugPrint('AG_DEBUG: Download error: $e');
        messenger.showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
    
    if (Platform.isMacOS) {
      webview.registerJavaScriptMessageHandler('downloadCard', (name, body) async {
        await handleDownloadUrl(body.toString());
      });
    } else if (Platform.isWindows) {
      webview.addOnWebMessageReceivedCallback((message) async {
        if (message.startsWith('DOWNLOAD:')) {
          final url = message.substring('DOWNLOAD:'.length);
          await handleDownloadUrl(url);
        }
      });
    }
    
    final String jsSendMessage = Platform.isMacOS
        ? 'window.webkit.messageHandlers.downloadCard.postMessage(href)'
        : 'window.chrome.webview.postMessage("DOWNLOAD:" + href)';
    
    webview.addScriptToExecuteOnDocumentCreated('''
      (function() {
        document.addEventListener('click', function(e) {
          var target = e.target;
          while (target && target.tagName !== 'A') {
            target = target.parentElement;
          }
          if (target && target.href) {
            var href = target.href;
            if (href.includes('download_card_image=true') || 
                (href.endsWith('.png') && !href.includes('aicharactercards.com/wp-content/uploads'))) {
              e.preventDefault();
              e.stopPropagation();
              $jsSendMessage;
              return false;
            }
          }
        }, true);
      })();
    ''');
    
    webview.launch('https://aicharactercards.com/');
  }

  Future<void> _openChubBrowser(BuildContext context) async {
    final repo = Provider.of<CharacterRepository>(context, listen: false);
    final worldRepo = Provider.of<WorldRepository>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: 'Chub.ai - Character Hub',
        titleBarTopPadding: Platform.isMacOS ? 20 : 0,
      ),
    );

    Future<void> handleChubDownload(String url) async {
      debugPrint('AG_DEBUG: Chub download intercepted: $url');
      
      try {
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(url));
        final httpResponse = await request.close();
        
        final bytes = <int>[];
        await for (final chunk in httpResponse) {
          bytes.addAll(chunk);
        }
        
        httpClient.close();
        
        final directory = await getApplicationDocumentsDirectory();
        final charDir = Directory('${directory.path}/KoboldManager/Characters');
        if (!await charDir.exists()) {
          await charDir.create(recursive: true);
        }
        
        final uri = Uri.parse(url);
        String fileName;
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.endsWith('.png')) {
          fileName = uri.pathSegments.last;
        } else {
          fileName = 'chub_card_${DateTime.now().millisecondsSinceEpoch}.png';
        }
        final tempFile = File('${charDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);
        
        final card = await repo.importCharacter(tempFile, worldRepo: worldRepo);
        
        webview.close();

        // Show tag dialog — Chub.ai cards likely have tags already
        if (card != null && context.mounted) {
          final tags = await TagDialog.show(context, card);
          if (tags != null && context.mounted) {
            card.tags = List.from(tags);
            await repo.updateCharacter(card);
          }
        }

        messenger.showSnackBar(
          SnackBar(
            content: const Text('Chub character downloaded and imported!'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      } catch (e) {
        debugPrint('AG_DEBUG: Chub download error: $e');
        messenger.showSnackBar(
          SnackBar(
            content: Text('Chub download failed: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }

    if (Platform.isMacOS) {
      webview.registerJavaScriptMessageHandler('downloadCard', (name, body) async {
        await handleChubDownload(body.toString());
      });
    } else if (Platform.isWindows) {
      webview.addOnWebMessageReceivedCallback((message) async {
        if (message.startsWith('DOWNLOAD:')) {
          final url = message.substring('DOWNLOAD:'.length);
          await handleChubDownload(url);
        }
      });
    }

    final String jsSendMessage = Platform.isMacOS
        ? 'window.webkit.messageHandlers.downloadCard.postMessage(href)'
        : 'window.chrome.webview.postMessage("DOWNLOAD:" + href)';

    webview.addScriptToExecuteOnDocumentCreated('''
      (function() {
        document.addEventListener('click', function(e) {
          var target = e.target;
          while (target && target.tagName !== 'A') {
            target = target.parentElement;
          }
          if (target && target.href) {
            var href = target.href;
            if (href.endsWith('.png') || 
                href.includes('/download') ||
                href.includes('characterhub.org/characters/download') ||
                (target.hasAttribute('download') && href.includes('.png'))) {
              e.preventDefault();
              e.stopPropagation();
              $jsSendMessage;
              return false;
            }
          }
        }, true);
      })();
    ''');

    webview.launch('https://chub.ai/');
  }

  void _showChubWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2D1111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text(
              '⚠️ TRAVELER, BEWARE ⚠️',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/eye_bleach.jpg',
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You are about to enter Chub.ai — a land where content '
                'moderation is more of a suggestion than a rule.',
                style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'You WILL encounter NSFW and potentially NSFL content. '
                'There is no "safe" section. There is no lifeguard on duty. '
                'Eye bleach is strongly advised — and may still not be enough.',
                style: TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Browse at your own discretion. '
                'We are not responsible for what you find... '
                'or what finds you. 👁️',
                style: TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Nope, I Choose Life', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _openChubBrowser(context);
            },
            child: const Text('I Fear Nothing. Proceed.'),
          ),
        ],
      ),
    );
  }
}
