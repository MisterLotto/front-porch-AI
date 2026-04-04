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
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/models/world.dart' as world_model;
import 'package:front_porch_ai/services/v2_card_service.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/database/database.dart';

class CharacterRepository extends ChangeNotifier {
  AppDatabase _db;
  final StorageService _storage;
  final List<CharacterCard> _characters = [];
  bool _isLoading = false;

  List<CharacterCard> get characters => List.unmodifiable(_characters);
  bool get isLoading => _isLoading;

  /// All unique tags across all characters (for autocomplete)
  List<String> get allTags {
    final tags = <String>{};
    for (final c in _characters) {
      tags.addAll(c.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  CharacterRepository(this._db, this._storage) {
    loadCharacters();
  }

  /// Extract the basename from a potentially full path (handles / and \).
  /// Returns the input unchanged if it's already a basename.
  static String _toBasename(String path) {
    return path.split(RegExp(r'[/\\]')).last;
  }

  /// Resolve a stored image path (basename or full path) to the local full path.
  String _resolveImagePath(String stored) {
    final basename = _toBasename(stored);
    return '${_storage.charactersDir.path}/$basename';
  }

  /// Update the database reference (e.g. after cloud sync replaces the DB file).
  void updateDatabase(AppDatabase db) { _db = db; }

  Future<void> loadCharacters() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final dbChars = await _db.getAllCharacters();
      _characters.clear();

      for (final c in dbChars) {
        final card = _characterFromRow(c);

        // Normalize DB path to basename-only (one-time migration for old full paths).
        // Then resolve to local full path for runtime use.
        if (card.imagePath != null) {
          final basename = _toBasename(card.imagePath!);
          if (basename != card.imagePath) {
            // DB still has a full path — strip it to basename for portability
            if (card.dbId != null) {
              await _db.updateCharacterImagePath(card.dbId!, basename);
            }
          }
          // Always resolve to local full path for in-memory use
          card.imagePath = _resolveImagePath(basename);
        }

        _characters.add(card);
      }
    } catch (e) {
      print('Error loading characters from DB: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete PNG files in the Characters directory that are not referenced
  /// by any character in the database. This cleans up orphans left behind
  /// when the DB is replaced via cloud sync or characters are deleted
  /// without their file being removed.
  Future<int> cleanOrphanedPngs() async {
    try {
      final charDir = _storage.charactersDir;
      if (!await charDir.exists()) return 0;

      // Collect all imagePaths currently referenced by loaded characters
      final referencedPaths = <String>{};
      for (final c in _characters) {
        if (c.imagePath != null) {
          referencedPaths.add(c.imagePath!);
        }
      }

      int deletedCount = 0;
      await for (final entity in charDir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
          if (!referencedPaths.contains(entity.path)) {
            debugPrint('[Cleanup] Deleting orphaned PNG: ${p.basename(entity.path)}');
            await entity.delete();
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        debugPrint('[Cleanup] Deleted $deletedCount orphaned character PNG(s)');
      }
      return deletedCount;
    } catch (e) {
      debugPrint('[Cleanup] Error cleaning orphaned PNGs: $e');
      return 0;
    }
  }

  /// Convert a DB row into a CharacterCard model.
  CharacterCard _characterFromRow(Character c) {
    List<String> altGreetings = [];
    try { altGreetings = List<String>.from(jsonDecode(c.alternateGreetings)); } catch (_) {}
    
    List<String> tags = [];
    try { tags = List<String>.from(jsonDecode(c.tags)); } catch (_) {}
    
    List<String> worldNames = [];
    try { worldNames = List<String>.from(jsonDecode(c.worldNames)); } catch (_) {}
    
    Lorebook? lorebook;
    if (c.lorebook != null) {
      try { lorebook = Lorebook.fromJson(jsonDecode(c.lorebook!)); } catch (_) {}
    }

    final card = CharacterCard(
      name: c.name,
      description: c.description,
      personality: c.personality,
      scenario: c.scenario,
      firstMessage: c.firstMessage,
      mesExample: c.mesExample,
      systemPrompt: c.systemPrompt,
      postHistoryInstructions: c.postHistoryInstructions,
      alternateGreetings: altGreetings,
      tags: tags,
      imagePath: c.imagePath,
      ttsVoice: c.ttsVoice,
      lorebook: lorebook,
      worldNames: worldNames,
    );
    // Store DB id for lookups
    card.dbId = c.id;
    return card;
  }

  Future<void> addCharacter(CharacterCard character) async {
    // Store basename only in DB for cross-platform portability
    final dbImagePath = character.imagePath != null ? _toBasename(character.imagePath!) : null;
    final dbId = await _db.insertCharacterReturningId(CharactersCompanion(
      name: Value(character.name),
      description: Value(character.description),
      personality: Value(character.personality),
      scenario: Value(character.scenario),
      firstMessage: Value(character.firstMessage),
      mesExample: Value(character.mesExample),
      systemPrompt: Value(character.systemPrompt),
      postHistoryInstructions: Value(character.postHistoryInstructions),
      alternateGreetings: Value(jsonEncode(character.alternateGreetings)),
      tags: Value(jsonEncode(character.tags)),
      imagePath: Value(dbImagePath),
      ttsVoice: Value(character.ttsVoice),
      lorebook: Value(character.lorebook != null ? jsonEncode(character.lorebook!.toJson()) : null),
      worldNames: Value(jsonEncode(character.worldNames)),
    ));
    character.dbId = dbId;
    _characters.add(character);
    notifyListeners();
  }

  void removeCharacter(CharacterCard character) {
    _characters.remove(character);
    notifyListeners();
  }

  Future<void> deleteCharacter(CharacterCard character, {WorldRepository? worldRepo, Directory? chatsDir, CloudSyncService? cloudSyncService}) async {
    // Remove from in-memory list
    _characters.remove(character);
    notifyListeners();

    // Delete from database
    if (character.dbId != null) {
      await _db.deleteCharacterById(character.dbId!);
    }
    
    // Delete the PNG file from disk
    if (character.imagePath != null) {
      try {
        final file = File(character.imagePath!);
        if (await file.exists()) {
          await file.delete();
          print('AG_DEBUG: Deleted character file: ${character.imagePath}');
        }
      } catch (e) {
        print('Error deleting character file: $e');
      }

      // Delete associated chat history folder
      if (chatsDir != null) {
        try {
          final charId = p.basenameWithoutExtension(character.imagePath!);
          final chatFolder = Directory('${chatsDir.path}/$charId');
          if (await chatFolder.exists()) {
            await chatFolder.delete(recursive: true);
            print('AG_DEBUG: Deleted chat folder: ${chatFolder.path}');
          }
        } catch (e) {
          print('Error deleting chat folder: $e');
        }
      }

      // Delete from cloud storage
      if (cloudSyncService != null) {
        final charId = p.basenameWithoutExtension(character.imagePath!);
        final pngName = p.basename(character.imagePath!);
        cloudSyncService.deleteRemoteCharacter(charId, pngName);
      }
    }
    
    // Remove any linked world
    if (worldRepo != null) {
      final linkedWorld = worldRepo.worlds.where(
        (w) => w.linkedCharacterName == character.name
      ).toList();
      for (final world in linkedWorld) {
        await worldRepo.deleteWorld(world);
      }
    }
  }

  Future<CharacterCard?> importCharacter(File file, {WorldRepository? worldRepo}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final v2Service = V2CardService();
      
      // Parse the V2 card data from the PNG tEXt chunk
      CharacterCard? card = await v2Service.readCard(file.path);
      
      // Fallback if no V2 data found in the PNG
      if (card == null) {
        final fileName = file.path.split('/').last.split('.').first;
        card = CharacterCard(
          name: fileName,
          description: '',
          imagePath: file.path,
        );
      }
      
      // Copy the file to the app's characters directory
      final charDir = _storage.charactersDir;
      if (!await charDir.exists()) {
        await charDir.create(recursive: true);
      }
      
      // Use the character name for the filename, sanitized
      final safeName = card.name.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');

      // Remove old PNG for same-named character to prevent duplicates
      final cardName = card.name;
      final existing = _characters.where((c) => c.name == cardName).toList();
      for (final oldChar in existing) {
        if (oldChar.imagePath != null) {
          try {
            final oldFile = File(oldChar.imagePath!);
            if (await oldFile.exists()) {
              await oldFile.delete();
              debugPrint('[Import] Deleted old PNG for ${card.name}: ${p.basename(oldChar.imagePath!)}');
            }
          } catch (e) {
            debugPrint('[Import] Could not delete old PNG: $e');
          }
        }
      }

      final destPath = '${charDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.png';
      await file.copy(destPath);
      
      // Update the imagePath to point to the local copy
      card.imagePath = destPath;

      // Insert into database
      // Store basename only in DB for cross-platform portability
      final dbImagePath = card.imagePath != null ? _toBasename(card.imagePath!) : null;
      final dbId = await _db.insertCharacterReturningId(CharactersCompanion(
        name: Value(card.name),
        description: Value(card.description),
        personality: Value(card.personality),
        scenario: Value(card.scenario),
        firstMessage: Value(card.firstMessage),
        mesExample: Value(card.mesExample),
        systemPrompt: Value(card.systemPrompt),
        postHistoryInstructions: Value(card.postHistoryInstructions),
        alternateGreetings: Value(jsonEncode(card.alternateGreetings)),
        tags: Value(jsonEncode(card.tags)),
        imagePath: Value(dbImagePath),
        ttsVoice: Value(card.ttsVoice),
        lorebook: Value(card.lorebook != null ? jsonEncode(card.lorebook!.toJson()) : null),
        worldNames: Value(jsonEncode(card.worldNames)),
      ));
      card.dbId = dbId;
      
      // Auto-create a linked world if the card has a lorebook
      if (card.lorebook != null && card.lorebook!.entries.isNotEmpty && worldRepo != null) {
        final world = world_model.World(
          name: "${card.name}'s world lore",
          description: 'Auto-imported from character card: ${card.name}',
          lorebook: Lorebook(entries: List.from(card.lorebook!.entries)),
          linkedCharacterName: card.name,
        );
        await worldRepo.saveWorld(world);
      }
      
      // Add to in-memory list (already inserted into DB above — do NOT call addCharacter() which would insert again)
      _characters.add(card);
      return card;
      
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Bulk import multiple character PNG files.
  /// [onProgress] is called after each file with (current, total, cardName, error).
  /// Returns a summary map: {imported: int, failed: int, errors: List<String>}.
  Future<Map<String, dynamic>> importCharacters(
    List<File> files, {
    WorldRepository? worldRepo,
    void Function(int current, int total, String name, String? error)? onProgress,
    bool Function()? isCancelled,
  }) async {
    int imported = 0;
    int failed = 0;
    final List<String> errors = [];

    for (int i = 0; i < files.length; i++) {
      // Check cancellation
      if (isCancelled != null && isCancelled()) break;

      final file = files[i];
      final fileName = file.path.split(Platform.pathSeparator).last;
      try {
        final card = await importCharacter(file, worldRepo: worldRepo);
        if (card != null) {
          imported++;
          onProgress?.call(i + 1, files.length, card.name, null);
        } else {
          failed++;
          final err = 'No card data found in $fileName';
          errors.add(err);
          onProgress?.call(i + 1, files.length, fileName, err);
        }
      } catch (e) {
        failed++;
        final err = '$fileName: $e';
        errors.add(err);
        onProgress?.call(i + 1, files.length, fileName, e.toString());
      }
    }

    return {'imported': imported, 'failed': failed, 'errors': errors};
  }

  Future<void> updateCharacter(CharacterCard card) async {
    if (card.imagePath == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final v2Service = V2CardService();
      // Overwrite the existing file with updated data
      await v2Service.saveCardAsPng(card, card.imagePath!, card.imagePath!);
      
      // Update in database — store basename only for cross-platform portability
      if (card.dbId != null) {
        final dbImagePath = card.imagePath != null ? _toBasename(card.imagePath!) : null;
        await _db.updateCharacter(CharactersCompanion(
          id: Value(card.dbId!),
          name: Value(card.name),
          description: Value(card.description),
          personality: Value(card.personality),
          scenario: Value(card.scenario),
          firstMessage: Value(card.firstMessage),
          mesExample: Value(card.mesExample),
          systemPrompt: Value(card.systemPrompt),
          postHistoryInstructions: Value(card.postHistoryInstructions),
          alternateGreetings: Value(jsonEncode(card.alternateGreetings)),
          tags: Value(jsonEncode(card.tags)),
          imagePath: Value(dbImagePath),
          ttsVoice: Value(card.ttsVoice),
          lorebook: Value(card.lorebook != null ? jsonEncode(card.lorebook!.toJson()) : null),
          worldNames: Value(jsonEncode(card.worldNames)),
          updatedAt: Value(DateTime.now()),
        ));
      }
      
      // Update the list entry
      final index = _characters.indexWhere((c) => c.imagePath == card.imagePath);
      if (index != -1) {
        _characters[index] = card;
      }
      notifyListeners();
      
    } catch (e) {
      print('Error updating character: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CharacterCard?> duplicateCharacter(CharacterCard card) async {
    _isLoading = true;
    notifyListeners();
    try {
      final newName = '${card.name} (duplicate)';
      
      // Clone the card model
      final clonedCard = CharacterCard(
        name: newName,
        description: card.description,
        personality: card.personality,
        scenario: card.scenario,
        firstMessage: card.firstMessage,
        mesExample: card.mesExample,
        systemPrompt: card.systemPrompt,
        postHistoryInstructions: card.postHistoryInstructions,
        alternateGreetings: List.from(card.alternateGreetings),
        tags: List.from(card.tags),
        ttsVoice: card.ttsVoice,
        lorebook: card.lorebook != null ? Lorebook(entries: List.from(card.lorebook!.entries)) : null,
        worldNames: List.from(card.worldNames),
      );

      // Handle image file duplication if exists
      if (card.imagePath != null) {
        final originalFile = File(card.imagePath!);
        if (await originalFile.exists()) {
          final charDir = _storage.charactersDir;
          if (!await charDir.exists()) {
            await charDir.create(recursive: true);
          }
          final safeName = newName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
          final destPath = '${charDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.png';
          await originalFile.copy(destPath);
          clonedCard.imagePath = destPath;

          // Now write the V2 card data to the *new* PNG
          final v2Service = V2CardService();
          await v2Service.saveCardAsPng(clonedCard, destPath, destPath);
        }
      }

      // Insert into database
      final dbImagePath = clonedCard.imagePath != null ? _toBasename(clonedCard.imagePath!) : null;
      final dbId = await _db.insertCharacterReturningId(CharactersCompanion(
        name: Value(clonedCard.name),
        description: Value(clonedCard.description),
        personality: Value(clonedCard.personality),
        scenario: Value(clonedCard.scenario),
        firstMessage: Value(clonedCard.firstMessage),
        mesExample: Value(clonedCard.mesExample),
        systemPrompt: Value(clonedCard.systemPrompt),
        postHistoryInstructions: Value(clonedCard.postHistoryInstructions),
        alternateGreetings: Value(jsonEncode(clonedCard.alternateGreetings)),
        tags: Value(jsonEncode(clonedCard.tags)),
        imagePath: Value(dbImagePath),
        ttsVoice: Value(clonedCard.ttsVoice),
        lorebook: Value(clonedCard.lorebook != null ? jsonEncode(clonedCard.lorebook!.toJson()) : null),
        worldNames: Value(jsonEncode(clonedCard.worldNames)),
      ));
      clonedCard.dbId = dbId;
      
      _characters.add(clonedCard);
      return clonedCard;
      
    } catch (e) {
      debugPrint('[Duplicate] Error duplicating character: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
