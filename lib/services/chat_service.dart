import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:kobold_character_card_manager/services/kobold_service.dart';
import 'package:kobold_character_card_manager/services/user_persona_service.dart';
import 'package:kobold_character_card_manager/services/storage_service.dart';
import 'package:kobold_character_card_manager/models/character_card.dart';
import 'package:kobold_character_card_manager/models/lorebook.dart';
import 'package:kobold_character_card_manager/services/world_repository.dart';
import 'package:kobold_character_card_manager/models/world.dart';

enum GenerationMode { normal, continue_, impersonate }

class ChatMessage {
  String text;
  final String sender;
  final bool isUser;

  ChatMessage({required this.text, required this.sender, required this.isUser});

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'sender': sender,
      'is_user': isUser,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] ?? '',
      sender: json['sender'] ?? '',
      isUser: json['is_user'] ?? false,
    );
  }
}

class ChatService extends ChangeNotifier {
  final KoboldService _koboldService;
  final UserPersonaService _userPersonaService;
  final StorageService _storageService;
  final WorldRepository _worldRepository;

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

  CharacterCard? get activeCharacter => _activeCharacter;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  bool get isLoadingSession => _isLoadingSession;
  String? get currentSessionId => _currentSessionId;
  double get generationProgress => _generationProgress;
  int get tokensGenerated => _tokensGenerated;
  int get maxTokens => _maxTokens;
  bool get isBuffering => _isBuffering;
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

