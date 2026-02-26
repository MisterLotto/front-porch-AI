import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/ui/dialogs/edit_character_dialog.dart';
import 'package:front_porch_ai/ui/dialogs/chat_settings_dialog.dart';
import 'package:front_porch_ai/ui/dialogs/model_settings_dialog.dart';
import 'package:front_porch_ai/ui/dialogs/tts_settings_dialog.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';
import 'package:front_porch_ai/ui/dialogs/user_persona_dialog.dart';
import 'package:front_porch_ai/ui/dialogs/context_viewer_dialog.dart';
import 'package:front_porch_ai/services/tts_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/voice_manager.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:file_picker/file_picker.dart';

class _StyledTextController extends TextEditingController {
  static final _pattern = RegExp(r'("[^"]*")|(\*[^*]*\*)');

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final text = this.text;
    final matches = _pattern.allMatches(text);

    if (matches.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final List<TextSpan> spans = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: style));
      }
      final matchText = match.group(0)!;
      if (matchText.startsWith('"')) {
        spans.add(TextSpan(
          text: matchText,
          style: style?.copyWith(color: Colors.amberAccent, fontWeight: FontWeight.w500),
        ));
      } else {
        spans.add(TextSpan(
          text: matchText,
          style: style?.copyWith(color: const Color(0xFF90CAF9)),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return TextSpan(children: spans, style: style);
  }
}


class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _StyledTextController _controller = _StyledTextController();
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  double _sidebarWidth = 300;

  @override
  void initState() {
    super.initState();
    // Auto-scroll logic could be enhanced here
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && _autoScroll) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatService>(
      builder: (context, chatService, child) {
        final character = chatService.activeCharacter;
        final messages = chatService.messages;
        final isGroup = chatService.isGroupMode;

        if (character == null && !isGroup) {
          return const Center(child: Text('No character selected.'));
        }
        
        // Trigger scroll on build if messages changed
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFF111827), // Darker background like Backyard
              appBar: isGroup
                  ? _buildGroupAppBar(context, chatService)
                  : _buildAppBar(context, character!),
              body: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final storageService = Provider.of<StorageService>(context);
                              final bgKey = storageService.chatBackground;
                              const bgAssets = {
                                'cyberpunk_bedroom': 'assets/backgrounds/cyberpunk_bedroom.png',
                                'coffee_shop': 'assets/backgrounds/coffee_shop.png',
                                'beach': 'assets/backgrounds/beach.png',
                                'futuristic_city': 'assets/backgrounds/futuristic_city.png',
                                'edm_rave': 'assets/backgrounds/edm_rave.png',
                                'cozy_library': 'assets/backgrounds/cozy_library.png',
                                'rainy_japan': 'assets/backgrounds/rainy_japan.png',
                                'space_station': 'assets/backgrounds/space_station.png',
                                'enchanted_forest': 'assets/backgrounds/enchanted_forest.png',
                                'anime_cherry_blossom': 'assets/backgrounds/anime_cherry_blossom.png',
                                'anime_rooftop': 'assets/backgrounds/anime_rooftop.png',
                                'anime_rooftop_sunset': 'assets/backgrounds/anime_rooftop_sunset.png',
                                'cherry_blossom': 'assets/backgrounds/cherry_blossom.png',
                                'beach_waves': 'assets/backgrounds/beach_waves.png',
                                'waifu_gaming_room': 'assets/backgrounds/waifu_gaming_room.png',
                                'waifu_beach_bar': 'assets/backgrounds/waifu_beach_bar.png',
                                'waifu_garden': 'assets/backgrounds/waifu_garden.png',
                                'waifu_neon': 'assets/backgrounds/waifu_neon.png',
                                'waifu_beach': 'assets/backgrounds/waifu_beach.png',
                              };
                              final bgPath = bgAssets[bgKey];

                              return Stack(
                                children: [
                                  if (bgPath != null) ...[
                                    Positioned.fill(
                                      child: Image.asset(
                                        bgPath,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black.withOpacity(0.45),
                                      ),
                                    ),
                                  ],
                                  ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(20),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final msg = messages[index];
                                      // In group mode, pass the character's image based on sender
                                      File? senderImage;
                                      Color? senderColor;
                                      if (isGroup && !msg.isUser) {
                                        final senderChar = chatService.groupCharacters
                                            .where((c) => c.name == msg.sender)
                                            .firstOrNull;
                                        senderImage = senderChar?.imagePath != null ? File(senderChar!.imagePath!) : null;
                                        final senderIdx = chatService.groupCharacters
                                            .indexWhere((c) => c.name == msg.sender);
                                        senderColor = _groupCharacterColor(senderIdx >= 0 ? senderIdx : 0);
                                      } else {
                                        senderImage = character?.imagePath != null ? File(character!.imagePath!) : null;
                                      }
                                      return _MessageBubble(
                                        message: msg, 
                                        characterImage: senderImage,
                                        index: index,
                                        senderColor: senderColor,
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (chatService.isGenerating)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A2332),
                              border: Border(top: BorderSide(color: Colors.white10)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      chatService.isBuffering ? 'Buffering...' : 'Generating response...',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${chatService.tokensPerSecond.toStringAsFixed(1)} t/s',
                                      style: const TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${chatService.tokensGenerated} / ${chatService.maxTokens} tokens',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${(chatService.generationProgress * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: chatService.generationProgress,
                                    minHeight: 4,
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color.lerp(
                                        const Color(0xFF3B82F6),
                                        const Color(0xFF10B981),
                                        chatService.generationProgress,
                                      )!,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  _buildInputArea(context, chatService),
                      ],
                    ),
                  ),
                  if (isGroup)
                    _buildResizableSidebar(
                      child: _buildGroupSidebar(chatService),
                    )
                  else if (character != null)
                    _buildResizableSidebar(
                      child: _buildRightSidebar(character, chatService),
                    ),
                ],
              ),
            ),
            if (chatService.isLoadingSession)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, CharacterCard character) {
    return AppBar(
      backgroundColor: const Color(0xFF1F2937),
      elevation: 0, 
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          CircleAvatar(
            backgroundImage: character.imagePath != null ? FileImage(File(character.imagePath!)) : null,
            child: character.imagePath == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(character.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (character.description.isNotEmpty)
                Text(
                  character.description.length > 30 ? '${character.description.substring(0, 30)}...' : character.description, 
                  style: const TextStyle(fontSize: 12, color: Colors.white54)
                ),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildGroupAppBar(BuildContext context, ChatService chatService) {
    final group = chatService.activeGroup!;
    final chars = chatService.groupCharacters;
    return AppBar(
      backgroundColor: const Color(0xFF1F2937),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          // Stacked avatars
          SizedBox(
            width: 24.0 + (chars.length.clamp(0, 4) - 1) * 16,
            height: 32,
            child: Stack(
              children: [
                for (int i = 0; i < chars.length.clamp(0, 4); i++)
                  Positioned(
                    left: i * 16.0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: _groupCharacterColor(i),
                      backgroundImage: chars[i].imagePath != null ? FileImage(File(chars[i].imagePath!)) : null,
                      child: chars[i].imagePath == null
                          ? Text(chars[i].name[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                '${chars.length} characters • ${group.turnOrder.name}',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Per-character color palette for group chats.
  static Color _groupCharacterColor(int index) {
    const colors = [
      Color(0xFF8B5CF6), // Purple
      Color(0xFF10B981), // Emerald
      Color(0xFFF59E0B), // Amber
      Color(0xFFEF4444), // Red
      Color(0xFF3B82F6), // Blue
      Color(0xFFEC4899), // Pink
      Color(0xFF14B8A6), // Teal
      Color(0xFFF97316), // Orange
    ];
    return colors[index % colors.length];
  }

  Future<void> _importChat() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final jsonData = await file.readAsString();
      
      if (!mounted) return;
      
      final chatService = Provider.of<ChatService>(context, listen: false);
      await chatService.importFromSillyTavern(jsonData);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat imported successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text('Import Failed'),
          content: Text('Error importing chat: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportChat() async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final jsonData = chatService.exportToSillyTavern();
      
      if (jsonData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No chat to export'), backgroundColor: Colors.orange),
        );
        return;
      }

      final characterName = chatService.activeCharacter?.name ?? 'chat';
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = '${characterName}_$timestamp.json';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Chat',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (path == null) return;

      final file = File(path);
      await file.writeAsString(jsonData);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat exported successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text('Export Failed'),
          content: Text('Error exporting chat: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showClearChatConfirmation(BuildContext context) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('New Chat'),
        content: const Text('This will clear the current conversation and start fresh. This can\'t be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              chatService.startNewChat();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('New Chat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    var sessions = await chatService.getSessions();

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text('Chat History'),
          content: SizedBox(
            width: 420,
            height: 350,
            child: sessions.isEmpty 
              ? const Center(child: Text('No previous chats found.'))
              : ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    final date = s['date'] as DateTime;
                    final dateStr = '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute.toString().padLeft(2, "0")}';
                    final isCurrent = s['id'] == chatService.currentSessionId;
                    final isBranch = s['parent_session'] != null;
                    final description = s['session_description'] as String?;

                    return ListTile(
                      leading: isBranch 
                        ? const Icon(Icons.call_split, size: 18, color: Colors.blueAccent) 
                        : null,
                      title: Text(s['preview'], style: const TextStyle(fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                          if (description != null && description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                description,
                                style: const TextStyle(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (isBranch)
                            Text('↳ Branched at message #${(s['fork_index'] ?? 0) + 1}',
                              style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: Colors.white38),
                            tooltip: 'Edit name & description',
                            onPressed: () => _showEditSessionDialog(
                              context, chatService, s,
                              onSaved: () async {
                                sessions = await chatService.getSessions();
                                setDialogState(() {});
                              },
                            ),
                          ),
                          if (isCurrent)
                            const Icon(Icons.check, color: Colors.greenAccent),
                        ],
                      ),
                      onTap: () {
                        chatService.loadSession(s['id']);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSessionDialog(
    BuildContext context,
    ChatService chatService,
    Map<String, dynamic> session, {
    required VoidCallback onSaved,
  }) {
    final nameController = TextEditingController(text: session['session_name'] ?? '');
    final descController = TextEditingController(text: session['session_description'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Edit Chat Session'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Session Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: 'e.g. "Adventure in the forest"',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF374151),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: 'Optional — appears under the timestamp',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF374151),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await chatService.renameSession(session['id'], nameController.text.trim());
              await chatService.updateSessionDescription(session['id'], descController.text.trim());
              Navigator.of(ctx).pop();
              onSaved();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ChatService chatService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Persona Switcher
          Consumer<UserPersonaService>(
            builder: (context, personaService, _) {
              final persona = personaService.persona;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0, bottom: 6),
                child: GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const UserPersonaDialog(),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    backgroundImage: persona.avatarPath != null ? FileImage(File(persona.avatarPath!)) : null,
                    child: persona.avatarPath == null 
                      ? const Icon(Icons.person, size: 18, color: Colors.white70) 
                      : null,
                  ),
                ),
              );
            },
          ),

          // Chat Management Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.folder_open, color: Colors.white70),
            padding: EdgeInsets.zero,
            tooltip: 'Chat Management',
            onSelected: (value) {
              if (value == 'new_chat') {
                _showClearChatConfirmation(context);
              } else if (value == 'history') {
                _showHistoryDialog(context);
              } else if (value == 'import') {
                _importChat();
              } else if (value == 'export') {
                _exportChat();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_chat',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 20),
                    SizedBox(width: 12),
                    Text('New Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20),
                    SizedBox(width: 12),
                    Text('Chat History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, size: 20),
                    SizedBox(width: 12),
                    Text('Import Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 20),
                    SizedBox(width: 12),
                    Text('Export Chat'),
                  ],
                ),
              ),
            ],
          ),
          
          // Magic Wand (Quick Impersonate)
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Colors.white70),
            padding: EdgeInsets.zero,
            tooltip: 'Impersonate',
            onPressed: chatService.isGenerating ? null : () {
              final prefix = _controller.text;
              chatService.impersonateUser(
                prefix: prefix,
                onToken: (accumulated) {
                  _controller.text = accumulated;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: accumulated.length),
                  );
                },
              );
            },
          ),

          // Context Budget Viewer
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white70),
            padding: EdgeInsets.zero,
            tooltip: 'Context Budget',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ContextViewerDialog(chatService: chatService),
              );
            },
          ),
          
          const SizedBox(width: 4),

          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.send,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: chatService.observerMode ? 'Direct the scene...' : 'Type a message...',
                hintStyle: TextStyle(color: chatService.observerMode ? Colors.amberAccent.withValues(alpha: 0.5) : Colors.white38),
                filled: true,
                fillColor: const Color(0xFF374151),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty && !chatService.isGenerating) {
                  chatService.sendMessage(value);
                  _controller.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          // Auto-play button (observer mode only)
          if (chatService.isGroupMode && chatService.observerMode && !chatService.isGenerating)
            Tooltip(
              message: chatService.autoPlayActive ? 'Pause auto-chat' : 'Start auto-chat',
              child: IconButton(
                icon: Icon(
                  chatService.autoPlayActive ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: chatService.autoPlayActive ? Colors.orangeAccent : Colors.amberAccent,
                ),
                onPressed: () {
                  if (chatService.autoPlayActive) {
                    chatService.stopAutoPlay();
                  } else {
                    chatService.startAutoPlay();
                  }
                },
              ),
            ),
          // Next Character button (group mode only, not in auto-play)
          if (chatService.isGroupMode && !chatService.isGenerating && !chatService.autoPlayActive)
            Tooltip(
              message: chatService.nextCharacter != null
                  ? 'Next: ${chatService.nextCharacter!.name}'
                  : 'Trigger next character',
              child: IconButton(
                icon: const Icon(Icons.group, color: Colors.purpleAccent),
                onPressed: () => chatService.triggerNextCharacter(),
              ),
            ),
          chatService.isGenerating
            ? IconButton(
                icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
                tooltip: chatService.autoPlayActive ? 'Stop Auto-Chat' : 'Stop Generation',
                onPressed: () {
                  chatService.stopAutoPlay();
                  chatService.stopGeneration();
                },
              )
            : Tooltip(
                message: chatService.observerMode ? 'Send director note' : 'Send message',
                child: IconButton(
                icon: Icon(
                  chatService.observerMode ? Icons.movie_creation : Icons.send,
                  color: chatService.observerMode ? Colors.amberAccent : Colors.blueAccent,
                ),
                onPressed: () {
                   if (_controller.text.isNotEmpty && !chatService.isGenerating) {
                      chatService.sendMessage(_controller.text);
                      _controller.clear();
                   }
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Wraps a sidebar widget with a draggable resize handle on its left edge.
  Widget _buildResizableSidebar({required Widget child}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _sidebarWidth = (_sidebarWidth - details.delta.dx).clamp(100, double.infinity);
              });
            },
            child: Container(
              width: 6,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: _sidebarWidth, child: child),
      ],
    );
  }

  Widget _buildRightSidebar(CharacterCard character, ChatService chatService) {
    final userName = Provider.of<UserPersonaService>(context, listen: false).persona.name;
    String replace(String text) {
      return text.replaceAll('{{char}}', character.name).replaceAll('{{user}}', userName);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          if (character.imagePath != null)
             Image.file(File(character.imagePath!), height: _sidebarWidth, width: _sidebarWidth, fit: BoxFit.cover),
          
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                       final result = await showDialog(
                         context: context,
                         builder: (context) => EditCharacterDialog(character: character),
                       );
                       if (result == true) {
                         // Force rebuild if character changed
                         setState(() {});
                       }
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Character'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                           showDialog(
                             context: context,
                             builder: (context) => const ChatSettingsDialog(),
                           );
                        },
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Chat', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                             context: context,
                             builder: (context) => const ModelSettingsDialog(),
                           );
                        },
                        icon: const Icon(Icons.memory, size: 16),
                        label: const Text('Model', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                             context: context,
                             builder: (context) => const TtsSettingsDialog(),
                           );
                        },
                        icon: const Icon(Icons.volume_up, size: 16),
                        label: const Text('TTS', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Lorebook Triggers', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 8),
                if (character.lorebook != null && character.lorebook!.entries.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // List entries with status dots
                      if (character.lorebook!.entries.where((e) => e.enabled).isEmpty)
                         const Text('No enabled entries.', style: TextStyle(color: Colors.white30, fontSize: 12)),
                      
                      ...character.lorebook!.entries.where((e) => e.enabled).map((entry) {
                         Color dotColor = Colors.redAccent;
                         if (entry.constant) {
                           dotColor = Colors.blueAccent;
                         } else if (entry.isTriggered) {
                           dotColor = Colors.greenAccent;
                         }

                         return Padding(
                           padding: const EdgeInsets.symmetric(vertical: 4.0),
                           child: Row(
                             children: [
                               Container(
                                 width: 8,
                                 height: 8,
                                 decoration: BoxDecoration(
                                   color: dotColor,
                                   shape: BoxShape.circle,
                                 ),
                               ),
                               const SizedBox(width: 8),
                               Expanded(
                                 child: Text(
                                   entry.key.isEmpty && entry.constant ? 'Always Active' : entry.displayName, 
                                   style: TextStyle(
                                     color: (entry.isTriggered || entry.constant) ? Colors.white : Colors.white54,
                                     fontSize: 12
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ),
                             ],
                           ),
                         );
                      }),
                    ],
                  )
                else
                  const Text('No lorebook entries.', style: TextStyle(color: Colors.white30, fontSize: 12)),
                  
                const SizedBox(height: 16),
                // Author's Note — editable
                _AuthorNoteSection(chatService: chatService),
                const SizedBox(height: 16),
                _SidebarSection(title: 'Scenario', content: replace(character.scenario)),
                const SizedBox(height: 16),
                _SidebarSection(title: 'Description', content: replace(character.description)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sidebar showing all characters in a group.
  Widget _buildGroupSidebar(ChatService chatService) {
    final chars = chatService.groupCharacters;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Settings buttons ──
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const ChatSettingsDialog(),
                          );
                        },
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Chat', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const ModelSettingsDialog(),
                          );
                        },
                        icon: const Icon(Icons.memory, size: 16),
                        label: const Text('Model', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const TtsSettingsDialog(),
                          );
                        },
                        icon: const Icon(Icons.volume_up, size: 16),
                        label: const Text('TTS', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showClearChatConfirmation(context),
                    icon: const Icon(Icons.add_comment, size: 16),
                    label: const Text('New Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // ── Director Mode toggle ──
                Row(
                  children: [
                    const Icon(Icons.movie_creation, size: 16, color: Colors.white54),
                    const SizedBox(width: 8),
                    const Text('Director Mode', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    Switch(
                      value: chatService.observerMode,
                      activeColor: Colors.amberAccent,
                      onChanged: chatService.isGenerating ? null : (val) => chatService.setObserverMode(val),
                    ),
                  ],
                ),
                if (chatService.observerMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Text(
                      'Characters chat autonomously. Use the input box to direct the scene.',
                      style: TextStyle(fontSize: 10, color: Colors.amberAccent.withValues(alpha: 0.7)),
                    ),
                  ),
                  // Delay slider
                  Consumer<StorageService>(
                    builder: (context, storage, _) {
                      chatService.directorDelaySec = storage.directorDelay;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Response Delay', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              const Spacer(),
                              Text('${storage.directorDelay.toStringAsFixed(1)}s',
                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              value: storage.directorDelay,
                              min: 0.5,
                              max: 60.0,
                              divisions: 119,
                              activeColor: Colors.amberAccent,
                              inactiveColor: Colors.white12,
                              onChanged: (val) => storage.setDirectorDelay(val),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text('Characters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Tap a character to make them respond next',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: chars.length,
              itemBuilder: (context, index) {
                final ch = chars[index];
                final color = _groupCharacterColor(index);
                final isNext = chatService.nextCharacter?.name == ch.name;
                return GestureDetector(
                  onTap: chatService.isGenerating ? null : () => chatService.setNextCharacter(ch),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isNext ? color.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isNext ? Border.all(color: color.withValues(alpha: 0.4)) : null,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: color,
                        backgroundImage: ch.imagePath != null ? FileImage(File(ch.imagePath!)) : null,
                        child: ch.imagePath == null
                            ? Text(ch.name[0], style: const TextStyle(fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: Text(ch.name, style: const TextStyle(fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ch.description.length > 40 ? '${ch.description.substring(0, 40)}...' : ch.description,
                            style: const TextStyle(fontSize: 11, color: Colors.white38),
                          ),
                          TextButton.icon(
                            onPressed: () => _showVoicePickerForCharacter(ch),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(Icons.record_voice_over, size: 12, color: ch.ttsVoice != null ? Colors.amberAccent : Colors.white24),
                            label: Text(
                              ch.ttsVoice ?? 'Default voice',
                              style: TextStyle(fontSize: 10, color: ch.ttsVoice != null ? Colors.amberAccent : Colors.white24),
                            ),
                          ),
                        ],
                      ),
                      trailing: isNext
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purpleAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                              ),
                              child: const Text('Next ▶', style: TextStyle(fontSize: 10, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                            )
                          : null,
                      dense: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showVoicePickerForCharacter(CharacterCard character) {
    final tts = Provider.of<TtsService>(context, listen: false);
    final voices = tts.activeVoices;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: Text('Voice for ${character.name}', style: const TextStyle(fontSize: 16)),
          content: SizedBox(
            width: 300,
            height: 400,
            child: voices.isEmpty
                ? const Center(
                    child: Text(
                      'No voices available.\nConfigure a TTS engine in TTS Settings first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.block, color: Colors.white38),
                        title: const Text('Use global default', style: TextStyle(color: Colors.white70)),
                        selected: character.ttsVoice == null,
                        selectedTileColor: Colors.blueAccent.withValues(alpha: 0.1),
                        onTap: () {
                          character.ttsVoice = null;
                          Provider.of<CharacterRepository>(ctx, listen: false).updateCharacter(character);
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                      ),
                      ...voices.map((v) => ListTile(
                        leading: Icon(
                          v.gender == 'Female' ? Icons.female : v.gender == 'Male' ? Icons.male : Icons.record_voice_over,
                          size: 18,
                          color: v.gender == 'Female' ? Colors.pinkAccent : v.gender == 'Male' ? Colors.cyanAccent : Colors.amberAccent,
                        ),
                        title: Text(v.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text('${v.language} · ${v.gender}',
                            style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        selected: character.ttsVoice == v.id,
                        selectedTileColor: Colors.blueAccent.withValues(alpha: 0.1),
                        onTap: () {
                          character.ttsVoice = v.id;
                          Provider.of<CharacterRepository>(ctx, listen: false).updateCharacter(character);
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                      )),
                    ],
                  ),
          ),
        );
      },
    );
  }
}



class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final File? characterImage;
  final int index;
  final Color? senderColor; // Non-null in group mode

  const _MessageBubble({required this.message, this.characterImage, required this.index, this.senderColor});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _thoughtExpanded = false;

  ChatMessage get message => widget.message;
  File? get characterImage => widget.characterImage;
  int get index => widget.index;

  @override
  Widget build(BuildContext context) {
    final isDirectorNote = message.characterId == '__director__';
    final bubbleOpacity = Provider.of<StorageService>(context).bubbleOpacity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isDirectorNote
            ? MainAxisAlignment.center
            : (message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start),
        children: [
          if (!message.isUser && !isDirectorNote) 
            CircleAvatar(
              backgroundImage: characterImage != null ? FileImage(characterImage!) : null,
              child: characterImage == null ? const Icon(Icons.person) : null,
              radius: 16,
            ),
          if (!message.isUser && !isDirectorNote) const SizedBox(width: 12),
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDirectorNote
                    ? Colors.amberAccent.withValues(alpha: 0.1 * bubbleOpacity)
                    : message.isUser
                        ? const Color(0xFF3B82F6).withValues(alpha: bubbleOpacity)
                        : widget.senderColor != null
                            ? widget.senderColor!.withValues(alpha: 0.15 * bubbleOpacity)
                            : const Color(0xFF374151).withValues(alpha: bubbleOpacity),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: message.isUser && !isDirectorNote ? const Radius.circular(12) : Radius.zero,
                  bottomRight: message.isUser && !isDirectorNote ? Radius.zero : const Radius.circular(12),
                ),
                border: isDirectorNote ? Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDirectorNote) ...[
                        const Icon(Icons.movie_creation, size: 14, color: Colors.amberAccent),
                        const SizedBox(width: 6),
                        const Text('Director', style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.amberAccent,
                          fontStyle: FontStyle.italic,
                        )),
                        const Spacer(),
                      ] else if (!message.isUser) ...[
                        Text(message.sender, style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: widget.senderColor ?? Colors.blueAccent,
                        )),
                        const Spacer(),
                      ],
                      // TTS speaker button
                      if (!message.isUser && message.sender != 'System' && !isDirectorNote)
                        Consumer2<TtsService, StorageService>(
                          builder: (context, tts, storage, _) {
                            if (!storage.ttsEnabled) return const SizedBox.shrink();
                            final msgId = 'msg_${widget.index}';
                            final isThisMsg = tts.currentMessageId == msgId;
                            final isGeneratingThis = isThisMsg && tts.isGenerating;
                            final isSpeakingThis = isThisMsg && tts.isSpeaking && !tts.isGenerating;

                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: isGeneratingThis
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => tts.stop(),
                                        borderRadius: BorderRadius.circular(10),
                                        child: const Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Icon(Icons.stop_circle, size: 16, color: Colors.redAccent),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                value: tts.generationProgress > 0 ? tts.generationProgress : null,
                                                strokeWidth: 2,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                            if (tts.generationProgress > 0)
                                              Text(
                                                '${(tts.generationProgress * 100).toInt()}',
                                                style: const TextStyle(color: Colors.white54, fontSize: 7),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : IconButton(
                                  icon: Icon(
                                    isSpeakingThis ? Icons.stop_circle : Icons.volume_up,
                                    size: 16,
                                    color: isSpeakingThis ? Colors.orangeAccent : Colors.white38,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: isSpeakingThis ? 'Stop speaking' : 'Speak message',
                                  onPressed: () {
                                    if (isSpeakingThis) {
                                      tts.stop();
                                    } else {
                                      final chatService = Provider.of<ChatService>(context, listen: false);
                                      String? voiceKey;
                                      if (chatService.activeGroup != null) {
                                        final charMatch = chatService.groupCharacters
                                            .where((c) => c.name == message.sender)
                                            .firstOrNull;
                                        voiceKey = charMatch?.ttsVoice;
                                      } else {
                                        voiceKey = chatService.activeCharacter?.ttsVoice;
                                      }
                                      tts.speak(
                                        message.displayText,
                                        voiceKey: voiceKey,
                                        messageId: msgId,
                                      );
                                    }
                                  },
                                ),
                            );
                          },
                        ),
                      if (message.sender != 'System') 
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white38),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Edit message',
                          onPressed: () => _showEditDialog(context, index),
                        ),
                      if (message.sender != 'System')
                        const SizedBox(width: 8),
                      if (message.sender != 'System') 
                        IconButton(
                          icon: const Icon(Icons.call_split, size: 16, color: Colors.white38),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Fork from here',
                          onPressed: () => _showForkConfirmation(context, index),
                        ),
                      if (message.sender != 'System')
                        const SizedBox(width: 8),
                      if (message.sender != 'System') 
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white38),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showDeleteConfirmation(context, index),
                        ),
                    ],
                  ),
                  if (!message.isUser) const SizedBox(height: 4),
                  // Collapsible Thought chip
                  if (!message.isUser && message.hasThinking)
                    GestureDetector(
                      onTap: () => setState(() => _thoughtExpanded = !_thoughtExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _thoughtExpanded ? Icons.expand_more : Icons.chevron_right,
                              size: 20,
                              color: Colors.white54,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A4A5A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Thought',
                                style: const TextStyle(fontSize: 12, color: Colors.tealAccent, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                          ],
                        ),
                      ),
                    ),
                  // Expanded thinking details
                  if (!message.isUser && message.hasThinking && _thoughtExpanded)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8, left: 20),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A3A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.thinkingDurationMs > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Thought for ${(message.thinkingDurationMs / 1000).toStringAsFixed(1)}s',
                                style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontStyle: FontStyle.italic),
                              ),
                            ),
                          if (message.thinkingContent != null)
                            Text(
                              message.thinkingContent!,
                              style: const TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                        ],
                      ),
                    ),
                  // Live thinking timer
                  if (!message.isUser && message.thinkingStartTime != null && message.thinkingDurationMs == 0)
                    Consumer<ChatService>(
                      builder: (context, chatService, _) {
                        if (!chatService.isGenerating) return const SizedBox.shrink();
                        final elapsed = DateTime.now().millisecondsSinceEpoch - message.thinkingStartTime!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 10, height: 10,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.tealAccent),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Thinking ${(elapsed / 1000).toStringAsFixed(0)}s...',
                                style: const TextStyle(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  _StyledChatMessage(text: message.displayText, isUser: message.isUser),
                  // Swipe arrows for alternate greetings on first message
                  if (index == 0 && !message.isUser)
                    Consumer<ChatService>(
                      builder: (context, chatService, _) {
                        final character = chatService.activeCharacter;
                        if (character == null) return const SizedBox.shrink();
                        final allGreetings = character.allGreetings;
                        if (allGreetings.length <= 1) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () => chatService.cycleGreeting(-1),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.chevron_left, size: 20, color: Colors.white54),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${chatService.greetingIndex + 1}/${allGreetings.length}',
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => chatService.cycleGreeting(1),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.chevron_right, size: 20, color: Colors.white54),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                // Action buttons: regen, continue, swipe arrows
                if (!message.isUser && message.sender != 'System')
                  Consumer<ChatService>(
                    builder: (context, chatService, _) {
                      final isLastBotMessage = index == chatService.messages.length - 1 && !chatService.isGenerating;
                      final hasSwipes = message.swipes.length > 1;

                      // Nothing to show if not last message and no swipes
                      if (!isLastBotMessage && !hasSwipes) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Regen button — last bot message only
                            if (isLastBotMessage) ...[
                              Tooltip(
                                message: 'Regenerate',
                                child: InkWell(
                                  onTap: () => chatService.regenerateLastMessage(),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.refresh, size: 20, color: Colors.orangeAccent),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Continue button
                              Tooltip(
                                message: 'Continue generation',
                                child: InkWell(
                                  onTap: () => chatService.continueGeneration(),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.arrow_downward, size: 20, color: Colors.blue),
                                  ),
                                ),
                              ),
                              if (hasSwipes) const SizedBox(width: 12),
                            ],
                            // Swipe arrows — only when multiple swipes exist
                            if (hasSwipes) ...[
                              InkWell(
                                onTap: () => chatService.swipeMessage(index, -1),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.chevron_left, size: 20, color: Colors.white54),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${message.swipeIndex + 1}/${message.swipes.length}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => chatService.swipeMessage(index, 1),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.chevron_right, size: 20, color: Colors.white54),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          if (message.isUser) const SizedBox(width: 12),
           if (message.isUser) 
            Consumer<UserPersonaService>(
              builder: (context, service, _) {
                final persona = service.personas.where((p) => p.name == message.sender).firstOrNull;
                if (persona?.avatarPath != null) {
                  return CircleAvatar(
                    backgroundImage: FileImage(File(persona!.avatarPath!)),
                    radius: 16,
                  );
                }
                return const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.person, color: Colors.white),
                  radius: 16,
                );
              },
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, int index) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Delete Message'),
        content: const Text('This can\'t be undone. Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              chatService.deleteMessage(index);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showForkConfirmation(BuildContext context, int index) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: Row(
          children: const [
            Icon(Icons.call_split, color: Colors.blueAccent, size: 22),
            SizedBox(width: 8),
            Text('Fork Conversation'),
          ],
        ),
        content: Text('Create a new branch from message #${index + 1}?\n\nThe current chat will remain unchanged. A new conversation will be created with messages up to this point.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              chatService.forkFromMessage(index);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Conversation forked! You are now on the new branch.')),
                );
              }
            },
            icon: const Icon(Icons.call_split, size: 18),
            label: const Text('Fork'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, int index) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final controller = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Edit Message'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            maxLines: 10,
            minLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF374151),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              chatService.editMessage(index, controller.text);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StyledChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const _StyledChatMessage({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final storageService = Provider.of<StorageService>(context);
    final scaledSize = 14.0 * storageService.textScale;
    // Two-pass approach:
    // Pass 1: Split on asterisk blocks *...* (including multi-line)
    // Pass 2: Within each segment, colorize quoted dialogue "..."
    // This ensures quotes inside asterisk blocks still get yellow treatment

    final plainStyle = TextStyle(color: Colors.white, fontSize: scaledSize);
    final dialogueStyle = TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w500, fontSize: scaledSize);
    final actionStyle = TextStyle(color: const Color(0xFF90CAF9), fontSize: scaledSize);

    // dotAll flag lets . match newlines, so *multi-line blocks* are captured
    final asteriskRegex = RegExp(r'\*[^*]+\*', dotAll: true);
    final quoteRegex = RegExp(r'"[^"]*"');

    List<TextSpan> spans = [];

    // Pass 1: Split by asterisk blocks
    int lastEnd = 0;
    for (final match in asteriskRegex.allMatches(text)) {
      // Process plain text before this asterisk block
      if (match.start > lastEnd) {
        _addColorizedQuotes(spans, text.substring(lastEnd, match.start), plainStyle, dialogueStyle, quoteRegex);
      }

      // Process the asterisk block — colorize inner quotes as yellow, rest as blue italic
      final blockText = match.group(0)!;
      _addColorizedQuotes(spans, blockText, actionStyle, dialogueStyle, quoteRegex);

      lastEnd = match.end;
    }

    // Process remaining text after last asterisk block
    if (lastEnd < text.length) {
      _addColorizedQuotes(spans, text.substring(lastEnd), plainStyle, dialogueStyle, quoteRegex);
    }

    if (spans.isEmpty) {
      return SelectionArea(
        child: Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: scaledSize, height: 1.4),
        ),
      );
    }

    return SelectionArea(
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.white, fontSize: scaledSize, height: 1.4, fontFamily: 'Roboto'),
          children: spans,
        ),
      ),
    );
  }

  /// Splits a segment of text by quoted dialogue and adds spans.
  /// Non-quoted text gets [baseStyle], quoted text gets [dialogueStyle].
  void _addColorizedQuotes(List<TextSpan> spans, String segment, TextStyle baseStyle, TextStyle dialogueStyle, RegExp quoteRegex) {
    int lastEnd = 0;
    for (final match in quoteRegex.allMatches(segment)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: segment.substring(lastEnd, match.start), style: baseStyle));
      }
      spans.add(TextSpan(text: match.group(0)!, style: dialogueStyle));
      lastEnd = match.end;
    }
    if (lastEnd < segment.length) {
      spans.add(TextSpan(text: segment.substring(lastEnd), style: baseStyle));
    }
  }
}

