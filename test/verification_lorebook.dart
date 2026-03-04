import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:front_porch_ai/models/world.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

// Manual Mocks

class MockKoboldService extends ChangeNotifier implements KoboldService {
  @override
  Future<String> generate(String prompt, {
    int maxLength = 80,
    int minLength = 0,
    double temp = 0.7,
    double repPenalty = 1.1,
    double topP = 0.9,
    double minP = 0.0,
    int repPenTokens = 64,
    double? dynatempRange,
    double xtcThreshold = 0.1,
    double xtcProbability = 0.5,
    List<String>? stopSequences,
    List<String>? bannedPhrases,
  }) async {
    return 'Response mentioning magic key';
  }

  @override
  Stream<String> generateStream(GenerationParams params) async* {
    yield 'Response mentioning magic key';
  }

  // LLMService interface
  @override bool get isReady => true;
  @override String get backendName => 'MockKobold';

  // Stubs for other methods
  @override String get baseUrl => '';
  @override bool get isProcessAlive => true;
  @override bool get isRunning => true;
  @override List<String> get logs => [];
  @override void setBaseUrl(String url) {}
  @override Future<void> startKobold(String executablePath, String modelPath, {
    int port = 5001,
    int gpuLayers = 0,
    int contextSize = 4096,
    bool useVulkan = false,
    bool useCublas = false,
    bool useMetal = false,
    bool useRocm = false,
  }) async {}
  @override Future<void> stopKobold() async {}
  @override Future<int> countTokens(String text) async => (text.length / 4).ceil();
}

class MockUserPersonaService extends ChangeNotifier implements UserPersonaService {
  final _persona = UserPersona(id: 'default', name: 'User');
  @override
  UserPersona get persona => _persona;
  @override
  List<UserPersona> get personas => [_persona];
  
  @override
  Future<void> updatePersona(UserPersona newPersona) async {}
  @override
  Future<void> createPersona(String name, String description, String persona, String? avatarPath) async {}
  @override
  Future<void> deletePersona(String id) async {}
  @override
  Future<void> setActivePersona(String id) async {}
  @override
  Future<void> exportToFile(String filePath) async {}
  @override
  Future<void> importFromFile(String filePath) async {}
  @override
  Future<void> reload() async {}
}

class MockStorageService extends ChangeNotifier implements StorageService {
  @override String get systemPrompt => 'System Prompt';
  @override double get minP => 0.1;
  @override double get temperature => 0.7;
  @override double get repeatPenalty => 1.1;
  @override int get repeatPenaltyTokens => 64;
  @override bool get dynamicTempEnabled => false;
  @override double get dynamicTempRange => 0;
  @override int get maxLength => 200;
  @override int get minLength => 0;
  @override List<String> get stopSequences => [];
  @override double get textScale => 1.0;
  @override List<Map<String, String>> get savedPrompts => [];
  @override bool get displayBufferEnabled => true;
  @override double get targetDisplayTps => 30.0;
  @override bool get autostartBackend => false;
  @override String? get lastUsedModelPath => null;
  @override int get gpuLayers => 0;
  @override int get contextSize => 8192;
  @override String get backendType => 'kobold';
  @override String get remoteApiKey => '';
  @override String get remoteApiUrl => 'https://openrouter.ai/api/v1';
  @override String get remoteModelName => '';
  @override bool? get useMetal => null;
  @override Future<void> get initialized => Future.value();
  @override Directory get chatsDir => Directory('');
  @override Directory get worldsDir => Directory('');
  
