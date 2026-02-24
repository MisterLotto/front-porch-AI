import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/models/world.dart' as world_model;
import 'package:front_porch_ai/services/v2_card_service.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';
import 'package:front_porch_ai/database/database.dart';

class CharacterRepository extends ChangeNotifier {
  AppDatabase _db;
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

  CharacterRepository(this._db) {
    loadCharacters();
  }

  /// Update the database reference (e.g. after cloud sync replaces the DB file).
  void updateDatabase(AppDatabase db) { _db = db; }

  Future<void> loadCharacters() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final dbChars = await _db.getAllCharacters();
      _characters.clear();
      
      // Get local characters directory for path rebasing (cross-platform sync)
      final directory = await getApplicationDocumentsDirectory();
      final localCharDir = '${directory.path}/KoboldManager/Characters';

      for (final c in dbChars) {
        final card = _characterFromRow(c);

        // Rebase imagePath if it doesn't exist locally (synced from another OS)
        if (card.imagePath != null && !File(card.imagePath!).existsSync()) {
          // Use regex split to handle both / and \ (p.basename fails with Windows paths on Linux)
          final filename = card.imagePath!.split(RegExp(r'[/\\]')).last;
          final rebasedPath = '$localCharDir/$filename';
          if (File(rebasedPath).existsSync()) {
            card.imagePath = rebasedPath;
            // Update the DB so future loads don't need rebasing
            if (card.dbId != null) {
              await _db.updateCharacter(CharactersCompanion(
                id: Value(card.dbId!),
                name: Value(card.name),
                imagePath: Value(rebasedPath),
              ));
            }
          }
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

  void addCharacter(CharacterCard character) {
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
      final directory = await getApplicationDocumentsDirectory();
      final charDir = Directory('${directory.path}/KoboldManager/Characters');
      if (!await charDir.exists()) {
        await charDir.create(recursive: true);
      }
      
      // Use the character name for the filename, sanitized
      final safeName = card.name.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
      final destPath = '${charDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.png';
      await file.copy(destPath);
      
      // Update the imagePath to point to the local copy
      card.imagePath = destPath;

      // Insert into database
      final dbId = await _db.insertCharacter(CharactersCompanion.insert(
        name: card.name,
        description: Value(card.description),
        personality: Value(card.personality),
        scenario: Value(card.scenario),
        firstMessage: Value(card.firstMessage),
        mesExample: Value(card.mesExample),
        systemPrompt: Value(card.systemPrompt),
        postHistoryInstructions: Value(card.postHistoryInstructions),
        alternateGreetings: Value(jsonEncode(card.alternateGreetings)),
        tags: Value(jsonEncode(card.tags)),
        imagePath: Value(card.imagePath),
        ttsVoice: Value(card.ttsVoice),
        lorebook: Value(card.lorebook != null ? jsonEncode(card.lorebook!.toJson()) : null),
        worldNames: Value(jsonEncode(card.worldNames)),
      ));
      card.dbId = dbId;
      
      // Auto-create a linked world if the card has a lorebook
      if (card.lorebook != null && card.lorebook!.entries.isNotEmpty && worldRepo != null) {
        final world = world_model.World(
          name: "${card.name}'s Lorebook",
          description: 'Auto-imported from character card: ${card.name}',
          lorebook: Lorebook(entries: List.from(card.lorebook!.entries)),
          linkedCharacterName: card.name,
        );
        await worldRepo.saveWorld(world);
      }
      
      addCharacter(card);
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
      
      // Update in database
      if (card.dbId != null) {
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
          imagePath: Value(card.imagePath),
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
}
