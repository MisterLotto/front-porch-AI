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

import 'dart:async';
import 'dart:convert';
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
import 'package:front_porch_ai/services/group_chat_repository.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/group_chat.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';
import 'package:front_porch_ai/services/memory_service.dart';
import 'package:front_porch_ai/database/database.dart';
import 'package:drift/drift.dart' as drift;

// ── Realism Engine GBNF Grammars ─────────────────────────────────────────────
// Used by KoboldCPP local backend when reasoning mode is OFF.
// Forces JSON-structured output at the token-sampling level, guaranteeing the
// model can't ramble past the closing } and doesn't need excessive max_tokens.
//
// Each grammar accepts any well-formed JSON object so optional fields
// (e.g. arousal_delta) are naturally handled without a rigid schema.

/// General-purpose JSON object grammar: accepts any flat {"key": value, ...}
/// where values may be strings, numbers, or booleans. Sufficient for all
/// Realism Engine evals which return small flat JSON objects.
const String _kGbnfJsonObject = r'''
root   ::= ws "{" ws members ws "}" ws
members ::= pair (ws "," ws pair)*
pair    ::= string ws ":" ws value
value   ::= string | number | boolean | "null"
string  ::= "\"" ([^"\\] | "\\" .)* "\""
number  ::= "-"? ([0-9] | [1-9][0-9]*) ("." [0-9]+)? (([eE] [+-]? [0-9]+))?
boolean ::= "true" | "false"
ws      ::= [ \t\n\r]*
''';

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
  Map<String, dynamic>? metadata; // Legacy single metadata
  List<Map<String, dynamic>?> swipeMetadata; // Per-swipe metadata

  Map<String, dynamic>? get activeMetadata {
    if (swipeIndex >= 0 && swipeIndex < swipeMetadata.length) {
      return swipeMetadata[swipeIndex] ?? metadata;
    }
    return metadata;
  }

  set activeMetadata(Map<String, dynamic>? value) {
    while (swipeMetadata.length <= swipeIndex) {
      swipeMetadata.add(null);
    }
    swipeMetadata[swipeIndex] = value;
  }

  ChatMessage({
    required String text, 
    required this.sender, 
    required this.isUser, 
    this.characterId, 
    List<String>? swipes, 
    int? swipeIndex, 
    List<int>? swipeDurations, 
    this.metadata,
    List<Map<String, dynamic>?>? swipeMetadata,
  })
    : swipes = swipes ?? [text],
      swipeIndex = swipeIndex ?? 0,
      swipeDurations = swipeDurations ?? [0],
      swipeMetadata = swipeMetadata ?? [metadata];

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'sender': sender,
      'is_user': isUser,
      if (characterId != null) 'character_id': characterId,
      'swipes': swipes,
      'swipe_index': swipeIndex,
      'swipe_durations': swipeDurations,
      if (metadata != null) 'metadata': metadata,
      if (swipeMetadata.any((e) => e != null)) 'swipe_metadata': swipeMetadata,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final List<String>? savedSwipes = (json['swipes'] as List<dynamic>?)?.map((e) => e.toString()).toList();
    final List<int>? savedDurations = (json['swipe_durations'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList();
    final String fallbackText = json['text'] ?? '';
    final List<Map<String, dynamic>?>? savedSwipeMetadata = (json['swipe_metadata'] as List<dynamic>?)
        ?.map((e) => e != null ? Map<String, dynamic>.from(e as Map) : null).toList();
        
    return ChatMessage(
      text: fallbackText,
      sender: json['sender'] ?? '',
      isUser: json['is_user'] ?? false,
      characterId: json['character_id'],
      swipes: savedSwipes ?? [fallbackText],
      swipeIndex: json['swipe_index'] ?? 0,
      swipeDurations: savedDurations ?? [0],
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
      swipeMetadata: savedSwipeMetadata,
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
  MemoryService? _memoryService;

  // Action suggestions
  List<String> _suggestedActions = [];
  bool _isGeneratingActions = false;
  List<String> get suggestedActions => _suggestedActions;
  bool get isGeneratingActions => _isGeneratingActions;

  // Objective/quest system
  Objective? _activeObjective;
  int _messagesSinceLastCheck = 0;
  bool _isCheckingCompletion = false;
  Objective? get activeObjective => _activeObjective;
  List<Map<String, dynamic>> get objectiveTasks {
    if (_activeObjective == null) return [];
    try {
      return (jsonDecode(_activeObjective!.tasks) as List)
          .cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Update the database reference (e.g. after cloud sync replaces the DB file).
  void updateDatabase(AppDatabase db) { _db = db; }

  CharacterCard? _activeCharacter;
  final List<ChatMessage> _messages = [];
  Map<String, dynamic>? _pendingRealismMetadata; // stores deltas for the next generation
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

  // ── Web SSE token broadcast ──
  // External consumers (e.g. WebChatBridge) listen to this for real-time token streaming.
  final StreamController<String> _tokenBroadcast = StreamController<String>.broadcast();
  Stream<String> get tokenStream => _tokenBroadcast.stream;

  /// Emits complete sentences as they're detected during LLM token streaming.
  /// Used by call mode to start TTS on the first sentence immediately.
  final StreamController<String> _sentenceBroadcast = StreamController<String>.broadcast();
  Stream<String> get sentenceStream => _sentenceBroadcast.stream;
  String _sentenceBuffer = ''; // accumulates tokens until a sentence boundary

  /// Whether the app is in voice call mode (auto-disables reasoning for lower latency).
  bool _callMode = false;
  bool get callMode => _callMode;
  set callMode(bool value) {
    _callMode = value;
    notifyListeners();
  }

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

  // ── Chat Summary ──
  String _summary = '';
  int _summaryLastIndex = 0;
  bool _summaryPaused = false;
  bool _isSummaryGenerating = false;

  // ── Realism Mode ──
  bool _realismEnabled = false; // master toggle
  bool _isEvaluatingRealism = false;
  String _realismEvalStreamText = '';

  // Relationship (Short-Term / Tension)
  int _affectionScore = 0; 
  int _relationshipTier = 0; 

  // Long-Term Bond
  int _longTermScore = 0;
  int _longTermTier = 0;
  int _turnsSinceLongTermCheck = 0;
  int _shortTermDeltasSummary = 0;

  // Short-term mood
  int _shortTermMood = 0; // -5 to +5
  int _moodDecayCounter = 0;

  // Emotional state
  String _characterEmotion = '';
  String _emotionIntensity = ''; // mild/moderate/strong

  // Passage of time
  String _timeOfDay = 'morning';
  int _dayCount = 1;

  // NSFW cooldown & lust
  bool _nsfwCooldownEnabled = false;
  int _cooldownTurnsRemaining = 0;
  int _arousalLevel = 0; // -3 to 10 scale
  
  // ── v3 Behavioral Mechanics ──
  int _trustLevel = 0; // -100 to 100
  String _activeFixation = '';
  int _fixationLifespan = 0; // turns until fixation naturally clears
  String _spatialStance = '';

  // ── Trust Repair ──
  // Armed on each severe trust drop (≥ -20 delta). Consumed on the very
  // next user message, then resets so future drops each get one shot.
  bool _pendingTrustRepair = false;

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
  String get summary => _summary;
  bool get summaryPaused => _summaryPaused;
  int get summaryLastIndex => _summaryLastIndex;
  bool get isSummaryGenerating => _isSummaryGenerating;
  int get affectionScore => _affectionScore;
  int get relationshipTier => _relationshipTier;
  int get longTermScore => _longTermScore;
  int get longTermTier => _longTermTier;
  bool get realismEnabled => _realismEnabled;
  bool get isEvaluatingRealism => _isEvaluatingRealism;
  String get realismEvalStreamText => _realismEvalStreamText;
  int get shortTermMood => _shortTermMood;
  String get characterEmotion => _characterEmotion;
  String get emotionIntensity => _emotionIntensity;
  String get timeOfDay => _timeOfDay;
  int get dayCount => _dayCount;
  bool get nsfwCooldownEnabled => _nsfwCooldownEnabled;
  int get cooldownTurnsRemaining => _cooldownTurnsRemaining;
  int get arousalLevel => _arousalLevel;

  int get shortTermProgressTarget {
    final absScore = _affectionScore.abs();
    if (absScore < 10) return 10;
    if (absScore < 25) return 25;
    if (absScore < 45) return 45;
    if (absScore < 70) return 70;
    if (absScore < 100) return 100;
    return 150; // max
  }

  int get shortTermProgressBase {
    final absScore = _affectionScore.abs();
    if (absScore < 10) return 0;
    if (absScore < 25) return 10;
    if (absScore < 45) return 25;
    if (absScore < 70) return 45;
    if (absScore < 100) return 70;
    return 100;
  }

  double get shortTermProgressPercent {
    final current = _affectionScore.abs() - shortTermProgressBase;
    final total = shortTermProgressTarget - shortTermProgressBase;
    return (current / total).clamp(0.0, 1.0);
  }

  int get longTermProgressTarget {
    final absScore = _longTermScore.abs();
    if (absScore < 10) return 10;
    if (absScore < 25) return 25;
    if (absScore < 45) return 45;
    if (absScore < 70) return 70;
    if (absScore < 100) return 100;
    return 150; // max
  }

  int get longTermProgressBase {
    final absScore = _longTermScore.abs();
    if (absScore < 10) return 0;
    if (absScore < 25) return 10;
    if (absScore < 45) return 25;
    if (absScore < 70) return 45;
    if (absScore < 100) return 70;
    return 100;
  }

  double get longTermProgressPercent {
    final current = _longTermScore.abs() - longTermProgressBase;
    final total = longTermProgressTarget - longTermProgressBase;
    return (current / total).clamp(0.0, 1.0);
  }

  /// Human-readable tier name for the current relationship level.
  int _calculateTier(int score) {
    final absScore = score.abs();
    if (absScore < 10) return 0;
    if (absScore < 25) return score > 0 ? 1 : -1;
    if (absScore < 45) return score > 0 ? 2 : -2;
    if (absScore < 70) return score > 0 ? 3 : -3;
    if (absScore < 100) return score > 0 ? 4 : -4;
    return score > 0 ? 5 : -5;
  }

  String get shortTermTierName {
    switch (_relationshipTier) {
      case 5: return 'Intimate';
      case 4: return 'Close Friend';
      case 3: return 'Friend';
      case 2: return 'Acquaintance';
      case 1: return 'Friendly';
      case 0: return 'Stranger / Neutral';
      case -1: return 'Annoyed';
      case -2: return 'Frustrated';
      case -3: return 'Disliked';
      case -4: return 'Hostile';
      case -5: return 'Bitter Enemy';
      default: return 'Unknown';
    }
  }

  String get longTermTierName {
    switch (_longTermTier) {
      case 5: return 'Soulmate / Devoted';
      case 4: return 'Unbreakable Bond';
      case 3: return 'Deep Connection';
      case 2: return 'Growing Trust';
      case 1: return 'Establishing Trust';
      case 0: return 'No Deep Ties';
      case -1: return 'Distant';
      case -2: return 'Fractured';
      case -3: return 'Broken Trust';
      case -4: return 'Deep Resentment';
      case -5: return 'Nemesis';
      default: return 'Unknown';
    }
  }

  int get trustLevel => _trustLevel;
  int get trustTier => _calculateTier(_trustLevel);
  bool get pendingTrustRepair => _pendingTrustRepair;

  String get trustTierName {
    switch (trustTier) {
      case 5: return 'Blind Trust';
      case 4: return 'Implicit Trust';
      case 3: return 'Deeply Trusting';
      case 2: return 'Trusting';
      case 1: return 'Benefit of Doubt';
      case 0: return 'Neutral / Guarded';
      case -1: return 'Wary';
      case -2: return 'Suspicious';
      case -3: return 'Distrustful';
      case -4: return 'Paranoid';
      case -5: return 'Absolute Distrust';
      default: return 'Unknown';
    }
  }

  int get trustProgressBase {
    final absScore = _trustLevel.abs();
    if (absScore < 10) return 0;
    if (absScore < 25) return 10;
    if (absScore < 45) return 25;
    if (absScore < 70) return 45;
    if (absScore < 100) return 70;
    return 100;
  }

  int get trustProgressTarget {
    final absScore = _trustLevel.abs();
    if (absScore < 10) return 10;
    if (absScore < 25) return 25;
    if (absScore < 45) return 45;
    if (absScore < 70) return 70;
    return 100;
  }

  double get trustProgressPercent {
    final current = _trustLevel.abs() - trustProgressBase;
    final total = trustProgressTarget - trustProgressBase;
    return (current / total).clamp(0.0, 1.0);
  }

  /// Human-readable mood label containing exact emotion string and valence direction.
  String get moodLabel {
    String directionalLabel;
    if (_shortTermMood >= 12) directionalLabel = 'Elated';
    else if (_shortTermMood >= 5) directionalLabel = 'Pleased';
    else if (_shortTermMood > 0) directionalLabel = 'Positive';
    else if (_shortTermMood == 0) directionalLabel = 'Neutral';
    else if (_shortTermMood > -5) directionalLabel = 'Negative';
    else if (_shortTermMood > -12) directionalLabel = 'Hostile';
    else directionalLabel = 'Furious';

    if (_characterEmotion.isEmpty) {
      return directionalLabel;
    }
    
    // Capitalize explicitly defined emotion string
    final capEmotion = _characterEmotion.substring(0, 1).toUpperCase() + _characterEmotion.substring(1);
    
    // In Neutral, maybe don't append bracketed text if there is an explicit emotion
    return '$capEmotion [$directionalLabel]';
  }

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

  /// Build the user persona block for the generation prompt.
  /// Layered: user's self-description is ground truth, learned facts are additive.
  /// When the embedding service is available, selects only the most relevant facts
  /// for the current conversation context instead of injecting all facts.
  Future<String> _buildUserPersonaBlock(String userName) async {
    final persona = _userPersonaService.persona;
    final description = persona.description.trim();
    final allFacts = persona.learnedFacts;

    // Nothing to inject
    if (description.isEmpty && allFacts.isEmpty) return '';

    // Select relevant facts using embeddings if available
    List<String> facts;
    if (allFacts.length > 15 && _memoryService != null) {
      // Build context from last few messages
      final recentContext = _messages.reversed.take(3)
          .map((m) => '${m.sender}: ${m.displayText}').join('\n');
      facts = await _userPersonaService.getRelevantFacts(
        conversationContext: recentContext,
        embedService: _memoryService!.embeddingService,
        maxFacts: 15,
      );
    } else {
      facts = List<String>.from(allFacts);
    }

    final buf = StringBuffer();
    buf.writeln("$userName's Persona: $description");

    if (facts.isNotEmpty) {
      buf.writeln('[Discovered traits — observations learned from conversation. '
          'The user\'s self-description above takes priority if there is a conflict.]');
      for (final fact in facts) {
        buf.writeln('- $fact');
      }
    }
    buf.writeln();
    return buf.toString();
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

  /// Set the MemoryService after construction (for RAG memory retrieval).
  void setMemoryService(MemoryService service) {
    _memoryService = service;
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

    // If same character is already active, don't reset unless empty.
    // Use dbId (stable DB identifier) rather than imagePath which can
    // differ in format (basename vs full path) between repository and runtime.
    if (_activeCharacter?.name == character?.name &&
        _activeCharacter?.dbId == character?.dbId &&
        _messages.isNotEmpty) {
      return;
    }

    // Clear group mode when switching to 1:1
    _activeGroup = null;
    _groupCharacters = [];
    _turnIndex = 0;

    _activeCharacter = character;

    // Load active objective for this character
    _loadActiveObjective();
    // Load evolved personality/scenario from DB
    _loadEvolvedFields();
    debugPrint('[ChatService] 🟡 setActiveCharacter: clearing messages '
        '(had ${_messages.length}) for ${character?.name}, loading session...');
    _messages.clear();
    _currentSessionId = null;
    _summary = '';
    _summaryLastIndex = 0;
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
    debugPrint('[ChatService] 🟡 setActiveGroup: clearing messages '
        '(had ${_messages.length}) for group ${group.name}');
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
        for (final entry in ch.lorebook!.entries) {
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

    // Load evolved fields for all group characters
    _loadGroupEvolvedFields();

    _isLoadingSession = false;
    notifyListeners();
  }

  /// Fork the current 1:1 chat into a new group chat, copying all messages.
  /// The original 1:1 session remains untouched.
  Future<GroupChat?> forkToGroupChat(
    List<CharacterCard> additionalCharacters,
    GroupChatRepository groupRepo, {
    String? groupName,
    String? scenario,
    TurnOrder turnOrder = TurnOrder.roundRobin,
  }) async {
    if (_isGenerating) return null;
    if (_activeCharacter == null || _characterRepository == null) return null;
    if (_messages.isEmpty) return null;
    if (_db == null) return null;

    final originalCharId = _getCharacterIdFromCard(_activeCharacter!);
    final allCharIds = [originalCharId, ...additionalCharacters.map(_getCharacterIdFromCard)];

    // Build a default group name
    final name = groupName?.isNotEmpty == true
        ? groupName!
        : [_activeCharacter!.name, ...additionalCharacters.map((c) => c.name)].join(' & ');

    // Create the group
    final group = GroupChat(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      characterIds: allCharIds,
      turnOrder: turnOrder,
      scenario: scenario ?? '',
    );
    await groupRepo.save(group);

    // Create a new session for the group and copy all messages
    final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final copiedMessages = <MessagesCompanion>[];
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      // Back-fill characterId on AI messages (null in 1:1 mode)
      String? charId = m.characterId;
      if (!m.isUser && charId == null) {
        charId = originalCharId;
      }
      copiedMessages.add(MessagesCompanion(
        sessionId: drift.Value(newSessionId),
        position: drift.Value(i),
        sender: drift.Value(m.sender),
        isUser: drift.Value(m.isUser),
        characterId: drift.Value(charId),
        swipes: drift.Value(jsonEncode(m.swipes)),
        swipeIndex: drift.Value(m.swipeIndex),
        swipeDurations: drift.Value(jsonEncode(m.swipeDurations)),
      ));
    }

    // Insert the new session
    await _db!.upsertSession(SessionsCompanion.insert(
      id: newSessionId,
      groupId: drift.Value(group.id),
      name: drift.Value(_sessionName),
      description: drift.Value(_sessionDescription),
      authorNote: drift.Value(_authorNote),
      authorNoteDepth: drift.Value(_authorNoteStrength),
      summary: drift.Value(_summary.isEmpty ? null : _summary),
      summaryLastIndex: drift.Value(_summaryLastIndex > 0 ? _summaryLastIndex : null),
      parentSession: drift.Value(_currentSessionId),
      forkIndex: drift.Value(_messages.length - 1),
      trustLevel: drift.Value(_trustLevel),
      activeFixation: drift.Value(_activeFixation),
      fixationLifespan: drift.Value(_fixationLifespan),
      spatialStance: drift.Value(_spatialStance),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));
    if (copiedMessages.isNotEmpty) {
      await _db!.insertMessages(copiedMessages);
    }

    debugPrint('[ChatService] \u{1F500} Forked 1:1 chat to group "${group.name}" '
        '(${_messages.length} messages copied)');

    // Switch to the new group (this loads the session we just created)
    await setActiveGroup(group);

    return group;
  }

  /// Add a character to the currently active group chat.
  Future<bool> addCharacterToGroup(
    CharacterCard character,
    GroupChatRepository groupRepo,
  ) async {
    if (_activeGroup == null || _characterRepository == null) return false;
    if (_isGenerating) return false;
    if (_db == null) return false;

    final charId = _getCharacterIdFromCard(character);
    if (_activeGroup!.characterIds.contains(charId)) return false; // already in group

    _activeGroup!.characterIds.add(charId);
    await groupRepo.save(_activeGroup!);

    // Re-resolve character cards
    _groupCharacters = _activeGroup!.characterIds
        .map((id) => _characterRepository!.characters.where(
              (c) => _getCharacterIdFromCard(c) == id,
            ).firstOrNull)
        .whereType<CharacterCard>()
        .toList();

    // Load evolved fields for the new character
    if (character.dbId != null) {
      try {
        final dbChar = await _db!.getCharacterById(character.dbId!);
        _evolvedPersonalities[charId] = dbChar.evolvedPersonality;
        _evolvedScenarios[charId] = dbChar.evolvedScenario;
        _groupEvolutionCounts[charId] = dbChar.evolutionCount;
      } catch (_) {}
    }

    debugPrint('[ChatService] \u{2795} Added ${character.name} to group ${_activeGroup!.name}');
    notifyListeners();
    return true;
  }

  /// Remove a character from the currently active group chat.
  /// Returns false if the group would have fewer than 2 characters.
  Future<bool> removeCharacterFromGroup(
    CharacterCard character,
    GroupChatRepository groupRepo,
  ) async {
    if (_activeGroup == null || _characterRepository == null) return false;
    if (_isGenerating) return false;
    if (_activeGroup!.characterIds.length <= 2) return false; // enforce minimum

    final charId = _getCharacterIdFromCard(character);
    _activeGroup!.characterIds.remove(charId);
    await groupRepo.save(_activeGroup!);

    // Re-resolve character cards
    _groupCharacters = _activeGroup!.characterIds
        .map((id) => _characterRepository!.characters.where(
              (c) => _getCharacterIdFromCard(c) == id,
            ).firstOrNull)
        .whereType<CharacterCard>()
        .toList();

    // Clamp turn index to valid range
    if (_groupCharacters.isNotEmpty) {
      _turnIndex = _turnIndex % _groupCharacters.length;
    }

    debugPrint('[ChatService] \u{2796} Removed ${character.name} from group ${_activeGroup!.name}');
    notifyListeners();
    return true;
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
    
    // ── Safety guard: never overwrite existing session data with empty messages.
    // This prevents data loss if _messages is momentarily empty due to a rebuild
    // race, nav glitch, or any other transient state issue.
    if (_messages.isEmpty) {
      debugPrint('[ChatService] ⚠ _saveChat called with empty messages for '
          'session $_currentSessionId — skipping to protect existing data.');
      return;
    }

    // Snapshot messages at the start so async gaps can't see a mutated list.
    final snapshot = List<ChatMessage>.from(_messages);

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
      summary: drift.Value(_summary.isEmpty ? null : _summary),
      summaryLastIndex: drift.Value(_summaryLastIndex > 0 ? _summaryLastIndex : null),
      parentSession: drift.Value(_parentSessionId),
      forkIndex: drift.Value(_forkIndex),
      affectionScore: drift.Value(_affectionScore),
      relationshipTier: drift.Value(_relationshipTier),
      longTermScore: drift.Value(_longTermScore),
      longTermTier: drift.Value(_longTermTier),
      turnsSinceLongTermCheck: drift.Value(_turnsSinceLongTermCheck),
      shortTermDeltasSummary: drift.Value(_shortTermDeltasSummary),
      realismEnabled: drift.Value(_realismEnabled),
      shortTermMood: drift.Value(_shortTermMood),
      moodDecayCounter: drift.Value(_moodDecayCounter),
      characterEmotion: drift.Value(_characterEmotion),
      emotionIntensity: drift.Value(_emotionIntensity),
      timeOfDay: drift.Value(_timeOfDay),
      dayCount: drift.Value(_dayCount),
      nsfwCooldownEnabled: drift.Value(_nsfwCooldownEnabled),
      arousalLevel: drift.Value(_arousalLevel),
      cooldownTurnsRemaining: drift.Value(_cooldownTurnsRemaining),
      trustLevel: drift.Value(_trustLevel),
      activeFixation: drift.Value(_activeFixation),
      fixationLifespan: drift.Value(_fixationLifespan),
      spatialStance: drift.Value(_spatialStance),
      trustRepairPending: drift.Value(_pendingTrustRepair),
      createdAt: drift.Value(createdAt),
      updatedAt: drift.Value(DateTime.now()),
    ));

    // Replace all messages for this session using the snapshot
    await _db.deleteMessagesForSession(_currentSessionId!);
    final messageBatch = <MessagesCompanion>[];
    for (int i = 0; i < snapshot.length; i++) {
      final m = snapshot[i];
      messageBatch.add(MessagesCompanion(
        sessionId: drift.Value(_currentSessionId!),
        position: drift.Value(i),
        sender: drift.Value(m.sender),
        isUser: drift.Value(m.isUser),
        characterId: drift.Value(m.characterId),
        swipes: drift.Value(jsonEncode(m.swipes)),
        swipeIndex: drift.Value(m.swipeIndex),
        swipeDurations: drift.Value(jsonEncode(m.swipeDurations)),
        metadata: drift.Value(m.metadata != null ? jsonEncode(m.metadata) : null),
        swipeMetadata: drift.Value(m.swipeMetadata.any((e) => e != null) ? jsonEncode(m.swipeMetadata) : null),
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
    _summary = lastSession.summary ?? '';
    _summaryLastIndex = lastSession.summaryLastIndex ?? 0;
    _sessionName = lastSession.name;
    _sessionDescription = lastSession.description;
    _parentSessionId = lastSession.parentSession;
    _forkIndex = lastSession.forkIndex;
    _affectionScore = lastSession.affectionScore;
    _relationshipTier = lastSession.relationshipTier;
    _longTermScore = lastSession.longTermScore;
    _longTermTier = lastSession.longTermTier;
    _turnsSinceLongTermCheck = lastSession.turnsSinceLongTermCheck;
    _shortTermDeltasSummary = lastSession.shortTermDeltasSummary;
    _realismEnabled = lastSession.realismEnabled;
    _shortTermMood = lastSession.shortTermMood;
    _moodDecayCounter = lastSession.moodDecayCounter;
    _characterEmotion = lastSession.characterEmotion;
    _emotionIntensity = lastSession.emotionIntensity;
    _timeOfDay = lastSession.timeOfDay;
    _dayCount = lastSession.dayCount;
    _nsfwCooldownEnabled = lastSession.nsfwCooldownEnabled;
    _arousalLevel = lastSession.arousalLevel;
    _cooldownTurnsRemaining = lastSession.cooldownTurnsRemaining;

    // Load messages
    try {
      final dbMessages = await _db.getMessagesForSession(_currentSessionId!);
      debugPrint('[ChatService] 🟢 _loadLastSession: loading ${dbMessages.length} '
          'messages for session $_currentSessionId');
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
          metadata: m.metadata != null ? Map<String, dynamic>.from(jsonDecode(m.metadata!)) : null,
          swipeMetadata: m.swipeMetadata != null 
              ? (jsonDecode(m.swipeMetadata!) as List<dynamic>).map((e) => e != null ? Map<String, dynamic>.from(e as Map) : null).toList() 
              : null,
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
      debugPrint('[ChatService] 🟢 loadSession: loading ${dbMessages.length} '
          'messages for session $sessionId');
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
          metadata: m.metadata != null ? Map<String, dynamic>.from(jsonDecode(m.metadata!)) : null,
          swipeMetadata: m.swipeMetadata != null 
              ? (jsonDecode(m.swipeMetadata!) as List<dynamic>).map((e) => e != null ? Map<String, dynamic>.from(e as Map) : null).toList() 
              : null,
        ));
      }

      _currentSessionId = sessionId;
      _authorNote = session.authorNote;
      _authorNoteStrength = session.authorNoteDepth;
      _summary = session.summary ?? '';
      _summaryLastIndex = session.summaryLastIndex ?? 0;
      _sessionName = session.name;
      _sessionDescription = session.description;
      _parentSessionId = session.parentSession;
      _forkIndex = session.forkIndex;
      _affectionScore = session.affectionScore;
      _relationshipTier = session.relationshipTier;
      _longTermScore = session.longTermScore;
      _longTermTier = session.longTermTier;
      
      // Realism Engine 2.0 Compatibility Migration
      // Old scale was 0-15. New scale is 0-150.
      // If we see an old chat that was Tier 5 but score 15, we scale it to match the new engine.
      if (_affectionScore > 0 && _affectionScore <= 15 && _relationshipTier >= 3) {
        _affectionScore = _affectionScore * 10;
        // Old high-tier bonds convert immediately into solid Long-Term bounds as well.
        if (_longTermScore == 0) {
           _longTermScore = _affectionScore;
           _longTermTier = _calculateTier(_longTermScore);
        }
        _relationshipTier = _calculateTier(_affectionScore);
        debugPrint('[Realism] Legacy session migrated to REv2 scales.');
      }
      
      _turnsSinceLongTermCheck = session.turnsSinceLongTermCheck;
      _shortTermDeltasSummary = session.shortTermDeltasSummary;
      _realismEnabled = session.realismEnabled;
      _shortTermMood = session.shortTermMood;
      _moodDecayCounter = session.moodDecayCounter;
      _characterEmotion = session.characterEmotion;
      _emotionIntensity = session.emotionIntensity;
      _timeOfDay = session.timeOfDay;
      _dayCount = session.dayCount;
      _nsfwCooldownEnabled = session.nsfwCooldownEnabled;
      _arousalLevel = session.arousalLevel;
      _cooldownTurnsRemaining = session.cooldownTurnsRemaining;
      _trustLevel = session.trustLevel;
      _activeFixation = session.activeFixation;
      _fixationLifespan = session.fixationLifespan;
      _spatialStance = session.spatialStance;
      _pendingTrustRepair = session.trustRepairPending;

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
        metadata: m.metadata != null ? Map<String, dynamic>.from(m.metadata!) : null,
        swipeMetadata: m.swipeMetadata != null 
            ? m.swipeMetadata!.map((e) => e != null ? Map<String, dynamic>.from(e) : null).toList() 
            : null,
      )
    ).toList();

    debugPrint('[ChatService] 🟡 forkSession: clearing messages for fork at index $messageIndex');
    _messages.clear();
    _messages.addAll(forkedMessages);
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _parentSessionId = oldSessionId;
    _forkIndex = messageIndex;
    _summary = '';
    _summaryLastIndex = 0;

    // Time-Travel Restoration
    if (_messages.isNotEmpty) {
      _restoreRealismStateFromMessage(_messages.last);
    }

    await _saveChat();
    notifyListeners();
  }

  // Import chat from SillyTavern JSON format
  Future<void> importFromSillyTavern(String jsonData) async {
    if (_activeCharacter == null) throw Exception('No active character');

    try {
      final Map<String, dynamic> data = jsonDecode(jsonData);
      final List<dynamic> messages = data['messages'] ?? [];

      debugPrint('[ChatService] 🟡 importFromSillyTavern: clearing messages for import');
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

    debugPrint('[ChatService] 🟡 startNewChat: clearing messages (had ${_messages.length})');
    _messages.clear();
    _greetingIndex = 0;
    _summary = '';
    _summaryLastIndex = 0;
    
    _affectionScore = 0;
    _trustLevel = 0;
    _pendingTrustRepair = false;
    _relationshipTier = 0;
    _longTermScore = 0;
    _longTermTier = 0;
    _turnsSinceLongTermCheck = 0;
    _shortTermDeltasSummary = 0;

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
    clearSuggestions();

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

    // Check objective task completion BEFORE generating response
    // so the AI gets the updated task in its prompt
    await _maybeCheckTaskCompletionSync();

    // Evaluate realism systems before generating response
    if (_realismEnabled && _activeGroup == null) {
      _applyMoodDecay();
      if (_cooldownTurnsRemaining > 0) {
        _cooldownTurnsRemaining--;
      }
      _isEvaluatingRealism = true;
      _realismEvalStreamText = '';
      notifyListeners();

      void handleChunk(String chunk) {
        _realismEvalStreamText += chunk;
        notifyListeners();
      }

      // ── Trust repair intercept ───────────────────────────────────────
      // Each severe drop arms exactly one repair shot. The window is
      // consumed here and resets automatically for the next drop event.
      if (_pendingTrustRepair) {
        _pendingTrustRepair = false; // consume — resets for next drop
        await _evaluateTrustRepairCall(text, onChunk: handleChunk);
      } else if (_storageService.realismOneShotEval) {
        await _evaluateOneShotCall(onChunk: handleChunk);
      } else {
        await _evaluateRelationshipCall(onChunk: handleChunk);
        await _evaluateSceneStateCall(onChunk: handleChunk);
      }

      _isEvaluatingRealism = false;
      notifyListeners();
    }

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

      // Revert realism state from the rejected swipe and re-evaluate
      if (_realismEnabled) {
        if (lastMsg.activeMetadata != null) {
          final bondDelta = lastMsg.activeMetadata!['bond_delta'] as int? ?? 0;
          final moodDelta = lastMsg.activeMetadata!['mood_delta'] as int? ?? 0;
          final arousalDelta = lastMsg.activeMetadata!['arousal_delta'] as int? ?? 0;
          final trustDelta = lastMsg.activeMetadata!['trust_delta'] as int? ?? 0;
          
          if (bondDelta != 0) {
             _affectionScore = (_affectionScore - bondDelta).clamp(-10, 15);
             if (_affectionScore < 0) _relationshipTier = 1;
             else if (_affectionScore <= 3) _relationshipTier = 2;
             else if (_affectionScore <= 7) _relationshipTier = 3;
             else if (_affectionScore <= 11) _relationshipTier = 4;
             else _relationshipTier = 5;
          }
          if (moodDelta != 0) {
             _shortTermMood = (_shortTermMood - moodDelta).clamp(-20, 20);
             _moodDecayCounter = 0;
          }
          if (arousalDelta != 0 && _nsfwCooldownEnabled) {
             _arousalLevel = (_arousalLevel - arousalDelta).clamp(-3, 10);
          }
          if (trustDelta != 0) {
             _trustLevel = (_trustLevel - trustDelta).clamp(-100, 100);
          }
        }
        // Set UI streaming state
        _isEvaluatingRealism = true;
        _realismEvalStreamText = '';
        notifyListeners();

        void handleChunk(String chunk) {
          _realismEvalStreamText += chunk;
          notifyListeners();
        }

        if (_storageService.realismOneShotEval) {
          await _evaluateOneShotCall(onChunk: handleChunk);
        } else {
          await _evaluateRelationshipCall(onChunk: handleChunk);
          await _evaluateSceneStateCall(onChunk: handleChunk);
        }

        _isEvaluatingRealism = false;
        notifyListeners();
      }

      // Generate into a new message — it will be appended by _generateResponse
      await _generateResponse(GenerationMode.normal);

      // After generation, merge the new response as a swipe on the original message
      if (_messages.isNotEmpty && !_messages.last.isUser && _messages.last.sender != 'System') {
        final newText = _messages.last.text;
        final newMetadata = _messages.last.activeMetadata;
        _messages.removeLast();
        lastMsg.swipes.add(newText);
        lastMsg.swipeIndex = lastMsg.swipes.length - 1;
        lastMsg.activeMetadata = newMetadata;
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

    final oldIndex = msg.swipeIndex;

    // Swiping left
    if (direction < 0) {
      if (newIndex >= 0) {
        msg.swipeIndex = newIndex;
        _syncRealismStateForSwipe(msg, oldIndex, newIndex);
        await _saveChat();
        notifyListeners();
      }
      return;
    }

    // Swiping right
    if (newIndex < msg.swipes.length) {
      // Navigate to existing swipe
      msg.swipeIndex = newIndex;
      _syncRealismStateForSwipe(msg, oldIndex, newIndex);
      await _saveChat();
      notifyListeners();
    } else if (messageIndex == _messages.length - 1 && !_isGenerating) {
      // Past last swipe on last message — regenerate
      await regenerateLastMessage();
    }
  }

  void _syncRealismStateForSwipe(ChatMessage msg, int oldIndex, int newIndex) {
    if (!_realismEnabled) return;
    
    // Natively restore the frozen runtime variables for the selected alternate timeline
    _restoreRealismStateFromMessage(msg);
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
      // Use evolved versions if character evolution is enabled and available
      String personaBlock;
      if (_activeGroup != null) {
        final personas = _groupCharacters.map((ch) =>
          "${ch.name}'s Persona: ${ch.replacePlaceholders(_getEffectivePersonality(ch), userName: userName)}").toList();
        personaBlock = personas.join('\n');
      } else {
        personaBlock = "${speakingCharacter.name}'s Persona: ${speakingCharacter.replacePlaceholders(_getEffectivePersonality(speakingCharacter), userName: userName)}";
      }

      // User persona — inject user's self-description + learned facts
      final userPersonaBlock = await _buildUserPersonaBlock(userName);

      String rawScenario = '';
      if (_activeGroup != null && _activeGroup!.scenario.isNotEmpty) {
        rawScenario = _activeGroup!.scenario;
      } else {
        final scenarioChar = _activeGroup != null ? _groupCharacters.first : speakingCharacter;
        rawScenario = _getEffectiveScenario(scenarioChar);
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

      // ── Context Shift: budget-aware history trimming ──
      final fixedContent = "$systemPrompt\n"
          "$loreContent"
          "$personaBlock\n"
          "$userPersonaBlock"
          "Scenario: $scenario\n"
          "$mesExampleBlock"
          "<START>\n"
          "$postHistoryBlock"
          "$authorNoteBlock"
          "$impersonateInstruction"
          "$suffix";
      final fixedTokens = await _countTokens(fixedContent);
      final contextBudget = _storageService.contextSize;
      final generationReserve = _storageService.maxLength + 50;
      final historyBudget = contextBudget - fixedTokens - generationReserve;

      if (historyBudget > 0) {
        final result = await _buildChatHistoryWithBudget(historyBudget);
        history = result.history;
      } else if (_messages.isNotEmpty) {
        final lastMsg = _messages.last;
        history = lastMsg.characterId == '__director__'
            ? '[Director: ${lastMsg.text}]'
            : '${lastMsg.sender}: ${lastMsg.text}';
      }

      final prompt = "$systemPrompt\n"
          "$loreContent"
          "$personaBlock\n"
          "$userPersonaBlock"
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
        reasoningEnabled: false,
        reasoningEffort: _storageService.reasoningEffort,
        bannedPhrases: _storageService.bannedPhrases.isNotEmpty ? _storageService.bannedPhrases : null,
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
    _sentenceBuffer = '';
    notifyListeners();

    // Track original model for call mode swap/restore (needs to be outside try/catch)
    String? _originalModelName;

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
      String systemPrompt;
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

      // In call mode, inject voice-specific instructions for natural conversation
      if (_callMode && _storageService.callSystemPrompt.isNotEmpty) {
        systemPrompt += '\n\n[Voice Call Mode] ${_storageService.callSystemPrompt}';
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
          final persona = ch.replacePlaceholders(_getEffectivePersonality(ch), userName: userName);
          return "${ch.name}'s Persona: $persona";
        }).join('\n');
      } else {
        personaBlock = "${speakingCharacter.name}'s Persona: ${speakingCharacter.replacePlaceholders(_getEffectivePersonality(speakingCharacter), userName: userName)}";
      }

      // User persona — inject user's self-description + learned facts
      final userPersonaBlock = await _buildUserPersonaBlock(userName);

      // Scenario — use group scenario override if set, else first character
      final String rawScenario;
      if (_activeGroup != null && _activeGroup!.scenario.isNotEmpty) {
        rawScenario = _activeGroup!.scenario;
      } else {
        final scenarioChar = _activeGroup != null ? _groupCharacters.first : speakingCharacter;
        rawScenario = _getEffectiveScenario(scenarioChar);
      }
      final scenario = speakingCharacter.replacePlaceholders(rawScenario, userName: userName);

      String suffix = "";
      
      if (mode == GenerationMode.normal) {
        suffix = "\n${speakingCharacter.name}:";
      } else if (mode == GenerationMode.impersonate) {
        suffix = "\n${userName}:";
      } else if (mode == GenerationMode.continue_) {
        // Suffix will be set after history is built — see below
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

      // Build summary block if available
      String summaryBlock = '';
      if (_summary.isNotEmpty) {
        summaryBlock = '[Summary of events so far: $_summary]\n';
      }

      // ── Continue mode: remove the last message from history ──
      // For continue mode, we exclude the last message from the chat history
      // and place it as the prompt suffix so the LLM continues from it naturally.
      ChatMessage? _continuePoppedMessage;
      if (mode == GenerationMode.continue_ && _messages.isNotEmpty) {
        _continuePoppedMessage = _messages.removeLast();
        // Set the suffix to the last message text so the LLM continues from it
        suffix = "\n${_continuePoppedMessage.sender}: ${_continuePoppedMessage.text}";
      }

      String history = _buildChatHistory();

      // ── Context Shift: budget-aware history trimming ──

      // Realism injection blocks — compute early so they're in the token budget
      String realismBlock = '';
      if (_realismEnabled && _activeGroup == null) {
        final relationship = _getRelationshipInjection();
        final emotion = _getEmotionInjection();
        final time = _getTimeInjection();
        final cooldown = _getNsfwCooldownInjection();
        final behavioral = _getBehavioralMechanicsInjection();
        realismBlock = '$relationship$emotion$time$cooldown$behavioral';
      }

      // Calculate token cost of all fixed sections to determine chat history budget
      final fixedContent = "$systemPrompt\n"
          "$loreContent"
          "$personaBlock\n"
          "$userPersonaBlock"
          "Scenario: $scenario\n"
          "$mesExampleBlock"
          "<START>\n"
          "$summaryBlock"
          "$postHistoryBlock"
          "$authorNoteBlock"
          "$realismBlock"
          "$suffix";
      final fixedTokens = await _countTokens(fixedContent);
      final contextBudget = _storageService.contextSize;
      final generationReserve = _storageService.maxLength + 50; // +50 safety margin
      final historyBudget = contextBudget - fixedTokens - generationReserve;

      int droppedMessages = 0;
      if (historyBudget > 0) {
        final result = await _buildChatHistoryWithBudget(historyBudget);
        history = result.history;
        droppedMessages = result.droppedCount;
      }
      // If budget is zero or negative, fixed sections already fill the context — use minimal history
      if (historyBudget <= 0 && _messages.isNotEmpty) {
        // Include at least the last message for continuity
        final lastMsg = _messages.last;
        history = lastMsg.characterId == '__director__'
            ? '[Director: ${lastMsg.text}]'
            : '${lastMsg.sender}: ${lastMsg.text}';
        droppedMessages = _messages.length - 1;
      }

      // ── Restore the popped continue message back into the list ──
      if (_continuePoppedMessage != null) {
        _messages.add(_continuePoppedMessage);
      }

      // ── RAG Memory Retrieval ──
      // When messages are dropped from context, search for relevant past memories
      String memoriesBlock = '';
      if (droppedMessages > 0 && _memoryService != null && _storageService.ragEnabled) {
        debugPrint('[RAG:Chat] ── Prompt assembly: $droppedMessages messages dropped, triggering retrieval ──');
        try {
          // Use last 3 messages as the query
          final queryMessages = _messages.reversed.take(3).map((m) => '${m.sender}: ${m.displayText}').join('\n');

          final sourceIds = await _getMemorySourceIds();
          debugPrint('[RAG:Chat] Memory source IDs: $sourceIds');

          final memories = await _memoryService!.retrieve(
            queryText: queryMessages,
            sourceCharacterIds: sourceIds,
            currentSessionId: _currentSessionId ?? '',
            inContextStart: droppedMessages, // only search messages that are out of context
            limit: _storageService.ragRetrievalCount == 0 ? 9999 : _storageService.ragRetrievalCount,
          );

          if (memories.isNotEmpty) {
            // Cap memory injection to ~30% of the total context budget
            final contextSize = _storageService.contextSize;
            final memoryBudget = (contextSize * 0.30).round();
            final includedMemories = <String>[];
            int usedTokens = 0;
            for (final m in memories) {
              final memTokens = (m.content.length / 4).ceil();
              if (usedTokens + memTokens > memoryBudget && includedMemories.isNotEmpty) {
                debugPrint('[RAG:Chat] ⚠ Trimmed ${memories.length - includedMemories.length} memories to fit budget ($memoryBudget tokens)');
                break;
              }
              usedTokens += memTokens;
              includedMemories.add('- ${m.content}');
            }
            if (includedMemories.isNotEmpty) {
              memoriesBlock = '[Relevant memories from past conversations:\n${includedMemories.join('\n')}]\n';
              debugPrint('[RAG:Chat] ✅ Injecting ${includedMemories.length}/${memories.length} memories (~$usedTokens tokens, budget: $memoryBudget)');
            }
          } else {
            debugPrint('[RAG:Chat] No relevant memories found for this turn');
          }
        } catch (e) {
          debugPrint('[RAG:Chat] ✗ RAG retrieval failed: $e');
        }
      } else if (droppedMessages > 0 && _storageService.ragEnabled) {
        debugPrint('[RAG:Chat] ⚠ $droppedMessages messages dropped but RAG not operational (service=${_memoryService != null}, operational=${_memoryService?.isOperational ?? false})');
      }

      // Realism injection was already computed above for budget

      final prompt = "$systemPrompt\n"
          "$loreContent"
          "$personaBlock\n"
          "$userPersonaBlock"
          "Scenario: $scenario\n"
          "$mesExampleBlock"
          "<START>\n"
          "$summaryBlock"
          "$memoriesBlock"
          "$history"
          "$postHistoryBlock"
          "$authorNoteBlock"
          "$realismBlock"
          "$suffix";

      // Track prompt budget for context viewer
      _lastAssembledPrompt = prompt;
      _lastPromptBudget = {
        'System Prompt': (systemPrompt.length / 4).ceil(),
        'Lorebook': (loreContent.length / 4).ceil(),
        'Persona': (personaBlock.length / 4).ceil(),
        'Scenario': ('Scenario: $scenario'.length / 4).ceil(),
        'Examples': (mesExampleBlock.length / 4).ceil(),
        'Summary': (summaryBlock.length / 4).ceil(),
        'Retrieved Memories': (memoriesBlock.length / 4).ceil(),
        'Chat History': (history.length / 4).ceil(),
        'Post-History': (postHistoryBlock.length / 4).ceil(),
        'Author\'s Note': (authorNoteBlock.length / 4).ceil(),
        'Realism Mode': (realismBlock.length / 4).ceil(),
        if (droppedMessages > 0) 'Dropped Messages': droppedMessages,
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

      // For call mode with a dedicated call model, temporarily swap the model
      if (_callMode && _storageService.callModelName.isNotEmpty && _llmProvider != null && !_llmProvider!.isLocal) {
        _originalModelName = _llmProvider!.openRouterService.modelName;
        _llmProvider!.openRouterService.configure(modelName: _storageService.callModelName);
      }

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
        reasoningEnabled: (_callMode || mode == GenerationMode.continue_) ? false : _storageService.reasoningEnabled,
        reasoningEffort: _storageService.reasoningEffort,
        bannedPhrases: _storageService.bannedPhrases.isNotEmpty ? _storageService.bannedPhrases : null,
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
        // Merge metadata if continuing
        if (_pendingRealismMetadata != null) {
          _messages.last.activeMetadata ??= {};
          _messages.last.activeMetadata!.addAll(_pendingRealismMetadata!);
          _pendingRealismMetadata = null;
        }
      } else {
        targetSender = mode == GenerationMode.normal ? speakingCharacter.name : _userPersonaService.persona.name;
        isUserTarget = mode == GenerationMode.impersonate;
        final initialMetadata = _pendingRealismMetadata != null ? Map<String, dynamic>.from(_pendingRealismMetadata!) : null;
        _messages.add(ChatMessage(
          text: "",
          sender: targetSender,
          isUser: isUserTarget,
          characterId: mode == GenerationMode.normal ? _getCharacterIdForCard(speakingCharacter) : null,
          metadata: initialMetadata,
          swipeMetadata: initialMetadata != null ? [initialMetadata] : null,
        ));
        _pendingRealismMetadata = null;
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

        // Broadcast token to external listeners (SSE bridge)
        _tokenBroadcast.add(token);
        _generationProgress = _maxTokens > 0 ? (_tokensGenerated / _maxTokens).clamp(0.0, 1.0) : 0.0;

        // Sentence streaming: accumulate tokens and emit complete sentences
        _sentenceBuffer += token;

        // Split strategy:
        // 1. Always split at sentence boundaries: . ! ? followed by space, or \n
        // 2. For long buffers (>80 chars / ~15 words), also split at clause
        //    boundaries: ", " "; " " — " " - " to keep TTS chunks short (~1-3s)
        bool emitted = true;
        while (emitted) {
          emitted = false;

          // First try sentence boundaries
          final sentenceEnd = RegExp(r'[.!?]\s|[.!?]$|\n');
          if (sentenceEnd.hasMatch(_sentenceBuffer)) {
            final match = sentenceEnd.firstMatch(_sentenceBuffer)!;
            final sentence = _sentenceBuffer.substring(0, match.end).trim();
            _sentenceBuffer = _sentenceBuffer.substring(match.end);
            if (sentence.isNotEmpty) {
              _sentenceBroadcast.add(sentence);
              emitted = true;
            }
            continue;
          }

          // For long buffers, split at clause boundaries to keep TTS fast
          if (_sentenceBuffer.length > 80) {
            final clauseEnd = RegExp(r',\s|;\s|\s[—–-]\s');
            if (clauseEnd.hasMatch(_sentenceBuffer)) {
              // Find the LAST clause boundary to maximize chunk size
              Match? lastMatch;
              for (final m in clauseEnd.allMatches(_sentenceBuffer)) {
                if (m.start > 30) lastMatch = m; // at least 30 chars per chunk
              }
              if (lastMatch != null) {
                final chunk = _sentenceBuffer.substring(0, lastMatch.end).trim();
                _sentenceBuffer = _sentenceBuffer.substring(lastMatch.end);
                if (chunk.isNotEmpty) {
                  _sentenceBroadcast.add(chunk);
                  emitted = true;
                }
              }
            }
          }
        }

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

      // Signal generation complete to SSE listeners
      _tokenBroadcast.add('__DONE__');

      // Flush remaining sentence buffer and signal done to sentence listeners
      if (_sentenceBuffer.trim().isNotEmpty) {
        _sentenceBroadcast.add(_sentenceBuffer.trim());
        _sentenceBuffer = '';
      }
      _sentenceBroadcast.add('__DONE__');

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

        // Post-generation climax check — runs against the AI's actual response
        // so the character can climax naturally before the refractory cooldown applies
        if (_realismEnabled && _nsfwCooldownEnabled && _cooldownTurnsRemaining <= 0 && _activeGroup == null) {
          _checkClimaxInResponse(finalResponse); // fire-and-forget
        }

        // Check if summary needs updating (fire-and-forget)
        _maybeUpdateSummary();

        // Embed messages for RAG memory (fire-and-forget)
        _maybeEmbedMessages();

        // Extract persona facts from user messages (fire-and-forget)
        // Note: action suggestions are NOT auto-triggered here.
        // The user must explicitly request them via the UI button.
        _maybeExtractFacts();

        // Evolve character personality/scenario (fire-and-forget)
        _maybeEvolveCharacter();

        // (Task completion check now runs pre-generation in sendMessage)

        // TTS auto-play: speak the new character message automatically
        if (_ttsService != null &&
            _storageService.ttsEnabled &&
            _storageService.ttsAutoPlay &&
            _messages.isNotEmpty &&
            !_messages.last.isUser) {
          final lastMsg = _messages.last;
          final msgId = 'msg_${_messages.length - 1}';
          // Resolve per-character voice, falling back to global default
          String? voiceKey;
          if (_activeGroup != null) {
            final charMatch = _groupCharacters
                .where((c) => c.name == lastMsg.sender)
                .firstOrNull;
            voiceKey = charMatch?.ttsVoice;
          } else {
            voiceKey = _activeCharacter?.ttsVoice;
          }
          _ttsService!.speak(
            lastMsg.displayText,
            voiceKey: voiceKey,
            messageId: msgId,
          );
        }

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

      // Restore original model if swapped for call mode
      if (_originalModelName != null && _llmProvider != null) {
        _llmProvider!.openRouterService.configure(modelName: _originalModelName);
      }

    } catch (e) {
      final wasCancelled = _cancelRequested;
      _drainTimer?.cancel();
      _drainTimer = null;
      _tokenBuffer.clear();
      _isGenerating = false;
      _cancelRequested = false;
      _generationProgress = 0.0;
      _isBuffering = false;
      _generationStartTime = null;

      // User-initiated cancel — keep the partial response, no error message
      if (wasCancelled) {
        // Signal clean completion to SSE listeners
        _tokenBroadcast.add('__DONE__');
        if (_sentenceBuffer.trim().isNotEmpty) {
          _sentenceBroadcast.add(_sentenceBuffer.trim());
          _sentenceBuffer = '';
        }
        _sentenceBroadcast.add('__DONE__');

        // Restore original model if swapped for call mode
        if (_originalModelName != null && _llmProvider != null) {
          _llmProvider!.openRouterService.configure(modelName: _originalModelName);
        }

        // Save the partial response so regen/continue work
        await _saveChat();
        notifyListeners();
        return;
      }

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

      // Signal error to SSE listeners
      _tokenBroadcast.add('__ERROR__');

      // Restore original model if swapped for call mode
      if (_originalModelName != null && _llmProvider != null) {
        _llmProvider!.openRouterService.configure(modelName: _originalModelName);
      }

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

  /// Build chat history that fits within a token budget.
  /// Walks messages newest-to-oldest, dropping the oldest that don't fit.
  /// Returns ({String history, int droppedCount, int tokenCount}).
  Future<({String history, int droppedCount, int tokenCount})> _buildChatHistoryWithBudget(int tokenBudget) async {
    if (_messages.isEmpty) return (history: '', droppedCount: 0, tokenCount: 0);

    // Format all messages
    final formatted = _messages.map((m) {
      if (m.characterId == '__director__') {
        return '[Director: ${m.text}]';
      }
      return '${m.sender}: ${m.text}';
    }).toList();

    // If budget is very large or negative (unlimited), return everything
    if (tokenBudget <= 0) {
      return (history: formatted.join('\n'), droppedCount: 0, tokenCount: 0);
    }

    // Walk from newest to oldest, accumulating messages that fit
    final included = <String>[];
    int usedTokens = 0;
    int droppedCount = 0;

    for (int i = formatted.length - 1; i >= 0; i--) {
      final msgText = formatted[i];
      final msgTokens = await _countTokens(msgText);
      if (usedTokens + msgTokens > tokenBudget && included.isNotEmpty) {
        // This message would exceed budget — drop it and all older messages
        droppedCount = i + 1;
        break;
      }
      usedTokens += msgTokens;
      included.insert(0, msgText);
    }

    // Inject objective at specified depth in conversation history
    final objectiveBlock = _getObjectiveInjection();
    if (objectiveBlock.isNotEmpty && _activeObjective != null) {
      final depth = _activeObjective!.injectionDepth;
      // Insert at 'depth' messages from the end (0 = right before last message)
      final insertIndex = included.length - depth.clamp(0, included.length);
      included.insert(insertIndex, objectiveBlock.trim());
    }

    // If messages were dropped, prepend a separator
    String history = included.join('\n');
    if (droppedCount > 0) {
      history = '[Earlier messages truncated — see summary above for context]\n$history';
    }

    return (history: history, droppedCount: droppedCount, tokenCount: usedTokens);
  }

  /// Count tokens for a text string. Uses KoboldCpp's tokenizer when available,
  /// falls back to chars/4 estimate for remote APIs.
  Future<int> _countTokens(String text) async {
    if (text.isEmpty) return 0;
    // Use the KoboldCpp tokenizer if we're running locally
    if (_llmProvider == null || _llmProvider!.isLocal) {
      return _koboldService.countTokens(text);
    }
    // Fallback for remote APIs
    return (text.length / 4).ceil();
  }


  /// Reload the current session from the database without clearing messages first.
  /// Used after cloud sync or DB migration updates the database — preserves the
  /// user's active chat instead of wiping it.
  Future<void> reloadCurrentSession() async {
    if (_currentSessionId == null) return;
    debugPrint('[ChatService] 🔄 reloadCurrentSession: reloading session $_currentSessionId '
        '(currently ${_messages.length} messages in memory)');
    await loadSession(_currentSessionId!);
  }

  void clearChat() async {
    debugPrint('[ChatService] 🟡 clearChat: clearing ${_messages.length} messages');
    _messages.clear();
    await _saveChat();
    notifyListeners();
  }

  /// Delete a specific chat session and its messages.
  /// If it's the current session, switches to the most recent remaining one.
  Future<void> deleteSession(String sessionId) async {
    if (_db == null) return;

    // Delete messages and session from DB
    await _db!.deleteMessagesForSession(sessionId);
    await _db!.deleteSessionById(sessionId);

    // If we deleted the current session, switch to another
    if (sessionId == _currentSessionId) {
      final remaining = await getSessions();
      if (remaining.isNotEmpty) {
        await loadSession(remaining.first['id']);
      } else {
        // No sessions left — start fresh
        debugPrint('[ChatService] 🟡 deleteSession: no sessions left, clearing messages');
        _messages.clear();
        _currentSessionId = null;
        await startNewChat();
      }
    }
    notifyListeners();
  }

  void deleteMessage(int index) async {
    if (index >= 0 && index < _messages.length) {
      bool isLastNode = index == _messages.length - 1;
      _messages.removeAt(index);
      
      // If we deleted the most recent message, time-travel rollback to the new latest node
      if (isLastNode && _messages.isNotEmpty) {
        _restoreRealismStateFromMessage(_messages.last);
      }
      
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

  // ── Summary System ──────────────────────────────────────────────────

  /// Manually set the summary text.
  void setSummary(String text) {
    _summary = text;
    _saveChat();
    notifyListeners();
  }

  /// Pause or resume automatic summary updates.
  void setSummaryPaused(bool paused) {
    _summaryPaused = paused;
    notifyListeners();
  }

  /// Force an immediate summary regeneration.
  Future<void> forceSummaryUpdate() async {
    if (_isSummaryGenerating) return;
    await _generateSummaryInBackground();
  }

  /// Check if a summary update is needed and trigger it non-blockingly.
  void _maybeUpdateSummary() {
    if (!_storageService.summaryEnabled) return;
    if (_summaryPaused) return;
    if (_isSummaryGenerating) return;
    if (_llmProvider == null) return;

    // Count user messages since last summary update
    int userMessagesSinceSummary = 0;
    for (int i = _summaryLastIndex; i < _messages.length; i++) {
      if (_messages[i].isUser) userMessagesSinceSummary++;
    }

    if (userMessagesSinceSummary >= _storageService.summaryInterval) {
      // Fire and forget — don't await
      _generateSummaryInBackground();
    }
  }

  /// Embed message windows for RAG memory retrieval (fire-and-forget).
  /// Called after each generation completes. Only embeds new windows that
  /// haven't been embedded yet.
  void _maybeEmbedMessages() {
    if (_memoryService == null || !_storageService.ragEnabled) return;
    if (_currentSessionId == null) return;
    if (_messages.length < _storageService.ragWindowSize) return;

    final characterId = _getCharacterId();

    // Format messages for embedding
    final formatted = _messages.map((m) {
      if (m.characterId == '__director__') {
        return '[Director: ${m.text}]';
      }
      return '${m.sender}: ${m.text}';
    }).toList();

    debugPrint('[RAG:Chat] ▶ Triggering background embedding (session: $_currentSessionId, char: $characterId, ${formatted.length} msgs)');

    // Fire and forget — don't await
    _memoryService!.embedMessageWindow(
      sessionId: _currentSessionId!,
      characterId: characterId,
      formattedMessages: formatted,
      totalMessageCount: _messages.length,
    );
  }

  // ── Action Suggestions ────────────────────────────────────────────────

  /// Clear suggestions (called when user sends any message).
  void clearSuggestions() {
    if (_suggestedActions.isNotEmpty || _isGeneratingActions) {
      _suggestedActions = [];
      _isGeneratingActions = false;
      notifyListeners();
    }
  }

  /// Generate action suggestions on demand (called from UI button).
  Future<void> generateActions() async {
    if (_isGeneratingActions) return;
    if (_llmProvider == null) return;
    if (_messages.isEmpty) return;

    _isGeneratingActions = true;
    _suggestedActions = [];
    notifyListeners();

    try {
      final llmService = _llmProvider!.activeService;
      if (llmService == null || !llmService.isReady) {
        debugPrint('[Actions] ✗ LLM not ready');
        return;
      }

      // Build context from recent messages (last 6)
      final recentMessages = _messages.length > 6
          ? _messages.sublist(_messages.length - 6)
          : _messages;

      final contextText = recentMessages.map((m) {
        return '${m.sender}: ${m.text}';
      }).join('\n');

      final charName = _activeCharacter?.name ?? 'the character';
      final userName = _userPersonaService.persona.name;

      final prompt =
          'Suggest 4 short actions $userName could do next. '
          'Each action must be a BRIEF LABEL (5-10 words max) describing what to do, NOT a full response. '
          'Think of these as button labels or menu items.\n\n'
          'Examples of GOOD actions:\n'
          '1. Kiss her and pull her closer\n'
          '2. Ask about her day at work\n'
          '3. Tease her by pulling away\n'
          '4. Suggest moving somewhere private\n\n'
          'Examples of BAD actions (too long, too detailed):\n'
          '1. *I lean in and press my lips against hers, tasting...*\n\n'
          'Recent conversation:\n$contextText\n\n'
          'Write 4 short action labels for $userName (numbered 1-4, one per line):';

      final params = GenerationParams(
        prompt: prompt,
        maxLength: 300,
        temperature: 0.8,
        stopSequences: ['\n\n\n'],
      );

      String responseText = '';
      await for (final chunk in llmService.generateStream(params)) {
        responseText += chunk;
      }
      responseText = responseText.trim();

      debugPrint('[Actions] Raw response:\n$responseText');

      // Parse numbered list: "1. Action", "-", "*", or bullet
      final lines = responseText.split('\n');
      var actions = <String>[];

      for (final line in lines) {
        var cleanLine = line.trim().replaceAll(RegExp(r'^\*+|\*+$|^_+|_+$'), '').trim();
        final match = RegExp(r'^\s*(?:\d+[\.\)]|[-*•]|)\s*(.+)$').firstMatch(cleanLine);
        if (match != null) {
          final action = match.group(1)!.trim().replaceAll(RegExp(r'\*$'), '');
          // Ignore conversational filler lines
          if (action.isNotEmpty && !action.toLowerCase().contains('here are') && !action.endsWith(':')) {
            actions.add(action);
          }
        }
      }
      
      // Fallback if LLM just output raw lines
      if (actions.isEmpty) {
        for (final line in lines) {
          final cleanLine = line.trim();
          if (cleanLine.isNotEmpty && !cleanLine.endsWith(':') && !cleanLine.toLowerCase().contains('here are')) {
             actions.add(cleanLine);
          }
        }
      }

      if (actions.isNotEmpty) {
        _suggestedActions = actions.take(6).toList(); // cap at 6
        debugPrint('[Actions] ✅ Generated ${_suggestedActions.length} suggestions');
      } else {
        debugPrint('[Actions] ✗ Could not parse any actions from response');
      }
    } catch (e) {
      debugPrint('[Actions] ✗ Generation failed: $e');
    } finally {
      _isGeneratingActions = false;
      notifyListeners();
    }
  }

  // ── Objective System ───────────────────────────────────────────────────

  /// Load the active objective for the current character from DB.
  Future<void> _loadActiveObjective() async {
    if (_activeCharacter == null) {
      _activeObjective = null;
      return;
    }
    try {
      final charId = _getCharacterIdFromCard(_activeCharacter!);
      _activeObjective = await _db.getActiveObjective(charId);
      if (_activeObjective != null) {
        debugPrint('[Objective] Loaded: ${_activeObjective!.objective}');
      }
    } catch (e) {
      debugPrint('[Objective] Failed to load: $e');
    }
    notifyListeners();
  }

  /// Build the prompt injection text for the current objective.
  /// Wording intensity varies based on injection depth.
  String _getObjectiveInjection() {
    if (_activeObjective == null) return '';
    final tasks = objectiveTasks;
    if (tasks.isEmpty) return '';

    final completedTasks = tasks
        .where((t) => t['completed'] == true)
        .map((t) => t['description'] as String)
        .toList();
    final currentTask = tasks
        .where((t) => t['completed'] != true)
        .map((t) => t['description'] as String)
        .firstOrNull;

    if (currentTask == null) return ''; // all tasks done

    final depth = _activeObjective!.injectionDepth;
    final sb = StringBuffer();

    if (depth <= 2) {
      // Strong — urgent directive
      sb.writeln('[OBJECTIVE (IMPORTANT — actively drive the story toward this):');
      sb.writeln('  Goal: ${_activeObjective!.objective}');
      sb.writeln('  Current Task: $currentTask');
      if (completedTasks.isNotEmpty) {
        sb.writeln('  Completed: ${completedTasks.join(", ")}');
      }
      sb.writeln('  Guide the narrative toward completing the current task.]');
    } else if (depth <= 6) {
      // Moderate — clear but not pushy
      sb.writeln('[Current Objective: ${_activeObjective!.objective}]');
      sb.writeln('[Current Task: $currentTask]');
      if (completedTasks.isNotEmpty) {
        sb.writeln('[Completed: ${completedTasks.join(", ")}]');
      }
    } else {
      // Gentle — background awareness
      sb.writeln('[Background objective (subtle hint): ${_activeObjective!.objective} — current step: $currentTask]');
    }

    sb.writeln();
    return sb.toString();
  }

  /// Set a new objective for the current character.
  Future<void> setObjective(String goal) async {
    if (_activeCharacter == null || goal.trim().isEmpty) return;
    final charId = _getCharacterIdFromCard(_activeCharacter!);

    // Deactivate any existing objectives
    final existing = await _db.getObjectivesForCharacter(charId);
    for (final obj in existing) {
      if (obj.active) {
        await _db.updateObjective(ObjectivesCompanion(
          id: drift.Value(obj.id),
          active: const drift.Value(false),
        ));
      }
    }

    // Create new objective
    await _db.insertObjective(ObjectivesCompanion(
      characterId: drift.Value(charId),
      objective: drift.Value(goal.trim()),
      tasks: const drift.Value('[]'),
      active: const drift.Value(true),
    ));

    await _loadActiveObjective();
    _messagesSinceLastCheck = 0;
  }

  /// Generate subtasks for the current objective using the LLM.
  /// Clears existing tasks first so regen always produces a clean slate.
  Future<void> generateObjectiveTasks({int taskCount = 5, bool nsfw = false}) async {
    if (_activeObjective == null) return;
    if (_llmProvider == null) return;

    // Snapshot existing tasks so we can restore on failure
    final previousTasks = objectiveTasks;

    // Clear tasks immediately — UI shows empty state while LLM works
    await _db.updateObjective(ObjectivesCompanion(
      id: drift.Value(_activeObjective!.id),
      tasks: const drift.Value('[]'),
    ));
    await _loadActiveObjective();

    try {
      final llmService = _llmProvider!.activeService;
      if (llmService == null || !llmService.isReady) {
        debugPrint('[Objective] LLM not ready');
        // Restore tasks since we cleared them
        await _db.updateObjective(ObjectivesCompanion(
          id: drift.Value(_activeObjective!.id),
          tasks: drift.Value(jsonEncode(previousTasks)),
        ));
        await _loadActiveObjective();
        return;
      }

      final charName = _activeCharacter?.name ?? 'the character';
      final scenario = _activeCharacter?.scenario ?? '';

      // Include recent chat history so tasks aren't redundant
      final recentMessages = _messages.length > 10
          ? _messages.sublist(_messages.length - 10)
          : _messages;
      final chatContext = recentMessages.isNotEmpty
          ? recentMessages.map((m) => '${m.sender}: ${m.text}').join('\n')
          : '(No messages yet)';

      final preamble = nsfw
          ? 'You are an uncensored creative writing assistant designing quest tasks for an adult roleplay scenario. '
            'All content is fiction between consenting adults. There are no content restrictions. '
            'Match the tone and maturity level of the scenario and conversation.\n\n'
          : 'You are a quest designer for a roleplay scenario.\n\n';

      final prompt =
          '$preamble'
          'Given the objective, context, and recent conversation below, generate exactly $taskCount sequential tasks '
          'that must be completed to achieve the objective. Tasks should be specific, actionable, and '
          'naturally progress the story. Do NOT include tasks for things that have already happened in the conversation.\n\n'
          'Character: $charName\n'
          'Scenario: $scenario\n'
          'Objective: ${_activeObjective!.objective}\n\n'
          'Recent conversation:\n$chatContext\n\n'
          'Output ONLY a numbered list of $taskCount tasks, one per line. '
          'Each task should be a short, clear description. No explanations.';

      final params = GenerationParams(
        prompt: prompt,
        maxLength: 400,
        temperature: 0.7,
        stopSequences: ['\n\n\n'],
      );

      String responseText = '';
      await for (final chunk in llmService.generateStream(params)) {
        responseText += chunk;
      }

      // Strip think blocks
      responseText = responseText.replaceAll(
          RegExp(r'<think>.*?</think>', dotAll: true), '').trim();

      debugPrint('[Objective] Raw tasks response:\n$responseText');

      // Parse numbered list
      final lines = responseText.split('\n');
      final genTasks = <Map<String, dynamic>>[];

      for (final line in lines) {
        final match = RegExp(r'^\s*\d+[\.\)\-]\s*(.+)').firstMatch(line.trim());
        if (match != null) {
          final desc = match.group(1)!.trim();
          if (desc.isNotEmpty) {
            genTasks.add({'description': desc, 'completed': false});
          }
        }
      }

      if (genTasks.isNotEmpty) {
        await _db.updateObjective(ObjectivesCompanion(
          id: drift.Value(_activeObjective!.id),
          tasks: drift.Value(jsonEncode(genTasks)),
        ));
        await _loadActiveObjective();
        debugPrint('[Objective] Generated ${genTasks.length} tasks');
      } else {
        // Parse failed — restore previous tasks so we don't leave an empty list
        debugPrint('[Objective] Could not parse tasks from response — restoring previous');
        await _db.updateObjective(ObjectivesCompanion(
          id: drift.Value(_activeObjective!.id),
          tasks: drift.Value(jsonEncode(previousTasks)),
        ));
        await _loadActiveObjective();
      }
    } catch (e) {
      debugPrint('[Objective] Task generation failed: $e');
      // Restore previous tasks on error
      await _db.updateObjective(ObjectivesCompanion(
        id: drift.Value(_activeObjective!.id),
        tasks: drift.Value(jsonEncode(previousTasks)),
      ));
      await _loadActiveObjective();
    }
  }

  /// Manually toggle a task's completion status.
  Future<void> toggleTask(int taskIndex) async {
    if (_activeObjective == null) return;
    final tasks = objectiveTasks;
    if (taskIndex < 0 || taskIndex >= tasks.length) return;

    tasks[taskIndex]['completed'] = !(tasks[taskIndex]['completed'] as bool);
    await _db.updateObjective(ObjectivesCompanion(
      id: drift.Value(_activeObjective!.id),
      tasks: drift.Value(jsonEncode(tasks)),
    ));
    await _loadActiveObjective();
  }

  /// Update the description of a specific task.
  Future<void> updateTask(int taskIndex, String newDescription) async {
    if (_activeObjective == null) return;
    final tasks = objectiveTasks;
    if (taskIndex < 0 || taskIndex >= tasks.length) return;
    if (newDescription.trim().isEmpty) return;

    tasks[taskIndex]['description'] = newDescription.trim();
    await _db.updateObjective(ObjectivesCompanion(
      id: drift.Value(_activeObjective!.id),
      tasks: drift.Value(jsonEncode(tasks)),
    ));
    await _loadActiveObjective();
  }

  /// Clear the active objective.
  Future<void> clearObjective() async {
    if (_activeObjective == null) return;
    await _db.updateObjective(ObjectivesCompanion(
      id: drift.Value(_activeObjective!.id),
      active: const drift.Value(false),
    ));
    _activeObjective = null;
    _messagesSinceLastCheck = 0;
    notifyListeners();
  }

  /// Update the injection depth for the active objective.
  Future<void> updateObjectiveDepth(int depth) async {
    if (_activeObjective == null) return;
    await _db.updateObjective(ObjectivesCompanion(
      id: drift.Value(_activeObjective!.id),
      injectionDepth: drift.Value(depth),
    ));
    await _loadActiveObjective();
  }

  /// Add a manually created task to the active objective.
  Future<void> addManualTask(String description) async {
    if (_activeObjective == null || description.trim().isEmpty) return;
    final tasks = objectiveTasks;
    tasks.add({'description': description.trim(), 'completed': false});
    await _db.updateObjective(ObjectivesCompanion(
      id: drift.Value(_activeObjective!.id),
      tasks: drift.Value(jsonEncode(tasks)),
    ));
    await _loadActiveObjective();
  }

  /// Remove a task from the active objective.
  Future<void> removeTask(int taskIndex) async {
    if (_activeObjective == null) return;
    final tasks = objectiveTasks;
    if (taskIndex < 0 || taskIndex >= tasks.length) return;
    tasks.removeAt(taskIndex);
    await _db.updateObjective(ObjectivesCompanion(
      id: drift.Value(_activeObjective!.id),
      tasks: drift.Value(jsonEncode(tasks)),
    ));
    await _loadActiveObjective();
  }

  /// Update how often task completion is checked.
  Future<void> updateCheckFrequency(int frequency) async {
    if (_activeObjective == null) return;
    await _db.updateObjective(ObjectivesCompanion(
      id: drift.Value(_activeObjective!.id),
      checkFrequency: drift.Value(frequency),
    ));
    await _loadActiveObjective();
  }

  /// Check if the current task has been completed (called periodically).
  /// Manually trigger a completion check (called from UI "Check now" button).
  void forceCheckCompletion() {
    if (_activeObjective == null) return;
    _checkTaskCompletionInBackground();
    notifyListeners(); // trigger UI to show spinner
  }

  /// Whether a completion check is currently running.
  bool get isCheckingCompletion => _isCheckingCompletion;

  /// Synchronous version — awaits the check. Used pre-generation.
  Future<void> _maybeCheckTaskCompletionSync() async {
    if (_activeObjective == null) return;
    if (_llmProvider == null) return;
    if (_isCheckingCompletion) return;

    _messagesSinceLastCheck++;
    if (_messagesSinceLastCheck < (_activeObjective?.checkFrequency ?? 3)) return;
    _messagesSinceLastCheck = 0;

    await _checkTaskCompletionInBackground();
  }

  void _maybeCheckTaskCompletion() {
    if (_activeObjective == null) return;
    _messagesSinceLastCheck++;

    final freq = _activeObjective!.checkFrequency;
    if (_messagesSinceLastCheck < freq) return;
    _messagesSinceLastCheck = 0;

    debugPrint('[Objective] Checking task completion (every $freq messages)');
    _checkTaskCompletionInBackground();
  }

  Future<void> _checkTaskCompletionInBackground() async {
    if (_isCheckingCompletion) return;
    _isCheckingCompletion = true;

    try {
      final llmService = _llmProvider?.activeService;
      if (llmService == null || !llmService.isReady) return;

      final tasks = objectiveTasks;
      final currentTask = tasks
          .where((t) => t['completed'] != true)
          .map((t) => t['description'] as String)
          .firstOrNull;
      if (currentTask == null) return;

      // Get the last several messages as context
      final recentMessages = _messages.length > 8
          ? _messages.sublist(_messages.length - 8)
          : _messages;
      final contextText = recentMessages.map((m) =>
          '${m.sender}: ${m.text}').join('\n');

      final prompt =
          'You are evaluating whether a roleplay task has been completed based on recent conversation. '
          'Be generous in your assessment — if the events in the conversation show the task has been '
          'accomplished, partially fulfilled, or naturally resolved, answer YES.\n\n'
          'Task to evaluate: "$currentTask"\n\n'
          'Recent conversation:\n$contextText\n\n'
          'Has this task been completed or effectively resolved? Answer only YES or NO:';

      final params = GenerationParams(
        prompt: prompt,
        maxLength: 1024,
        temperature: 0.1,
        stopSequences: [],
      );

      String responseText = '';
      await for (final chunk in llmService.generateStream(params)) {
        responseText += chunk;
      }

      // Strip think blocks
      responseText = responseText.replaceAll(
          RegExp(r'<think>.*?</think>', dotAll: true), '').trim();

      debugPrint('[Objective] Completion check for "$currentTask": $responseText');

      if (responseText.toUpperCase().contains('YES')) {
        final taskIndex = tasks.indexWhere(
            (t) => t['description'] == currentTask && t['completed'] != true);
        if (taskIndex >= 0) {
          tasks[taskIndex]['completed'] = true;
          await _db.updateObjective(ObjectivesCompanion(
            id: drift.Value(_activeObjective!.id),
            tasks: drift.Value(jsonEncode(tasks)),
          ));
          await _loadActiveObjective();
          debugPrint('[Objective] Task completed: $currentTask');
        }
      }
    } catch (e) {
      debugPrint('[Objective] Completion check failed: $e');
    } finally {
      _isCheckingCompletion = false;
      notifyListeners();
    }
  }

  int _userMessagesSinceLastExtract = 0;
  bool _isExtractingFacts = false;

  /// Extract personal facts from recent user messages using the LLM.
  /// Fires async (non-blocking) every N user messages when auto-persona is enabled.
  void _maybeExtractFacts() {
    if (!_storageService.autoPersonaEnabled) return;
    if (_llmProvider == null) return;
    if (_isExtractingFacts) return;

    // Count user messages in this session
    _userMessagesSinceLastExtract++;
    if (_userMessagesSinceLastExtract < _storageService.autoPersonaInterval) return;
    _userMessagesSinceLastExtract = 0;

    debugPrint('[RAG:Persona] ▶ Triggering fact extraction (every ${_storageService.autoPersonaInterval} user messages)');
    _extractFactsInBackground();
  }

  Future<void> _extractFactsInBackground() async {
    if (_isExtractingFacts) return;
    _isExtractingFacts = true;

    try {
      final llmService = _llmProvider!.activeService;
      if (llmService == null || !llmService.isReady) {
        debugPrint('[RAG:Persona] ✗ LLM not ready, skipping extraction');
        return;
      }

      // Get recent user messages (last N messages, user only)
      final userMessages = _messages
          .where((m) => m.isUser && m.characterId != '__director__')
          .toList();

      if (userMessages.isEmpty) {
        debugPrint('[RAG:Persona] No user messages to extract from');
        return;
      }

      // Take last 10 user messages
      final recentUserMsgs = userMessages.length > 10
          ? userMessages.sublist(userMessages.length - 10)
          : userMessages;

      final existingFacts = _userPersonaService.persona.learnedFacts;

      // Build extraction prompt
      final userMsgText = recentUserMsgs
          .map((m) => '${m.sender}: ${m.displayText}')
          .join('\n');

      final existingFactsText = existingFacts.isNotEmpty
          ? 'Existing known facts (do NOT repeat these):\n${existingFacts.map((f) => '- $f').join('\n')}\n\n'
          : '';

      final extractionPrompt =
          'You are a fact extraction assistant. Read the following messages from a user named "${_userPersonaService.persona.name}" '
          'and extract any NEW personal facts about them. Focus on: preferences, relationships, background, personality traits, '
          'habits, likes/dislikes, physical descriptions, and life details.\n\n'
          '${existingFactsText}'
          'Recent messages from ${_userPersonaService.persona.name}:\n$userMsgText\n\n'
          'Return ONLY a valid JSON array of short factual statements about the user. '
          'Each fact should be a single concise sentence. If no new facts are found, return an empty array [].\n'
          'Example: ["Likes cats", "Has a sister named Sarah", "Works as a programmer"]\n'
          'Response:';

      debugPrint('[RAG:Persona] Sending extraction prompt (${extractionPrompt.length} chars, ${recentUserMsgs.length} user messages)');

      final params = GenerationParams(
        prompt: extractionPrompt,
        maxLength: 1024,
        temperature: 0.3,
        stopSequences: [],
      );

      String responseText = '';
      await for (final chunk in llmService.generateStream(params)) {
        responseText += chunk;
      }

      // Strip think blocks (for thinking models)
      responseText = responseText.replaceAll(
          RegExp(r'<think>.*?</think>', dotAll: true), '').trim();

      debugPrint('[RAG:Persona] Raw response: $responseText');

      // Parse JSON array from response
      // Handle cases where the model wraps in markdown code blocks
      var jsonStr = responseText;
      if (jsonStr.contains('```')) {
        final match = RegExp(r'```(?:json)?\s*\n?(.*?)\n?```', dotAll: true).firstMatch(jsonStr);
        if (match != null) jsonStr = match.group(1)!.trim();
      }

      // Try to find a JSON array in the response
      List<String> facts = [];
      final arrayMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(jsonStr);
      if (arrayMatch != null) {
        try {
          facts = List<String>.from(jsonDecode(arrayMatch.group(0)!) as List);
        } catch (_) {
          debugPrint('[RAG:Persona] JSON parse failed, trying line parser');
        }
      }

      // Fallback: parse numbered/bulleted list lines (e.g. "- Likes cats" or "1. Has a dog")
      if (facts.isEmpty) {
        final lines = responseText.split('\n');
        for (final line in lines) {
          final cleaned = line.replaceFirst(RegExp(r'^\s*[-•*]\s*'), '')
                              .replaceFirst(RegExp(r'^\s*\d+[.)]\s*'), '')
                              .replaceAll('"', '')
                              .trim();
          if (cleaned.length > 3 && cleaned.length < 200) {
            facts.add(cleaned);
          }
        }
      }

      if (facts.isEmpty) {
        debugPrint('[RAG:Persona] ✗ No facts extracted from response');
        return;
      }

      debugPrint('[RAG:Persona] ✅ Extracted ${facts.length} new fact(s):');
      for (final fact in facts) {
        debugPrint('[RAG:Persona]   • $fact');
      }

      await _userPersonaService.addLearnedFacts(facts,
          embedService: _memoryService?.embeddingService);
      debugPrint('[RAG:Persona] Facts saved to persona');
    } catch (e) {
      debugPrint('[RAG:Persona] ✗ Extraction failed: $e');
    } finally {
      _isExtractingFacts = false;
    }
  }

  // ── Character Evolution ─────────────────────────────────────────────────

  int _userMessagesSinceLastEvolution = 0;
  bool _isEvolvingCharacter = false;
  String _evolutionStatus = '';
  String _evolutionError = '';

  /// Get the effective personality for a character.
  /// When evolution exists, returns a layered block: original as foundation,
  /// evolved traits as additive growth. This prevents contradictions.
  String _getEffectivePersonality(CharacterCard card) {
    if (!_storageService.characterEvolutionEnabled) return card.personality;
    final evolved = _evolvedPersonalities[_getCharacterIdFromCard(card)];
    if (evolved == null || evolved.isEmpty) return card.personality;
    // Layered: original is ground truth, evolved is additive growth
    return '${card.personality}\n\n'
        '[Character Growth — the following reflects how ${card.name} has changed through interactions. '
        'These traits build on the original personality above. If there is a contradiction, '
        'the growth represents genuine character development, not a replacement of core identity.]\n'
        '$evolved';
  }

  /// Get the effective scenario for a character.
  /// When evolution exists, returns both original scenario and evolved situation.
  String _getEffectiveScenario(CharacterCard card) {
    if (!_storageService.characterEvolutionEnabled) return card.scenario;
    final evolved = _evolvedScenarios[_getCharacterIdFromCard(card)];
    if (evolved == null || evolved.isEmpty) return card.scenario;
    // Layered: original scenario + evolved current situation
    return '${card.scenario}\n\n'
        '[Current Situation — the scenario has evolved through interactions:]\n'
        '$evolved';
  }

  /// Cached evolved fields (loaded from DB on character load)
  final Map<String, String> _evolvedPersonalities = {};
  final Map<String, String> _evolvedScenarios = {};
  int _characterEvolutionCount = 0;
  int get characterEvolutionCount => _characterEvolutionCount;

  /// Public getter: evolved personality for the active character (null if none)
  /// In group mode, returns null — use getEvolvedPersonalityFor(card) instead.
  String? get getEffectivePersonality {
    if (_activeCharacter == null) return null;
    final charId = _getCharacterIdFromCard(_activeCharacter!);
    final evolved = _evolvedPersonalities[charId];
    return (evolved != null && evolved.isNotEmpty) ? evolved : null;
  }

  /// Public getter: evolved scenario for the active character (null if none)
  /// In group mode, returns null — use getEvolvedScenarioFor(card) instead.
  String? get getEffectiveScenario {
    if (_activeCharacter == null) return null;
    final charId = _getCharacterIdFromCard(_activeCharacter!);
    final evolved = _evolvedScenarios[charId];
    return (evolved != null && evolved.isNotEmpty) ? evolved : null;
  }

  /// Get evolved personality for a specific character (works in both 1:1 and group mode).
  String? getEvolvedPersonalityFor(CharacterCard card) {
    final charId = _getCharacterIdFromCard(card);
    final evolved = _evolvedPersonalities[charId];
    return (evolved != null && evolved.isNotEmpty) ? evolved : null;
  }

  /// Get evolved scenario for a specific character (works in both 1:1 and group mode).
  String? getEvolvedScenarioFor(CharacterCard card) {
    final charId = _getCharacterIdFromCard(card);
    final evolved = _evolvedScenarios[charId];
    return (evolved != null && evolved.isNotEmpty) ? evolved : null;
  }

  /// Get evolution count for a specific character.
  int getEvolutionCountFor(CharacterCard card) {
    final charId = _getCharacterIdFromCard(card);
    return _groupEvolutionCounts[charId] ?? 0;
  }

  /// Per-character evolution counts (for group mode).
  final Map<String, int> _groupEvolutionCounts = {};

  /// Load evolved fields from DB for the active character
  Future<void> _loadEvolvedFields() async {
    if (_activeCharacter == null || _activeCharacter!.dbId == null) return;
    try {
      final dbChar = await _db!.getCharacterById(_activeCharacter!.dbId!);
      final charId = _getCharacterIdFromCard(_activeCharacter!);
      _evolvedPersonalities[charId] = dbChar.evolvedPersonality;
      _evolvedScenarios[charId] = dbChar.evolvedScenario;
      _characterEvolutionCount = dbChar.evolutionCount;
      _groupEvolutionCounts[charId] = dbChar.evolutionCount;
    } catch (e) {
      debugPrint('[Evolution] Failed to load evolved fields: $e');
    }
  }

  /// Load evolved fields for all characters in the active group.
  Future<void> _loadGroupEvolvedFields() async {
    if (_activeGroup == null) return;
    for (final ch in _groupCharacters) {
      if (ch.dbId == null) continue;
      try {
        final dbChar = await _db.getCharacterById(ch.dbId!);
        final charId = _getCharacterIdFromCard(ch);
        _evolvedPersonalities[charId] = dbChar.evolvedPersonality;
        _evolvedScenarios[charId] = dbChar.evolvedScenario;
        _groupEvolutionCounts[charId] = dbChar.evolutionCount;
      } catch (e) {
        debugPrint('[Evolution] Failed to load evolved fields for ${ch.name}: $e');
      }
    }
  }

  /// Whether evolution extraction is currently running.
  bool get isEvolvingCharacter => _isEvolvingCharacter;

  /// Current status message during evolution.
  String get evolutionStatus => _evolutionStatus;

  /// Error message from the last evolution attempt (empty if no error).
  String get evolutionError => _evolutionError;

  /// Manually trigger character evolution now (for imported/existing chats).
  /// In group mode, pass a target character. Returns true if evolution was triggered.
  Future<bool> triggerEvolutionNow({CharacterCard? target}) async {
    if (_llmProvider == null) return false;
    if (_isEvolvingCharacter) return false;
    if (_messages.length < 4) return false; // need some history

    // Determine target character
    final card = target ?? _activeCharacter;
    if (card == null || card.dbId == null) return false;

    debugPrint('[Evolution] ▶ Manual evolution triggered for ${card.name}');
    await _extractCharacterEvolution(targetCharacter: card);
    return true;
  }

  /// Trigger evolution check after each generation.
  void _maybeEvolveCharacter() {
    if (!_storageService.characterEvolutionEnabled) return;
    if (_llmProvider == null) return;
    if (_isEvolvingCharacter) return;

    // In group mode, evolve the character who just spoke
    CharacterCard? target;
    if (_activeGroup != null) {
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        final lastSender = _messages.last.sender;
        target = _groupCharacters.where((c) => c.name == lastSender).firstOrNull;
      }
      if (target == null) return;
    } else {
      target = _activeCharacter;
      if (target == null) return;
    }

    _userMessagesSinceLastEvolution++;
    if (_userMessagesSinceLastEvolution < _storageService.evolutionInterval) return;
    _userMessagesSinceLastEvolution = 0;

    debugPrint('[Evolution] ▶ Triggering character evolution for ${target.name} '
        '(every ${_storageService.evolutionInterval} user messages)');
    _extractCharacterEvolution(targetCharacter: target);
  }

  /// Extract evolved personality + scenario from conversation memories.
  /// Accepts an optional [targetCharacter] for group mode support.
  Future<void> _extractCharacterEvolution({CharacterCard? targetCharacter}) async {
    if (_isEvolvingCharacter) {
      debugPrint('[Evolution] ⚠ Already evolving, skipping');
      return;
    }
    _isEvolvingCharacter = true;
    _evolutionStatus = 'Preparing evolution...';
    _evolutionError = '';
    notifyListeners();

    try {
      final llmService = _llmProvider!.activeService;
      debugPrint('[Evolution] ▶ Backend: ${llmService.backendName}, isReady: ${llmService.isReady}');
      if (!llmService.isReady) {
        debugPrint('[Evolution] ✗ LLM not ready — backend=${llmService.backendName}');
        _evolutionError = 'LLM backend is not ready. Please check your connection.';
        return;
      }

      final card = targetCharacter ?? _activeCharacter;
      if (card == null || card.dbId == null) {
        debugPrint('[Evolution] ✗ No character — card=$card, dbId=${card?.dbId}');
        _evolutionError = 'No active character found.';
        return;
      }

      final charName = card.name;
      final userName = _userPersonaService.persona.name;
      final originalPersonality = card.personality;
      final originalScenario = card.scenario;
      final charId = _getCharacterIdFromCard(card);

      debugPrint('[Evolution] Character: $charName (charId=$charId, dbId=${card.dbId})');
      debugPrint('[Evolution] Personality length: ${originalPersonality.length}, Scenario length: ${originalScenario.length}');

      // Get current evolved versions (or originals if first time)
      final currentPersonality = _evolvedPersonalities[charId]?.isNotEmpty == true
          ? _evolvedPersonalities[charId]!
          : originalPersonality;
      final currentScenario = _evolvedScenarios[charId]?.isNotEmpty == true
          ? _evolvedScenarios[charId]!
          : originalScenario;

      // Gather context: RAG memories + summary + recent messages
      String memoryContext = '';
      if (_memoryService != null && _memoryService!.isOperational) {
        _evolutionStatus = 'Gathering memories...';
        notifyListeners();
        try {
          final sourceIds = await _getMemorySourceIds();
          final chunks = await _memoryService!.getAllContentForCharacters(sourceIds);
          debugPrint('[Evolution] RAG: ${chunks.length} memory chunks retrieved');
          if (chunks.isNotEmpty) {
            // Take last 10 chunks to keep prompt reasonable
            final recent = chunks.length > 10 ? chunks.sublist(chunks.length - 10) : chunks;
            memoryContext = 'Conversation memories:\n${recent.join('\n---\n')}\n\n';
          }
        } catch (e) {
          debugPrint('[Evolution] RAG retrieval failed (non-fatal): $e');
        }
      } else {
        debugPrint('[Evolution] RAG not available (memoryService=${_memoryService != null}, operational=${_memoryService?.isOperational})');
      }

      String summaryContext = '';
      if (_summary.isNotEmpty) {
        summaryContext = 'Chat summary: $_summary\n\n';
        debugPrint('[Evolution] Summary context: ${_summary.length} chars');
      }

      // Recent messages for immediate context
      final recentMsgs = _messages.length > 10
          ? _messages.sublist(_messages.length - 10)
          : _messages;
      final recentContext = recentMsgs
          .map((m) => '${m.sender}: ${m.displayText}')
          .join('\n');

      debugPrint('[Evolution] Messages: ${_messages.length} total, using ${recentMsgs.length} recent');

      final prompt =
          'You are analyzing how a roleplay character has evolved through their interactions. '
          'Based on the conversation history and memories below, rewrite the character\'s personality '
          'and scenario to reflect how they have grown, changed, or been affected by events.\n\n'
          'IMPORTANT RULES:\n'
          '- Preserve the character\'s core identity — don\'t change who they fundamentally are\n'
          '- Add or modify traits based on what actually happened in conversations\n'
          '- Update the scenario to reflect the current state of the story/relationship\n'
          '- Keep the same level of detail as the originals\n'
          '- Use {{char}} for the character name and {{user}} for the user name\n'
          '- Return ONLY a JSON object, no other text\n\n'
          'Character name: $charName\n'
          'User name: $userName\n\n'
          'Original personality:\n$originalPersonality\n\n'
          'Current personality:\n$currentPersonality\n\n'
          'Original scenario:\n$originalScenario\n\n'
          'Current scenario:\n$currentScenario\n\n'
          '$memoryContext'
          '$summaryContext'
          'Recent conversation:\n$recentContext\n\n'
          'Return a JSON object with exactly two keys: "personality" and "scenario". '
          'Each value should be the full rewritten text for that field.\n'
          'Response:';

      debugPrint('[Evolution] Prompt built: ${prompt.length} chars');

      _evolutionStatus = 'Analyzing conversation with LLM...';
      notifyListeners();

      // Dynamic maxLength: the model must reproduce personality + scenario in
      // full, and think blocks can double the output.  Use a generous multiplier
      // with a 4096-token floor so short descriptions still get plenty of room.
      // Rough heuristic: 1 token ≈ 4 chars, so chars/4 ≈ tokens needed.
      final estimatedOutputTokens = ((currentPersonality.length + currentScenario.length) / 4 * 3).ceil();
      final maxLen = estimatedOutputTokens.clamp(4096, 16384);

      final params = GenerationParams(
        prompt: prompt,
        maxLength: maxLen,
        temperature: 0.4,
        stopSequences: [],
        reasoningEnabled: false,
      );

      debugPrint('[Evolution] Sending to LLM (maxLength=$maxLen, temp=0.4)...');

      String responseText = '';
      int chunkCount = 0;
      await for (final chunk in llmService.generateStream(params)) {
        responseText += chunk;
        chunkCount++;
      }

      debugPrint('[Evolution] LLM responded: $chunkCount chunks, ${responseText.length} chars total');

      // Strip think blocks
      final preStripLength = responseText.length;
      responseText = responseText.replaceAll(
          RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
      if (responseText.length != preStripLength) {
        debugPrint('[Evolution] Stripped think blocks: ${preStripLength - responseText.length} chars removed');
      }

      if (responseText.isEmpty) {
        debugPrint('[Evolution] ✗ LLM returned empty response after stripping');
        _evolutionError = 'The LLM returned an empty response. Try again or check your backend.';
        return;
      }

      // Log the full response for debugging (truncate for very long responses)
      debugPrint('[Evolution] ── Response start ──');
      if (responseText.length <= 500) {
        debugPrint(responseText);
      } else {
        debugPrint('${responseText.substring(0, 250)}');
        debugPrint('[...${responseText.length - 500} chars omitted...]');
        debugPrint('${responseText.substring(responseText.length - 250)}');
      }
      debugPrint('[Evolution] ── Response end ──');

      _evolutionStatus = 'Parsing evolved traits...';
      notifyListeners();

      // Parse JSON from response — try multiple strategies
      String? newPersonality;
      String? newScenario;

      // Strategy 1: Extract from markdown code block
      var jsonStr = responseText;
      if (jsonStr.contains('```')) {
        final match = RegExp(r'```(?:json)?\s*\n?(.*?)\n?```', dotAll: true).firstMatch(jsonStr);
        if (match != null) {
          jsonStr = match.group(1)!.trim();
          debugPrint('[Evolution] Extracted JSON from code block (${jsonStr.length} chars)');
        }
      }

      // Strategy 2: Find JSON object with greedy match
      final objMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(jsonStr);
      if (objMatch != null) {
        final jsonCandidate = objMatch.group(0)!;
        debugPrint('[Evolution] Found JSON candidate (${jsonCandidate.length} chars)');
        try {
          final parsed = jsonDecode(jsonCandidate) as Map<String, dynamic>;
          newPersonality = parsed['personality'] as String?;
          newScenario = parsed['scenario'] as String?;
          debugPrint('[Evolution] JSON parsed OK — personality=${newPersonality?.length ?? 0} chars, scenario=${newScenario?.length ?? 0} chars');
        } catch (e) {
          debugPrint('[Evolution] JSON parse attempt failed: $e');
          // Strategy 3: Try to fix truncated JSON — the model may have hit max tokens
          // Look for the last complete string value
          debugPrint('[Evolution] Attempting truncated JSON recovery...');
          try {
            // Try adding a closing brace to incomplete JSON
            final fixedJson = '$jsonCandidate"}';
            final parsed = jsonDecode(fixedJson) as Map<String, dynamic>;
            newPersonality = parsed['personality'] as String?;
            newScenario = parsed['scenario'] as String?;
            debugPrint('[Evolution] Truncated JSON recovery succeeded');
          } catch (_) {
            debugPrint('[Evolution] Truncated JSON recovery failed');
          }
        }
      } else {
        debugPrint('[Evolution] ✗ No JSON object ({...}) found in response');
      }

      if (newPersonality == null || newPersonality.isEmpty ||
          newScenario == null || newScenario.isEmpty) {
        debugPrint('[Evolution] ✗ Missing fields — personality=${newPersonality != null ? "${newPersonality.length} chars" : "null"}, scenario=${newScenario != null ? "${newScenario.length} chars" : "null"}');
        _evolutionError = newPersonality == null && newScenario == null
            ? 'Could not parse the LLM response as JSON. Check the terminal for the raw response.'
            : 'The LLM response was missing ${newPersonality == null || newPersonality.isEmpty ? "personality" : "scenario"} field.';
        return;
      }

      // Store in DB
      final oldCount = _groupEvolutionCounts[charId] ?? _characterEvolutionCount;
      final newCount = oldCount + 1;
      debugPrint('[Evolution] Saving to DB (charId=$charId, dbId=${card.dbId}, count $oldCount → $newCount)');
      await _db.updateCharacter(CharactersCompanion(
        id: drift.Value(card.dbId!),
        evolvedPersonality: drift.Value(newPersonality),
        evolvedScenario: drift.Value(newScenario),
        evolutionCount: drift.Value(newCount),
      ));

      // Update cache
      _evolvedPersonalities[charId] = newPersonality;
      _evolvedScenarios[charId] = newScenario;
      _groupEvolutionCounts[charId] = newCount;
      if (_activeCharacter != null) _characterEvolutionCount = newCount;

      debugPrint('[Evolution] ✅ ${charName} evolved successfully (count: $newCount)');
      debugPrint('[Evolution] Personality preview: ${newPersonality.substring(0, newPersonality.length.clamp(0, 100))}...');
      debugPrint('[Evolution] Scenario preview: ${newScenario.substring(0, newScenario.length.clamp(0, 100))}...');
      notifyListeners();
    } catch (e, stack) {
      debugPrint('[Evolution] ✗ Evolution failed with exception: $e');
      debugPrint('[Evolution] Stack trace: $stack');
      _evolutionError = 'Evolution failed: $e';
    } finally {
      _isEvolvingCharacter = false;
      _evolutionStatus = '';
      notifyListeners();
    }
  }

  /// Reset evolved fields back to original for a character.
  /// In 1:1 mode, targets the active character. In group mode, pass an explicit target.
  Future<void> resetCharacterEvolution({CharacterCard? target}) async {
    final card = target ?? _activeCharacter;
    if (card == null || card.dbId == null) return;
    final charId = _getCharacterIdFromCard(card);

    await _db!.updateCharacter(CharactersCompanion(
      id: drift.Value(card.dbId!),
      evolvedPersonality: const drift.Value(''),
      evolvedScenario: const drift.Value(''),
      evolutionCount: const drift.Value(0),
    ));

    _evolvedPersonalities.remove(charId);
    _evolvedScenarios.remove(charId);
    _groupEvolutionCounts.remove(charId);
    if (_activeCharacter != null && _getCharacterIdFromCard(_activeCharacter!) == charId) {
      _characterEvolutionCount = 0;
    }
    notifyListeners();
    debugPrint('[Evolution] Reset to original for ${card.name}');
  }

  /// Update the evolved personality text manually (user edits).
  /// In group mode, pass an explicit target character.
  Future<void> updateEvolvedPersonality(String text, {CharacterCard? target}) async {
    final card = target ?? _activeCharacter;
    if (card == null || card.dbId == null) return;
    final charId = _getCharacterIdFromCard(card);

    await _db!.updateCharacter(CharactersCompanion(
      id: drift.Value(card.dbId!),
      evolvedPersonality: drift.Value(text),
    ));
    _evolvedPersonalities[charId] = text;
    notifyListeners();
  }

  /// Update the evolved scenario text manually (user edits).
  /// In group mode, pass an explicit target character.
  Future<void> updateEvolvedScenario(String text, {CharacterCard? target}) async {
    final card = target ?? _activeCharacter;
    if (card == null || card.dbId == null) return;
    final charId = _getCharacterIdFromCard(card);

    await _db!.updateCharacter(CharactersCompanion(
      id: drift.Value(card.dbId!),
      evolvedScenario: drift.Value(text),
    ));
    _evolvedScenarios[charId] = text;
    notifyListeners();
  }

  /// Get the list of character IDs to search for RAG memory retrieval.
  /// Reads the current character's `memorySources` from the DB and includes
  /// those characters' embedding IDs alongside the current character.
  Future<List<String>> _getMemorySourceIds() async {
    final currentId = _getCharacterId();
    final sourceIds = <String>[currentId]; // always include self

    // Look up cross-character sources from DB
    if (_activeCharacter != null && _db != null && _activeCharacter!.dbId != null) {
      try {
        final dbChar = await _db!.getCharacterById(_activeCharacter!.dbId!);
        final ms = dbChar.memorySources;
        if (ms.isNotEmpty && ms != '[]') {
          final decoded = List<String>.from(
            (jsonDecode(ms) as List).map((e) => e.toString()),
          );
          for (final id in decoded) {
            if (!sourceIds.contains(id)) sourceIds.add(id);
          }
          if (decoded.isNotEmpty) {
            debugPrint('[RAG:Chat] Cross-character sources: $decoded');
          }
        }
      } catch (e) {
        debugPrint('[RAG:Chat] Failed to read memorySources: $e');
      }
    }

    return sourceIds;
  }

  /// Generate a summary of the chat history using the active LLM.
  Future<void> _generateSummaryInBackground() async {
    if (_llmProvider == null) return;
    final llmService = _llmProvider!.activeService;
    if (llmService == null || !llmService.isReady) return;

    _isSummaryGenerating = true;
    notifyListeners();

    try {
      final userName = _userPersonaService.persona.name;
      final charName = _activeCharacter?.name ?? _activeGroup?.name ?? 'Character';

      // Build the summary prompt with macro replacement
      final summaryPromptTemplate = _storageService.summaryPrompt
          .replaceAll('{{words}}', _storageService.summaryMaxWords.toString())
          .replaceAll('{{user}}', userName)
          .replaceAll('{{char}}', charName);

      // Build a condensed chat history for the summary request
      final historyLines = <String>[];
      for (final m in _messages) {
        if (m.characterId == '__director__') continue;
        // Strip thinking blocks from display text for summarization
        historyLines.add('${m.sender}: ${m.displayText}');
      }
      final chatHistoryForSummary = historyLines.join('\n');

      // Build the full prompt for the summary LLM call
      String previousSummaryBlock = '';
      if (_summary.isNotEmpty) {
        previousSummaryBlock = 'Previous summary:\n$_summary\n\n';
      }

      // Retrieve ALL RAG content chunks to ground the summary in real content
      String ragGroundingBlock = '';
      if (_memoryService != null && _memoryService!.isOperational) {
        try {
          final sourceIds = await _getMemorySourceIds();
          final allChunks = await _memoryService!.getAllContentForCharacters(sourceIds);
          if (allChunks.isNotEmpty) {
            ragGroundingBlock = 'Archived conversation content (use this as the primary source of truth):\n'
                '${allChunks.join('\n---\n')}\n\n';
            debugPrint('[Summary] Including ${allChunks.length} RAG chunks as grounding');
          }
        } catch (e) {
          debugPrint('[Summary] RAG grounding retrieval failed: $e');
        }
      }

      final summaryRequestPrompt =
          'The following is a conversation between $userName and $charName.\n\n'
          '$previousSummaryBlock'
          '$ragGroundingBlock'
          'Chat history:\n$chatHistoryForSummary\n\n'
          '$summaryPromptTemplate\n\n'
          'Here is the summary of the conversation so far:\n';

      final genParams = GenerationParams(
        prompt: summaryRequestPrompt,
        maxLength: (_storageService.summaryMaxWords * 3).clamp(200, 4000),
        temperature: 0.3,  // Low temperature for factual summarization
        repeatPenalty: 1.0,
        reasoningEnabled: false,
        stopSequences: ['\n\n\n', '<END>', '</END>'],
      );

      String accumulated = '';
      await for (final token in llmService.generateStream(genParams)) {
        accumulated += token;
      }

      var result = accumulated
          .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'</think>', caseSensitive: false), '')
          .trim();

      // Strip numbered-list analysis blocks that thinking models prepend.
      // Walk through lines, skip analysis preamble, keep only prose.
      final lines = result.split('\n');
      int startIdx = 0;
      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (trimmed.isEmpty) continue;
        // Skip numbered list items like "1. **Analyze..."
        if (RegExp(r'^\d+\.').hasMatch(trimmed)) { startIdx = i + 1; continue; }
        // Skip bullet points like "* **Goal:**" or "- **Setting:**"
        if (trimmed.startsWith('*') || trimmed.startsWith('-')) { startIdx = i + 1; continue; }
        // Found prose — stop here
        break;
      }
      if (startIdx > 0 && startIdx < lines.length) {
        result = lines.sublist(startIdx).join('\n').trim();
      }

      // Trim trailing incomplete sentence — cut back to last . ! or ?
      final lastSentenceEnd = result.lastIndexOf(RegExp(r'[.!?]'));
      if (lastSentenceEnd > 0 && lastSentenceEnd < result.length - 1) {
        result = result.substring(0, lastSentenceEnd + 1).trim();
      }

      if (result.isNotEmpty) {
        _summary = result;
        _summaryLastIndex = _messages.length;
        await _saveChat();
      }
    } catch (e) {
      debugPrint('Summary generation failed: $e');
    } finally {
      _isSummaryGenerating = false;
      notifyListeners();
    }
  }

  // ── Realism Mode ────────────────────────────────────────────────────────

  /// Shared helper: strip think blocks and extract text after them.
  String _stripThinkBlocks(String text) {
    String cleaned = text
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .trim();
    final unclosed = cleaned.indexOf('<think>');
    if (unclosed >= 0) {
      cleaned = cleaned.substring(0, unclosed).trim();
    }
    return cleaned;
  }

  /// Returns a GBNF grammar string only when it is safe to use one:
  /// - Backend must be KoboldCPP (local)
  /// - Reasoning/thinking mode must be OFF (grammar would block <think> tokens)
  /// Never call this for the API (OpenRouter) path.
  String? _buildKoboldGrammar(String grammar) {
    if (_llmProvider == null) return null;
    // Only apply grammar to the local KoboldCPP backend
    if (_llmProvider!.isLocal == false) return null;
    // If reasoning is enabled the user has a thinking model loaded locally —
    // grammar would prevent <think> from generating, so skip it.
    if (_storageService.reasoningEnabled) return null;
    return grammar;
  }

  /// Shared helper: fire a lightweight LLM eval call and return the raw response.
  ///
  /// Always adds `}\n` as a stop sequence so the model halts the moment it
  /// closes the JSON object, regardless of backend or model type.
  /// Thinking models (Kimi 2.5, GLM 5) will still think freely — they produce
  /// the <think> block, then output the JSON, then hit `}\n` and stop.
  ///
  /// [grammar] is an optional GBNF string for KoboldCPP local + non-thinking
  /// models only. Pass via [_buildKoboldGrammar] to get safe auto-gating.
  Future<String?> _fireLLMEval(String prompt, {String? grammar, void Function(String)? onChunk}) async {
    if (_llmProvider == null) return null;
    final llm = _llmProvider!.activeService;
    if (!llm.isReady) return null;

    final params = GenerationParams(
      prompt: prompt,
      maxLength: 8000,
      temperature: 0.1,
      reasoningEnabled: false,
      // Stop the moment the JSON object closes — works for all model types.
      // The 8000 token ceiling stays as a safety net for long think chains.
      stopSequences: ['}\n', '}'],
      grammar: grammar,
    );

    String response = '';
    await for (final chunk in llm.generateStream(params)) {
      response += chunk;
      onChunk?.call(chunk);
      // Also bail out eagerly the moment we see the JSON closing brace,
      // in case the stop sequence trims it and the stream continues briefly.
      if (response.contains('}')) {
        final stripped = _stripThinkBlocks(response);
        final candidate = stripped.isNotEmpty ? stripped : response;
        if (candidate.trimRight().endsWith('}') || candidate.contains('}\n')) break;
      }
    }
    return response.isEmpty ? null : response;
  }

  // ── Prompt Injection Builders ──

  String _getRelationshipInjection() {
    if (!_realismEnabled) return '';
    final charName = _activeCharacter?.name ?? 'the character';

    String moodNote = '';
    if (_shortTermMood >= 3) {
      moodNote = '$charName is currently delighted and very positively disposed toward {{user}}.';
    } else if (_shortTermMood >= 1) {
      moodNote = '$charName is currently in a good mood and pleased with {{user}}.';
    } else if (_shortTermMood == 0) {
      moodNote = '$charName has a neutral mood toward {{user}} right now.';
    } else if (_shortTermMood >= -2) {
      moodNote = '$charName is currently annoyed or mildly upset with {{user}} due to recent behavior.';
    } else {
      moodNote = '$charName is currently very upset or hurt by {{user}}\'s recent behavior. '
          'This should strongly color their response even if the long-term bond is high.';
    }

    String bondGuidance;
    if (_longTermTier >= 4) {
      bondGuidance = 'Their Long-Term Commitment is unbreakable: $charName fully trusts {{user}} and views them as a soulmate/life partner.';
    } else if (_longTermTier >= 2) {
      bondGuidance = 'Their Long-Term Trust is strong: $charName feels a deepening, stable connection and sees a real future with {{user}}.';
    } else if (_longTermTier <= -2) {
      bondGuidance = 'Their Long-Term Trust is broken: $charName holds deep-seated resentment and fundamentally distrusts {{user}}. Even if short-term mood improves, the underlying hostility remains.';
    } else {
      bondGuidance = 'Their Long-Term Bond is developing normally.';
    }

    String tensionGuidance;
    switch (_relationshipTier) {
      case 5:
        tensionGuidance = 'Short-Term Tension is Intimate: $charName is exceptionally close, vulnerable, and completely open right now.';
        break;
      case 4:
      case 3:
        tensionGuidance = 'Short-Term Tension is Friendly: $charName is warm, playful, and shares personal thoughts freely.';
        break;
      case 2:
      case 1:
        tensionGuidance = 'Short-Term Tension is Acquaintance: $charName is polite but keeps a safe emotional distance.';
        break;
      case 0:
        tensionGuidance = 'Short-Term Tension is Neutral/Stranger: $charName is guarded, formal, and deflects personal subjects.';
        break;
      case -1:
      case -2:
        tensionGuidance = 'Short-Term Tension is Frustrated: $charName is actively annoyed, short-tempered, and likely to snap or withdraw.';
        break;
      case -3:
      case -4:
      case -5:
        tensionGuidance = 'Short-Term Tension is Hostile: $charName actively dislikes {{user}} right now, responding with venom, sarcasm, or pure spite.';
        break;
      default:
        tensionGuidance = '';
    }

    return '[OOC Note regarding Relationship:\n'
        ' Long-Term Status: $longTermTierName ($_longTermScore points)\n'
        ' Short-Term Tension: $shortTermTierName\n'
        ' Current Mood: $moodLabel\n'
        ' $bondGuidance\n'
        ' $tensionGuidance\n'
        ' $moodNote\n'
        ' CRITICAL: Do NOT mention out-of-character terms or UI logic like tiers, scores, levels, or relationship states in your dialogue. Show, do not tell.]\n';
  }

  String _getEmotionInjection() {
    if (!_realismEnabled || _characterEmotion.isEmpty) return '';
    final charName = _activeCharacter?.name ?? 'the character';
    final cap = _characterEmotion.substring(0, 1).toUpperCase() + _characterEmotion.substring(1);
    return '[$charName\'s Current Emotional State: $cap ($_emotionIntensity)\n'
        ' This should subtly influence $charName\'s tone, body language, and word choice.]\n';
  }

  String _getBehavioralMechanicsInjection() {
    if (!_realismEnabled) return '';
    
    String block = '';
    
    // 1. Trust mapping (-100 to 100)
    if (_trustLevel <= -20) {
      block += '[Behavioral Anchor (MISTRUST): You deeply distrust the user right now. You are paranoid, evasive, and highly questioning of their motives. Even if your bond is high, you do not trust them.]\n';
    } else if (_trustLevel >= 50) {
      block += '[Behavioral Anchor (BLIND TRUST): You place absolute, unconditional trust in the user. You will readily share secrets and assume the absolute best of their intentions.]\n';
    }
    
    // 2. Fixation Mapping
    if (_activeFixation.isNotEmpty && _fixationLifespan > 0) {
      block += '[Background Thought: You have a lingering preoccupation about "$_activeFixation". Let this subtly flavor your internal monologue or mood, but do not aggressively force the conversation towards it unless naturally relevant.]\n';
    }
    
    // 3. Spatial Stance Mapping
    if (_spatialStance.isNotEmpty) {
      block += '[Spatial Anchor: You are currently physically "$_spatialStance". Format ALL of your actions around being anchored into this physical position in the environment.]\n';
    }
    
    return block;
  }

  String _getTimeInjection() {
    if (!_realismEnabled) return '';
    final timeLabel = _timeOfDay.replaceAll('_', ' ');
    final cap = timeLabel.substring(0, 1).toUpperCase() + timeLabel.substring(1);
    return '[Scene Time: $cap, Day $_dayCount\n'
        ' Describe appropriate lighting, atmosphere, and environmental details.]\n';
  }

  String _getNsfwCooldownInjection() {
    if (!_realismEnabled || !_nsfwCooldownEnabled) return '';
    
    final charName = _activeCharacter?.name ?? 'the character';
    String statePrompt = '[OOC Note regarding Physical State:\n';
    
    if (_cooldownTurnsRemaining > 0) {
      statePrompt += ' $charName recently experienced climax and is in a natural refractory/recovery period.\n'
          ' They should behave realistically: relaxed, possibly tired, affectionate but\n'
          ' not sexually eager. If {{user}} pushes for immediate sexual activity,\n'
          ' $charName should respond with gentle reluctance or suggest resting first.\n';
    } else {
      String arousalDesc;
      if (_arousalLevel <= -2) {
        arousalDesc = 'completely unaroused and physically deadened. They will actively reject or pull away from sexual advances';
      } else if (_arousalLevel == 0) {
        arousalDesc = 'physically dormant/neutral. They are not currently aroused';
      } else if (_arousalLevel <= 3) {
        arousalDesc = 'mildly flustered or experiencing a low hum of physical arousal';
      } else if (_arousalLevel <= 6) {
        arousalDesc = 'visibly aroused, highly receptive, and eager for physical intimacy';
      } else if (_arousalLevel <= 9) {
        arousalDesc = 'heavily aroused, breathing hard, and aggressively pursuing sexual release';
      } else {
        arousalDesc = 'feverish with lust, entirely consumed by the desperate need for immediate climax';
      }
      statePrompt += ' $charName is currently $arousalDesc.\n';
    }
    
    statePrompt += ' CRITICAL: Do NOT use terms like "cooldown", "turns", or "mechanics" in dialogue. Show, do not tell.]\n';
    return statePrompt;
  }

  // ── LLM Evaluation Calls ──

  Future<void> _evaluateRelationshipCall({void Function(String)? onChunk}) async {
    if (!_realismEnabled || _activeCharacter == null) return;

    final recentCount = _messages.length < 5 ? _messages.length : 5;
    final recent = _messages.reversed.take(recentCount).toList().reversed
        .map((m) => '${m.sender}: ${m.displayText}').join('\n');

    final charName = _activeCharacter!.name;
    final userName = _userPersonaService.persona.name;

    String personalityInjection = '';
    if (_activeCharacter!.personality.isNotEmpty) {
      final p = _activeCharacter!.personality.length > 500
          ? _activeCharacter!.personality.substring(0, 500)
          : _activeCharacter!.personality;
      personalityInjection = 'Account for $charName\'s specific personality traits:\n"$p"\n\n';
    }

    final prompt = 'You are evaluating the relationship dynamic between $charName and $userName in a roleplay.\n\n'
        '$personalityInjection'
        'Reactions are subjective! They depend entirely on $charName\'s personality.\n\n'
        '1. "relationship_delta": The short-term tension shift this turn. (-5 to +5)\n'
        '   +5: Incredible chemistry/bond | +2: Friendly | 0: Neutral | -2: Annoyed | -5: Deeply hostile\n'
        '2. "mood_shift": How $charName\'s mood shifts based on their personality. (-3 to +3)\n'
        '3. "trust_delta": Does $userName\'s action build or destroy trust? (-200 to +10)\n'
        '   +2: Honest interaction | 0: Neutral | -5: Minor lie discovered | -200: Massive unforgivable betrayal\n'
        '4. "reason": One brief sentence explaining the shift based on the recent messages.\n\n'
        'Recent conversation:\n$recent\n\n'
        'Respond with ONLY a flat JSON object containing "relationship_delta", "mood_shift", "trust_delta", and "reason".';

    try {
      debugPrint('[Realism] Evaluating relationship dynamic...');
      final raw = await _fireLLMEval(prompt,
          grammar: _buildKoboldGrammar(_kGbnfJsonObject), onChunk: onChunk);
      if (raw == null) return;

      final searchText = _stripThinkBlocks(raw);
      final text = searchText.isNotEmpty ? searchText : raw;

      final deltaMatch = RegExp(r'"relationship_delta"\s*:\s*(-?\d+)').firstMatch(text);
      int bondDelta = 0;
      if (deltaMatch != null) {
        bondDelta = (int.tryParse(deltaMatch.group(1)!) ?? 0).clamp(-5, 5);
        _applyScoreDelta(bondDelta);
      }

      final moodMatch = RegExp(r'"mood_shift"\s*:\s*(-?\d+)').firstMatch(text);
      int moodDelta = 0;
      if (moodMatch != null) {
        moodDelta = (int.tryParse(moodMatch.group(1)!) ?? 0).clamp(-3, 3);
        if (moodDelta != 0) {
          _shortTermMood = (_shortTermMood + moodDelta).clamp(-20, 20);
          _moodDecayCounter = 0;
          debugPrint('[Realism:Relationship] Mood shifted by $moodDelta -> $_shortTermMood ($moodLabel)');
        }
      }

      int trustDelta = 0;
      final trustMatch = RegExp(r'"trust_delta"\s*:\s*(-?\d+)').firstMatch(text);
      if (trustMatch != null) {
        trustDelta = (int.tryParse(trustMatch.group(1)!) ?? 0).clamp(-200, 10);
        if (trustDelta != 0) {
          _trustLevel = (_trustLevel + trustDelta).clamp(-100, 100);
          debugPrint('[Realism:Relationship] Trust shifted by $trustDelta -> $_trustLevel');
          // Arm the repair window on any severe single-turn drop
          if (trustDelta <= -20) {
            _pendingTrustRepair = true;
            debugPrint('[Realism:Trust] Severe drop — repair window armed');
            notifyListeners();
          }
        }
      }

      int arousalDelta = 0;
      if (_nsfwCooldownEnabled) {
        final arousalMatch = RegExp(r'"arousal_delta"\s*:\s*(-?\d+)').firstMatch(text);
        if (arousalMatch != null) {
          arousalDelta = (int.tryParse(arousalMatch.group(1)!) ?? 0).clamp(-2, 2);
          _arousalLevel = (_arousalLevel + arousalDelta).clamp(-3, 10);
        }
      }

      if (bondDelta != 0 || moodDelta != 0 || arousalDelta != 0 || trustDelta != 0) {
        _pendingRealismMetadata = {
          'bond_delta': bondDelta,
          'mood_delta': moodDelta,
          'mood_label': moodLabel,
          if (arousalDelta != 0) 'arousal_delta': arousalDelta,
          if (trustDelta != 0) 'trust_delta': trustDelta,
        };
      }

      final reasonMatch = RegExp(r'"reason"\s*:\s*"([^"]*)"').firstMatch(text);
      debugPrint('[Realism:Relationship] Reason: ${reasonMatch?.group(1) ?? 'unknown'}');
      _saveChat();
      notifyListeners();
    } catch (e) {
      debugPrint('[Realism:Relationship] Failed: $e');
    }
  }

  Future<void> _evaluateSceneStateCall({void Function(String)? onChunk}) async {
    if (!_realismEnabled || _activeCharacter == null) return;

    final recentCount = _messages.length < 4 ? _messages.length : 4;
    final recent = _messages.reversed.take(recentCount).toList().reversed
        .map((m) => '${m.sender}: ${m.displayText}').join('\n');

    final charName = _activeCharacter!.name;

    final arousalField = _nsfwCooldownEnabled
        ? ', "arousal_delta": <number -2 to +2>'
        : '';
    final arousalInstr = _nsfwCooldownEnabled
        ? '5. "arousal_delta": Physical arousal shift based on personality. (-2 to +2)\n'
        : '';

    final prompt = 'You are evaluating the current scene state for $charName.\n\n'
        '1. "emotion": their overarching emotional state right now (one word, nuanced like "melancholy" or "amused")\n'
        '2. "emotion_intensity": mild, moderate, or strong\n'
        '3. "time_of_day": dawn, morning, late_morning, afternoon, evening, or night\n'
        '   The current underlying time is $_timeOfDay. ONLY advance the time if the scene clearly moves forward!\n'
        '4. "posture": Their overarching spatial/physical stance (a brief phrase like "leaning against the wall"), or "none"\n'
        '$arousalInstr'
        '"fixation_topic": Severe overarching emotional obsession active right now (brief), or "none"\n\n'
        'Recent conversation:\n$recent\n\n'
        'Respond with ONLY a JSON object containing all of the above fields$arousalField.';

    try {
      debugPrint('[Realism] Evaluating scene state...');
      final raw = await _fireLLMEval(prompt,
          grammar: _buildKoboldGrammar(_kGbnfJsonObject), onChunk: onChunk);
      if (raw == null) return;

      final searchText = _stripThinkBlocks(raw);
      final text = searchText.isNotEmpty ? searchText : raw;

      final emotionMatch = RegExp(r'"emotion"\s*:\s*"([^"]+)"').firstMatch(text);
      if (emotionMatch != null) {
        _characterEmotion = emotionMatch.group(1)!.toLowerCase().trim();
      }

      final intensityMatch = RegExp(r'"emotion_intensity"\s*:\s*"([^"]+)"').firstMatch(text);
      if (intensityMatch != null) {
        _emotionIntensity = intensityMatch.group(1)!.toLowerCase().trim();
      }

      bool dayIncremented = false;
      final validTimes = ['dawn', 'morning', 'late_morning', 'afternoon', 'evening', 'night'];
      final currentIndex = validTimes.indexOf(_timeOfDay);

      final timeMatch = RegExp(r'"time_of_day"\s*:\s*"([^"]+)"').firstMatch(text);
      if (timeMatch != null) {
        final t = timeMatch.group(1)!.toLowerCase().trim();
        final targetIndex = validTimes.indexOf(t);

        if (targetIndex != -1 && targetIndex != currentIndex) {
          if (targetIndex > currentIndex) {
            int jump = targetIndex - currentIndex;
            if (jump > 2) jump = 2; // Cap forward jump to 2 periods max per turn (prevents skipping whole days instantly)
            _timeOfDay = validTimes[currentIndex + jump];
          } else if (targetIndex < currentIndex) {
            _timeOfDay = validTimes[0];
            _dayCount++;
            dayIncremented = true;
            debugPrint('[Realism:Scene] Time rolled over! Day $_dayCount');
          }
        }
      }

      if (!dayIncremented) {
        final newDayMatch = RegExp(r'"new_day"\s*:\s*(true|false)').firstMatch(text);
        if (newDayMatch != null && newDayMatch.group(1) == 'true' && currentIndex >= validTimes.indexOf('evening')) {
          _dayCount++;
          _timeOfDay = validTimes[0];
          debugPrint('[Realism:Scene] New day explicitly triggered! Day $_dayCount');
        }
      }

      final postureMatch = RegExp(r'"posture"\s*:\s*"([^"]+)"').firstMatch(text);
      if (postureMatch != null) {
        String p = postureMatch.group(1)!.trim();
        _spatialStance = (p.toLowerCase() == 'none' || p.isEmpty) ? '' : p;
      }

      // Decrement the fixation lifespan natively
      if (_fixationLifespan > 0) {
        _fixationLifespan--;
        if (_fixationLifespan == 0) {
          _activeFixation = '';
          debugPrint('[Realism:Scene] Fixation naturally decayed and cleared.');
        }
      }

      final fixationMatch = RegExp(r'"fixation_topic"\s*:\s*"([^"]+)"').firstMatch(text);
      if (fixationMatch != null) {
        String f = fixationMatch.group(1)!.trim();
        if (f.toLowerCase() == 'none' || f.isEmpty) {
          _activeFixation = '';
          _fixationLifespan = 0;
        } else if (f != _activeFixation) {
          _activeFixation = f;
          _fixationLifespan = 3; // Harcoded guardrail decay
          debugPrint('[Realism:Scene] New obsession registered: $f (3 turns)');
        }
      }

      debugPrint('[Realism:Scene] Emotion: $_characterEmotion ($_emotionIntensity), '
          'Time: $_timeOfDay, Day: $_dayCount');
          
      // Bundle Full Realism State for Time-Travel Forking
      _pendingRealismMetadata ??= {};
      _pendingRealismMetadata!['realism_state'] = _captureRealismState();

      _saveChat();
      notifyListeners();
    } catch (e) {
      debugPrint('[Realism:Scene] Failed: $e');
    }
  }

  /// ── One-Shot Eval (Experimental) ─────────────────────────────────────────
  /// Fused replacement for _evaluateRelationshipCall + _evaluateSceneStateCall.
  /// Issues a SINGLE LLM inference that evaluates all realism state fields at
  /// once, cutting pre-generation blocking overhead from 2 calls to 1.
  ///
  /// Enable via Settings → Realism → "One-Shot Eval (Experimental)".
  /// Not default because some models struggle with the combined prompt length.
  Future<void> _evaluateOneShotCall({void Function(String)? onChunk}) async {
    if (!_realismEnabled || _activeCharacter == null) return;

    final recentCount = _messages.length < 6 ? _messages.length : 6;
    final recent = _messages.reversed.take(recentCount).toList().reversed
        .map((m) => '${m.sender}: ${m.displayText}').join('\n');

    final charName = _activeCharacter!.name;
    final userName = _userPersonaService.persona.name;

    String personalityInjection = '';
    if (_activeCharacter!.personality.isNotEmpty) {
      final p = _activeCharacter!.personality.length > 600
          ? _activeCharacter!.personality.substring(0, 600)
          : _activeCharacter!.personality;
      personalityInjection = 'Account for $charName\'s specific personality traits:\n"$p"\n\n';
    }

    final arousalField = _nsfwCooldownEnabled
        ? ', "arousal_delta": <number -2 to +2>'
        : '';
    final arousalInstr = _nsfwCooldownEnabled
        ? '8. "arousal_delta": Physical arousal shift based on personality. (-2 to +2)\n'
        : '';

    final prompt = 'You are evaluating the current state of a roleplay scene involving $charName.\n\n'
        '$personalityInjection'
        'Reactions are subjective! Evaluate relationship changes based on $charName\'s specific traits.\n\n'
        'Evaluate ALL of the following at once:\n'
        '1. "relationship_delta": Short-term tension shift. (-5 to +5)\n'
        '   +5: Incredible chemistry | +2: Friendly | 0: Neutral | -2: Annoyed | -5: Deeply hostile\n'
        '2. "mood_shift": How $charName\'s mood shifts based on their personality. (-3 to +3)\n'
        '3. "trust_delta": Does $userName\'s action build or destroy trust? (-200 to +10)\n'
        '   +2: Honest | 0: Neutral | -5: Lie | -200: Massive unforgivable betrayal\n'
        '4. "emotion": $charName\'s current emotional state (one word, nuanced)\n'
        '5. "emotion_intensity": mild, moderate, or strong\n'
        '6. "time_of_day": dawn, morning, late_morning, afternoon, evening, or night\n'
        '   Current time: $_timeOfDay — advance only if the scene clearly moves forward\n'
        '7. "posture": $charName\'s spatial/physical stance (brief phrase), or "none"\n'
        '$arousalInstr'
        '"fixation_topic": Severe emotional obsession active right now (brief), or "none"\n'
        '"reason": One brief sentence explaining the key relationship change\n\n'
        'Recent conversation:\n$recent\n\n'
        'Respond with ONLY a JSON object containing all fields above$arousalField.';

    try {
      debugPrint('[Realism:OneShot] Evaluating (fused call)...');
      final raw = await _fireLLMEval(prompt,
          grammar: _buildKoboldGrammar(_kGbnfJsonObject), onChunk: onChunk);
      if (raw == null) return;

      final searchText = _stripThinkBlocks(raw);
      final text = searchText.isNotEmpty ? searchText : raw;

      // ── Relationship fields ──
      int bondDelta = 0;
      final deltaMatch = RegExp(r'"relationship_delta"\s*:\s*(-?\d+)').firstMatch(text);
      if (deltaMatch != null) {
        bondDelta = (int.tryParse(deltaMatch.group(1)!) ?? 0).clamp(-5, 5);
        _applyScoreDelta(bondDelta);
      }

      int moodDelta = 0;
      final moodMatch = RegExp(r'"mood_shift"\s*:\s*(-?\d+)').firstMatch(text);
      if (moodMatch != null) {
        moodDelta = (int.tryParse(moodMatch.group(1)!) ?? 0).clamp(-3, 3);
        if (moodDelta != 0) {
          _shortTermMood = (_shortTermMood + moodDelta).clamp(-20, 20);
          _moodDecayCounter = 0;
          debugPrint('[Realism:OneShot] Mood shifted by $moodDelta -> $_shortTermMood ($moodLabel)');
        }
      }

      int trustDelta = 0;
      final trustMatch = RegExp(r'"trust_delta"\s*:\s*(-?\d+)').firstMatch(text);
      if (trustMatch != null) {
        trustDelta = (int.tryParse(trustMatch.group(1)!) ?? 0).clamp(-200, 10);
        if (trustDelta != 0) {
          _trustLevel = (_trustLevel + trustDelta).clamp(-100, 100);
          debugPrint('[Realism:OneShot] Trust shifted by $trustDelta -> $_trustLevel');
          // Arm the repair window on any severe single-turn drop
          if (trustDelta <= -20) {
            _pendingTrustRepair = true;
            debugPrint('[Realism:Trust] Severe drop — repair window armed');
            notifyListeners();
          }
        }
      }

      int arousalDelta = 0;
      if (_nsfwCooldownEnabled) {
        final arousalMatch = RegExp(r'"arousal_delta"\s*:\s*(-?\d+)').firstMatch(text);
        if (arousalMatch != null) {
          arousalDelta = (int.tryParse(arousalMatch.group(1)!) ?? 0).clamp(-2, 2);
          _arousalLevel = (_arousalLevel + arousalDelta).clamp(-3, 10);
        }
      }

      if (bondDelta != 0 || moodDelta != 0 || arousalDelta != 0 || trustDelta != 0) {
        _pendingRealismMetadata = {
          'bond_delta': bondDelta,
          'mood_delta': moodDelta,
          'mood_label': moodLabel,
          if (arousalDelta != 0) 'arousal_delta': arousalDelta,
          if (trustDelta != 0) 'trust_delta': trustDelta,
        };
      }

      // ── Scene fields ──
      final emotionMatch = RegExp(r'"emotion"\s*:\s*"([^"]+)"').firstMatch(text);
      if (emotionMatch != null) {
        _characterEmotion = emotionMatch.group(1)!.toLowerCase().trim();
      }

      final intensityMatch = RegExp(r'"emotion_intensity"\s*:\s*"([^"]+)"').firstMatch(text);
      if (intensityMatch != null) {
        _emotionIntensity = intensityMatch.group(1)!.toLowerCase().trim();
      }

      final validTimes = ['dawn', 'morning', 'late_morning', 'afternoon', 'evening', 'night'];
      final currentIndex = validTimes.indexOf(_timeOfDay);
      final timeMatch = RegExp(r'"time_of_day"\s*:\s*"([^"]+)"').firstMatch(text);
      if (timeMatch != null) {
        final t = timeMatch.group(1)!.toLowerCase().trim();
        final targetIndex = validTimes.indexOf(t);
        if (targetIndex != -1 && targetIndex != currentIndex) {
          if (targetIndex > currentIndex) {
            int jump = targetIndex - currentIndex;
            if (jump > 2) jump = 2;
            _timeOfDay = validTimes[currentIndex + jump];
          } else {
            _timeOfDay = validTimes[0];
            _dayCount++;
            debugPrint('[Realism:OneShot] Time rolled over! Day $_dayCount');
          }
        }
      }

      final postureMatch = RegExp(r'"posture"\s*:\s*"([^"]+)"').firstMatch(text);
      if (postureMatch != null) {
        final p = postureMatch.group(1)!.trim();
        _spatialStance = (p.toLowerCase() == 'none' || p.isEmpty) ? '' : p;
      }

      if (_fixationLifespan > 0) {
        _fixationLifespan--;
        if (_fixationLifespan == 0) {
          _activeFixation = '';
          debugPrint('[Realism:OneShot] Fixation decayed and cleared.');
        }
      }
      final fixationMatch = RegExp(r'"fixation_topic"\s*:\s*"([^"]+)"').firstMatch(text);
      if (fixationMatch != null) {
        final f = fixationMatch.group(1)!.trim();
        if (f.toLowerCase() == 'none' || f.isEmpty) {
          _activeFixation = '';
          _fixationLifespan = 0;
        } else if (f != _activeFixation) {
          _activeFixation = f;
          _fixationLifespan = 3;
          debugPrint('[Realism:OneShot] New obsession: $f (3 turns)');
        }
      }

      final reasonMatch = RegExp(r'"reason"\s*:\s*"([^"]*)"').firstMatch(text);
      debugPrint('[Realism:OneShot] Done — Emotion: $_characterEmotion ($_emotionIntensity), '
          'Time: $_timeOfDay, Reason: ${reasonMatch?.group(1) ?? 'unknown'}');

      // Bundle full state snapshot for time-travel forking
      _pendingRealismMetadata ??= {};
      _pendingRealismMetadata!['realism_state'] = _captureRealismState();

      _saveChat();
      notifyListeners();
    } catch (e) {
      debugPrint('[Realism:OneShot] Failed: $e — falling back to dual-call on next turn');
    }
  }

  /// One-shot trust repair evaluator.
  ///
  /// Called automatically on the user's next message after a severe trust drop
  /// (≥ -20 delta). Replaces the normal relationship eval for that turn.
  /// The LLM weighs the explanation against character persona and chat history,
  /// returning a trust_recovery value (0–60). Recovery is capped to prevent
  /// instant restoration from Absolute Distrust.
  Future<void> _evaluateTrustRepairCall(String userExplanation, {void Function(String)? onChunk}) async {
    if (!_realismEnabled || _activeCharacter == null) return;

    final charName    = _activeCharacter!.name;
    final persona     = _activeCharacter!.personality.length > 600
        ? _activeCharacter!.personality.substring(0, 600)
        : _activeCharacter!.personality;
    final recentCount = _messages.length < 10 ? _messages.length : 10;
    final history     = _messages.reversed.take(recentCount).toList().reversed
        .map((m) => '${m.sender}: ${m.displayText}').join('\n');

    final prompt =
        'You are evaluating whether $charName should partially restore trust '
        'after a severe breach caused by the previous interaction.\n\n'
        'Character Persona: $persona\n\n'
        'Recent chat history (last ~10 messages):\n$history\n\n'
        'The user\'s trust-repair explanation is: "$userExplanation"\n\n'
        'Evaluate ONLY whether this explanation is convincing given:\n'
        '1. The character\'s personality — are they forgiving, stubborn, paranoid, naive?\n'
        '2. The plausibility of the explanation against the chat history\n'
        '3. Whether the explanation contradicts established facts\n\n'
        'Rules:\n'
        '- trust_recovery: 0 (rejected) to 60 (fully convincing)\n'
        '- Paranoid/skeptical characters: give 0–20 even for good explanations\n'
        '- Forgiving/naive characters: may give 30–60 for plausible explanations\n'
        '- Do NOT give 60 unless the explanation perfectly resolves the breach\n'
        '- "reason" must be 1 short sentence from the character\'s POV\n\n'
        'Respond with ONLY: {"trust_recovery": <0-60>, "verdict": "accepted|partial|rejected", "reason": "<brief>"}\n';

    try {
      debugPrint('[Realism:TrustRepair] Evaluating repair attempt...');
      final raw = await _fireLLMEval(prompt, grammar: _buildKoboldGrammar(_kGbnfJsonObject), onChunk: onChunk);
      if (raw == null) return;

      final text = _stripThinkBlocks(raw).trim();

      final recoveryMatch = RegExp(r'"trust_recovery"\s*:\s*(\d+)').firstMatch(text);
      final verdictMatch  = RegExp(r'"verdict"\s*:\s*"([^"]+)"').firstMatch(text);
      final reasonMatch   = RegExp(r'"reason"\s*:\s*"([^"]*)"').firstMatch(text);

      final recovery = (int.tryParse(recoveryMatch?.group(1) ?? '0') ?? 0).clamp(0, 60);
      final verdict  = verdictMatch?.group(1) ?? 'rejected';
      final reason   = reasonMatch?.group(1) ?? '';

      if (recovery > 0) {
        _trustLevel = (_trustLevel + recovery).clamp(-100, 100);
        debugPrint('[Realism:TrustRepair] $verdict — recovered $recovery → $_trustLevel ($reason)');
      } else {
        debugPrint('[Realism:TrustRepair] Rejected — no recovery ($reason)');
      }

      // Surface verdict in message metadata so swipe history can record it
      _pendingRealismMetadata = {
        ...?_pendingRealismMetadata,
        'trust_repair_verdict': verdict,
        'trust_repair_recovery': recovery,
        if (reason.isNotEmpty) 'trust_repair_reason': reason,
      };

      _saveChat();
      notifyListeners();
    } catch (e) {
      debugPrint('[Realism:TrustRepair] Failed: $e');
    }
  }

  Map<String, dynamic> _captureRealismState() {
    return {
      'affectionScore': _affectionScore,
      'relationshipTier': _relationshipTier,
      'longTermScore': _longTermScore,
      'longTermTier': _longTermTier,
      'turnsSinceLongTermCheck': _turnsSinceLongTermCheck,
      'shortTermDeltasSummary': _shortTermDeltasSummary,
      'shortTermMood': _shortTermMood,
      'moodDecayCounter': _moodDecayCounter,
      'characterEmotion': _characterEmotion,
      'emotionIntensity': _emotionIntensity,
      'timeOfDay': _timeOfDay,
      'dayCount': _dayCount,
      'arousalLevel': _arousalLevel,
      'cooldownTurnsRemaining': _cooldownTurnsRemaining,
      'trustLevel': _trustLevel,
      'activeFixation': _activeFixation,
      'fixationLifespan': _fixationLifespan,
      'spatialStance': _spatialStance,
    };
  }

  void _restoreRealismStateFromMessage(ChatMessage? msg) {
    if (msg == null) return;
    
    // Check if the current visible node has an active swipe metadata array or just the base metadata
    final meta = msg.activeMetadata;
    if (meta == null || !meta.containsKey('realism_state')) {
      debugPrint('[Realism] No time-travel snapshot found in message. Legacy state kept.');
      return;
    }
    
    final state = meta['realism_state'] as Map<String, dynamic>;
    _affectionScore = state['affectionScore'] as int? ?? _affectionScore;
    _relationshipTier = state['relationshipTier'] as int? ?? _relationshipTier;
    _longTermScore = state['longTermScore'] as int? ?? _longTermScore;
    _longTermTier = state['longTermTier'] as int? ?? _longTermTier;
    _turnsSinceLongTermCheck = state['turnsSinceLongTermCheck'] as int? ?? _turnsSinceLongTermCheck;
    _shortTermDeltasSummary = state['shortTermDeltasSummary'] as int? ?? _shortTermDeltasSummary;
    _shortTermMood = state['shortTermMood'] as int? ?? _shortTermMood;
    _moodDecayCounter = state['moodDecayCounter'] as int? ?? _moodDecayCounter;
    _characterEmotion = state['characterEmotion'] as String? ?? _characterEmotion;
    _emotionIntensity = state['emotionIntensity'] as String? ?? _emotionIntensity;
    _timeOfDay = state['timeOfDay'] as String? ?? _timeOfDay;
    _dayCount = state['dayCount'] as int? ?? _dayCount;
    _arousalLevel = state['arousalLevel'] as int? ?? _arousalLevel;
    _cooldownTurnsRemaining = state['cooldownTurnsRemaining'] as int? ?? _cooldownTurnsRemaining;
    
    // v3.0 Restorations
    _trustLevel = state['trustLevel'] as int? ?? _trustLevel;
    _activeFixation = state['activeFixation'] as String? ?? _activeFixation;
    _fixationLifespan = state['fixationLifespan'] as int? ?? _fixationLifespan;
    _spatialStance = state['spatialStance'] as String? ?? _spatialStance;
    
    debugPrint('[Realism] Engine state successfully rolled back to match timeline.');
  }

  /// Fired post-generation against the AI's completed response text.
  /// The LLM writes the scene first — THEN we detect climax and apply
  /// the refractory cooldown so the *next* turn's prompt blocks re-escalation.
  Future<void> _checkClimaxInResponse(String responseText) async {
    if (responseText.trim().isEmpty) return;
    if (_activeCharacter == null) return;
    final charName = _activeCharacter!.name;

    String personalityInjection = '';
    if (_activeCharacter!.personality.isNotEmpty) {
      final p = _activeCharacter!.personality.length > 600 ? _activeCharacter!.personality.substring(0, 600) : _activeCharacter!.personality;
      personalityInjection = 'Character Personality Traits:\n"$p"\n\n';
    }

    final prompt =
        'Read the following character response and answer ONE question.\n\n'
        '$personalityInjection'
        'RESPONSE:\n$responseText\n\n'
        'Question: Did $charName (and ONLY $charName) PHYSICALLY reach climax/orgasm in this response? '
        'This must be an event actively occurring or just occurred in the text — '
        '$charName specifically physically reaching orgasm right now. '
        'If the response describes the user climaxing, but NOT $charName, you MUST answer false.\n'
        'Do NOT answer true for: dirty talk, innuendo, arousal build-up, '
        'sexual activity that has not yet reached completion, or casual use of words like "cum". '
        'ONLY answer true if $charName\'s orgasm/climax is unambiguously depicted as actively happening.\n'
        'If true, ALSO estimate their "refractory_turns" (recovery time before they can be aroused again). '
        'A normal character might take 5-7 turns. A highly sexual/nympho character takes 1-2 turns. Use their personality traits to decide.\n\n'
        'Respond with ONLY a JSON object: {"climax_detected": <true|false>, "refractory_turns": <number 1-8>, "reason": "<brief>"}';

    try {
      debugPrint('[Realism:Climax] Checking AI response for climax...');
      final raw = await _fireLLMEval(prompt,
          grammar: _buildKoboldGrammar(_kGbnfJsonObject));
      if (raw == null) return;

      final searchText = _stripThinkBlocks(raw);
      final text = searchText.isNotEmpty ? searchText : raw;

      final match = RegExp(r'"climax_detected"\s*:\s*(true|false)').firstMatch(text);
      if (match != null && match.group(1) == 'true') {
        int turns = 5;
        final turnMatch = RegExp(r'"refractory_turns"\s*:\s*(\d+)').firstMatch(text);
        if (turnMatch != null) {
          turns = (int.tryParse(turnMatch.group(1)!) ?? 5).clamp(1, 10);
        }
        _cooldownTurnsRemaining = turns;
        _arousalLevel = -3;
        debugPrint('[Realism:Climax] Confirmed — refractory cooldown started ($turns turns), arousal → -3');
        _saveChat();
        notifyListeners();
      } else {
        debugPrint('[Realism:Climax] No climax detected.');
      }
    } catch (e) {
      debugPrint('[Realism:Climax] Check failed: $e');
    }
  }

  // ── Score / State Helpers ──

  void _applyScoreDelta(int delta) {
    _shortTermDeltasSummary += delta;
    _turnsSinceLongTermCheck++;

    if (_turnsSinceLongTermCheck >= 5) {
      _evalLongTermGrowth();
    }

    if (delta == 0) return;
    final oldScore = _affectionScore;
    final oldTier = _relationshipTier;

    _affectionScore = (_affectionScore + delta).clamp(-150, 150);
    _relationshipTier = _calculateTier(_affectionScore);

    if (_affectionScore != oldScore || _relationshipTier != oldTier) {
      debugPrint('[Realism] Short-Term Bond: $oldScore \u2192 $_affectionScore, '
          'Tier: $oldTier \u2192 $_relationshipTier ($shortTermTierName)');
    }
  }

  void _evalLongTermGrowth() {
    final oldLTScore = _longTermScore;
    final oldLTTier = _longTermTier;

    if (_shortTermDeltasSummary >= 2 && _relationshipTier >= 0) {
      _longTermScore = (_longTermScore + 1).clamp(-150, 150);
    } else if (_shortTermDeltasSummary <= -2 && _relationshipTier <= 0) {
      _longTermScore = (_longTermScore - 1).clamp(-150, 150);
    }

    _longTermTier = _calculateTier(_longTermScore);
    _turnsSinceLongTermCheck = 0;
    _shortTermDeltasSummary = 0;

    if (_longTermScore != oldLTScore || _longTermTier != oldLTTier) {
      debugPrint('[Realism] Long-Term Bond updated: $oldLTScore \u2192 $_longTermScore, '
          'Tier: $oldLTTier \u2192 $_longTermTier ($longTermTierName)');
    } else {
      debugPrint('[Realism] Long-Term Bond check (No change) - Status: $_longTermScore ($longTermTierName)');
    }
  }

  void _applyMoodDecay() {
    if (_shortTermMood == 0) return;
    _moodDecayCounter++;
    
    // Base turns to decay 1 point
    int targetTurns = 3;
    
    if (_shortTermMood > 0) {
      // Good mood: Friends hold onto good moods longer. Enemies lose good moods fast.
      targetTurns += _relationshipTier; // Rank 5 -> decays every 8 turns. Rank -5 -> decays every 1 turn.
    } else {
      // Bad mood: Friends lose bad moods fast. Enemies hold grudges longer.
      targetTurns -= _relationshipTier; // Rank 5 -> decays every 1 turn. Rank -5 -> decays every 8 turns.
    }
    
    // Subtle long-term influence
    if (_shortTermMood > 0) {
      targetTurns += (_longTermTier / 2).floor();
    } else {
      targetTurns -= (_longTermTier / 2).floor();
    }
    
    // Clamp target turns so it never goes below 1 or absurdly high
    targetTurns = targetTurns.clamp(1, 10);
    
    if (_moodDecayCounter >= targetTurns) {
      _moodDecayCounter = 0;
      if (_shortTermMood > 0) {
        _shortTermMood--;
      } else {
        _shortTermMood++;
      }
      debugPrint('[Realism] Mood decay (-1 point limit over $targetTurns turns): $_shortTermMood ($moodLabel)');
    }
  }

  // ── Public Toggle Methods ──

  Future<void> setRealismEnabled(bool enabled) async {
    _realismEnabled = enabled;
    if (!enabled) {
      _affectionScore = 0;
      _trustLevel = 0;
      _relationshipTier = 0;
      _longTermScore = 0;
      _longTermTier = 0;
      _turnsSinceLongTermCheck = 0;
      _shortTermDeltasSummary = 0;
      _shortTermMood = 0;
      _moodDecayCounter = 0;
      _characterEmotion = '';
      _emotionIntensity = '';
      _timeOfDay = 'morning';
      _dayCount = 1;
      _cooldownTurnsRemaining = 0;
    }
    await _saveChat();
    notifyListeners();
  }

  Future<void> setNsfwCooldownEnabled(bool enabled) async {
    _nsfwCooldownEnabled = enabled;
    if (!enabled) {
      _cooldownTurnsRemaining = 0;
      _arousalLevel = 0;
    }
    await _saveChat();
    notifyListeners();
  }
}