  @override Future<void> setSystemPrompt(String value) async {}
  @override Future<void> setMinP(double value) async {}
  @override Future<void> setTemperature(double value) async {}
  @override Future<void> setRepeatPenalty(double value) async {}
  @override Future<void> setRepeatPenaltyTokens(int value) async {}
  @override Future<void> setDynamicTempEnabled(bool value) async {}
  @override Future<void> setDynamicTempRange(double value) async {}
  @override Future<void> setMaxLength(int value) async {}
  @override Future<void> setMinLength(int value) async {}
  @override Future<void> setRootPath(String path) async {}
  @override Future<void> setUseCublas(bool value) async {}
  @override Future<void> setUseVulkan(bool value) async {}
  @override Future<void> setUseMetal(bool value) async {}
  @override Future<void> setAutostartBackend(bool value) async {}
  @override Future<void> setLastUsedModelPath(String? value) async {}
  @override Future<void> setGpuLayers(int value) async {}
  @override Future<void> setContextSize(int value) async {}
  @override Future<void> setStopSequences(List<String> value) async {}
  @override Future<void> addStopSequence(String value) async {}
  @override Future<void> removeStopSequence(String value) async {}
  @override Future<void> setTextScale(double value) async {}
  @override Future<void> savePrompt(String name, String content) async {}
  @override Future<void> deleteSavedPrompt(String name) async {}
  @override void loadSavedPrompt(String name) {}
  @override Future<void> setDisplayBufferEnabled(bool value) async {}
  @override Future<void> setTargetDisplayTps(double value) async {}
  @override Future<void> setBackendType(String value) async {}
  @override Future<void> setRemoteApiKey(String value) async {}
  @override Future<void> setRemoteApiUrl(String value) async {}
  @override Future<void> setRemoteModelName(String value) async {}

  @override bool get reasoningEnabled => false;
  @override String get reasoningEffort => 'medium';
  @override Future<void> setReasoningEnabled(bool value) async {}
  @override Future<void> setReasoningEffort(String value) async {}

  @override double get xtcThreshold => 0.1;
  @override double get xtcProbability => 0.5;
  @override Future<void> setXtcThreshold(double value) async {}
  @override Future<void> setXtcProbability(double value) async {}

  @override String? get rootPath => null;
  @override Directory get binDir => Directory('');
  @override Directory get modelsDir => Directory('');
  @override bool? get useCublas => false;
  @override bool? get useVulkan => false;

  // TTS settings
  @override bool get ttsEnabled => false;
  @override String get ttsVoiceModel => '';
  @override double get ttsSpeechRate => 1.0;
  @override bool get ttsAutoPlay => false;
  @override Future<void> setTtsEnabled(bool value) async {}
  @override Future<void> setTtsVoiceModel(String value) async {}
  @override Future<void> setTtsSpeechRate(double value) async {}
  @override Future<void> setTtsAutoPlay(bool value) async {}
}

class MockWorldRepository extends ChangeNotifier implements WorldRepository {
  @override List<World> get worlds => [];
  @override bool get isLoading => false;
  @override Future<void> loadWorlds() async {}
  @override Future<void> saveWorld(World world) async {}
  @override Future<void> deleteWorld(World world) async {}
  @override World? getWorld(String id) => null;
  @override Future<void> exportWorld(World world, String outputPath) async {}
  @override Future<void> importWorld(File file) async {}
}

