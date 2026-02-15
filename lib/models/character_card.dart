import 'package:kobold_character_card_manager/models/lorebook.dart';

class CharacterCard {
  String name;
  String description;
  String personality;
  String scenario;
  String firstMessage;
  String? imagePath;
  Lorebook? lorebook;
  List<String> worldNames;

  CharacterCard({
    required this.name,
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMessage = '',
    this.imagePath,
    this.lorebook,
    this.worldNames = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'personality': personality,
      'scenario': scenario,
      'first_mes': firstMessage,
      'character_book': lorebook?.toJson(),
      'world_names': worldNames,
    };
  }

  String get formattedDescription {
    if (description.isEmpty) return '';
    // Case-insensitive replacement of {{char}} with name
    return description.replaceAll(RegExp(r'\{\{char\}\}', caseSensitive: false), name);
  }

  // V2 spec fields can be added here later (e.g., character_book, etc.)
}
