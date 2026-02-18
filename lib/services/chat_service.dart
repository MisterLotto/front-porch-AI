import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/models/group_chat.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:front_porch_ai/models/world.dart';

enum GenerationMode { normal, continue_, impersonate }

class ChatMessage {
  final List<String> swipes;
  int swipeIndex;
  final String sender;
  final bool isUser;
  final String? characterId; // which character card sent this (null = user or 1:1 mode)
  final List<int> swipeDurations; // thinking duration in ms per swipe

  String get text => swipes.isNotEmpty ? swipes[swipeIndex] : '';
  set text(String value) {
    if (swipes.isNotEmpty) {
      swipes[swipeIndex] = value;
    }
  }

  /// Returns text with <think>...</think> blocks removed for display.
  /// Also handles in-progress thinking (no closing tag yet during streaming).
  String get displayText {
    final raw = text;
    // Strip completed think blocks
    var result = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>\s*', caseSensitive: false), '');
    // Strip in-progress think block (opened but not yet closed during streaming)
    result = result.replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '');
    return result.trim();
  }

  /// Returns the thinking content (between <think> tags), or null if none.
  /// Handles both completed and in-progress (streaming) think blocks.
  String? get thinkingContent {
    // Try completed think block first
    final closed = RegExp(r'<think>([\s\S]*?)</think>', caseSensitive: false).firstMatch(text);
    if (closed != null) return closed.group(1)?.trim();
    // Try in-progress think block (no closing tag yet)
    final open = RegExp(r'<think>([\s\S]*?)$', caseSensitive: false).firstMatch(text);
    return open?.group(1)?.trim();
  }

  /// Whether this message has thinking content (either from tags or tracked duration)
  bool get hasThinking => thinkingContent != null || thinkingDurationMs > 0;

  int get thinkingDurationMs => swipeIndex < swipeDurations.length ? swipeDurations[swipeIndex] : 0;
  set thinkingDurationMs(int value) {
    while (swipeDurations.length <= swipeIndex) {
      swipeDurations.add(0);
    }
    swipeDurations[swipeIndex] = value;
  }

  int? thinkingStartTime; // Runtime only, for live timer

  ChatMessage({required String text, required this.sender, required this.isUser, this.characterId, List<String>? swipes, int? swipeIndex, List<int>? swipeDurations})
    : swipes = swipes ?? [text],
      swipeIndex = swipeIndex ?? 0,
      swipeDurations = swipeDurations ?? [0];

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'sender': sender,
      'is_user': isUser,
      if (characterId != null) 'character_id': characterId,
      'swipes': swipes,
      'swipe_index': swipeIndex,
      'swipe_durations': swipeDurations,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final List<String>? savedSwipes = (json['swipes'] as List<dynamic>?)?.map((e) => e.toString()).toList();
    final List<int>? savedDurations = (json['swipe_durations'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList();
    final String fallbackText = json['text'] ?? '';
    return ChatMessage(
      text: fallbackText,
      sender: json['sender'] ?? '',
      isUser: json['is_user'] ?? false,
      characterId: json['character_id'],
      swipes: savedSwipes ?? [fallbackText],
      swipeIndex: json['swipe_index'] ?? 0,
      swipeDurations: savedDurations ?? [0],
    );
  }
}

class ChatService extends ChangeNotifier {
  final KoboldService _koboldService;
  final UserPersonaService _userPersonaService;
  final StorageService _storageService;
  final WorldRepository _worldRepository;
  LLMProvider? _llmProvider;
  CharacterRepository? _characterRepository;

  CharacterCard? _activeCharacter;
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _isLoadingSession = false;
  bool _cancelRequested = false;
  String? _currentSessionId;
  double _generationProgress = 0.0;
  int _tokensGenerated = 0;
  int _maxTokens = 0;
  DateTime? _generationStartTime;
  bool _isBuffering = false;
  final List<String> _tokenBuffer = [];
  Timer? _drainTimer;
  int _displayedTokenCount = 0;
  final List<DateTime> _tokenTimestamps = []; // Rolling window for TPS measurement

  // ── Group chat state ──
  GroupChat? _activeGroup;
  List<CharacterCard> _groupCharacters = [];
  int _turnIndex = 0;

  /// Default system prompt for group chats, designed to prevent characters
  /// from speaking for each other and maintain turn discipline.
  static const String defaultGroupSystemPrompt =
      'You are roleplaying in a multi-character group conversation. '
      'CRITICAL RULES:\n'
      '1. You MUST only write dialogue and actions for the character whose turn it is (indicated after <START>). '
      'NEVER write dialogue, thoughts, or actions for other characters or {{user}}.\n'
      '2. Stay fully in character \u2014 use the speaking character\'s unique voice, mannerisms, personality, and speech patterns.\n'
      '3. Keep your response focused on ONE character\'s contribution. Do not narrate what other characters do or say.\n'
      '4. React naturally to what other characters and {{user}} have said. Reference their words, but do not put words in their mouths.\n'
      '5. Write in the style of collaborative roleplay: use *asterisks* for actions/narration and regular text for dialogue.\n'
      '6. Keep responses concise and punchy \u2014 leave room for the next character to respond.\n'
      '7. Never break character or reference the fact that you are an AI.';

  /// Default system prompt for local KoboldCPP backends (smaller models).
  /// Kept concise so it doesn't eat too much of the limited context window.
  static const String defaultKoboldSystemPrompt =
      'Write {{char}}\'s next reply in this roleplay with {{user}}. '
      'Stay in character as {{char}} at all times. '
      'Use *asterisks* for actions and narration, regular text for dialogue. '
      'Be creative, descriptive, and drive the scene forward. '
      'Never write actions or dialogue for {{user}}. '
      'Never break character or mention being an AI.';

