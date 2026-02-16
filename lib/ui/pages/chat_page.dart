import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/services/chat_service.dart';
import 'package:kobold_character_card_manager/models/character_card.dart';
import 'package:kobold_character_card_manager/ui/dialogs/edit_character_dialog.dart';
import 'package:kobold_character_card_manager/ui/dialogs/chat_settings_dialog.dart';
import 'package:kobold_character_card_manager/ui/dialogs/model_settings_dialog.dart';
import 'package:kobold_character_card_manager/services/user_persona_service.dart';
import 'package:kobold_character_card_manager/ui/dialogs/user_persona_dialog.dart';

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

        if (character == null) {
          return const Center(child: Text('No character selected.'));
        }
        
        // Trigger scroll on build if messages changed
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFF111827), // Darker background like Backyard
              appBar: _buildAppBar(context, character),
              body: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(20),
                            itemCount: messages.length + (chatService.isGenerating ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
                                return _TypingBubble(characterImage: character.imagePath != null ? File(character.imagePath!) : null);
                              }
                              final msg = messages[index];
                              return _MessageBubble(
                                message: msg, 
                                characterImage: character.imagePath != null ? File(character.imagePath!) : null,
                                index: index,
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
                                      'Generating response...',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
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
                  _buildRightSidebar(character),
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
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'new_chat') {
              _showClearChatConfirmation(context);
            } else if (value == 'history') {
              _showHistoryDialog(context);
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'new_chat',
              child: Row(
                children: [
                   Icon(Icons.chat_bubble_outline, size: 20),
                   SizedBox(width: 8),
                   Text('New Chat'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'history',
              child: Row(
                children: [
                   Icon(Icons.history, size: 20),
                   SizedBox(width: 8),
                   Text('Chat History'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
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
    final sessions = await chatService.getSessions();

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Chat History'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: sessions.isEmpty 
            ? const Center(child: Text('No previous chats found.'))
            : ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final s = sessions[index];
                  final date = s['date'] as DateTime;
                  final dateStr = '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute.toString().padLeft(2, "0")}';
                  final isCurrent = s['id'] == chatService.currentSessionId;

                  return ListTile(
                    title: Text(s['preview'], style: const TextStyle(fontSize: 14)),
                    subtitle: Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    trailing: isCurrent ? const Icon(Icons.check, color: Colors.greenAccent) : null,
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

          // Hamburger Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white70),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'regenerate') {
                chatService.regenerateLastMessage();
              } else if (value == 'impersonate') {
                chatService.impersonateUser();
              } else if (value == 'continue') {
                chatService.continueGeneration();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'regenerate',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 12),
                    Text('Regenerate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'impersonate',
                child: Row(
                  children: [
                    Icon(Icons.person_search, size: 20),
                    SizedBox(width: 12),
                    Text('Impersonate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'continue',
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward, size: 20),
                    SizedBox(width: 12),
                    Text('Continue'),
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
            onPressed: chatService.isGenerating ? null : () => chatService.impersonateUser(),
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
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.white38),
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
          chatService.isGenerating
            ? IconButton(
                icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
                tooltip: 'Stop Generation',
                onPressed: () => chatService.stopGeneration(),
              )
            : IconButton(
                icon: const Icon(Icons.send, color: Colors.blueAccent),
                onPressed: () {
                   if (_controller.text.isNotEmpty && !chatService.isGenerating) {
                      chatService.sendMessage(_controller.text);
                      _controller.clear();
                   }
                },
              ),
        ],
      ),
    );
  }

  Widget _buildRightSidebar(CharacterCard character) {
    String replace(String text) {
      return text.replaceAll('{{char}}', character.name).replaceAll('{{user}}', 'User');
    }

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          if (character.imagePath != null)
             Image.file(File(character.imagePath!), height: 300, width: 300, fit: BoxFit.cover),
          
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
                _SidebarSection(title: 'Note', content: 'Author Note placeholder...'),
                const SizedBox(height: 16),
                _SidebarSection(title: 'Character Persona', content: replace(character.personality)),
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
}

class _TypingBubble extends StatelessWidget {
  final File? characterImage;

  const _TypingBubble({this.characterImage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: characterImage != null ? FileImage(characterImage!) : null,
            child: characterImage == null ? const Icon(Icons.person) : null,
            radius: 16,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF374151),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                ),
                SizedBox(width: 12),
                Text('Typing...', style: TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final File? characterImage;
  final int index;

  const _MessageBubble({required this.message, this.characterImage, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) 
            CircleAvatar(
              backgroundImage: characterImage != null ? FileImage(characterImage!) : null,
              child: characterImage == null ? const Icon(Icons.person) : null,
              radius: 16,
            ),
          if (!message.isUser) const SizedBox(width: 12),
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? const Color(0xFF3B82F6) : const Color(0xFF374151),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: message.isUser ? const Radius.circular(12) : Radius.zero,
                  bottomRight: message.isUser ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!message.isUser)
                        Text(message.sender, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
                      if (!message.isUser) const Spacer(),
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
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white38),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showDeleteConfirmation(context, index),
                        ),
                    ],
                  ),
                  if (!message.isUser) const SizedBox(height: 4),
                  _StyledChatMessage(text: message.text, isUser: message.isUser),
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
    // Two-pass approach:
    // Pass 1: Split on asterisk blocks *...*
    // Pass 2: Within each segment, colorize quoted dialogue "..."
    // This ensures quotes inside asterisk blocks still get yellow treatment

    const plainStyle = TextStyle(color: Colors.white);
    const dialogueStyle = TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w500);
    const actionStyle = TextStyle(color: Color(0xFF90CAF9));

    final asteriskRegex = RegExp(r'\*[^*]+\*');
    final quoteRegex = RegExp(r'"[^"]*"');

    List<TextSpan> spans = [];

    // Pass 1: Split by asterisk blocks
    int lastEnd = 0;
    for (final match in asteriskRegex.allMatches(text)) {
      // Process plain text before this asterisk block
      if (match.start > lastEnd) {
        _addColorizedQuotes(spans, text.substring(lastEnd, match.start), plainStyle, dialogueStyle, quoteRegex);
      }

      // Process the asterisk block — colorize inner quotes as yellow, rest as blue
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
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
      );
    }

    return SelectionArea(
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4, fontFamily: 'Roboto'),
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
