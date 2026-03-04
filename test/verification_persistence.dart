import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'dart:io';
import 'dart:convert';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:front_porch_ai/models/world.dart';

class MockKoboldService extends Fake implements KoboldService {
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
    return "Mock Response";
  }
}

class MockStorageService extends Fake implements StorageService {
  @override
  Directory get chatsDir => Directory('test_chats');
  @override
  String get systemPrompt => "System Prompt";
  @override
  int get maxLength => 100;
  @override
  int get minLength => 0;
  @override
  double get minP => 0.1;
  @override
  double get temperature => 0.7;
  @override
  double get repeatPenalty => 1.1;
  @override
  int get repeatPenaltyTokens => 64;
  @override
  bool get dynamicTempEnabled => false;
  @override
  double get dynamicTempRange => 0.7;
  @override
  double get xtcThreshold => 0.1;
  @override
  double get xtcProbability => 0.5;
}

class MockUserPersonaService extends Fake implements UserPersonaService {
  @override
  UserPersona persona = UserPersona(id: 'default', name: 'User', description: 'User Description');
}

class MockWorldRepository extends Fake implements WorldRepository {
  @override
  List<World> get worlds => [];
  @override
  Future<void> loadWorlds() async {}
}

void main() {
  test('Chat persistence verification', () async {
    final mockKobold = MockKoboldService();
    final mockPersona = MockUserPersonaService();
    final mockStorage = MockStorageService();
    
    // Clean up test dir
    final testDir = Directory('test_chats');
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
    await testDir.create();

    final chatService = ChatService(mockKobold, mockPersona, mockStorage, MockWorldRepository());
    final char = CharacterCard(name: 'TestChar', firstMessage: 'Hello {{user}}', imagePath: 'test_char.png');
    
    // 1. Set active character (should create initial session)
    chatService.setActiveCharacter(char);
    // Wait for async startup
    await Future.delayed(const Duration(milliseconds: 100));
    expect(chatService.messages.length, 1);
    expect(chatService.messages[0].text, 'Hello User');
    
    final charDir = Directory('test_chats/test_char');
    expect(await charDir.exists(), true);
    
    final sessionFiles = await charDir.list().length;
    expect(sessionFiles, 1);

    // 2. Send message
    await chatService.sendMessage("How are you?");
    expect(chatService.messages.length, 3); // User + Typing (briefly) + AI
    
    // Wait for typewriter? Our mock returns immediately.
    // In actual ChatService, typewriter loops and adds/removes messages.
    // In our test, it might be 3 if it finished.
    
    // Check file content
    final files = await charDir.list().toList();
    final content = await (files.first as File).readAsString();
    final List<dynamic> jsonList = jsonDecode(content);
    expect(jsonList.length, 3);
    expect(jsonList[1]['text'], 'How are you?');

    // 3. New Chat
    await chatService.startNewChat();
    expect(chatService.messages.length, 1);
    final sessionFilesAfterNew = await charDir.list().length;
    expect(sessionFilesAfterNew, 2);

    // 4. Reload
    final chatService2 = ChatService(mockKobold, mockPersona, mockStorage, MockWorldRepository());
    chatService2.setActiveCharacter(char);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(chatService2.messages.length, 1, reason: "Should load latest session (which is the new empty one)");
    
    // Clean up
    await testDir.delete(recursive: true);
  });
}
