import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:front_porch_ai/database/database.dart';

class UserPersona {
  final String id;
  final String title;
  final String name;
  final String description;
  final String persona;
  final String? avatarPath;

  /// Returns title if set, otherwise name — used for display in persona list
  String get displayLabel => title.isNotEmpty ? title : name;

  UserPersona({
    required this.id,
    this.title = '',
    this.name = 'User',
    this.description = '',
    this.persona = '',
    this.avatarPath,
  });

  UserPersona copyWith({
    String? title,
    String? name,
    String? description,
    String? persona,
    String? avatarPath,
  }) {
    return UserPersona(
      id: this.id,
      title: title ?? this.title,
      name: name ?? this.name,
      description: description ?? this.description,
      persona: persona ?? this.persona,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'name': name,
      'description': description,
      'persona': persona,
      'avatar_path': avatarPath,
    };
  }

  factory UserPersona.fromJson(Map<String, dynamic> json) {
    return UserPersona(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      name: json['name'] ?? 'User',
      description: json['description'] ?? '',
      persona: json['persona'] ?? '',
      avatarPath: json['avatar_path'],
    );
  }
}

class UserPersonaService extends ChangeNotifier {
  AppDatabase _db;
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

  UserPersonaService(this._db) {
    _loadPersonas();
  }

  /// Update the database reference (e.g. after cloud sync replaces the DB file).
  void updateDatabase(AppDatabase db) { _db = db; }

  Future<void> _loadPersonas() async {
    try {
      final dbPersonas = await _db.getAllPersonas();

      if (dbPersonas.isEmpty) {
        // Create default persona
        final defaultId = DateTime.now().millisecondsSinceEpoch.toString();
        await _db.insertPersona(PersonasCompanion.insert(
          id: defaultId,
          name: const Value('User'),
          isActive: const Value(true),
        ));
        _personas = [UserPersona(id: defaultId, name: 'User')];
        _activePersonaId = defaultId;
      } else {
        _personas = dbPersonas.map((p) => UserPersona(
          id: p.id,
          title: p.title,
          name: p.name,
          description: p.description,
          persona: p.persona,
          avatarPath: p.avatarPath,
        )).toList();

        final active = dbPersonas.where((p) => p.isActive).firstOrNull;
        _activePersonaId = active?.id ?? _personas.first.id;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading personas from DB: $e');
    }
  }

  Future<void> createPersona(String title, String name, String description, String persona, String? avatarPath) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    await _db.insertPersona(PersonasCompanion.insert(
      id: id,
      title: Value(title),
      name: Value(name),
      description: Value(description),
      persona: Value(persona),
      avatarPath: Value(avatarPath),
      isActive: const Value(true),
    ));
    
    // Deactivate others
    await _db.setActivePersona(id);

    final newPersona = UserPersona(
      id: id,
      title: title,
      name: name,
      description: description,
      persona: persona,
      avatarPath: avatarPath,
    );
    _personas.add(newPersona);
    _activePersonaId = id;
    notifyListeners();
  }

  Future<void> updatePersona(UserPersona updatedPersona) async {
    final index = _personas.indexWhere((p) => p.id == updatedPersona.id);
    if (index != -1) {
      _personas[index] = updatedPersona;
      
      await _db.updatePersona(PersonasCompanion(
        id: Value(updatedPersona.id),
        title: Value(updatedPersona.title),
        name: Value(updatedPersona.name),
        description: Value(updatedPersona.description),
        persona: Value(updatedPersona.persona),
        avatarPath: Value(updatedPersona.avatarPath),
        isActive: Value(updatedPersona.id == _activePersonaId),
      ));
      
      notifyListeners();
    }
  }

  Future<void> deletePersona(String id) async {
    if (_personas.length <= 1) return; // Prevent deleting the last one

    _personas.removeWhere((p) => p.id == id);
    await _db.deletePersonaById(id);
    
    // If we deleted the active one, switch to the first one
    if (_activePersonaId == id) {
      _activePersonaId = _personas.first.id;
      await _db.setActivePersona(_activePersonaId);
    }
    
    notifyListeners();
  }

  Future<void> setActivePersona(String id) async {
    if (_personas.any((p) => p.id == id)) {
      _activePersonaId = id;
      await _db.setActivePersona(id);
      notifyListeners();
    }
  }

  // ── Cloud Sync helpers ──────────────────────────────────────────────

  /// Export all personas + active ID to a JSON file for cloud sync.
  Future<void> exportToFile(String filePath) async {
    final data = {
      'active_persona_id': _activePersonaId,
      'personas': _personas.map((p) => p.toJson()).toList(),
    };
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  /// Import personas from a JSON file (downloaded from cloud).
  Future<void> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return;
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    final list = (data['personas'] as List?)?.map((e) => UserPersona.fromJson(e)).toList();
    if (list != null && list.isNotEmpty) {
      // Clear existing personas from DB and re-import
      for (final p in _personas) {
        await _db.deletePersonaById(p.id);
      }
      _personas = list;
      _activePersonaId = data['active_persona_id'] ?? _personas.first.id;
      
      for (final p in _personas) {
        await _db.insertPersona(PersonasCompanion.insert(
          id: p.id,
          title: Value(p.title),
          name: Value(p.name),
          description: Value(p.description),
          persona: Value(p.persona),
          avatarPath: Value(p.avatarPath),
          isActive: Value(p.id == _activePersonaId),
        ));
      }
      notifyListeners();
    }
  }

  /// Reload personas from DB (e.g. after cloud sync import).
  Future<void> reload() async {
    await _loadPersonas();
  }
}
