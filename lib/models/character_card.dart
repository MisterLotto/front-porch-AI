import 'package:front_porch_ai/models/lorebook.dart';

class CharacterCard {
  String name;
  String description;
  String personality;
  String scenario;
  String firstMessage;
  String mesExample;
  String systemPrompt;
  String postHistoryInstructions;
  List<String> alternateGreetings;
  List<String> tags;
  String? imagePath;
  String? folderId;
  Lorebook? lorebook;
  List<String> worldNames;
  String? ttsVoice; // Piper voice key for per-character TTS
  int? dbId; // SQLite row ID (runtime only, not serialized)

  CharacterCard({
    required this.name,
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMessage = '',
    this.mesExample = '',
    this.systemPrompt = '',
    this.postHistoryInstructions = '',
    this.alternateGreetings = const [],
    this.tags = const [],
    this.imagePath,
    this.folderId,
    this.lorebook,
    this.worldNames = const [],
    this.ttsVoice,
  });

  /// All greetings: primary first message + alternates
  List<String> get allGreetings {
    final greetings = <String>[firstMessage];
    greetings.addAll(alternateGreetings);
    return greetings.where((g) => g.isNotEmpty).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'personality': personality,
      'scenario': scenario,
      'first_mes': firstMessage,
      'mes_example': mesExample,
      'system_prompt': systemPrompt,
      'post_history_instructions': postHistoryInstructions,
      'alternate_greetings': alternateGreetings,
      'tags': tags,
      'character_book': lorebook?.toJson(),
      'world_names': worldNames,
      if (ttsVoice != null) 'tts_voice': ttsVoice,
    };
  }

  String replacePlaceholders(String text, {String userName = 'You'}) {
    return text
        .replaceAll(RegExp(r'\{\{char\}\}', caseSensitive: false), name)
        .replaceAll(RegExp(r'<char>', caseSensitive: false), name)
        .replaceAll(RegExp(r'\{\{user\}\}', caseSensitive: false), userName)
        .replaceAll(RegExp(r'<user>', caseSensitive: false), userName);
  }

  String get formattedDescription => replacePlaceholders(description);

  // V2 spec fields can be added here later (e.g., character_book, etc.)
}
