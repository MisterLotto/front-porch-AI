import 'package:kobold_character_card_manager/models/lorebook.dart';

class CharacterCard {
  String name;
  String description;
  String personality;
  String scenario;
  String firstMessage;
  List<String> alternateGreetings;
  List<String> tags;
  String? imagePath;
  String? folderId;
  Lorebook? lorebook;
  List<String> worldNames;

  CharacterCard({
    required this.name,
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMessage = '',
    this.alternateGreetings = const [],
    this.tags = const [],
    this.imagePath,
    this.folderId,
    this.lorebook,
    this.worldNames = const [],
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
      'alternate_greetings': alternateGreetings,
      'tags': tags,
      'character_book': lorebook?.toJson(),
      'world_names': worldNames,
    };
  }

  String get formattedDescription {
    if (description.isEmpty) return '';
    // Replace {{char}} and {{user}} placeholders with actual name
    return description
        .replaceAll('{{char}}', name)
        .replaceAll('{{user}}', 'You');
  }

  // V2 spec fields can be added here later (e.g., character_book, etc.)
}