  /// Default system prompt for remote API backends (large cloud models).
  /// Highly detailed to leverage the model's full capabilities.
  static const String defaultApiSystemPrompt =
      'You are an expert collaborative fiction writer and immersive roleplay partner. '
      'You write as {{char}} in an ongoing interactive story with {{user}}.\n\n'
      'CORE IDENTITY:\n'
      '- Embody {{char}} completely. Every response must reflect their unique personality, speech patterns, '
      'vocabulary level, emotional state, and worldview as defined in their character description.\n'
      '- {{char}} is a living, breathing character with their own desires, fears, opinions, and agency \u2014 '
      'not a servant of {{user}}. They can disagree, have bad days, make mistakes, and act according to their own motivations.\n\n'
      'WRITING CRAFT:\n'
      '- Write in a natural, literary style. Vary sentence length and structure. Avoid repetitive sentence openings.\n'
      '- Show emotions through body language, micro-expressions, vocal tone, and subtle actions rather than stating '
      'feelings directly ("she clenched her jaw" not "she felt angry").\n'
      '- Use all five senses \u2014 sight, sound, smell, touch, taste \u2014 to create vivid, immersive scenes.\n'
      '- Dialogue should feel natural and conversational. Characters can interrupt, trail off, use contractions, '
      'stumble over words, or speak in fragments when emotionally charged.\n'
      '- Weave internal thoughts, environmental details, and physical sensations into responses to create depth.\n'
      '- Match the tone and pacing to the scene: tense moments get short, punchy prose; reflective moments get '
      'slower, more lyrical writing.\n\n'
      'ANTI-SLOP RULES \u2014 AVOID THESE CLICH\u00c9S:\n'
      '- Do NOT use: "a symphony of", "a dance of", "sent shivers down", "electricity coursed through", '
      '"breath hitched", "pupils dilated", "orbs" (for eyes), "ministrations", "mewled", '
      '"the air crackled with", "a masterpiece of", "elicited a moan".\n'
      '- Do NOT start responses with: "I", a sigh, a chuckle, or raising an eyebrow.\n'
      '- Do NOT use purple prose or melodramatic narration. Keep descriptions grounded and specific.\n'
      '- Vary your emotional vocabulary \u2014 don\'t repeat the same descriptors across responses.\n\n'
      'RESPONSE GUIDELINES:\n'
      '- Write 2-5 paragraphs per response unless the scene calls for shorter exchanges.\n'
      '- Always advance the scene meaningfully. Each response should move the story forward through action, '
      'revelation, or emotional development.\n'
      '- End responses at natural pause points that invite {{user}} to react \u2014 don\'t resolve conflicts or '
      'answer your own questions.\n'
      '- Never narrate {{user}}\'s actions, thoughts, dialogue, or emotional reactions. Their agency is sacred.\n'
      '- Never break the fourth wall, mention being an AI, or reference the roleplay as fiction.\n'
      '- Maintain continuity with all previously established facts, character history, and world details.\n\n'
      'DIALOGUE FORMAT:\n'
      '- Use regular text for speech: "Like this," she said.\n'
      '- Use *asterisks* for actions and narration: *She leaned against the doorframe, arms crossed.*\n'
      '- Internal thoughts can be written in italics or described through narration.';