  Future<void> setActiveCharacter(CharacterCard? character) async {
    // If same character is already active, don't reset unless empty
    if (_activeCharacter?.name == character?.name && 
        _activeCharacter?.imagePath == character?.imagePath && 
        _messages.isNotEmpty) {
      return;
    }

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

  String _getCharacterId() {
    if (_activeCharacter == null) return "unknown";
    // Use filename from imagePath or just name
    if (_activeCharacter!.imagePath != null) {
       return path.basenameWithoutExtension(_activeCharacter!.imagePath!);
    }
    return _activeCharacter!.name.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
  }

  Future<void> _saveChat() async {
    if (_activeCharacter == null || _currentSessionId == null) return;
    
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
    if (_activeCharacter == null) return;
    
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
      
      // Re-scan context for lore? 
      // Ideally we scan the whole history or just enough. 
      // For now, scan the last message to keep state consistent with current behavior.
      if (_messages.isNotEmpty) {
        _scanLorebook(_messages.last.text);
      }
    } catch (e) {
      print('Error loading chat session: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    if (_activeCharacter == null) return [];
    
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
    if (_activeCharacter == null) return;
    
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

  Future<void> startNewChat() async {
    if (_activeCharacter == null) return;

    _messages.clear();
    _greetingIndex = 0;
    if (_activeCharacter!.firstMessage.isNotEmpty) {
      _messages.add(ChatMessage(
        text: _buildFirstMessage(_activeCharacter!),
        sender: _activeCharacter!.name,
        isUser: false,
      ));
      _scanLorebook(_messages.last.text);
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
    if (_activeCharacter == null || text.trim().isEmpty) return;

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
      _messages.removeLast();
      await _saveChat();
      notifyListeners();

      await _generateResponse(GenerationMode.normal);
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

  Future<void> _generateResponse(GenerationMode mode) async {
    _isGenerating = true;
    _generationProgress = 0.0;
    _tokensGenerated = 0;
    _maxTokens = _storageService.maxLength;
    _generationStartTime = DateTime.now();
    _isBuffering = true;
    notifyListeners();

    try {
      final systemPrompt = _storageService.systemPrompt;
      
      // Build Lorebook content
      String loreContent = '';
      List<String> activeLoreStrings = [];

      // Character Lore
      if (_activeCharacter?.lorebook != null) {
        final activeEntries = _activeCharacter!.lorebook!.entries.where((e) => e.enabled && (e.isTriggered || e.constant));
        activeLoreStrings.addAll(activeEntries.map((e) => e.content));
      }

      // World Lore
      for (final worldName in _activeCharacter!.worldNames) {
        final world = _worldRepository.worlds.where((w) => w.name == worldName).firstOrNull;
        if (world == null) continue;
        final activeWorldEntries = world.lorebook.entries.where((e) => e.enabled && (e.isTriggered || e.constant));
        activeLoreStrings.addAll(activeWorldEntries.map((e) => e.content));
      }

      if (activeLoreStrings.isNotEmpty) {
        loreContent = "Context Info:\n${activeLoreStrings.join('\n')}\n";
      }

      final userName = _userPersonaService.persona.name;
      
      // Apply replacements to lore content
      if (loreContent.isNotEmpty) {
        loreContent = _activeCharacter!.replacePlaceholders(loreContent, userName: userName);
      }

      String history = _buildChatHistory();
      String suffix = "";
      
      if (mode == GenerationMode.normal) {
        suffix = "\n${_activeCharacter!.name}:";
      } else if (mode == GenerationMode.impersonate) {
        suffix = "\n${userName}:";
      } else if (mode == GenerationMode.continue_) {
        // Continue appends to the last message, so we don't add a new header.
        suffix = ""; 
      }

      final prompt = "$systemPrompt\n"
          "$loreContent"
          "${_activeCharacter!.name}'s Persona: ${_activeCharacter!.replacePlaceholders(_activeCharacter!.personality, userName: userName)}\n"
          "Scenario: ${_activeCharacter!.replacePlaceholders(_activeCharacter!.scenario, userName: userName)}\n"
          "<START>\n"
          "$history"
          "$suffix";

      final stopSequences = {
        ..._storageService.stopSequences,
        '\nUser:',
        '\n${_activeCharacter!.name}:',
        '\n${_userPersonaService.persona.name}:',
      }.toList();

      // Get streaming response
      final stream = _koboldService.generateStream(
        prompt,
        maxLength: _storageService.maxLength,
        minLength: _storageService.minLength,
        minP: _storageService.minP,
        temp: _storageService.temperature,
        repPenalty: _storageService.repeatPenalty,
        repPenTokens: _storageService.repeatPenaltyTokens,
        dynatempRange: _storageService.dynamicTempEnabled ? _storageService.dynamicTempRange : null,
        stopSequences: stopSequences,
      );
      
      String accumulatedResponse = "";
      bool stopFound = false;
      _tokenBuffer.clear();
      _displayedTokenCount = 0;
      _tokenTimestamps.clear();
      bool streamDone = false;

      // Determine message identity
      String originalText = '';
      String targetSender;
      bool isUserTarget;

      if (mode == GenerationMode.continue_) {
        originalText = _messages.last.text;
        targetSender = _messages.last.sender;
        isUserTarget = _messages.last.isUser;
      } else {
        targetSender = mode == GenerationMode.normal ? _activeCharacter!.name : _userPersonaService.persona.name;
        isUserTarget = mode == GenerationMode.impersonate;
        _messages.add(ChatMessage(text: "", sender: targetSender, isUser: isUserTarget));
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
        _messages.removeLast();
        _messages.add(ChatMessage(text: displayText, sender: targetSender, isUser: isUserTarget));
        notifyListeners();
      }

      // Read display buffer settings
      final bufferEnabled = _storageService.displayBufferEnabled;
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
        for (final stop in stopSequences) {
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
      _messages.add(ChatMessage(
        text: "Error: $e", 
        sender: "System", 
        isUser: false
      ));
      notifyListeners();
    } 
  }

  void _scanLorebook(String text) {
    if (_activeCharacter?.lorebook == null) return;
    
    // Case-insensitive search
    final lowerText = text.toLowerCase();
    bool changed = false;

    for (final entry in _activeCharacter!.lorebook!.entries) {
      if (!entry.enabled) continue;

      // If already triggered, we don't re-trigger (which would reset depth), 
      // OR we DO re-trigger to refresh depth? 
      // User said "control for how many messages a lorebook effects the context".
      // Usually re-triggering refreshes the depth.
      
      // Split keys by comma if multiple keywords exist for one entry
      final keys = entry.key.split(',').map((k) => k.trim().toLowerCase()).where((k) => k.isNotEmpty);
      
      for (final key in keys) {
        if (lowerText.contains(key)) {
          if (!entry.isTriggered) {
            entry.isTriggered = true;
            changed = true;
          }
          // Refresh depth every time the keyword is seen
          entry.remainingDepth = entry.stickyDepth;
          break; // Found a matching key for this entry
        }
      }
    }

    // Scan shared Worlds
    for (final worldName in _activeCharacter!.worldNames) {
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

    if (changed) {
      notifyListeners();
    }
  }

  void _decrementLoreDepth() {
    if (_activeCharacter?.lorebook == null) return;
    bool changed = false;

    for (final entry in _activeCharacter!.lorebook!.entries) {
      if (entry.isTriggered && !entry.constant) {
        entry.remainingDepth--;
        if (entry.remainingDepth <= 0) {
          entry.isTriggered = false;
          changed = true;
        }
      }
    }

    // Decrement Worlds
    for (final worldName in _activeCharacter!.worldNames) {
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
