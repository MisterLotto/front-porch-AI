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
import 'package:front_porch_ai/services/tts_service.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/models/group_chat.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';
import 'package:front_porch_ai/models/world.dart';
import 'package:front_porch_ai/database/database.dart';
import 'package:drift/drift.dart' as drift;

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
  late AppDatabase _db;
  LLMProvider? _llmProvider;
  CharacterRepository? _characterRepository;
  TtsService? _ttsService;

  /// Update the database reference (e.g. after cloud sync replaces the DB file).
  void updateDatabase(AppDatabase db) { _db = db; }

  CharacterCard? _activeCharacter;
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _isLoadingSession = false;
  bool _cancelRequested = false;
  int _generationEpoch = 0;
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

  // ── Director Mode ──
  bool _observerMode = false;
  bool _autoPlayActive = false;
  double directorDelaySec = 15.0; // seconds between auto-chat responses

  // ── Author's Note ──
  String _authorNote = '';
  int _authorNoteStrength = 4;

  // ── Context / Prompt Budget ──
  Map<String, int> _lastPromptBudget = {};
  String _lastAssembledPrompt = '';

  // ── Session Metadata ──
  String? _sessionName;
  String? _sessionDescription;

  // ── Chat Branching ──
  String? _parentSessionId;
  int? _forkIndex;

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

  /// System prompt for Observer Mode — characters interact with each other, user is not present.
  static const String observerModeSystemPrompt =
      'You are roleplaying in a multi-character group conversation. '
      'The user is NOT a participant in this story — they are an invisible observer/director. '
      'CRITICAL RULES:\n'
      '1. You MUST only write dialogue and actions for the character whose turn it is. '
      'NEVER write for other characters.\n'
      '2. Characters should interact naturally WITH EACH OTHER — address other characters by name, '
      'respond to what they said, react to their actions. Build on the conversation organically.\n'
      '3. Stay fully in character — use the speaking character\'s unique voice and personality.\n'
      '4. If a [Director] note appears, follow its guidance to steer the scene (introduce new topics, '
      'create conflict, have a character enter/leave, etc.) but do NOT acknowledge the director directly.\n'
      '5. Write in collaborative roleplay style: *asterisks* for actions, regular text for dialogue.\n'
      '6. Keep responses concise — leave room for the next character to respond.\n'
      '7. Never break character or reference being an AI.\n'
      '8. Characters may naturally address each other, start side conversations, argue, agree, '
      'tell stories, ask questions, or react emotionally — make the conversation feel alive and dynamic.';

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
  bool get observerMode => _observerMode;
  bool get autoPlayActive => _autoPlayActive;
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

  /// Set the database instance after construction.
  void setDatabase(AppDatabase db) {
    _db = db;
  }

  String get authorNote => _authorNote;
  int get authorNoteStrength => _authorNoteStrength;
  Map<String, int> get lastPromptBudget => _lastPromptBudget;
  String get lastAssembledPrompt => _lastAssembledPrompt;
  int get contextSize => _storageService.contextSize;
  String? get parentSessionId => _parentSessionId;
  int? get forkIndex => _forkIndex;
  String? get sessionName => _sessionName;
  String? get sessionDescription => _sessionDescription;

  void setAuthorNote(String note, {int? strength}) {
    _authorNote = note;
    if (strength != null) _authorNoteStrength = strength;
    _saveChat();
    notifyListeners();
  }

  /// Build the Author's Note block with strength-modulated wrapper text.
  /// Strength 1–3: subtle suggestion, 4–7: standard, 8–10: urgent directive.
  String _buildAuthorNoteBlock() {
    if (_authorNote.isEmpty) return '';
    if (_authorNoteStrength <= 3) {
      return '[Author\'s Note (gentle suggestion): $_authorNote]\n';
    } else if (_authorNoteStrength <= 7) {
      return '[Author\'s Note: $_authorNote]\n';
    } else {
      return '[Author\'s Note (IMPORTANT — apply immediately): $_authorNote]\n';
    }
  }

  /// Set the CharacterRepository so group mode can look up characters.
  void setCharacterRepository(CharacterRepository repo) {
    _characterRepository = repo;
  }

  /// Set the LLMProvider after construction (to break circular dependency in provider tree).
  void setLLMProvider(LLMProvider provider) {
    _llmProvider = provider;
  }

  /// Set the CloudSyncService after construction.
  CloudSyncService? _cloudSyncService;
  void setCloudSyncService(CloudSyncService service) {
    _cloudSyncService = service;
  }

  /// Set the TtsService after construction (for TTS-aware auto-play delay).
  void setTtsService(TtsService service) {
    _ttsService = service;
  }

  /// Wait for TTS to finish speaking, then apply the configured delay before auto-play.
  void _waitForTtsThenContinue() {
    if (!_autoPlayActive || !_observerMode) return;
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_autoPlayActive || !_observerMode) {
        timer.cancel();
        return;
      }
      if (_ttsService == null || !_ttsService!.isSpeaking) {
        timer.cancel();
        final delayMs = (directorDelaySec * 1000).round();
        Future.delayed(Duration(milliseconds: delayMs), () {
          if (_autoPlayActive && !_isGenerating) {
            _autoPlayNext();
          }
        });
      }
    });
  }

  Future<void> setActiveCharacter(CharacterCard? character) async {
    // Cancel any in-flight generation before switching context
    await _cancelAndWaitForGeneration();
    _generationEpoch++;

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
    // Cancel any in-flight generation before switching context
    await _cancelAndWaitForGeneration();
    _generationEpoch++;

    if (_characterRepository == null) return;

    // Clear 1:1 mode
    _activeCharacter = null;
    _messages.clear();
    _currentSessionId = null;
    _isLoadingSession = true;
    _turnIndex = 0;
    _activeGroup = group;
    _observerMode = group.directorMode;
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

    // Look up character DB id if in 1:1 mode
    String? characterDbId;
    String? groupDbId;
    if (_activeGroup != null) {
      groupDbId = _activeGroup!.id;
    } else if (_activeCharacter?.dbId != null) {
      characterDbId = _activeCharacter!.dbId;
    }

    // Upsert session (INSERT OR REPLACE to avoid UNIQUE constraint errors)
    final timestamp = int.tryParse(_currentSessionId!) ?? 0;
    final createdAt = timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now();
    await _db.upsertSession(SessionsCompanion.insert(
      id: _currentSessionId!,
      characterId: drift.Value(characterDbId),
      groupId: drift.Value(groupDbId),
      name: drift.Value(_sessionName),
      description: drift.Value(_sessionDescription),
      authorNote: drift.Value(_authorNote),
      authorNoteDepth: drift.Value(_authorNoteStrength),
      parentSession: drift.Value(_parentSessionId),
      forkIndex: drift.Value(_forkIndex),
      createdAt: drift.Value(createdAt),
      updatedAt: drift.Value(DateTime.now()),
    ));

    // Replace all messages for this session
    await _db.deleteMessagesForSession(_currentSessionId!);
    final messageBatch = <MessagesCompanion>[];
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      messageBatch.add(MessagesCompanion(
        sessionId: drift.Value(_currentSessionId!),
        position: drift.Value(i),
        sender: drift.Value(m.sender),
        isUser: drift.Value(m.isUser),
        characterId: drift.Value(m.characterId),
        swipes: drift.Value(jsonEncode(m.swipes)),
        swipeIndex: drift.Value(m.swipeIndex),
        swipeDurations: drift.Value(jsonEncode(m.swipeDurations)),
      ));
    }
    if (messageBatch.isNotEmpty) {
      await _db.insertMessages(messageBatch);
    }
  }

  Future<void> _loadLastSession() async {
    if (_activeCharacter == null && _activeGroup == null) return;
    
    // Get sessions from DB
    List<Session> sessions;
    if (_activeGroup != null) {
      sessions = await _db.getSessionsForGroup(_activeGroup!.id);
    } else if (_activeCharacter?.dbId != null) {
      sessions = await _db.getSessionsForCharacter(_activeCharacter!.dbId!);
    } else {
      return;
    }

    if (sessions.isEmpty) return;

    // Sessions are already sorted descending by createdAt
    final lastSession = sessions.first;
    _currentSessionId = lastSession.id;
    _authorNote = lastSession.authorNote;
    _authorNoteStrength = lastSession.authorNoteDepth;
    _sessionName = lastSession.name;
    _sessionDescription = lastSession.description;
    _parentSessionId = lastSession.parentSession;
    _forkIndex = lastSession.forkIndex;

    // Load messages
    try {
      final dbMessages = await _db.getMessagesForSession(_currentSessionId!);
      _messages.clear();
      for (final m in dbMessages) {
        List<String> swipes;
        try { swipes = List<String>.from(jsonDecode(m.swipes)); } catch (_) { swipes = ['']; }
        List<int> swipeDurations;
        try { swipeDurations = List<int>.from((jsonDecode(m.swipeDurations) as List).map((e) => (e as num).toInt())); } catch (_) { swipeDurations = [0]; }

        _messages.add(ChatMessage(
          text: swipes.isNotEmpty ? swipes[m.swipeIndex] : '',
          sender: m.sender,
          isUser: m.isUser,
          characterId: m.characterId,
          swipes: swipes,
          swipeIndex: m.swipeIndex,
          swipeDurations: swipeDurations,
        ));
      }

      if (_messages.isNotEmpty) {
        _scanLorebook(_messages.last.text);
      }
    } catch (e) {
      print('Error loading chat session: $e');
    }
  }

  /// Get sessions for a given character/group ID without setting it as active.
  Future<List<Map<String, dynamic>>> getSessionsForId(String charId) async {
    // Determine if this is a group or character
    List<Session> dbSessions;
    if (charId.startsWith('group_')) {
      final groupId = charId.replaceFirst('group_', '');
      dbSessions = await _db.getSessionsForGroup(groupId);
    } else {
      // Find character by imagePath basename
      final allChars = await _db.getAllCharacters();
      final match = allChars.where((c) {
        if (c.imagePath == null) return false;
        return path.basenameWithoutExtension(c.imagePath!) == charId;
      }).firstOrNull;
      if (match != null) {
        dbSessions = await _db.getSessionsForCharacter(match.id);
      } else {
        dbSessions = [];
      }
    }

    List<Map<String, dynamic>> sessions = [];
    for (final s in dbSessions) {
      final timestamp = int.tryParse(s.id) ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

      // Get message count and preview
      final msgs = await _db.getMessagesForSession(s.id);
      String preview = 'New Conversation';
      if (s.name != null && s.name!.isNotEmpty) {
        preview = s.name!;
      } else if (msgs.length > 1) {
        // Use second message text as preview
        try {
          final swipes = List<String>.from(jsonDecode(msgs[1].swipes));
          preview = swipes.isNotEmpty ? swipes[msgs[1].swipeIndex] : '';
          if (preview.length > 50) preview = '${preview.substring(0, 50)}...';
        } catch (_) {}
      }

      sessions.add({
        'id': s.id,
        'date': date,
        'preview': preview,
        'message_count': msgs.length,
        if (s.name != null) 'session_name': s.name,
        if (s.description != null) 'session_description': s.description,
        if (s.parentSession != null) 'parent_session': s.parentSession,
        if (s.forkIndex != null) 'fork_index': s.forkIndex,
      });
    }

    sessions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return sessions;
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    if (_activeCharacter == null && _activeGroup == null) return [];
    final charId = _getCharacterId();
    return getSessionsForId(charId);
  }

  Future<void> loadSession(String sessionId) async {
    if (_activeCharacter == null && _activeGroup == null) return;
    
    final session = await _db.getSessionById(sessionId);
    if (session == null) return;

    try {
      final dbMessages = await _db.getMessagesForSession(sessionId);
      _messages.clear();
      for (final m in dbMessages) {
        List<String> swipes;
        try { swipes = List<String>.from(jsonDecode(m.swipes)); } catch (_) { swipes = ['']; }
        List<int> swipeDurations;
        try { swipeDurations = List<int>.from((jsonDecode(m.swipeDurations) as List).map((e) => (e as num).toInt())); } catch (_) { swipeDurations = [0]; }

        _messages.add(ChatMessage(
          text: swipes.isNotEmpty ? swipes[m.swipeIndex] : '',
          sender: m.sender,
          isUser: m.isUser,
          characterId: m.characterId,
          swipes: swipes,
          swipeIndex: m.swipeIndex,
          swipeDurations: swipeDurations,
        ));
      }

      _currentSessionId = sessionId;
      _authorNote = session.authorNote;
      _authorNoteStrength = session.authorNoteDepth;
      _sessionName = session.name;
      _sessionDescription = session.description;
      _parentSessionId = session.parentSession;
      _forkIndex = session.forkIndex;

      if (_messages.isNotEmpty) {
        _scanLorebook(_messages.last.text);
      }
      notifyListeners();
    } catch (e) {
      print('Error loading session $sessionId: $e');
    }
  }

  /// Rename a session.
  Future<void> renameSession(String sessionId, String name) async {
    final session = await _db.getSessionById(sessionId);
    if (session == null) return;

    await _db.updateSession(SessionsCompanion(
      id: drift.Value(sessionId),
      name: drift.Value(name.isEmpty ? null : name),
      updatedAt: drift.Value(DateTime.now()),
    ));

    // Update in-memory if this is the current session
    if (sessionId == _currentSessionId) {
      _sessionName = name.isEmpty ? null : name;
      notifyListeners();
    }
  }

  /// Update the description of a session.
  Future<void> updateSessionDescription(String sessionId, String description) async {
    final session = await _db.getSessionById(sessionId);
    if (session == null) return;

    await _db.updateSession(SessionsCompanion(
      id: drift.Value(sessionId),
      description: drift.Value(description.isEmpty ? null : description),
      updatedAt: drift.Value(DateTime.now()),
    ));

    // Update in-memory if this is the current session
    if (sessionId == _currentSessionId) {
      _sessionDescription = description.isEmpty ? null : description;
      notifyListeners();
    }
  }

  /// Create a new session by forking from message at [messageIndex].
  /// Copies messages 0..messageIndex into a new session and switches to it.
  Future<void> forkFromMessage(int messageIndex) async {
    if ((_activeCharacter == null && _activeGroup == null) || _currentSessionId == null) return;
    if (messageIndex < 0 || messageIndex >= _messages.length) return;

    final oldSessionId = _currentSessionId!;
    final forkedMessages = _messages.sublist(0, messageIndex + 1).map((m) =>
      ChatMessage(
        text: m.text,
        sender: m.sender,
        isUser: m.isUser,
        characterId: m.characterId,
        swipes: List.from(m.swipes),
        swipeIndex: m.swipeIndex,
        swipeDurations: List.from(m.swipeDurations),
      )
    ).toList();

    _messages.clear();
    _messages.addAll(forkedMessages);
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _parentSessionId = oldSessionId;
    _forkIndex = messageIndex;

    await _saveChat();
    notifyListeners();
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

    // In observer mode, route to sendDirectorNote instead
    if (_observerMode && _activeGroup != null) {
      await sendDirectorNote(text);
      return;
    }

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

  /// Set observer mode on/off.
  void setObserverMode(bool value) {
    _observerMode = value;
    if (!value) {
      _autoPlayActive = false;
    }
    notifyListeners();
  }

  /// Send a director note — appears as a bracketed instruction in the prompt
  /// but is not part of the in-story dialogue.
  Future<void> sendDirectorNote(String text) async {
    if (_activeGroup == null || text.trim().isEmpty) return;

    _messages.add(ChatMessage(
      text: text,
      sender: 'Director',
      isUser: true,
      characterId: '__director__',
    ));
    await _saveChat();
    notifyListeners();

    _scanLorebook(text);
    _decrementLoreDepth();

    await _generateResponse(GenerationMode.normal);
  }

  /// Start auto-play: characters keep chatting automatically.
  void startAutoPlay() {
    if (_activeGroup == null || !_observerMode) return;
    _autoPlayActive = true;
    notifyListeners();
    _autoPlayNext();
  }

  /// Stop auto-play.
  void stopAutoPlay() {
    _autoPlayActive = false;
    notifyListeners();
  }

  /// Internal: trigger the next auto-play response.
  Future<void> _autoPlayNext() async {
    if (!_autoPlayActive || !_observerMode || _activeGroup == null) return;
    if (_isGenerating) return; // wait for current generation to finish

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

  Future<void> impersonateUser({String prefix = '', required Function(String accumulated) onToken}) async {
    if ((_activeCharacter == null && _activeGroup == null) || _isGenerating) return;

    _isGenerating = true;
    _cancelRequested = false;
    notifyListeners();

    try {
      final userName = _userPersonaService.persona.name;

      // Determine the speaking character (needed for prompt construction)
      CharacterCard speakingCharacter;
      if (_activeGroup != null) {
        speakingCharacter = _groupCharacters.first;
      } else {
        speakingCharacter = _activeCharacter!;
      }

      // Build prompt the same way _generateResponse does
      final String systemPrompt;
      if (_activeGroup != null && _activeGroup!.systemPrompt.isNotEmpty) {
        systemPrompt = _activeGroup!.systemPrompt;
      } else if (_activeGroup != null) {
        systemPrompt = _observerMode ? observerModeSystemPrompt : defaultGroupSystemPrompt;
      } else if (speakingCharacter.systemPrompt.isNotEmpty) {
        systemPrompt = speakingCharacter.systemPrompt;
      } else if (_storageService.systemPrompt.isNotEmpty) {
        systemPrompt = _storageService.systemPrompt;
      } else {
        final isApi = _llmProvider != null && !_llmProvider!.isLocal;
        systemPrompt = isApi ? defaultApiSystemPrompt : defaultKoboldSystemPrompt;
      }

      // Lorebook
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
        loreContent = speakingCharacter.replacePlaceholders(loreContent, userName: userName);
      }

      // Persona & scenario
      String personaBlock;
      if (_activeGroup != null) {
        final personas = _groupCharacters.map((ch) =>
          "${ch.name}'s Persona: ${ch.replacePlaceholders(ch.personality, userName: userName)}").toList();
        personaBlock = personas.join('\n');
      } else {
        personaBlock = "${speakingCharacter.name}'s Persona: ${speakingCharacter.replacePlaceholders(speakingCharacter.personality, userName: userName)}";
      }

      String rawScenario = '';
      if (_activeGroup != null && _activeGroup!.scenario.isNotEmpty) {
        rawScenario = _activeGroup!.scenario;
      } else {
        final scenarioChar = _activeGroup != null ? _groupCharacters.first : speakingCharacter;
        rawScenario = scenarioChar.scenario;
      }
      final scenario = speakingCharacter.replacePlaceholders(rawScenario, userName: userName);

      String history = _buildChatHistory();

      // Suffix: user name + any partial text the user typed
      String suffix = "\n$userName:";
      if (prefix.isNotEmpty) {
        suffix = "$suffix $prefix";
      }

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

      String postHistoryBlock = '';
      if (speakingCharacter.postHistoryInstructions.isNotEmpty) {
        postHistoryBlock = '${speakingCharacter.replacePlaceholders(speakingCharacter.postHistoryInstructions, userName: userName)}\n';
      }

      String authorNoteBlock = '';
      if (_authorNote.isNotEmpty) {
        authorNoteBlock = _buildAuthorNoteBlock();
      }

      // Impersonate instruction — comprehensive guidance for writing as the user
      final impersonateInstruction =
          '[System: You are now writing as $userName (the user), NOT as ${speakingCharacter.name} or any other character. '
          'Compose $userName\'s next message in first person. '
          'Match $userName\'s established voice, personality, and writing style from the conversation so far. '
          'Write only $userName\'s words and actions — never narrate for ${speakingCharacter.name} or other characters. '
          'Do not include meta-commentary, stage directions for others, or break the fourth wall. '
          'Keep the response natural, and consistent with the scene.]\n';

      final prompt = "$systemPrompt\n"
          "$loreContent"
          "$personaBlock\n"
          "Scenario: $scenario\n"
          "$mesExampleBlock"
          "<START>\n"
          "$history"
          "$postHistoryBlock"
          "$authorNoteBlock"
          "$impersonateInstruction"
          "$suffix";

      // Stop sequences: character names only (not user — we ARE the user)
      final stopSequences = {
        ..._storageService.stopSequences,
      };
      if (_activeGroup != null) {
        for (final ch in _groupCharacters) {
          stopSequences.add('\n${ch.name}:');
        }
      } else {
        stopSequences.add('\n${_activeCharacter!.name}:');
      }

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
        xtcThreshold: _storageService.xtcThreshold,
        xtcProbability: _storageService.xtcProbability,
        stopSequences: stopSequences.toList(),
        // Always disable reasoning for impersonate — we only want plain text
        reasoningEnabled: false,
        reasoningEffort: _storageService.reasoningEffort,
      );

      final stream = llmService.generateStream(genParams);
      String accumulated = prefix;
      bool inThinkBlock = false;

      await for (final token in stream) {
        if (_cancelRequested) break;
        // Filter out <think>...</think> reasoning blocks entirely
        if (token.contains('<think>')) {
          inThinkBlock = true;
          continue;
        }
        if (token.contains('</think>')) {
          inThinkBlock = false;
          continue;
        }
        if (inThinkBlock) continue;
        accumulated += token;
        onToken(accumulated);
      }
    } catch (e) {
      print('Impersonate error: $e');
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
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
    final epoch = ++_generationEpoch;
    _isGenerating = true;
    _generationProgress = 0.0;
    _tokensGenerated = 0;
    _maxTokens = _storageService.maxLength;
    _generationStartTime = DateTime.now();
    _isBuffering = true;
    notifyListeners();

    try {
      final userName = _userPersonaService.persona.name;

      // Determine the speaking character first (needed for system prompt priority)
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

      // ── System prompt selection ──
      // Priority: group custom > group default > character > user global > backend default
      final String systemPrompt;
      if (_activeGroup != null && _activeGroup!.systemPrompt.isNotEmpty) {
        // User wrote a custom group system prompt — use it
        systemPrompt = _activeGroup!.systemPrompt;
      } else if (_activeGroup != null) {
        // Group mode, no custom prompt — use observer or default
        systemPrompt = _observerMode ? observerModeSystemPrompt : defaultGroupSystemPrompt;
      } else if (speakingCharacter.systemPrompt.isNotEmpty) {
        // Character has its own system prompt — use it
        systemPrompt = speakingCharacter.systemPrompt;
      } else if (_storageService.systemPrompt.isNotEmpty) {
        // Single-char mode with a user-defined global prompt — respect it
        systemPrompt = _storageService.systemPrompt;
      } else {
        // Single-char mode, no user prompt — pick default based on backend
        final isApi = _llmProvider != null && !_llmProvider!.isLocal;
        systemPrompt = isApi ? defaultApiSystemPrompt : defaultKoboldSystemPrompt;
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

      // Build post-history instructions block
      String postHistoryBlock = '';
      if (speakingCharacter.postHistoryInstructions.isNotEmpty) {
        postHistoryBlock = '${speakingCharacter.replacePlaceholders(speakingCharacter.postHistoryInstructions, userName: userName)}\n';
      }

      // Author's note — placed right before the character speaks for maximum influence
      String authorNoteBlock = '';
      if (_authorNote.isNotEmpty) {
        authorNoteBlock = _buildAuthorNoteBlock();
      }

      final prompt = "$systemPrompt\n"
          "$loreContent"
          "$personaBlock\n"
          "Scenario: $scenario\n"
          "$mesExampleBlock"
          "<START>\n"
          "$history"
          "$postHistoryBlock"
          "$authorNoteBlock"
          "$suffix";

      // Track prompt budget for context viewer
      _lastAssembledPrompt = prompt;
      _lastPromptBudget = {
        'System Prompt': (systemPrompt.length / 4).ceil(),
        'Lorebook': (loreContent.length / 4).ceil(),
        'Persona': (personaBlock.length / 4).ceil(),
        'Scenario': ('Scenario: $scenario'.length / 4).ceil(),
        'Examples': (mesExampleBlock.length / 4).ceil(),
        'Chat History': (history.length / 4).ceil(),
        'Post-History': (postHistoryBlock.length / 4).ceil(),
        'Author\'s Note': (authorNoteBlock.length / 4).ceil(),
      };
      // Remove zero-value entries
      _lastPromptBudget.removeWhere((_, v) => v == 0);

      // Stop sequences: include character names, and user name (except when impersonating)
      final stopSequences = {
        ..._storageService.stopSequences,
      };
      // In impersonate mode the model IS the user, so don't stop on user name
      if (mode != GenerationMode.impersonate) {
        stopSequences.add('\nUser:');
        stopSequences.add('\n${_userPersonaService.persona.name}:');
      }
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
        xtcThreshold: _storageService.xtcThreshold,
        xtcProbability: _storageService.xtcProbability,
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
        if (epoch != _generationEpoch) return; // stale generation
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
          if (epoch != _generationEpoch) { _drainTimer?.cancel(); _drainTimer = null; return; } // stale
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
            // Buffer target = how many tokens fill the configured duration
            final bufferDuration = _storageService.bufferDurationSeconds;
            int bufferTarget;
            if (currentTps > 0) {
              bufferTarget = (currentTps * bufferDuration).round().clamp(5, _maxTokens);
            } else {
              bufferTarget = 30; // Fallback if TPS unknown
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

      // Only finalize if this generation is still current
      if (epoch == _generationEpoch) {
        final finalResponse = accumulatedResponse.trim();
        if (finalResponse.isNotEmpty) {
          _scanLorebook(finalResponse);
        }
        
        // Bot message counts as a message towards depth
        _decrementLoreDepth();
        
        // Save session after AI message is complete
        await _saveChat();

        // Auto-play: if director mode is active, queue the next character
        if (_autoPlayActive && _observerMode && _activeGroup != null) {
          // If TTS is active, wait for it to finish before starting the delay
          if (_ttsService != null && _ttsService!.isSpeaking) {
            _waitForTtsThenContinue();
          } else {
            final delayMs = (directorDelaySec * 1000).round();
            Future.delayed(Duration(milliseconds: delayMs), () {
              if (_autoPlayActive && !_isGenerating) {
                _autoPlayNext();
              }
            });
          }
        }
      }

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
    final lines = _messages.map((m) {
      // Director notes get bracketed so the AI treats them as instructions
      if (m.characterId == '__director__') {
        return '[Director: ${m.text}]';
      }
      return '${m.sender}: ${m.text}';
    }).toList();
    return lines.join("\n");
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
      // Abort the in-flight HTTP request so we don't have to wait for the next token
      _llmProvider?.activeService.abortGeneration();
    }
  }

  /// Cancel any in-flight generation and wait for it to fully stop.
  Future<void> _cancelAndWaitForGeneration() async {
    if (!_isGenerating) return;
    _cancelRequested = true;
    // Spin until _generateResponse finishes its cleanup
    while (_isGenerating) {
      await Future.delayed(const Duration(milliseconds: 10));
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
