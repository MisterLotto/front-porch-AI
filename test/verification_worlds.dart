import 'package:flutter_test/flutter_test.dart';
import 'package:kobold_character_card_manager/services/chat_service.dart';
import 'package:kobold_character_card_manager/models/character_card.dart';
import 'package:kobold_character_card_manager/models/world.dart';
import 'package:kobold_character_card_manager/models/lorebook.dart';
import 'package:kobold_character_card_manager/services/world_repository.dart';
import 'package:kobold_character_card_manager/services/kobold_service.dart';
import 'package:kobold_character_card_manager/services/user_persona_service.dart';
import 'package:kobold_character_card_manager/services/storage_service.dart';
import 'dart:io';

class MockKoboldService extends Fake implements KoboldService {
  @override
  Future<String> generate(String prompt, {int maxLength = 80, int minLength = 0, double temp = 0.7, double repPenalty = 1.1, double topP = 0.9, double minP = 0.0, int repPenTokens = 64, double? dynatempRange}) async {
    return "Mock Response";
  }
}

class MockStorageService extends Fake implements StorageService {
  @override
  Directory get chatsDir => Directory('test_chats');
  @override
  Directory get worldsDir => Directory('test_worlds');
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
}

class MockUserPersonaService extends Fake implements UserPersonaService {
  @override
  UserPersona persona = UserPersona(name: 'User', description: 'User Description');
}

void main() {
  test('World Management & Lore Scanning Verification', () async {
    final mockKobold = MockKoboldService();
    final mockPersona = MockUserPersonaService();
    final mockStorage = MockStorageService();
    
    // Clean up
    final worldDir = Directory('test_worlds');
    if (await worldDir.exists()) await worldDir.delete(recursive: true);
    await worldDir.create();
    final chatDir = Directory('test_chats');
    if (await chatDir.exists()) await chatDir.delete(recursive: true);
    await chatDir.create();

    final worldRepo = WorldRepository(mockStorage);
    final chatService = ChatService(mockKobold, mockPersona, mockStorage, worldRepo);

    // 1. Create a World
    final world = World(
      name: 'OldRepublic',
      lorebook: Lorebook(entries: [
        LorebookEntry(key: 'Jedi', content: 'Peacekeepers of the galaxy.', stickyDepth: 2),
      ]),
    );
    await worldRepo.saveWorld(world);

    // 2. Create Character and link World
    final char = CharacterCard(
      name: 'Bastila', 
      worldNames: ['OldRepublic'],
      lorebook: Lorebook(entries: [
        LorebookEntry(key: 'Meditation', content: 'Battle Meditation skill.', stickyDepth: 2),
      ]),
    );

    chatService.setActiveCharacter(char);
    await Future.delayed(const Duration(milliseconds: 100));

    // 3. Trigger Character Lore
    await chatService.sendMessage("I need your Meditation.");
    expect(char.lorebook!.entries[0].isTriggered, true);
    
    // 4. Trigger World Lore
    await chatService.sendMessage("Tell me about the Jedi.");
    final loadedWorld = worldRepo.worlds.firstWhere((w) => w.name == 'OldRepublic');
    expect(loadedWorld.lorebook.entries[0].isTriggered, true);
    expect(loadedWorld.lorebook.entries[0].remainingDepth, 1); // User trig (2) -> Bot decr (1)

    // 5. Verify Depth Decrement
    await chatService.sendMessage("Next message"); // User decr (0) -> isTrig false
    expect(loadedWorld.lorebook.entries[0].isTriggered, false);

    // Clean up
    await worldDir.delete(recursive: true);
    await chatDir.delete(recursive: true);
  });
}
