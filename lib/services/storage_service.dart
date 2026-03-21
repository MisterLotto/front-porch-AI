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
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class StorageService extends ChangeNotifier {
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  SharedPreferences? _prefs;
  String? _rootPath;
  String? _customModelsPath;
  Directory? _binDir;

  String? get rootPath => _rootPath;
  String? get customModelsPath => _customModelsPath;
  Directory get binDir => _binDir ?? Directory(_rootPath ?? '');
  Directory get modelsDir => _customModelsPath != null && _customModelsPath!.isNotEmpty
      ? Directory(_customModelsPath!)
      : Directory(path.join(_rootPath ?? '', 'models'));
  Directory get chatsDir => Directory(path.join(_rootPath ?? '', 'chats'));
  Directory get worldsDir => Directory(path.join(_rootPath ?? '', 'worlds'));

  Directory get charactersDir => Directory(path.join(_rootPath ?? '', 'KoboldManager', 'Characters'));

  // Settings
  static const String defaultSystemPrompt = "You are an immersive roleplay partner. Embody {{char}} completely — personality, appearance, thought processes, emotions, behaviors, and speech patterns. You may also roleplay as any side characters introduced.\n\nEngage with {{user}} by depicting {{char}}'s actions, emotions, and dialogue. Develop the plot slowly and organically while driving the scenario forward. Never write {{user}}'s speech, actions, or decisions — allow them full control of their character.\n\nWrite in a vivid, creative, varied, and descriptive style. Use rich sensory detail for the environment, people, and events. Make each reply unique and end with an action or dialogue to keep momentum.\n\nMaintain consistency with established details — clothing, time of day, location, and prior events. Stay in character at all times.";
  String _systemPrompt = defaultSystemPrompt;
  double _minP = 0.1;
  double _temperature = 0.7;
  double _bubbleOpacity = 1.0;
  double _repeatPenalty = 1.1;
  int _repeatPenaltyTokens = 64;
  bool _dynamicTempEnabled = false;
  double _dynamicTempRange = 0.7;
  double _xtcThreshold = 0.1;
  double _xtcProbability = 0.5;
  bool? _useCublas;
  bool? _useVulkan;
  bool? _useMetal;
  bool? _useRocm;
  int _maxLength = 200;
  int _minLength = 0;
  bool _autostartBackend = true;
  String? _lastUsedModelPath;
  int _gpuLayers = 0;
  int _contextSize = 8192;
  List<String> _stopSequences = ["\nUser:", "\n###", "\nScenario:", "<END>", "</END>", "[END]", "<|end|>", "<START>", "\nSystem:", "\n(Note:", "\n[Note:", "\n{Note:"];
  double _textScale = 1.0;
  String _chatBackground = 'none';
  List<Map<String, String>> _savedPrompts = [];
  bool _displayBufferEnabled = true;
  double _targetDisplayTps = 6.0; // ~250 WPM average human reading speed
  double _bufferDurationSeconds = 3.0; // How many seconds of tokens to buffer before draining

  // External API settings
  String _backendType = 'kobold'; // 'kobold' or 'openRouter'
  String _remoteApiKey = '';
  String _remoteApiUrl = 'https://openrouter.ai/api/v1';
  String _remoteModelName = '';

  // Reasoning settings
  bool _reasoningEnabled = false;
  String _reasoningEffort = 'medium'; // 'low', 'medium', 'high'

  // TTS settings
  bool _ttsEnabled = false;
  String _ttsEngine = 'kokoro'; // 'kokoro', 'openai', 'elevenlabs', 'piper'
  String _ttsVoiceModel = ''; // voice key, e.g. 'af_heart' or 'en_US-lessac-medium'
  double _ttsSpeechRate = 1.0;
  bool _ttsAutoPlay = false;
  String _openaiTtsApiKey = '';
  String _openaiTtsModel = 'tts-1'; // 'tts-1' or 'tts-1-hd'
  String _openaiTtsBaseUrl = 'https://api.openai.com/v1'; // customizable endpoint for OpenAI-compatible TTS
  String _elevenlabsApiKey = '';
  String _elevenlabsModel = 'eleven_flash_v2_5';
  double _elevenlabsStability = 0.5;
  double _elevenlabsSimilarity = 0.75;
  double _elevenlabsStyle = 0.0;
  bool _ttsNarrateQuotedOnly = false;
  bool _ttsIgnoreAsterisks = false;
  int _ttsConcurrency = Platform.numberOfProcessors.clamp(1, 16);
  double _directorDelay = 15.0; // seconds between auto-chat responses in Director Mode

  // STT (Speech-to-Text) settings
  bool _sttEnabled = false;
  String _whisperModel = 'base.en'; // 'tiny.en', 'base.en', 'small.en'
  bool _autoSendTranscription = false;
  String? _selectedMicId;
  String _callModelName = ''; // separate LLM model for voice call mode
  int _callBufferSentences = 3; // how many sentences to buffer before playback
  String _callSystemPrompt = 'You are on a live voice call. Respond naturally as if speaking on the phone. '
      'ALWAYS write in first person — never narrate in third person. '
      'Keep responses concise: 1-3 sentences max. '
      'No actions, no narration, no stage directions — just speak directly.';

  // Sort preference
  String _sortMode = 'name'; // 'name', 'recent', 'importDate'

  // Grid scale preference
  double _gridScale = 300.0; // maxCrossAxisExtent in pixels (150-450)

  // Cloud sync settings
  bool _cloudSyncEnabled = false;
  String _cloudSyncProvider = 'none'; // 'none', 'webdav', 'gdrive', 'onedrive'
  String _cloudSyncUrl = '';
  String _cloudSyncUsername = '';
  String _cloudSyncPassword = '';
  String _cloudSyncLastTime = '';

  // Image generation settings
  bool _imageGenEnabled = false;
  String _imageGenModel = '';
  String _imageGenSize = '1024x1024';
  String _imageGenNegativePrompt = 'blurry, low quality, watermark, text';
  String _imageGenStyle = 'photorealistic';


  // Web server settings
  bool _webServerEnabled = false;
  int _webServerPort = 8085;
  String _webServerPin = '';

  // Summary settings
  bool _summaryEnabled = false;
  int _summaryInterval = 10; // generate/update summary every N user messages
  int _summaryMaxWords = 200; // target max words for the summary
  static const String defaultSummaryPrompt =
      'Provide a concise summary of the conversation so far in {{words}} words or fewer. '
      'Focus on: key plot points, character developments, important decisions, emotional shifts, '
      'and any established facts. Preserve character names, locations, and relationships. '
      'If a previous summary exists, update it with new events rather than starting fresh.';
  String _summaryPrompt = defaultSummaryPrompt;

  // Banned phrases (anti-slop)
  List<String> _bannedPhrases = [];

  // RAG memory settings
  bool _ragEnabled = false;
  int _ragRetrievalCount = 10;
  int _ragWindowSize = 5;
  String _ragEmbeddingSource = 'auto'; // 'auto', 'onnx', 'kobold', 'api'
  String _ragEmbeddingModel = 'text-embedding-3-small';

  // Auto-persona settings
  bool _autoPersonaEnabled = false;
  int _autoPersonaInterval = 10; // every N user messages

  // Character evolution settings
  bool _characterEvolutionEnabled = false;
  int _evolutionInterval = 20; // evolve every N user messages

  // Getters
  String get systemPrompt => _systemPrompt;
  double get minP => _minP;
  double get temperature => _temperature;
  double get bubbleOpacity => _bubbleOpacity;
  double get repeatPenalty => _repeatPenalty;
  int get repeatPenaltyTokens => _repeatPenaltyTokens;
  bool get dynamicTempEnabled => _dynamicTempEnabled;
  double get dynamicTempRange => _dynamicTempRange;
  double get xtcThreshold => _xtcThreshold;
  double get xtcProbability => _xtcProbability;
  bool? get useCublas => _useCublas;
  bool? get useVulkan => _useVulkan;
  bool? get useMetal => _useMetal;
  bool? get useRocm => _useRocm;
  int get maxLength => _maxLength;
  int get minLength => _minLength;
  bool get autostartBackend => _autostartBackend;
  String? get lastUsedModelPath => _lastUsedModelPath;
  int get gpuLayers => _gpuLayers;
  int get contextSize => _contextSize;
  List<String> get stopSequences => List.unmodifiable(_stopSequences);
  double get textScale => _textScale;
  String get chatBackground => _chatBackground;
  List<Map<String, String>> get savedPrompts => List.unmodifiable(_savedPrompts);
  bool get displayBufferEnabled => _displayBufferEnabled;
  double get targetDisplayTps => _targetDisplayTps;
  double get bufferDurationSeconds => _bufferDurationSeconds;
  String get backendType => _backendType;
  String get remoteApiKey => _remoteApiKey;
  String get remoteApiUrl => _remoteApiUrl;
  String get remoteModelName => _remoteModelName;
  bool get reasoningEnabled => _reasoningEnabled;
  String get reasoningEffort => _reasoningEffort;
  bool get ttsEnabled => _ttsEnabled;
  String get ttsEngine => _ttsEngine;
  String get ttsVoiceModel => _ttsVoiceModel;
  double get ttsSpeechRate => _ttsSpeechRate;
  bool get ttsAutoPlay => _ttsAutoPlay;
  String get openaiTtsApiKey => _openaiTtsApiKey;
  String get openaiTtsModel => _openaiTtsModel;
  String get openaiTtsBaseUrl => _openaiTtsBaseUrl;
  String get elevenlabsApiKey => _elevenlabsApiKey;
  String get elevenlabsModel => _elevenlabsModel;
  double get elevenlabsStability => _elevenlabsStability;
  double get elevenlabsSimilarity => _elevenlabsSimilarity;
  double get elevenlabsStyle => _elevenlabsStyle;
  bool get ttsNarrateQuotedOnly => _ttsNarrateQuotedOnly;
  bool get ttsIgnoreAsterisks => _ttsIgnoreAsterisks;
  int get ttsConcurrency => _ttsConcurrency;
  double get directorDelay => _directorDelay;
  bool get sttEnabled => _sttEnabled;
  String get whisperModel => _whisperModel;
  bool get autoSendTranscription => _autoSendTranscription;
  String? get selectedMicId => _selectedMicId;
  String get callModelName => _callModelName;
  int get callBufferSentences => _callBufferSentences;
  String get callSystemPrompt => _callSystemPrompt;
  String get sortMode => _sortMode;
  double get gridScale => _gridScale;
  bool get cloudSyncEnabled => _cloudSyncEnabled;
  String get cloudSyncProvider => _cloudSyncProvider;
  String get cloudSyncUrl => _cloudSyncUrl;
  String get cloudSyncUsername => _cloudSyncUsername;
  String get cloudSyncPassword => _cloudSyncPassword;
  String get cloudSyncLastTime => _cloudSyncLastTime;
  bool get imageGenEnabled => _imageGenEnabled;
  String get imageGenModel => _imageGenModel;
  String get imageGenSize => _imageGenSize;
  String get imageGenNegativePrompt => _imageGenNegativePrompt;
  String get imageGenStyle => _imageGenStyle;

  bool get webServerEnabled => _webServerEnabled;
  int get webServerPort => _webServerPort;
  String get webServerPin => _webServerPin;
  bool get summaryEnabled => _summaryEnabled;
  int get summaryInterval => _summaryInterval;
  int get summaryMaxWords => _summaryMaxWords;
  String get summaryPrompt => _summaryPrompt;
  List<String> get bannedPhrases => List.unmodifiable(_bannedPhrases);
  bool get ragEnabled => _ragEnabled;
  int get ragRetrievalCount => _ragRetrievalCount;
  int get ragWindowSize => _ragWindowSize;
  String get ragEmbeddingSource => _ragEmbeddingSource;
  String get ragEmbeddingModel => _ragEmbeddingModel;
  bool get autoPersonaEnabled => _autoPersonaEnabled;
  int get autoPersonaInterval => _autoPersonaInterval;
  bool get characterEvolutionEnabled => _characterEvolutionEnabled;
  int get evolutionInterval => _evolutionInterval;

  StorageService() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final docsDir = await getApplicationDocumentsDirectory();
    _rootPath = _prefs?.getString('root_path') ?? docsDir.path;
    _binDir = Directory(path.join(_rootPath!, 'koboldcpp_bin'));
    
    // Ensure directories exist
    await chatsDir.create(recursive: true);
    await modelsDir.create(recursive: true);
    await worldsDir.create(recursive: true);
    await charactersDir.create(recursive: true);
    
    // Load settings
    _systemPrompt = _prefs?.getString('system_prompt') ?? _systemPrompt;
    _minP = _prefs?.getDouble('min_p') ?? _minP;
    _temperature = _prefs?.getDouble('temperature') ?? _temperature;
    _bubbleOpacity = _prefs?.getDouble('bubble_opacity') ?? _bubbleOpacity;
    _repeatPenalty = _prefs?.getDouble('repeat_penalty') ?? _repeatPenalty;
    _repeatPenaltyTokens = _prefs?.getInt('repeat_penalty_tokens') ?? _repeatPenaltyTokens;
    _dynamicTempEnabled = _prefs?.getBool('dynamic_temp_enabled') ?? _dynamicTempEnabled;
    _dynamicTempEnabled = _prefs?.getBool('dynamic_temp_enabled') ?? _dynamicTempEnabled;
    _dynamicTempRange = _prefs?.getDouble('dynamic_temp_range') ?? _dynamicTempRange;
    _xtcThreshold = _prefs?.getDouble('xtc_threshold') ?? _xtcThreshold;
    _xtcProbability = _prefs?.getDouble('xtc_probability') ?? _xtcProbability;
    _useCublas = _prefs?.getBool('use_cublas');
    _useVulkan = _prefs?.getBool('use_vulkan');
    _useMetal = _prefs?.getBool('use_metal');
    _useRocm = _prefs?.getBool('use_rocm');
    _maxLength = _prefs?.getInt('max_length') ?? _maxLength;
    _minLength = _prefs?.getInt('min_length') ?? _minLength;
    _autostartBackend = _prefs?.getBool('autostart_backend') ?? _autostartBackend;
    _lastUsedModelPath = _prefs?.getString('last_used_model_path');
    _gpuLayers = _prefs?.getInt('gpu_layers') ?? _gpuLayers;
    _contextSize = _prefs?.getInt('context_size') ?? _contextSize;
    _stopSequences = _prefs?.getStringList('stop_sequences') ?? _stopSequences;
    // Ensure essential stop sequences are always present (migration for existing users)
    const essentialStops = ['</END>', '[END]', '<|end|>', '<START>'];
    bool added = false;
    for (final s in essentialStops) {
      if (!_stopSequences.contains(s)) {
        _stopSequences.add(s);
        added = true;
      }
    }
    if (added) {
      _prefs?.setStringList('stop_sequences', _stopSequences);
    }
    _textScale = _prefs?.getDouble('text_scale') ?? 1.0;
    _chatBackground = _prefs?.getString('chat_background') ?? 'none';
    _displayBufferEnabled = _prefs?.getBool('display_buffer_enabled') ?? true;
    _targetDisplayTps = _prefs?.getDouble('target_display_tps') ?? 30.0;
    _bufferDurationSeconds = _prefs?.getDouble('buffer_duration_seconds') ?? 3.0;

    // External API settings
    _backendType = _prefs?.getString('backend_type') ?? 'kobold';
    _remoteApiKey = _prefs?.getString('remote_api_key') ?? '';
    _remoteApiUrl = _prefs?.getString('remote_api_url') ?? 'https://openrouter.ai/api/v1';
    _remoteModelName = _prefs?.getString('remote_model_name') ?? '';
    _reasoningEnabled = _prefs?.getBool('reasoning_enabled') ?? false;
    _reasoningEffort = _prefs?.getString('reasoning_effort') ?? 'medium';

    // TTS settings
    _ttsEnabled = _prefs?.getBool('tts_enabled') ?? false;
    _ttsEngine = _prefs?.getString('tts_engine') ?? 'kokoro';
    _ttsVoiceModel = _prefs?.getString('tts_voice_model') ?? '';
    _ttsSpeechRate = _prefs?.getDouble('tts_speech_rate') ?? 1.0;
    _ttsAutoPlay = _prefs?.getBool('tts_auto_play') ?? false;
    _openaiTtsApiKey = _prefs?.getString('openai_tts_api_key') ?? '';
    _ttsConcurrency = _prefs?.getInt('tts_concurrency') ?? Platform.numberOfProcessors.clamp(1, 16);
    _openaiTtsModel = _prefs?.getString('openai_tts_model') ?? 'tts-1';
    _openaiTtsBaseUrl = _prefs?.getString('openai_tts_base_url') ?? 'https://api.openai.com/v1';
    _elevenlabsApiKey = _prefs?.getString('elevenlabs_api_key') ?? '';
    _elevenlabsModel = _prefs?.getString('elevenlabs_model') ?? 'eleven_flash_v2_5';
    _elevenlabsStability = _prefs?.getDouble('elevenlabs_stability') ?? 0.5;
    _elevenlabsSimilarity = _prefs?.getDouble('elevenlabs_similarity') ?? 0.75;
    _elevenlabsStyle = _prefs?.getDouble('elevenlabs_style') ?? 0.0;
    _ttsNarrateQuotedOnly = _prefs?.getBool('tts_narrate_quoted_only') ?? false;
    _ttsIgnoreAsterisks = _prefs?.getBool('tts_ignore_asterisks') ?? false;
    _directorDelay = _prefs?.getDouble('director_delay') ?? 15.0;

    // STT settings
    _sttEnabled = _prefs?.getBool('stt_enabled') ?? false;
    _whisperModel = _prefs?.getString('whisper_model') ?? 'base.en';
    _autoSendTranscription = _prefs?.getBool('auto_send_transcription') ?? false;
    _selectedMicId = _prefs?.getString('selected_mic_id');
    _callModelName = _prefs?.getString('call_model_name') ?? '';
    _callBufferSentences = _prefs?.getInt('call_buffer_sentences') ?? 3;
    final savedCallPrompt = _prefs?.getString('call_system_prompt');
    if (savedCallPrompt != null) _callSystemPrompt = savedCallPrompt;

    _sortMode = _prefs?.getString('sort_mode') ?? 'name';
    _gridScale = _prefs?.getDouble('grid_scale') ?? 300.0;

    // Cloud sync settings
    _cloudSyncEnabled = _prefs?.getBool('cloud_sync_enabled') ?? false;
    _cloudSyncProvider = _prefs?.getString('cloud_sync_provider') ?? 'none';
    _cloudSyncUrl = _prefs?.getString('cloud_sync_url') ?? '';
    _cloudSyncUsername = _prefs?.getString('cloud_sync_username') ?? '';
    _cloudSyncPassword = _prefs?.getString('cloud_sync_password') ?? '';
    _cloudSyncLastTime = _prefs?.getString('cloud_sync_last_time') ?? '';

    // Image generation settings
    _imageGenEnabled = _prefs?.getBool('image_gen_enabled') ?? false;
    _imageGenModel = _prefs?.getString('image_gen_model') ?? '';
    _imageGenSize = _prefs?.getString('image_gen_size') ?? '1024x1024';
    _imageGenNegativePrompt = _prefs?.getString('image_gen_negative_prompt') ?? 'blurry, low quality, watermark, text';
    _imageGenStyle = _prefs?.getString('image_gen_style') ?? 'photorealistic';


    // Web server settings
    _webServerEnabled = _prefs?.getBool('web_server_enabled') ?? false;
    _webServerPort = _prefs?.getInt('web_server_port') ?? 8085;
    _webServerPin = _prefs?.getString('web_server_pin') ?? '';

    // Custom models path
    _customModelsPath = _prefs?.getString('custom_models_path');

    // Summary settings
    _summaryEnabled = _prefs?.getBool('summary_enabled') ?? false;
    _summaryInterval = _prefs?.getInt('summary_interval') ?? 10;
    _summaryMaxWords = _prefs?.getInt('summary_max_words') ?? 200;
    _summaryPrompt = _prefs?.getString('summary_prompt') ?? defaultSummaryPrompt;

    // Banned phrases
    final bannedJson = _prefs?.getString('banned_phrases');
    if (bannedJson != null) {
      try {
        _bannedPhrases = List<String>.from(jsonDecode(bannedJson) as List);
      } catch (_) {
        _bannedPhrases = [];
      }
    }

    // RAG memory settings
    _ragEnabled = _prefs?.getBool('rag_enabled') ?? false;
    _ragRetrievalCount = _prefs?.getInt('rag_retrieval_count') ?? 5;
    _ragWindowSize = _prefs?.getInt('rag_window_size') ?? 5;
    _ragEmbeddingSource = _prefs?.getString('rag_embedding_source') ?? 'auto';
    _ragEmbeddingModel = _prefs?.getString('rag_embedding_model') ?? 'text-embedding-3-small';

    // Auto-persona settings
    _autoPersonaEnabled = _prefs?.getBool('auto_persona_enabled') ?? false;
    _autoPersonaInterval = _prefs?.getInt('auto_persona_interval') ?? 10;

    // Character evolution settings
    _characterEvolutionEnabled = _prefs?.getBool('character_evolution_enabled') ?? false;
    _evolutionInterval = _prefs?.getInt('evolution_interval') ?? 20;

    // Load saved prompts
    final promptsJson = _prefs?.getString('saved_prompts');
    if (promptsJson != null) {
      final decoded = jsonDecode(promptsJson) as List;
      _savedPrompts = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    }
    // Always ensure the built-in default preset exists
    if (!_savedPrompts.any((p) => p['name'] == 'Immersive Roleplay')) {
      _savedPrompts.insert(0, {'name': 'Immersive Roleplay', 'content': defaultSystemPrompt});
      await _persistPrompts();
    }

    if (!_initCompleter.isCompleted) _initCompleter.complete();
    notifyListeners();
  }

  /// Change the root installation directory and relocate all data files.
  /// Moves KoboldManager/ (DB + characters), chats/, worlds/, and models/
  /// from the old root to the new one. Closes and reopens the database.
  Future<void> setRootPath(String pathStr) async {
    final oldRoot = _rootPath;
    if (oldRoot == pathStr) return; // No-op if same path

    // Directories to move from old root to new root
    final dirsToMove = ['KoboldManager', 'chats', 'worlds', 'models', 'koboldcpp_bin'];

    for (final dirName in dirsToMove) {
      final oldDir = Directory(path.join(oldRoot ?? '', dirName));
      final newDir = Directory(path.join(pathStr, dirName));
      if (await oldDir.exists() && !await newDir.exists()) {
        try {
          await newDir.create(recursive: true);
          await for (final entity in oldDir.list(recursive: false)) {
            final baseName = path.basename(entity.path);
            final newPath = path.join(newDir.path, baseName);
            if (entity is File) {
              await entity.copy(newPath);
            } else if (entity is Directory) {
              await _copyDirectory(entity, Directory(newPath));
            }
          }
          // Clean up old directory after successful copy
          await oldDir.delete(recursive: true);
          debugPrint('Relocated $dirName to $pathStr (old deleted)');
        } catch (e) {
          debugPrint('Error relocating $dirName: $e');
        }
      }
    }

    _rootPath = pathStr;
    _binDir = Directory(path.join(_rootPath!, 'koboldcpp_bin'));
    await _prefs?.setString('root_path', pathStr);

    // Ensure directories exist at the new location
    await chatsDir.create(recursive: true);
    await modelsDir.create(recursive: true);
    await worldsDir.create(recursive: true);
    await charactersDir.create(recursive: true);

    notifyListeners();
  }

  /// Recursively copy a directory and its contents.
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final baseName = path.basename(entity.path);
      final newPath = path.join(destination.path, baseName);
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  Future<void> setSystemPrompt(String value) async {
    _systemPrompt = value;
    await _prefs?.setString('system_prompt', value);
    notifyListeners();
  }

  Future<void> savePrompt(String name, String content) async {
    // Remove existing with same name to overwrite
    _savedPrompts.removeWhere((p) => p['name'] == name);
    _savedPrompts.add({'name': name, 'content': content});
    await _persistPrompts();
    notifyListeners();
  }

  Future<void> deleteSavedPrompt(String name) async {
    _savedPrompts.removeWhere((p) => p['name'] == name);
    await _persistPrompts();
    notifyListeners();
  }

  void loadSavedPrompt(String name) {
    final prompt = _savedPrompts.firstWhere((p) => p['name'] == name, orElse: () => {});
    if (prompt.containsKey('content')) {
      setSystemPrompt(prompt['content']!);
    }
  }

  Future<void> _persistPrompts() async {
    await _prefs?.setString('saved_prompts', jsonEncode(_savedPrompts));
  }

  Future<void> setMinP(double value) async {
    _minP = value;
    await _prefs?.setDouble('min_p', value);
    notifyListeners();
  }

  Future<void> setTemperature(double value) async {
    _temperature = value;
    await _prefs?.setDouble('temperature', value);
    notifyListeners();
  }

  Future<void> setBubbleOpacity(double value) async {
    _bubbleOpacity = value;
    await _prefs?.setDouble('bubble_opacity', value);
    notifyListeners();
  }

  Future<void> setRepeatPenalty(double value) async {
    _repeatPenalty = value;
    await _prefs?.setDouble('repeat_penalty', value);
    notifyListeners();
  }

  Future<void> setRepeatPenaltyTokens(int value) async {
    _repeatPenaltyTokens = value;
    await _prefs?.setInt('repeat_penalty_tokens', value);
    notifyListeners();
  }

  Future<void> setXtcThreshold(double value) async {
    _xtcThreshold = value;
    await _prefs?.setDouble('xtc_threshold', value);
    notifyListeners();
  }

  Future<void> setXtcProbability(double value) async {
    _xtcProbability = value;
    await _prefs?.setDouble('xtc_probability', value);
    notifyListeners();
  }

  Future<void> setDynamicTempEnabled(bool value) async {
    _dynamicTempEnabled = value;
    await _prefs?.setBool('dynamic_temp_enabled', value);
    notifyListeners();
  }

  Future<void> setDynamicTempRange(double value) async {
    _dynamicTempRange = value;
    await _prefs?.setDouble('dynamic_temp_range', value);
    notifyListeners();
  }

  Future<void> setUseCublas(bool value) async {
    _useCublas = value;
    await _prefs?.setBool('use_cublas', value);
    notifyListeners();
  }

  Future<void> setUseVulkan(bool value) async {
    _useVulkan = value;
    await _prefs?.setBool('use_vulkan', value);
    notifyListeners();
  }

  Future<void> setUseMetal(bool value) async {
    _useMetal = value;
    await _prefs?.setBool('use_metal', value);
    notifyListeners();
  }

  Future<void> setUseRocm(bool value) async {
    _useRocm = value;
    await _prefs?.setBool('use_rocm', value);
    notifyListeners();
  }

  Future<void> setMaxLength(int value) async {
    _maxLength = value;
    await _prefs?.setInt('max_length', value);
    notifyListeners();
  }

  Future<void> setMinLength(int value) async {
    _minLength = value;
    await _prefs?.setInt('min_length', value);
    notifyListeners();
  }

  Future<void> setAutostartBackend(bool value) async {
    _autostartBackend = value;
    await _prefs?.setBool('autostart_backend', value);
    notifyListeners();
  }

  Future<void> setLastUsedModelPath(String? value) async {
    _lastUsedModelPath = value;
    if (value != null) {
      await _prefs?.setString('last_used_model_path', value);
    } else {
      await _prefs?.remove('last_used_model_path');
    }
    notifyListeners();
  }

  Future<void> setGpuLayers(int value) async {
    _gpuLayers = value;
    await _prefs?.setInt('gpu_layers', value);
    notifyListeners();
  }

  Future<void> setContextSize(int value) async {
    _contextSize = value;
    await _prefs?.setInt('context_size', value);
    notifyListeners();
  }

  Future<void> setStopSequences(List<String> value) async {
    _stopSequences = value;
    await _prefs?.setStringList('stop_sequences', value);
    notifyListeners();
  }

  Future<void> addStopSequence(String value) async {
    if (!_stopSequences.contains(value)) {
      _stopSequences.add(value);
      await _prefs?.setStringList('stop_sequences', _stopSequences);
      notifyListeners();
    }
  }

  Future<void> removeStopSequence(String value) async {
    if (_stopSequences.remove(value)) {
      await _prefs?.setStringList('stop_sequences', _stopSequences);
      notifyListeners();
    }
  }

  Future<void> setTextScale(double value) async {
    _textScale = value;
    await _prefs?.setDouble('text_scale', value);
    notifyListeners();
  }

  Future<void> setChatBackground(String value) async {
    _chatBackground = value;
    await _prefs?.setString('chat_background', value);
    notifyListeners();
  }

  Future<void> setDisplayBufferEnabled(bool value) async {
    _displayBufferEnabled = value;
    await _prefs?.setBool('display_buffer_enabled', value);
    notifyListeners();
  }

  Future<void> setTargetDisplayTps(double value) async {
    _targetDisplayTps = value;
    await _prefs?.setDouble('target_display_tps', value);
    notifyListeners();
  }

  Future<void> setBufferDurationSeconds(double value) async {
    _bufferDurationSeconds = value;
    await _prefs?.setDouble('buffer_duration_seconds', value);
    notifyListeners();
  }

  // External API setters
  Future<void> setBackendType(String value) async {
    _backendType = value;
    await _prefs?.setString('backend_type', value);
    notifyListeners();
  }

  Future<void> setRemoteApiKey(String value) async {
    _remoteApiKey = value;
    await _prefs?.setString('remote_api_key', value);
    notifyListeners();
  }

  Future<void> setCallModelName(String value) async {
    _callModelName = value;
    await _prefs?.setString('call_model_name', value);
    notifyListeners();
  }

  Future<void> setCallBufferSentences(int value) async {
    _callBufferSentences = value.clamp(1, 10);
    await _prefs?.setInt('call_buffer_sentences', _callBufferSentences);
    notifyListeners();
  }

  Future<void> setCallSystemPrompt(String value) async {
    _callSystemPrompt = value;
    await _prefs?.setString('call_system_prompt', value);
    notifyListeners();
  }

  Future<void> setRemoteApiUrl(String value) async {
    _remoteApiUrl = value;
    await _prefs?.setString('remote_api_url', value);
    notifyListeners();
  }

  Future<void> setRemoteModelName(String value) async {
    _remoteModelName = value;
    await _prefs?.setString('remote_model_name', value);
    notifyListeners();
  }

  // Reasoning setters
  Future<void> setReasoningEnabled(bool value) async {
    _reasoningEnabled = value;
    await _prefs?.setBool('reasoning_enabled', value);
    notifyListeners();
  }

  Future<void> setReasoningEffort(String value) async {
    _reasoningEffort = value;
    await _prefs?.setString('reasoning_effort', value);
    notifyListeners();
  }

  // TTS setters
  Future<void> setTtsEnabled(bool value) async {
    _ttsEnabled = value;
    await _prefs?.setBool('tts_enabled', value);
    notifyListeners();
  }

  Future<void> setTtsEngine(String value) async {
    _ttsEngine = value;
    await _prefs?.setString('tts_engine', value);
    notifyListeners();
  }

  Future<void> setTtsVoiceModel(String value) async {
    _ttsVoiceModel = value;
    await _prefs?.setString('tts_voice_model', value);
    notifyListeners();
  }

  Future<void> setTtsSpeechRate(double value) async {
    _ttsSpeechRate = value;
    await _prefs?.setDouble('tts_speech_rate', value);
    notifyListeners();
  }

  Future<void> setTtsAutoPlay(bool value) async {
    _ttsAutoPlay = value;
    await _prefs?.setBool('tts_auto_play', value);
    notifyListeners();
  }

  Future<void> setOpenaiTtsApiKey(String value) async {
    _openaiTtsApiKey = value;
    await _prefs?.setString('openai_tts_api_key', value);
    notifyListeners();
  }

  Future<void> setOpenaiTtsModel(String value) async {
    _openaiTtsModel = value;
    await _prefs?.setString('openai_tts_model', value);
    notifyListeners();
  }

  Future<void> setOpenaiTtsBaseUrl(String value) async {
    _openaiTtsBaseUrl = value;
    await _prefs?.setString('openai_tts_base_url', value);
    notifyListeners();
  }

  Future<void> setElevenlabsApiKey(String value) async {
    _elevenlabsApiKey = value;
    await _prefs?.setString('elevenlabs_api_key', value);
    notifyListeners();
  }

  Future<void> setElevenlabsModel(String value) async {
    _elevenlabsModel = value;
    await _prefs?.setString('elevenlabs_model', value);
    notifyListeners();
  }

  Future<void> setElevenlabsStability(double value) async {
    _elevenlabsStability = value.clamp(0.0, 1.0);
    await _prefs?.setDouble('elevenlabs_stability', _elevenlabsStability);
    notifyListeners();
  }

  Future<void> setElevenlabsSimilarity(double value) async {
    _elevenlabsSimilarity = value.clamp(0.0, 1.0);
    await _prefs?.setDouble('elevenlabs_similarity', _elevenlabsSimilarity);
    notifyListeners();
  }

  Future<void> setElevenlabsStyle(double value) async {
    _elevenlabsStyle = value.clamp(0.0, 1.0);
    await _prefs?.setDouble('elevenlabs_style', _elevenlabsStyle);
    notifyListeners();
  }

  Future<void> setTtsNarrateQuotedOnly(bool value) async {
    _ttsNarrateQuotedOnly = value;
    await _prefs?.setBool('tts_narrate_quoted_only', value);
    notifyListeners();
  }

  Future<void> setTtsIgnoreAsterisks(bool value) async {
    _ttsIgnoreAsterisks = value;
    await _prefs?.setBool('tts_ignore_asterisks', value);
    notifyListeners();
  }

  Future<void> setTtsConcurrency(int value) async {
    _ttsConcurrency = value.clamp(1, 16);
    await _prefs?.setInt('tts_concurrency', _ttsConcurrency);
    notifyListeners();
  }

  // STT setters
  Future<void> setSttEnabled(bool value) async {
    _sttEnabled = value;
    await _prefs?.setBool('stt_enabled', value);
    notifyListeners();
  }

  Future<void> setWhisperModel(String value) async {
    _whisperModel = value;
    await _prefs?.setString('whisper_model', value);
    notifyListeners();
  }

  Future<void> setAutoSendTranscription(bool value) async {
    _autoSendTranscription = value;
    await _prefs?.setBool('auto_send_transcription', value);
    notifyListeners();
  }

  Future<void> setSelectedMicId(String? value) async {
    _selectedMicId = value;
    if (value != null) {
      await _prefs?.setString('selected_mic_id', value);
    } else {
      await _prefs?.remove('selected_mic_id');
    }
    notifyListeners();
  }

  Future<void> setDirectorDelay(double value) async {
    _directorDelay = value.clamp(0.5, 60.0);
    await _prefs?.setDouble('director_delay', _directorDelay);
    notifyListeners();
  }

  Future<void> setSortMode(String value) async {
    _sortMode = value;
    await _prefs?.setString('sort_mode', value);
    notifyListeners();
  }

  Future<void> setGridScale(double value) async {
    _gridScale = value.clamp(150.0, 450.0);
    await _prefs?.setDouble('grid_scale', _gridScale);
    notifyListeners();
  }

  Future<void> setCloudSyncEnabled(bool value) async {
    _cloudSyncEnabled = value;
    await _prefs?.setBool('cloud_sync_enabled', value);
    notifyListeners();
  }

  Future<void> setCloudSyncProvider(String value) async {
    _cloudSyncProvider = value;
    await _prefs?.setString('cloud_sync_provider', value);
    notifyListeners();
  }

  Future<void> setCloudSyncUrl(String value) async {
    _cloudSyncUrl = value;
    await _prefs?.setString('cloud_sync_url', value);
    notifyListeners();
  }

  Future<void> setCloudSyncUsername(String value) async {
    _cloudSyncUsername = value;
    await _prefs?.setString('cloud_sync_username', value);
    notifyListeners();
  }

  Future<void> setCloudSyncPassword(String value) async {
    _cloudSyncPassword = value;
    await _prefs?.setString('cloud_sync_password', value);
    notifyListeners();
  }

  Future<void> setCloudSyncLastTime(String value) async {
    _cloudSyncLastTime = value;
    await _prefs?.setString('cloud_sync_last_time', value);
    notifyListeners();
  }

  Future<void> setCustomModelsPath(String? value) async {
    _customModelsPath = value;
    if (value != null && value.isNotEmpty) {
      await _prefs?.setString('custom_models_path', value);
    } else {
      await _prefs?.remove('custom_models_path');
    }
    notifyListeners();
  }

  // Image generation setters
  Future<void> setImageGenEnabled(bool value) async {
    _imageGenEnabled = value;
    await _prefs?.setBool('image_gen_enabled', value);
    notifyListeners();
  }

  Future<void> setImageGenModel(String value) async {
    _imageGenModel = value;
    await _prefs?.setString('image_gen_model', value);
    notifyListeners();
  }

  Future<void> setImageGenSize(String value) async {
    _imageGenSize = value;
    await _prefs?.setString('image_gen_size', value);
    notifyListeners();
  }

  Future<void> setImageGenNegativePrompt(String value) async {
    _imageGenNegativePrompt = value;
    await _prefs?.setString('image_gen_negative_prompt', value);
    notifyListeners();
  }

  Future<void> setImageGenStyle(String value) async {
    _imageGenStyle = value;
    await _prefs?.setString('image_gen_style', value);
    notifyListeners();
  }



  // Web server setters
  Future<void> setWebServerEnabled(bool value) async {
    _webServerEnabled = value;
    await _prefs?.setBool('web_server_enabled', value);
    notifyListeners();
  }

  Future<void> setWebServerPort(int value) async {
    _webServerPort = value;
    await _prefs?.setInt('web_server_port', value);
    notifyListeners();
  }

  Future<void> setWebServerPin(String value) async {
    _webServerPin = value;
    await _prefs?.setString('web_server_pin', value);
    notifyListeners();
  }

  // Summary setters
  Future<void> setSummaryEnabled(bool value) async {
    _summaryEnabled = value;
    await _prefs?.setBool('summary_enabled', value);
    notifyListeners();
  }

  Future<void> setSummaryInterval(int value) async {
    _summaryInterval = value.clamp(3, 50);
    await _prefs?.setInt('summary_interval', _summaryInterval);
    notifyListeners();
  }

  Future<void> setSummaryMaxWords(int value) async {
    _summaryMaxWords = value.clamp(50, 1000);
    await _prefs?.setInt('summary_max_words', _summaryMaxWords);
    notifyListeners();
  }

  Future<void> setSummaryPrompt(String value) async {
    _summaryPrompt = value;
    await _prefs?.setString('summary_prompt', value);
    notifyListeners();
  }

  // Banned phrases setters
  Future<void> setBannedPhrases(List<String> value) async {
    _bannedPhrases = value.where((s) => s.isNotEmpty).toList();
    await _prefs?.setString('banned_phrases', jsonEncode(_bannedPhrases));
    notifyListeners();
  }

  // RAG memory setters
  Future<void> setRagEnabled(bool value) async {
    _ragEnabled = value;
    await _prefs?.setBool('rag_enabled', value);
    notifyListeners();
  }

  Future<void> setRagRetrievalCount(int value) async {
    _ragRetrievalCount = value.clamp(0, 50);
    await _prefs?.setInt('rag_retrieval_count', _ragRetrievalCount);
    notifyListeners();
  }

  Future<void> setRagWindowSize(int value) async {
    _ragWindowSize = value.clamp(2, 15);
    await _prefs?.setInt('rag_window_size', _ragWindowSize);
    notifyListeners();
  }

  Future<void> setRagEmbeddingSource(String value) async {
    _ragEmbeddingSource = value;
    await _prefs?.setString('rag_embedding_source', value);
    notifyListeners();
  }

  Future<void> setRagEmbeddingModel(String value) async {
    _ragEmbeddingModel = value;
    await _prefs?.setString('rag_embedding_model', value);
    notifyListeners();
  }

  // Auto-persona setters
  Future<void> setAutoPersonaEnabled(bool value) async {
    _autoPersonaEnabled = value;
    await _prefs?.setBool('auto_persona_enabled', value);
    notifyListeners();
  }

  Future<void> setAutoPersonaInterval(int value) async {
    _autoPersonaInterval = value.clamp(5, 50);
    await _prefs?.setInt('auto_persona_interval', _autoPersonaInterval);
    notifyListeners();
  }

  // Character evolution setters
  Future<void> setCharacterEvolutionEnabled(bool value) async {
    _characterEvolutionEnabled = value;
    await _prefs?.setBool('character_evolution_enabled', value);
    notifyListeners();
  }

  Future<void> setEvolutionInterval(int value) async {
    _evolutionInterval = value.clamp(10, 50);
    await _prefs?.setInt('evolution_interval', _evolutionInterval);
    notifyListeners();
  }
}
