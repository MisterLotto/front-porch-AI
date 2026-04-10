// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/embedding_service.dart';

class UserPersona {
  final String id;
  final String title;
  final String name;
  final String description;
  final String persona;
  final List<String> learnedFacts;
  final String? avatarPath;

  /// Returns title if set, otherwise name — used for display in persona list
  String get displayLabel => title.isNotEmpty ? title : name;

  UserPersona({
    required this.id,
    this.title = '',
    this.name = 'User',
    this.description = '',
    this.persona = '',
    this.learnedFacts = const [],
    this.avatarPath,
  });

  UserPersona copyWith({
    String? title,
    String? name,
    String? description,
    String? persona,
    List<String>? learnedFacts,
    String? avatarPath,
  }) {
    return UserPersona(
      id: this.id,
      title: title ?? this.title,
      name: name ?? this.name,
      description: description ?? this.description,
      persona: persona ?? this.persona,
      learnedFacts: learnedFacts ?? this.learnedFacts,
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
      'learned_facts': learnedFacts,
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
      learnedFacts: (json['learned_facts'] as List?)?.cast<String>() ?? const [],
      avatarPath: json['avatar_path'],
    );
  }
}

class UserPersonaService extends ChangeNotifier {
  AppDatabase _db;
  List<UserPersona> _personas = [];
  String _activePersonaId = '';

  /// In-memory cache of fact text → embedding vector.
  /// Invalidated when facts change. Populated lazily.
  final Map<String, List<double>> _factEmbeddings = {};

