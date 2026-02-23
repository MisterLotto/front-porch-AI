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

  // Settings
  static const String defaultSystemPrompt = "You are an immersive roleplay partner. Embody {{char}} completely — personality, appearance, thought processes, emotions, behaviors, and speech patterns. You may also roleplay as any side characters introduced.\n\nEngage with {{user}} by depicting {{char}}'s actions, emotions, and dialogue. Develop the plot slowly and organically while driving the scenario forward. Never write {{user}}'s speech, actions, or decisions — allow them full control of their character.\n\nWrite in a vivid, creative, varied, and descriptive style. Use rich sensory detail for the environment, people, and events. Make each reply unique and end with an action or dialogue to keep momentum.\n\nMaintain consistency with established details — clothing, time of day, location, and prior events. Stay in character at all times.";
  String _systemPrompt = defaultSystemPrompt;
  double _minP = 0.1;
  double _temperature = 0.7;
  double _repeatPenalty = 1.1;
  int _repeatPenaltyTokens = 64;
  bool _dynamicTempEnabled = false;
  double _dynamicTempRange = 0.7;
  bool? _useCublas;
  bool? _useVulkan;
  bool? _useMetal;
  int _maxLength = 200;
  int _minLength = 0;
  bool _autostartBackend = true;
  String? _lastUsedModelPath;
  int _gpuLayers = 0;
  int _contextSize = 8192;
  List<String> _stopSequences = ["\nUser:", "\n###", "\nScenario:", "<END>", "\nSystem:", "\n(Note:", "\n[Note:", "\n{Note:"];
  double _textScale = 1.0;
  List<Map<String, String>> _savedPrompts = [];
  bool _displayBufferEnabled = true;
  double _targetDisplayTps = 6.0; // ~250 WPM average human reading speed

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
  String _ttsEngine = 'kokoro'; // 'kokoro', 'openai', 'piper'
  String _ttsVoiceModel = ''; // voice key, e.g. 'af_heart' or 'en_US-lessac-medium'
  double _ttsSpeechRate = 1.0;
  bool _ttsAutoPlay = false;
  String _openaiTtsApiKey = '';
  String _openaiTtsModel = 'tts-1'; // 'tts-1' or 'tts-1-hd'
  int _ttsConcurrency = Platform.numberOfProcessors.clamp(1, 16);

  // Sort preference
  String _sortMode = 'name'; // 'name', 'recent', 'importDate'

  // Grid scale preference
  double _gridScale = 300.0; // maxCrossAxisExtent in pixels (150-450)


  // Getters
  String get systemPrompt => _systemPrompt;
  double get minP => _minP;
  double get temperature => _temperature;
  double get repeatPenalty => _repeatPenalty;
  int get repeatPenaltyTokens => _repeatPenaltyTokens;
  bool get dynamicTempEnabled => _dynamicTempEnabled;
  double get dynamicTempRange => _dynamicTempRange;
  bool? get useCublas => _useCublas;
  bool? get useVulkan => _useVulkan;
  bool? get useMetal => _useMetal;
  int get maxLength => _maxLength;
  int get minLength => _minLength;
  bool get autostartBackend => _autostartBackend;
  String? get lastUsedModelPath => _lastUsedModelPath;
  int get gpuLayers => _gpuLayers;
  int get contextSize => _contextSize;
  List<String> get stopSequences => List.unmodifiable(_stopSequences);
  double get textScale => _textScale;
  List<Map<String, String>> get savedPrompts => List.unmodifiable(_savedPrompts);
  bool get displayBufferEnabled => _displayBufferEnabled;
  double get targetDisplayTps => _targetDisplayTps;
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
  int get ttsConcurrency => _ttsConcurrency;
  String get sortMode => _sortMode;
  double get gridScale => _gridScale;

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
    
    // Load settings
    _systemPrompt = _prefs?.getString('system_prompt') ?? _systemPrompt;
    _minP = _prefs?.getDouble('min_p') ?? _minP;
    _temperature = _prefs?.getDouble('temperature') ?? _temperature;
    _repeatPenalty = _prefs?.getDouble('repeat_penalty') ?? _repeatPenalty;
    _repeatPenaltyTokens = _prefs?.getInt('repeat_penalty_tokens') ?? _repeatPenaltyTokens;
    _dynamicTempEnabled = _prefs?.getBool('dynamic_temp_enabled') ?? _dynamicTempEnabled;
    _dynamicTempEnabled = _prefs?.getBool('dynamic_temp_enabled') ?? _dynamicTempEnabled;
    _dynamicTempRange = _prefs?.getDouble('dynamic_temp_range') ?? _dynamicTempRange;
    _useCublas = _prefs?.getBool('use_cublas');
    _useVulkan = _prefs?.getBool('use_vulkan');
    _useMetal = _prefs?.getBool('use_metal');
    _maxLength = _prefs?.getInt('max_length') ?? _maxLength;
    _minLength = _prefs?.getInt('min_length') ?? _minLength;
    _autostartBackend = _prefs?.getBool('autostart_backend') ?? _autostartBackend;
    _lastUsedModelPath = _prefs?.getString('last_used_model_path');
    _gpuLayers = _prefs?.getInt('gpu_layers') ?? _gpuLayers;
    _contextSize = _prefs?.getInt('context_size') ?? _contextSize;
    _stopSequences = _prefs?.getStringList('stop_sequences') ?? _stopSequences;
    _textScale = _prefs?.getDouble('text_scale') ?? 1.0;
    _displayBufferEnabled = _prefs?.getBool('display_buffer_enabled') ?? true;
    _targetDisplayTps = _prefs?.getDouble('target_display_tps') ?? 30.0;

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
    _sortMode = _prefs?.getString('sort_mode') ?? 'name';
    _gridScale = _prefs?.getDouble('grid_scale') ?? 300.0;

    // Custom models path
    _customModelsPath = _prefs?.getString('custom_models_path');

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

  Future<void> setRootPath(String pathStr) async {
    _rootPath = pathStr;
    _binDir = Directory(path.join(_rootPath!, 'koboldcpp_bin'));
    await _prefs?.setString('root_path', pathStr);
    notifyListeners();
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

  Future<void> setTtsConcurrency(int value) async {
    _ttsConcurrency = value.clamp(1, 16);
    await _prefs?.setInt('tts_concurrency', _ttsConcurrency);
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

  Future<void> setCustomModelsPath(String? value) async {
    _customModelsPath = value;
    if (value != null && value.isNotEmpty) {
      await _prefs?.setString('custom_models_path', value);
    } else {
      await _prefs?.remove('custom_models_path');
    }
    notifyListeners();
  }
}
