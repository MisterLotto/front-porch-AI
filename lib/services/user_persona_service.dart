import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPersona {
  final String id;
  final String name;
  final String description;
  final String persona;
  final String? avatarPath;

  UserPersona({
    required this.id,
    this.name = 'User',
    this.description = '',
    this.persona = '',
    this.avatarPath,
  });

  UserPersona copyWith({
    String? name,
    String? description,
    String? persona,
    String? avatarPath,
  }) {
    return UserPersona(
      id: this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      persona: persona ?? this.persona,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'persona': persona,
      'avatar_path': avatarPath,
    };
  }

  factory UserPersona.fromJson(Map<String, dynamic> json) {
    return UserPersona(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? 'User',
      description: json['description'] ?? '',
      persona: json['persona'] ?? '',
      avatarPath: json['avatar_path'],
    );
  }
}

class UserPersonaService extends ChangeNotifier {
  List<UserPersona> _personas = [];
  String _activePersonaId = '';

  List<UserPersona> get personas => List.unmodifiable(_personas);
  
  UserPersona get persona {
    if (_personas.isEmpty) {
      return UserPersona(id: 'default', name: 'User');
    }
    return _personas.firstWhere(
      (p) => p.id == _activePersonaId, 
      orElse: () => _personas.first
    );
  }

  UserPersonaService() {
    _loadPersonas();
  }

  Future<void> _loadPersonas() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load active ID
    _activePersonaId = prefs.getString('active_persona_id') ?? '';

    // Load list
    final List<String>? jsonList = prefs.getStringList('user_personas');
    
    if (jsonList != null) {
      _personas = jsonList.map((str) => UserPersona.fromJson(jsonDecode(str))).toList();
    }

    // Migration or first run: if empty, try to load old legacy single persona or create default
    if (_personas.isEmpty) {
      final oldName = prefs.getString('user_name');
      if (oldName != null) {
        // Migrate legacy
        final legacyPersona = UserPersona(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: oldName,
          description: prefs.getString('user_description') ?? '',
          persona: prefs.getString('user_persona') ?? '',
        );
        _personas.add(legacyPersona);
        _activePersonaId = legacyPersona.id;
      } else {
        // Default
        final defaultPersona = UserPersona(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'User',
        );
        _personas.add(defaultPersona);
        _activePersonaId = defaultPersona.id;
      }
      await _savePersonas();
    }

    notifyListeners();
  }

  Future<void> _savePersonas() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _personas.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('user_personas', jsonList);
    await prefs.setString('active_persona_id', _activePersonaId);
    notifyListeners();
  }

  Future<void> createPersona(String name, String description, String persona, String? avatarPath) async {
    final newPersona = UserPersona(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      persona: persona,
      avatarPath: avatarPath,
    );
    _personas.add(newPersona);
    _activePersonaId = newPersona.id; // Auto switch to new? Maybe.
    await _savePersonas();
  }

  Future<void> updatePersona(UserPersona updatedPersona) async {
    final index = _personas.indexWhere((p) => p.id == updatedPersona.id);
    if (index != -1) {
      _personas[index] = updatedPersona;
      await _savePersonas();
    }
  }

  Future<void> deletePersona(String id) async {
    if (_personas.length <= 1) return; // Prevent deleting the last one

    _personas.removeWhere((p) => p.id == id);
    
    // If we deleted the active one, switch to the first one
    if (_activePersonaId == id) {
      _activePersonaId = _personas.first.id;
    }
    
    await _savePersonas();
  }

  Future<void> setActivePersona(String id) async {
    if (_personas.any((p) => p.id == id)) {
      _activePersonaId = id;
      await _savePersonas();
    }
  }
}