  /// Similarity threshold for considering two facts as duplicates.
  /// Lowered from 0.85 to catch more near-duplicates with slightly different wording.
  static const double _dedupThreshold = 0.75;

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
          learnedFacts: _parseFactsList(p.learnedFacts),
          avatarPath: p.avatarPath,
        )).toList();

        final active = dbPersonas.where((p) => p.isActive).firstOrNull;
        _activePersonaId = active?.id ?? _personas.first.id;
      }

      _factEmbeddings.clear(); // Invalidate cache on reload
      notifyListeners();

      // One-time garbage cleanup: filter historically polluted facts
      final removed = await cleanupGarbageFacts();
      if (removed > 0) {
        debugPrint('[RAG:Persona] Startup cleanup: removed $removed garbage fact(s)');
      }
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
        learnedFacts: Value(jsonEncode(updatedPersona.learnedFacts)),
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
    
    _factEmbeddings.clear(); // Invalidate cache
    notifyListeners();
  }

  Future<void> setActivePersona(String id) async {
    if (_personas.any((p) => p.id == id)) {
      _activePersonaId = id;
      await _db.setActivePersona(id);
      _factEmbeddings.clear(); // Invalidate cache on persona switch
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
      _factEmbeddings.clear(); // Invalidate cache
      notifyListeners();
    }
  }

  /// Reload personas from DB (e.g. after cloud sync import).
  Future<void> reload() async {
    await _loadPersonas();
  }

  /// Parse a JSON string of facts into a List<String>, handling errors.
  static List<String> _parseFactsList(String json) {
    try {
      if (json.isEmpty || json == '[]') return [];
      return List<String>.from(jsonDecode(json) as List);
    } catch (_) {
      return [];
    }
  }

  // ── Embedding-Aware Fact Management ─────────────────────────────────

  /// Ensure embeddings are cached for all current facts.
  /// Only embeds facts that aren't already in the cache.
  Future<void> _ensureFactEmbeddings(EmbeddingService embedService) async {
    final facts = persona.learnedFacts;
    final uncached = facts.where((f) => !_factEmbeddings.containsKey(f)).toList();
    if (uncached.isEmpty) return;

    debugPrint('[RAG:Persona] Caching embeddings for ${uncached.length} fact(s)...');
    for (final fact in uncached) {
      final vec = await embedService.embed(fact);
      if (vec != null) {
        _factEmbeddings[fact] = vec;
      }
    }
  }

  /// Cosine similarity between two vectors.
  static double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0.0 ? 0.0 : dot / denom;
  }

  /// Add a learned fact to the active persona.
  Future<void> addLearnedFact(String fact) async {
    final current = persona;
    final facts = List<String>.from(current.learnedFacts);
    if (facts.contains(fact)) return; // dedup
    facts.add(fact);
    await updatePersona(current.copyWith(learnedFacts: facts));
  }

  /// Add multiple learned facts with semantic dedup via embeddings.
  ///
  /// When [embedService] is provided and available:
  /// - Each new fact is embedded and compared against existing facts
  /// - If similarity > [_dedupThreshold], the longer/more detailed version is kept
  /// - Genuinely unique facts are added normally
  ///
  /// Falls back to exact-string dedup when embeddings are unavailable.
  Future<void> addLearnedFacts(List<String> newFacts, {EmbeddingService? embedService}) async {
    final current = persona;
    final facts = List<String>.from(current.learnedFacts);
    bool changed = false;

    // Fast path: no embeddings available — exact-string dedup (original behavior)
    if (embedService == null || !embedService.isAvailable) {
      for (final fact in newFacts) {
        if (!facts.contains(fact) && fact.trim().isNotEmpty) {
          facts.add(fact);
          changed = true;
        }
      }
      if (changed) {
        await updatePersona(current.copyWith(learnedFacts: facts));
      }
      return;
    }

    // Embedding path: semantic dedup
    debugPrint('[RAG:Persona] Semantic dedup: ${newFacts.length} new fact(s) against ${facts.length} existing');

    // Ensure existing facts are embedded
    await _ensureFactEmbeddings(embedService);

    for (final newFact in newFacts) {
      if (newFact.trim().isEmpty) continue;
      if (facts.contains(newFact)) continue; // exact match skip

      // Embed the new fact
      final newVec = await embedService.embed(newFact);
      if (newVec == null) {
        // Embedding failed — fall back to exact-string dedup (already checked above)
        facts.add(newFact);
        changed = true;
        continue;
      }

      // Compare against all existing fact embeddings
      double bestScore = 0.0;
      int bestIndex = -1;

      for (int i = 0; i < facts.length; i++) {
        final existingVec = _factEmbeddings[facts[i]];
        if (existingVec == null) continue;

        final score = _cosineSimilarity(newVec, existingVec);
        if (score > bestScore) {
          bestScore = score;
          bestIndex = i;
        }
      }

      if (bestScore >= _dedupThreshold && bestIndex >= 0) {
        // Semantic duplicate found — keep the more detailed version
        final existing = facts[bestIndex];
        if (newFact.length > existing.length) {
          debugPrint('[RAG:Persona] ↻ Replacing "$existing" with "$newFact" (score: ${bestScore.toStringAsFixed(3)})');
          // Update cache: remove old, add new
          _factEmbeddings.remove(existing);
          _factEmbeddings[newFact] = newVec;
          facts[bestIndex] = newFact;
          changed = true;
        } else {
          debugPrint('[RAG:Persona] ≡ Skipping "$newFact" — duplicate of "$existing" (score: ${bestScore.toStringAsFixed(3)})');
        }
      } else {
        // Genuinely new fact
        debugPrint('[RAG:Persona] + Adding new fact: "$newFact" (best existing score: ${bestScore.toStringAsFixed(3)})');
        _factEmbeddings[newFact] = newVec;
        facts.add(newFact);
        changed = true;
      }
    }

    if (changed) {
      await updatePersona(current.copyWith(learnedFacts: facts));
    }
  }

  /// Get the most relevant facts for the current conversation context.
  ///
  /// When [embedService] is available, embeds [conversationContext] and returns
  /// the top [maxFacts] facts ranked by cosine similarity.
  /// Falls back to returning all facts when embeddings are unavailable.
  Future<List<String>> getRelevantFacts({
    required String conversationContext,
    EmbeddingService? embedService,
    int maxFacts = 15,
  }) async {
    final facts = persona.learnedFacts;
    if (facts.isEmpty) return [];

    // If no embedding service or few enough facts, return all
    if (embedService == null || !embedService.isAvailable || facts.length <= maxFacts) {
      return List<String>.from(facts);
    }

    // Embed the conversation context
    final queryVec = await embedService.embed(conversationContext);
    if (queryVec == null) return List<String>.from(facts); // fallback

    // Ensure all facts are embedded
    await _ensureFactEmbeddings(embedService);

    // Score each fact against the conversation context
    final scored = <({String fact, double score})>[];
    for (final fact in facts) {
      final factVec = _factEmbeddings[fact];
      if (factVec == null) {
        scored.add((fact: fact, score: 0.0)); // include uncached facts with low priority
        continue;
      }
      final score = _cosineSimilarity(queryVec, factVec);
      scored.add((fact: fact, score: score));
    }

    // Sort by relevance and take top N
    scored.sort((a, b) => b.score.compareTo(a.score));
    final selected = scored.take(maxFacts).map((s) => s.fact).toList();

    debugPrint('[RAG:Persona] Selected ${selected.length}/${facts.length} relevant facts for context');
    return selected;
  }

  /// Remove a learned fact by index.
  Future<void> removeLearnedFact(int index) async {
    final current = persona;
    final facts = List<String>.from(current.learnedFacts);
    if (index >= 0 && index < facts.length) {
      final removed = facts.removeAt(index);
      _factEmbeddings.remove(removed); // Clean up cache
      await updatePersona(current.copyWith(learnedFacts: facts));
    }
  }

  /// One-time garbage cleanup: run quality filters against all existing facts.
  /// Call on app launch to clean up historically polluted fact lists.
  /// Returns the number of facts removed.
  Future<int> cleanupGarbageFacts() async {
    final current = persona;
    final facts = List<String>.from(current.learnedFacts);
    if (facts.isEmpty) return 0;

    final originalCount = facts.length;
    facts.removeWhere((fact) => _isGarbageFact(fact));
    final removed = originalCount - facts.length;

    if (removed > 0) {
      debugPrint('[RAG:Persona] Garbage cleanup: removed $removed/$originalCount facts');
      _factEmbeddings.clear(); // Invalidate cache since facts changed
      await updatePersona(current.copyWith(learnedFacts: facts));
    }
    return removed;
  }

  /// Check if a fact matches garbage patterns.
  /// Mirrors the quality gate in chat_service.dart.
  static bool _isGarbageFact(String fact) {
    final f = fact.trim();
    // Too short or too long
    if (f.length < 8 || f.length > 200) return true;
    // Contains RP asterisks
    if (f.contains('*')) return true;
    // Starts with action verbs
    if (RegExp(r'^(walks|runs|looks|says|said|goes|went|came|sat|stood|turned|moved|grabbed|took|pulled|pushed|kissed|hugged|touched|smiled|laughed|nodded|sighed|whispered|moaned|gasped)\b', caseSensitive: false).hasMatch(f)) return true;
    // Meta-commentary
    if (RegExp(r'^(no new facts|none|n/a|nothing|unknown|unclear|not sure|i don.?t know)', caseSensitive: false).hasMatch(f)) return true;
    // Too generic
    if (RegExp(r'^(is nice|is good|is bad|likes things|does stuff|is a person|is human|exists)', caseSensitive: false).hasMatch(f)) return true;
    // JSON artifacts
    if (RegExp(r'[\[\]{}]').hasMatch(f)) return true;
    // Repeated punctuation / encoding garbage
    if (RegExp(r'[.!?]{3,}|\\[nrt]|&#|%[0-9a-f]{2}', caseSensitive: false).hasMatch(f)) return true;
    // Third-person narrator voice
    if (RegExp(r'^(the user|the player|they|he|she)\s+(is|was|had|has|did|does|went|walked|said|looked|seemed|appeared)\b', caseSensitive: false).hasMatch(f)) return true;
    return false;
  }
}