  CharacterCard? get activeCharacter => _activeCharacter;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  bool get isLoadingSession => _isLoadingSession;
  String? get currentSessionId => _currentSessionId;
  double get generationProgress => _generationProgress;
  int get tokensGenerated => _tokensGenerated;
  int get maxTokens => _maxTokens;
  bool get isBuffering => _isBuffering;
  bool get isGroupMode => _activeGroup != null;
  GroupChat? get activeGroup => _activeGroup;
  List<CharacterCard> get groupCharacters => List.unmodifiable(_groupCharacters);
  /// The character who will speak next in group mode.
  CharacterCard? get nextCharacter {
    if (_activeGroup == null || _groupCharacters.isEmpty) return null;
    if (_activeGroup!.turnOrder == TurnOrder.roundRobin) {
      return _groupCharacters[_turnIndex % _groupCharacters.length];
    }
    return null; // random is chosen at generation time
  }
  double get tokensPerSecond {
    if (_tokenTimestamps.length < 2) return 0.0;
    // Use rolling window: tokens in the last 3 seconds
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 3));
    final recent = _tokenTimestamps.where((t) => t.isAfter(cutoff)).length;
    if (recent < 2) {
      // Fallback to overall average
      if (_generationStartTime == null || _tokensGenerated == 0) return 0.0;
      final elapsed = now.difference(_generationStartTime!).inMilliseconds / 1000.0;
      return elapsed > 0 ? _tokensGenerated / elapsed : 0.0;
    }
    final windowStart = _tokenTimestamps.where((t) => t.isAfter(cutoff)).first;
    final windowElapsed = now.difference(windowStart).inMilliseconds / 1000.0;
    return windowElapsed > 0 ? recent / windowElapsed : 0.0;
  }
  int _greetingIndex = 0;
  int get greetingIndex => _greetingIndex;

  ChatService(this._koboldService, this._userPersonaService, this._storageService, this._worldRepository);

  /// Set the CharacterRepository so group mode can look up characters.
  void setCharacterRepository(CharacterRepository repo) {
    _characterRepository = repo;
  }

  /// Set the LLMProvider after construction (to break circular dependency in provider tree).
  void setLLMProvider(LLMProvider provider) {
    _llmProvider = provider;
  }

  Future<void> setActiveCharacter(CharacterCard? character) async {
    // If same character is already active, don't reset unless empty
    if (_activeCharacter?.name == character?.name && 
        _activeCharacter?.imagePath == character?.imagePath && 
        _messages.isNotEmpty) {
      return;
    }

    // Clear group mode when switching to 1:1
    _activeGroup = null;
    _groupCharacters = [];
    _turnIndex = 0;

    _activeCharacter = character;
    _messages.clear();
    _currentSessionId = null;
    _isLoadingSession = true;
    notifyListeners();
    
    if (_activeCharacter != null) {
      // Reset lorebook trigger state
      if (_activeCharacter!.lorebook != null) {
        for (var entry in _activeCharacter!.lorebook!.entries) {
          entry.isTriggered = false;
        }
      }
      // Reset world lore triggers
      for (final worldName in _activeCharacter!.worldNames) {
        final world = _worldRepository.worlds.where((w) => w.name == worldName).firstOrNull;
        if (world != null) {
          for (final entry in world.lorebook.entries) {
            entry.isTriggered = false;
          }
        }
      }

      // Try to load last session
      await _loadLastSession();
      
      // If no session loaded, start fresh
      if (_messages.isEmpty) {
        if (_activeCharacter!.firstMessage.isNotEmpty) {
           _messages.add(ChatMessage(
            text: _buildFirstMessage(_activeCharacter!),
            sender: _activeCharacter!.name,
            isUser: false,
          ));
          // Scan first message for lore
          _scanLorebook(_messages.last.text);
        }
        // Save the initial message session
        _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
        await _saveChat();
      }
    }
    _isLoadingSession = false;
    notifyListeners();
  }

  /// Enter group chat mode with the given GroupChat definition.
  Future<void> setActiveGroup(GroupChat group) async {
    if (_characterRepository == null) return;

    // Clear 1:1 mode
    _activeCharacter = null;
    _messages.clear();
    _currentSessionId = null;
    _isLoadingSession = true;
    _turnIndex = 0;
    _activeGroup = group;
    notifyListeners();

    // Resolve character IDs to cards
    _groupCharacters = group.characterIds
        .map((id) => _characterRepository!.characters.where(
              (c) => _getCharacterIdFromCard(c) == id,
            ).firstOrNull)
        .whereType<CharacterCard>()
        .toList();

    // Reset all lorebook triggers
    for (final ch in _groupCharacters) {
      if (ch.lorebook != null) {
        for (var entry in ch.lorebook!.entries) {
          entry.isTriggered = false;
        }
      }
      for (final worldName in ch.worldNames) {
        final world = _worldRepository.worlds.where((w) => w.name == worldName).firstOrNull;
        if (world != null) {
          for (final entry in world.lorebook.entries) {
            entry.isTriggered = false;
          }
        }
      }
    }

    // Try to load last session for this group
    await _loadLastSession();

    // If no session, create a greeting
    if (_messages.isEmpty && _groupCharacters.isNotEmpty) {
      String greetingText;
      String greetingSender;
      String? greetingCharId;

      if (group.firstMessage.isNotEmpty) {
        // Use custom group first message — attribute to "Narrator" or group name
        greetingText = group.firstMessage;
        greetingSender = group.name;
        greetingCharId = null;
      } else {
        // Fall back to first character's greeting
        final first = _groupCharacters.first;
        greetingText = first.firstMessage.isNotEmpty ? _buildFirstMessage(first) : '';
        greetingSender = first.name;
        greetingCharId = _getCharacterIdFromCard(first);
      }

      if (greetingText.isNotEmpty) {
        _messages.add(ChatMessage(
          text: greetingText,
          sender: greetingSender,
          isUser: false,
          characterId: greetingCharId,
        ));
        _scanLorebook(_messages.last.text);
      }
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await _saveChat();
    }

    _isLoadingSession = false;
    notifyListeners();
  }

  /// Returns a stable ID string for a character card.
  String _getCharacterIdFromCard(CharacterCard card) {
    if (card.imagePath != null) {
      return path.basenameWithoutExtension(card.imagePath!);
    }
    return card.name.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
  }

  String _getCharacterId() {
    if (_activeGroup != null) {
      return 'group_${_activeGroup!.id}';
    }
    if (_activeCharacter == null) return "unknown";
    return _getCharacterIdFromCard(_activeCharacter!);
  }

  /// Helper used when constructing messages.
  String? _getCharacterIdForCard(CharacterCard card) {
    return _getCharacterIdFromCard(card);
  }

  Future<void> _saveChat() async {
    if ((_activeCharacter == null && _activeGroup == null) || _currentSessionId == null) return;
    
    final charId = _getCharacterId();
    final charDir = Directory('${_storageService.chatsDir.path}/$charId');
    if (!await charDir.exists()) {
      await charDir.create(recursive: true);
    }

    final file = File('${charDir.path}/$_currentSessionId.json');
    final jsonList = _messages.map((m) => m.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<void> _loadLastSession() async {
    if (_activeCharacter == null && _activeGroup == null) return;
    
    final charId = _getCharacterId();
    final charDir = Directory('${_storageService.chatsDir.path}/$charId');
    if (!await charDir.exists()) return;

    final files = await charDir.list().where((f) => f is File && f.path.endsWith('.json')).toList();
    if (files.isEmpty) return;

    // Sort by name (which is timestamp) descending
    files.sort((a, b) => b.path.compareTo(a.path));
    
    final lastFile = files.first as File;
    _currentSessionId = path.basenameWithoutExtension(lastFile.path);
    
    try {
      final content = await lastFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      _messages.clear();
      _messages.addAll(jsonList.map((m) => ChatMessage.fromJson(m)));
      
      if (_messages.isNotEmpty) {
        _scanLorebook(_messages.last.text);
      }
    } catch (e) {
      print('Error loading chat session: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    if (_activeCharacter == null && _activeGroup == null) return [];
    
    final charId = _getCharacterId();
    final charDir = Directory('${_storageService.chatsDir.path}/$charId');
    if (!await charDir.exists()) return [];

    final files = await charDir.list().where((f) => f is File && f.path.endsWith('.json')).toList();
    
    List<Map<String, dynamic>> sessions = [];
    for (var f in files) {
      final id = path.basenameWithoutExtension(f.path);
      final timestamp = int.tryParse(id) ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      
      // Peek at first message for a preview?
      String preview = "New Conversation";
      try {
        final content = await (f as File).readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        if (jsonList.length > 1) {
          // Use the first user message or second message as preview
          preview = jsonList[1]['text'];
          if (preview.length > 50) preview = '${preview.substring(0, 50)}...';
        }
      } catch (_) {}

      sessions.add({
        'id': id,
        'date': date,
        'preview': preview,
      });
    }

    // Sort descending
    sessions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return sessions;
  }

  Future<void> loadSession(String sessionId) async {
    if (_activeCharacter == null && _activeGroup == null) return;
    
    final charId = _getCharacterId();
    final file = File('${_storageService.chatsDir.path}/$charId/$sessionId.json');
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      
      _messages.clear();
      _messages.addAll(jsonList.map((m) => ChatMessage.fromJson(m)));
      _currentSessionId = sessionId;
      
      if (_messages.isNotEmpty) {
        _scanLorebook(_messages.last.text);
      }
      notifyListeners();
    } catch (e) {
      print('Error loading session $sessionId: $e');
    }
  }

  // Import chat from SillyTavern JSON format
  Future<void> importFromSillyTavern(String jsonData) async {
    if (_activeCharacter == null) throw Exception('No active character');

    try {
      final Map<String, dynamic> data = jsonDecode(jsonData);
      final List<dynamic> messages = data['messages'] ?? [];

      _messages.clear();
      
      for (final msg in messages) {
        final String name = msg['name'] ?? '';
        final bool isUser = msg['is_user'] ?? false;
        final String text = msg['mes'] ?? '';
        
        _messages.add(ChatMessage(
          text: text,
          sender: name,
          isUser: isUser,
        ));
      }

      // Create new session for imported chat
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await _saveChat();
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to parse SillyTavern JSON: $e');
    }
  }

  // Export current chat to SillyTavern JSON format
  String? exportToSillyTavern() {
    if (_messages.isEmpty) return null;

    final List<Map<String, dynamic>> messages = _messages.map((msg) {
      return {
        'name': msg.sender,
        'is_user': msg.isUser,
        'mes': msg.text,
        'send_date': DateTime.now().millisecondsSinceEpoch,
      };
    }).toList();

    final Map<String, dynamic> export = {
      'chat_metadata': {
        'note_prompt': '',
        'note_interval': 0,
      },
      'messages': messages,
    };

    return jsonEncode(export);
  }

  Future<void> startNewChat() async {
    if (_activeCharacter == null && _activeGroup == null) return;

    _messages.clear();
    _greetingIndex = 0;

    if (_activeGroup != null && _groupCharacters.isNotEmpty) {
      // Group mode: greeting from first character
      final first = _groupCharacters.first;
      if (first.firstMessage.isNotEmpty) {
        _messages.add(ChatMessage(
          text: _buildFirstMessage(first),
          sender: first.name,
          isUser: false,
          characterId: _getCharacterIdFromCard(first),
        ));
        _scanLorebook(_messages.last.text);
      }
      _turnIndex = 0;
    } else if (_activeCharacter != null) {
      // 1:1 mode
      if (_activeCharacter!.firstMessage.isNotEmpty) {
        _messages.add(ChatMessage(
          text: _buildFirstMessage(_activeCharacter!),
          sender: _activeCharacter!.name,
          isUser: false,
        ));
        _scanLorebook(_messages.last.text);
      }
    }
    
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    await _saveChat();
    notifyListeners();
  }

  /// Cycle the first message through alternate greetings
  Future<void> cycleGreeting(int direction) async {
    if (_activeCharacter == null || _messages.isEmpty) return;
    final allGreetings = _activeCharacter!.allGreetings;
    if (allGreetings.length <= 1) return;

    _greetingIndex = (_greetingIndex + direction) % allGreetings.length;
    if (_greetingIndex < 0) _greetingIndex += allGreetings.length;

    // Replace the first message text
    final greeting = allGreetings[_greetingIndex];
    _messages[0] = ChatMessage(
      text: _buildFirstMessage(_activeCharacter!, greetingText: greeting),
      sender: _activeCharacter!.name,
      isUser: false,
    );
    
    await _saveChat();
    notifyListeners();
  }

  String _buildFirstMessage(CharacterCard character, {String? greetingText}) {
    String msg = greetingText ?? character.firstMessage;
    // Use the robust replacement logic from the model
    return character.replacePlaceholders(
      msg, 
      userName: _userPersonaService.persona.name
    );
  }

  Future<void> sendMessage(String text) async {
    if ((_activeCharacter == null && _activeGroup == null) || text.trim().isEmpty) return;

    final senderName = _userPersonaService.persona.name;
    _messages.add(ChatMessage(text: text, sender: senderName, isUser: true));
    await _saveChat();
    notifyListeners();

    // Scan user input for lore keywords
    _scanLorebook(text);

    // User message counts as a message towards depth
    _decrementLoreDepth();

    await _generateResponse(GenerationMode.normal);
  }

  Future<void> regenerateLastMessage() async {
    if (_messages.isEmpty || _isGenerating) return;

    // Check if the last message is from the character
    if (!_messages.last.isUser && _messages.last.sender != 'System') {
      // Instead of removing the message, we generate a new swipe
      // Temporarily remove the last message so the prompt doesn't include it
      final lastMsg = _messages.removeLast();
      notifyListeners();

      // Generate into a new message — it will be appended by _generateResponse
      await _generateResponse(GenerationMode.normal);

      // After generation, merge the new response as a swipe on the original message
      if (_messages.isNotEmpty && !_messages.last.isUser && _messages.last.sender != 'System') {
        final newText = _messages.last.text;
        _messages.removeLast();
        lastMsg.swipes.add(newText);
        lastMsg.swipeIndex = lastMsg.swipes.length - 1;
        _messages.add(lastMsg);
        await _saveChat();
        notifyListeners();
      }
    }
  }

  /// Navigate swipes on a specific message. direction: -1 = left, +1 = right.
  /// If swiping right past the last swipe on the last bot message, regenerates.
  Future<void> swipeMessage(int messageIndex, int direction) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final msg = _messages[messageIndex];
    if (msg.isUser || msg.sender == 'System') return;

    final newIndex = msg.swipeIndex + direction;

    // Swiping left
    if (direction < 0) {
      if (newIndex >= 0) {
        msg.swipeIndex = newIndex;
        await _saveChat();
        notifyListeners();
      }
      return;
    }

    // Swiping right
    if (newIndex < msg.swipes.length) {
      // Navigate to existing swipe
      msg.swipeIndex = newIndex;
      await _saveChat();
      notifyListeners();
    } else if (messageIndex == _messages.length - 1 && !_isGenerating) {
      // Past last swipe on last message — regenerate
      await regenerateLastMessage();
    }
  }

  Future<void> continueGeneration() async {
    if (_messages.isEmpty || _isGenerating) return;
    
    // Only continue if the last message is from a bot (non-user, non-system)
    if (!_messages.last.isUser && _messages.last.sender != 'System') {
      await _generateResponse(GenerationMode.continue_);
    }
  }

  Future<void> impersonateUser() async {
    if (_activeCharacter == null || _isGenerating) return;
    
    // Impersonate adds a bot-generated response for the USER
    await _generateResponse(GenerationMode.impersonate);
  }

  /// Trigger the next character to speak in group mode.
  Future<void> triggerNextCharacter() async {
    if (_activeGroup == null || _groupCharacters.isEmpty || _isGenerating) return;
    await _generateResponse(GenerationMode.normal);
  }

  /// Manually select which character speaks next in group mode.
  void setNextCharacter(CharacterCard character) {
    if (_activeGroup == null) return;
    final idx = _groupCharacters.indexWhere((c) => c.name == character.name);
    if (idx >= 0) {
      _turnIndex = idx;
      notifyListeners();
    }
  }

  /// Pick which character speaks next based on turn order.
  CharacterCard _pickNextGroupCharacter() {
    if (_activeGroup!.turnOrder == TurnOrder.random) {
      return _groupCharacters[Random().nextInt(_groupCharacters.length)];
    }
    // Round robin
    final char = _groupCharacters[_turnIndex % _groupCharacters.length];
    _turnIndex++;
    return char;
  }

  Future<void> _generateResponse(GenerationMode mode) async {
    _isGenerating = true;
    _generationProgress = 0.0;
    _tokensGenerated = 0;
    _maxTokens = _storageService.maxLength;
    _generationStartTime = DateTime.now();
    _isBuffering = true;
    notifyListeners();

    try {
      // ── System prompt selection ──
      // Priority: group custom > group default > user global > backend default
      final String systemPrompt;
      if (_activeGroup != null && _activeGroup!.systemPrompt.isNotEmpty) {
        // User wrote a custom group system prompt — use it
        systemPrompt = _activeGroup!.systemPrompt;
      } else if (_activeGroup != null) {
        // Group mode, no custom prompt — use the group default
        systemPrompt = defaultGroupSystemPrompt;
      } else if (_storageService.systemPrompt.isNotEmpty) {
        // Single-char mode with a user-defined global prompt — respect it
        systemPrompt = _storageService.systemPrompt;
      } else {
        // Single-char mode, no user prompt — pick default based on backend
        final isApi = _llmProvider != null && !_llmProvider!.isLocal;
        systemPrompt = isApi ? defaultApiSystemPrompt : defaultKoboldSystemPrompt;
      }
      final userName = _userPersonaService.persona.name;

      // Determine the speaking character
      CharacterCard speakingCharacter;
      if (_activeGroup != null) {
        speakingCharacter = (mode == GenerationMode.continue_ && _messages.isNotEmpty && !_messages.last.isUser)
          ? _groupCharacters.firstWhere(
              (c) => c.name == _messages.last.sender,
              orElse: () => _pickNextGroupCharacter(),
            )
          : _pickNextGroupCharacter();
      } else {
        speakingCharacter = _activeCharacter!;
      }

      // Build Lorebook content from all relevant characters
      String loreContent = '';
      List<String> activeLoreStrings = [];

      final loreCharacters = _activeGroup != null ? _groupCharacters : [_activeCharacter!];
      for (final ch in loreCharacters) {
        if (ch.lorebook != null) {
          final activeEntries = ch.lorebook!.entries.where((e) => e.enabled && (e.isTriggered || e.constant));
          activeLoreStrings.addAll(activeEntries.map((e) => e.content));
        }
        for (final worldName in ch.worldNames) {
          final world = _worldRepository.worlds.where((w) => w.name == worldName).firstOrNull;
          if (world == null) continue;
          final activeWorldEntries = world.lorebook.entries.where((e) => e.enabled && (e.isTriggered || e.constant));
          activeLoreStrings.addAll(activeWorldEntries.map((e) => e.content));
        }
      }

      if (activeLoreStrings.isNotEmpty) {
        loreContent = "Context Info:\n${activeLoreStrings.join('\n')}\n";
      }

      // Apply replacements to lore content
      if (loreContent.isNotEmpty) {
        loreContent = speakingCharacter.replacePlaceholders(loreContent, userName: userName);
      }

      // Build persona block(s)
      String personaBlock;
      if (_activeGroup != null) {
        personaBlock = _groupCharacters.map((ch) {
          final persona = ch.replacePlaceholders(ch.personality, userName: userName);
          return "${ch.name}'s Persona: $persona";
        }).join('\n');
      } else {
        personaBlock = "${speakingCharacter.name}'s Persona: ${speakingCharacter.replacePlaceholders(speakingCharacter.personality, userName: userName)}";
      }

      // Scenario — use group scenario override if set, else first character
      final String rawScenario;
      if (_activeGroup != null && _activeGroup!.scenario.isNotEmpty) {
        rawScenario = _activeGroup!.scenario;
      } else {
        final scenarioChar = _activeGroup != null ? _groupCharacters.first : speakingCharacter;
        rawScenario = scenarioChar.scenario;
      }
      final scenario = speakingCharacter.replacePlaceholders(rawScenario, userName: userName);

      String history = _buildChatHistory();
      String suffix = "";
      
      if (mode == GenerationMode.normal) {
        suffix = "\n${speakingCharacter.name}:";
      } else if (mode == GenerationMode.impersonate) {
        suffix = "\n${userName}:";
      } else if (mode == GenerationMode.continue_) {
        suffix = ""; 
      }

      // Build example dialogues block
      String mesExampleBlock = '';
      if (_activeGroup != null) {
        final examples = _groupCharacters
            .where((ch) => ch.mesExample.isNotEmpty)
            .map((ch) => ch.replacePlaceholders(ch.mesExample, userName: userName))
            .toList();
        if (examples.isNotEmpty) {
          mesExampleBlock = '${examples.join('\n')}\n';
        }
      } else if (speakingCharacter.mesExample.isNotEmpty) {
        mesExampleBlock = '${speakingCharacter.replacePlaceholders(speakingCharacter.mesExample, userName: userName)}\n';
      }

      final prompt = "$systemPrompt\n"
          "$loreContent"
          "$personaBlock\n"
          "Scenario: $scenario\n"
          "$mesExampleBlock"
          "<START>\n"
          "$history"
          "$suffix";

      // Stop sequences: include all character names + user
      final stopSequences = {
        ..._storageService.stopSequences,
        '\nUser:',
        '\n${_userPersonaService.persona.name}:',
      };
      if (_activeGroup != null) {
        for (final ch in _groupCharacters) {
          stopSequences.add('\n${ch.name}:');
        }
      } else {
        stopSequences.add('\n${_activeCharacter!.name}:');
      }
      final stopList = stopSequences.toList();

      // Get the active LLM service (local or remote)
      final llmService = _llmProvider?.activeService ?? _koboldService;

      final genParams = GenerationParams(
        prompt: prompt,
        maxLength: _storageService.maxLength,
        minLength: _storageService.minLength,
        minP: _storageService.minP,
        temperature: _storageService.temperature,
        repeatPenalty: _storageService.repeatPenalty,
        repPenTokens: _storageService.repeatPenaltyTokens,
        dynatempRange: _storageService.dynamicTempEnabled ? _storageService.dynamicTempRange : null,
        stopSequences: stopList,
        reasoningEnabled: _storageService.reasoningEnabled,
        reasoningEffort: _storageService.reasoningEffort,
      );

      // Get streaming response from whichever backend is active
      final stream = llmService.generateStream(genParams);
      
      String accumulatedResponse = "";
      bool stopFound = false;
      _tokenBuffer.clear();
      _displayedTokenCount = 0;
      _tokenTimestamps.clear();
      bool streamDone = false;
      DateTime? _thinkStartTime;
      bool _thinkStarted = false;
      bool _thinkEnded = false;

      // Determine message identity
      String originalText = '';
      String targetSender;
      bool isUserTarget;

      if (mode == GenerationMode.continue_) {
        originalText = _messages.last.text;
        targetSender = _messages.last.sender;
        isUserTarget = _messages.last.isUser;
      } else {
        targetSender = mode == GenerationMode.normal ? speakingCharacter.name : _userPersonaService.persona.name;
        isUserTarget = mode == GenerationMode.impersonate;
        _messages.add(ChatMessage(
          text: "",
          sender: targetSender,
          isUser: isUserTarget,
          characterId: mode == GenerationMode.normal ? _getCharacterIdForCard(speakingCharacter) : null,
        ));
      }

      // Helper to update the visible message from buffer
      void _flushBufferToDisplay() {
        if (_tokenBuffer.isEmpty && _displayedTokenCount == 0) return;
        // Build displayed text from all tokens up to _displayedTokenCount
        final displayTokens = _tokenBuffer.take(_displayedTokenCount).join();
        String displayText;
        if (mode == GenerationMode.continue_) {
          displayText = originalText + displayTokens;
        } else {
          displayText = displayTokens.trimLeft();
        }
        // CRITICAL: Modify existing message in place to preserve thinkingStartTime and other metadata
        _messages.last.text = displayText;
        notifyListeners();
      }

      // Read display buffer settings — disable for remote APIs (they're fast enough)
      final isRemoteBackend = _llmProvider != null && !_llmProvider!.isLocal;
      final bufferEnabled = isRemoteBackend ? false : _storageService.displayBufferEnabled;
      final targetTps = _storageService.targetDisplayTps;

      // Drain timer: displays tokens at the user-configured constant rate
      void _startDrainTimer() {
        if (_drainTimer != null) return;
        final interval = Duration(milliseconds: (1000.0 / targetTps).round());
        _drainTimer = Timer.periodic(interval, (_) {
          if (_displayedTokenCount < _tokenBuffer.length) {
            _displayedTokenCount++;
            _flushBufferToDisplay();
          } else if (streamDone) {
            // Stream finished and buffer fully drained
            _drainTimer?.cancel();
            _drainTimer = null;
          }
          // If buffer is caught up but stream still running, timer ticks idly until more tokens arrive
        });
      }

      // Consume the stream — tokens go into buffer (or display immediately)
      await for (final token in stream) {
        if (_cancelRequested) break;
        accumulatedResponse += token;
        _tokensGenerated++;
        _tokenTimestamps.add(DateTime.now());
        _generationProgress = _maxTokens > 0 ? (_tokensGenerated / _maxTokens).clamp(0.0, 1.0) : 0.0;

        // Client-side safety trim check (mid-stream)
        for (final stop in stopList) {
          if (accumulatedResponse.contains(stop)) {
            int index = accumulatedResponse.indexOf(stop);
            final trimmedTotal = accumulatedResponse.substring(0, index);
            final previousTotal = _tokenBuffer.join();
            final lastTokenContribution = trimmedTotal.substring(previousTotal.length.clamp(0, trimmedTotal.length));
            if (lastTokenContribution.isNotEmpty) {
              _tokenBuffer.add(lastTokenContribution);
            }
            accumulatedResponse = trimmedTotal;
            stopFound = true;
            break;
          }
        }

        if (!stopFound) {
          _tokenBuffer.add(token);
        }

        // Track think timing
        if (!_thinkStarted && accumulatedResponse.contains('<think>')) {
          _thinkStarted = true;
          _thinkStartTime = DateTime.now();
          if (_messages.isNotEmpty) {
            _messages.last.thinkingStartTime = _thinkStartTime!.millisecondsSinceEpoch;
          }
        }
        if (_thinkStarted && !_thinkEnded && accumulatedResponse.contains('</think>')) {
          _thinkEnded = true;
          if (_thinkStartTime != null && _messages.isNotEmpty) {
            _messages.last.thinkingDurationMs = DateTime.now().difference(_thinkStartTime!).inMilliseconds;
            // Keep thinkingStartTime for fallback display logic in UI
          }
        }

        if (bufferEnabled) {
          // Calculate current rolling TPS (last 3 seconds)
          final now = DateTime.now();
          final cutoff = now.subtract(const Duration(seconds: 3));
          final recentCount = _tokenTimestamps.where((t) => t.isAfter(cutoff)).length;
          final windowStart = _tokenTimestamps.where((t) => t.isAfter(cutoff)).firstOrNull ?? _generationStartTime!;
          final windowElapsed = now.difference(windowStart).inMilliseconds / 1000.0;
          final currentTps = (recentCount >= 2 && windowElapsed > 0) ? recentCount / windowElapsed : (_tokensGenerated > 0 ? _tokensGenerated / (now.difference(_generationStartTime!).inMilliseconds / 1000.0) : 0.0);

          if (_drainTimer == null && _tokensGenerated >= 10) {
            // Not yet draining — calculate when to start
            int bufferTarget;
            if (currentTps >= targetTps) {
              bufferTarget = (targetTps * 2).round().clamp(30, 120);
            } else if (currentTps > 0) {
              final ratio = currentTps / targetTps;
              bufferTarget = (_maxTokens * (1.0 - ratio)).ceil();
              bufferTarget = (bufferTarget * 1.05).ceil().clamp(10, _maxTokens);
            } else {
              bufferTarget = _maxTokens; // Can't estimate, wait for all
            }

            if (_tokenBuffer.length >= bufferTarget) {
              _isBuffering = false;
              _startDrainTimer();
            }
          } else if (_drainTimer != null) {
            // Already draining — check if buffer is running low
            final remaining = _tokenBuffer.length - _displayedTokenCount;
            if (remaining <= 3 && !streamDone) {
              // Buffer critically low — pause drain to rebuild
              _drainTimer?.cancel();
              _drainTimer = null;
              _isBuffering = true;
            }
          }
        } else {
          // No buffer: display tokens immediately
          _isBuffering = false;
          _displayedTokenCount = _tokenBuffer.length;
          _flushBufferToDisplay();
        }

        // Update TPS/progress in the bar even during buffering
        notifyListeners();

        if (stopFound) break;
      }

      // Mark stream as done
      streamDone = true;
      _isBuffering = false;

      if (!bufferEnabled) {
        // No buffer: everything already displayed
        _displayedTokenCount = _tokenBuffer.length;
        _flushBufferToDisplay();
      } else if (_drainTimer == null) {
        // Buffer never started draining (genTps < targetTps) — start now with all tokens ready
        _startDrainTimer();
        // Wait for drain to complete
        while (_displayedTokenCount < _tokenBuffer.length) {
          await Future.delayed(const Duration(milliseconds: 16));
        }
        _drainTimer?.cancel();
        _drainTimer = null;
      } else {
        // Drain already running — wait for it to finish
        while (_displayedTokenCount < _tokenBuffer.length) {
          await Future.delayed(const Duration(milliseconds: 16));
        }
        _drainTimer?.cancel();
        _drainTimer = null;
      }

      _isGenerating = false;
      _cancelRequested = false;
      _generationProgress = 0.0;
      _isBuffering = false;
      _generationStartTime = null;
      notifyListeners();

      final finalResponse = accumulatedResponse.trim();
      if (finalResponse.isNotEmpty) {
        _scanLorebook(finalResponse);
      }
      
      // Bot message counts as a message towards depth
      _decrementLoreDepth();
      
      // Save session after AI message is complete
      await _saveChat();

    } catch (e) {
      _drainTimer?.cancel();
      _drainTimer = null;
      _tokenBuffer.clear();
      _isGenerating = false;
      _cancelRequested = false;
      _generationProgress = 0.0;
      _isBuffering = false;
      _generationStartTime = null;

      // Build user-friendly error message
      String errorMsg = e.toString();
      // Strip Dart's "Exception: " prefix for cleaner display
      errorMsg = errorMsg.replaceFirst(RegExp(r'^Exception:\s*'), '');

      if (errorMsg.contains('STREAMING_NOT_SUPPORTED') || errorMsg.contains('HTTP 405')) {
        errorMsg = 'HTTP 405: The server does not support this request. '
            'If streaming is enabled, try disabling it in Settings > Generation Settings. '
            'Also verify your API URL is correct.';
      } else if (errorMsg.contains('Backend process crashed')) {
        errorMsg = 'The backend crashed (likely out of VRAM). '
            'Try reducing GPU layers or context size in Settings.';
      } else if (errorMsg.contains('timed out') || errorMsg.contains('TimeoutException')) {
        errorMsg = 'Request timed out. The model may be too large or the server too slow.';
      }

      _messages.add(ChatMessage(
        text: errorMsg, 
        sender: "System", 
        isUser: false
      ));
      notifyListeners();
    } 
  }

  void _scanLorebook(String text) {
    // Scan all relevant characters' lorebooks
    final characters = _activeGroup != null ? _groupCharacters : (_activeCharacter != null ? [_activeCharacter!] : <CharacterCard>[]);
    if (characters.isEmpty) return;
    
    final lowerText = text.toLowerCase();
    bool changed = false;

    for (final ch in characters) {
      if (ch.lorebook != null) {
        for (final entry in ch.lorebook!.entries) {
          if (!entry.enabled) continue;
          final keys = entry.key.split(',').map((k) => k.trim().toLowerCase()).where((k) => k.isNotEmpty);
          for (final key in keys) {
            if (lowerText.contains(key)) {
              if (!entry.isTriggered) {
                entry.isTriggered = true;
                changed = true;
              }
              entry.remainingDepth = entry.stickyDepth;
              break;
            }
          }
        }
      }

      // Scan shared Worlds
      for (final worldName in ch.worldNames) {
        final world = _worldRepository.worlds.where((w) => w.name == worldName).firstOrNull;
        if (world == null) continue;

        for (final entry in world.lorebook.entries) {
          if (!entry.enabled) continue;
          final keys = entry.key.split(',').map((k) => k.trim().toLowerCase()).where((k) => k.isNotEmpty);
          for (final key in keys) {
            if (lowerText.contains(key)) {
              if (!entry.isTriggered) {
                entry.isTriggered = true;
                changed = true;
              }
              entry.remainingDepth = entry.stickyDepth;
              break;
            }
          }
        }
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _decrementLoreDepth() {
    final characters = _activeGroup != null ? _groupCharacters : (_activeCharacter != null ? [_activeCharacter!] : <CharacterCard>[]);
    if (characters.isEmpty) return;
    bool changed = false;

    for (final ch in characters) {
      if (ch.lorebook != null) {
        for (final entry in ch.lorebook!.entries) {
          if (entry.isTriggered && !entry.constant) {
            entry.remainingDepth--;
            if (entry.remainingDepth <= 0) {
              entry.isTriggered = false;
              changed = true;
            }
          }
        }
      }

      for (final worldName in ch.worldNames) {
        final world = _worldRepository.worlds.where((w) => w.name == worldName).firstOrNull;
        if (world == null) continue;

        for (final entry in world.lorebook.entries) {
          if (entry.isTriggered && !entry.constant) {
            entry.remainingDepth--;
            if (entry.remainingDepth <= 0) {
              entry.isTriggered = false;
              changed = true;
            }
          }
        }
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  String _buildChatHistory() {
    return _messages.map((m) => "${m.sender}: ${m.text}").join("\n");
  }

  void clearChat() async {
    _messages.clear();
    await _saveChat();
    notifyListeners();
  }

  void deleteMessage(int index) async {
    if (index >= 0 && index < _messages.length) {
      _messages.removeAt(index);
      await _saveChat();
      notifyListeners();
    }
  }

  void stopGeneration() {
    if (_isGenerating) {
      _cancelRequested = true;
    }
  }

  void editMessage(int index, String newText) async {
    if (index >= 0 && index < _messages.length) {
      final old = _messages[index];
      _messages[index] = ChatMessage(
        text: newText,
        sender: old.sender,
        isUser: old.isUser,
      );
      await _saveChat();
      notifyListeners();
    }
  }
}
