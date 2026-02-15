import 'package:kobold_character_card_manager/models/lorebook.dart';

class World {
  String name;
  String description;
  Lorebook lorebook;

  World({
    required this.name,
    this.description = '',
    required this.lorebook,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'lorebook': lorebook.toJson(),
    };
  }

  factory World.fromJson(Map<String, dynamic> json) {
    return World(
      name: json['name'] ?? 'New World',
      description: json['description'] ?? '',
      lorebook: json['lorebook'] != null 
          ? Lorebook.fromJson(json['lorebook'])
          : Lorebook(entries: []),
    );
  }
}