class _SidebarSection extends StatelessWidget {
  final String title;
  final String content;

  const _SidebarSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

class _AuthorNoteSection extends StatefulWidget {
  final ChatService chatService;
  const _AuthorNoteSection({required this.chatService});

  @override
  State<_AuthorNoteSection> createState() => _AuthorNoteSectionState();
}

class _AuthorNoteSectionState extends State<_AuthorNoteSection> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.chatService.authorNote);
  }

  @override
  void didUpdateWidget(covariant _AuthorNoteSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.chatService.authorNote) {
      _controller.text = widget.chatService.authorNote;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sticky_note_2_outlined, size: 16, color: Colors.amber),
            const SizedBox(width: 6),
            const Text("Author's Note",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          maxLines: 4,
          minLines: 2,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Instructions injected into context...',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blueAccent),
            ),
            contentPadding: const EdgeInsets.all(10),
          ),
          onChanged: (val) {
            widget.chatService.setAuthorNote(val, strength: widget.chatService.authorNoteStrength);
          },
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final strength = widget.chatService.authorNoteStrength;
            Color sliderColor;
            String tierLabel;
            if (strength <= 3) {
              sliderColor = Colors.blueAccent;
              tierLabel = 'Subtle';
            } else if (strength <= 7) {
              sliderColor = Colors.amberAccent;
              tierLabel = 'Moderate';
            } else {
              sliderColor = Colors.redAccent;
              tierLabel = 'Strong';
            }
            return Column(
              children: [
                Row(
                  children: [
                    const Tooltip(
                      message: 'Controls how forcefully the author\'s note is applied.\n'
                        'Subtle: a gentle suggestion the AI may follow.\n'
                        'Moderate: standard injection into context.\n'
                        'Strong: an urgent directive the AI should apply immediately.',
                      child: Text('Strength: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: sliderColor,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: sliderColor,
                        ),
                        child: Slider(
                          value: strength.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '$strength — $tierLabel',
                          onChanged: (val) {
                            widget.chatService.setAuthorNote(
                              widget.chatService.authorNote,
                              strength: val.round(),
                            );
                          },
                        ),
                      ),
                    ),
                    Text('$strength',
                      style: TextStyle(color: sliderColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: sliderColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: sliderColor.withOpacity(0.3)),
                        ),
                        child: Text(tierLabel,
                          style: TextStyle(color: sliderColor, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