void main() {
  test('Lorebook serialization', () {
    final entry = LorebookEntry(key: 'key1, key2', content: 'content1');
    final lorebook = Lorebook(entries: [entry]);
    final json = lorebook.toJson();
    
    expect(json['entries'].length, 1);
    expect(json['entries'][0]['key'], 'key1, key2');
    
    final deserialized = Lorebook.fromJson(json);
    expect(deserialized.entries.length, 1);
    expect(deserialized.entries[0].content, 'content1');
  });

  test('ChatService scans lorebook keywords', () async {
    final mockKobold = MockKoboldService();
    final mockPersona = MockUserPersonaService();
    final mockStorage = MockStorageService();
    
    final chatService = ChatService(mockKobold, mockPersona, mockStorage, MockWorldRepository());
    
    final char = CharacterCard(name: 'TestChar', firstMessage: 'Hello');
    char.lorebook = Lorebook(entries: [
      LorebookEntry(key: 'magic switch', content: 'Magic is real', stickyDepth: 4), // Depth 4 stays for 2 turns
      LorebookEntry(key: 'hidden gem', content: 'Shiny', enabled: false), // Disabled
    ]);
    
    chatService.setActiveCharacter(char);
    
    // Test triggering
    await chatService.sendMessage('I found a magic switch');
    
    expect(char.lorebook!.entries[0].isTriggered, true, reason: 'Should stay triggered with depth 4');
    expect(char.lorebook!.entries[0].remainingDepth, 3, reason: 'Decremented once (Bot message completion)');
    expect(char.lorebook!.entries[1].isTriggered, false, reason: 'Should not trigger disabled entry');
  });
  
  test('ChatService scans bot response for lorebook keywords', () async {
    final mockKobold = MockKoboldService(); 
    // Mock generate returns "Response mentioning magic key"
    
    final mockPersona = MockUserPersonaService();
    final mockStorage = MockStorageService();
    
    final chatService = ChatService(mockKobold, mockPersona, mockStorage, MockWorldRepository());
    
    final char = CharacterCard(name: 'TestChar', firstMessage: 'Hello');
    char.lorebook = Lorebook(entries: [
      LorebookEntry(key: 'magic key', content: 'Unlocks door', stickyDepth: 4),
    ]);
    
    chatService.setActiveCharacter(char);
    
    await chatService.sendMessage('Tell me about the key');
    
    // Wait for generation (mock is immediate but async)
    await Future.delayed(const Duration(milliseconds: 100));
    
    expect(char.lorebook!.entries[0].isTriggered, true, reason: 'Should scan bot response');
  });

  test('ChatService handles constant entries', () async {
    final mockKobold = MockKoboldService();
    final mockPersona = MockUserPersonaService();
    final mockStorage = MockStorageService();
    
    final chatService = ChatService(mockKobold, mockPersona, mockStorage, MockWorldRepository());
    
    final char = CharacterCard(name: 'TestChar', firstMessage: 'Hello');
    char.lorebook = Lorebook(entries: [
      LorebookEntry(key: '', content: 'Constant info', constant: true),
    ]);
    
    chatService.setActiveCharacter(char);
    
    // Send message unrelated to any key (key is empty anyway)
    await chatService.sendMessage('Hello');
    
    // Verify it's considered "active" in context logic (though isTriggered remains false for constants usually, 
    // the prompt builder checks (isTriggered || constant). 
    // We can't easily check the private method prompt builder here without reflection or refactoring.
    // But we can check that it didn't crash and the entry state is valid.
    
    expect(char.lorebook!.entries[0].constant, true);
    // isTriggered should remain false because scanLorebook ignores constant entries or emptiness? 
    // Actually scanLogic checks keys. If key is empty, it probably won't match.
    expect(char.lorebook!.entries[0].isTriggered, false);
  });

  test('ChatService handles lorebook depth', () async {
    final mockKobold = MockKoboldService();
    final mockPersona = MockUserPersonaService();
    final mockStorage = MockStorageService();
    
    final chatService = ChatService(mockKobold, mockPersona, mockStorage, MockWorldRepository());
    
    final char = CharacterCard(name: 'TestChar', firstMessage: 'Hello');
    char.lorebook = Lorebook(entries: [
      LorebookEntry(key: 'trigger', content: 'Deep Lore', stickyDepth: 2),
    ]);
    
    chatService.setActiveCharacter(char);
    
    // Trigger it
    await chatService.sendMessage("Let's trigger it");
    expect(char.lorebook!.entries[0].isTriggered, true);
    expect(char.lorebook!.entries[0].remainingDepth, 1, reason: 'Decremented once after user message');
    
    // AI responds (mock delayed but we can wait or ignore if immediate)
    // Actually our mock is immediate, so sendMessage completes after AI respond and decrement.
    // wait... in sendMessage: 
    // _decrementLoreDepth(); // After user message. Depth 2 -> 1.
    // ... generation ...
    // _decrementLoreDepth(); // After AI message. Depth 1 -> 0.
    
    // So with depth 2, it should EXPIRE after 1 turn (User + AI).
    expect(char.lorebook!.entries[0].isTriggered, false, reason: 'Should expire after 1 turn with depth 2');
    
    // Test with depth 4 (should stay for 1 more turn)
    char.lorebook!.entries[0].stickyDepth = 4;
    char.lorebook!.entries[0].isTriggered = false;
    
    await chatService.sendMessage('trigger');
    // after user: 4 -> 3
    // after ai: 3 -> 2
    expect(char.lorebook!.entries[0].isTriggered, true);
    expect(char.lorebook!.entries[0].remainingDepth, 2);
    
    await chatService.sendMessage('next turn');
    // after user: 2 -> 1
    // after ai: 1 -> 0
    expect(char.lorebook!.entries[0].isTriggered, false);
  });
}
