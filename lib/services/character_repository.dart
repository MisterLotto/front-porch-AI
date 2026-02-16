import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kobold_character_card_manager/models/character_card.dart';
import 'package:kobold_character_card_manager/models/lorebook.dart';
import 'package:kobold_character_card_manager/models/world.dart';
import 'package:kobold_character_card_manager/services/v2_card_service.dart';
import 'package:kobold_character_card_manager/services/world_repository.dart';

class CharacterRepository extends ChangeNotifier {
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

  CharacterRepository() {
    loadCharacters();
  }

  Future<void> loadCharacters() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final charDir = Directory('${directory.path}/KoboldManager/Characters');
      
      if (await charDir.exists()) {
        _characters.clear();
        final v2Service = V2CardService();
        
        await for (final entity in charDir.list()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
            try {
              final card = await v2Service.readCard(entity.path);
              if (card != null) {
                _characters.add(card);
              }
            } catch (e) {
              print('Failed to load card ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error loading characters: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addCharacter(CharacterCard character) {
    _characters.add(character);
    notifyListeners();
  }

  void removeCharacter(CharacterCard character) {
    _characters.remove(character);
    notifyListeners();
  }

  Future<void> deleteCharacter(CharacterCard character, {WorldRepository? worldRepo}) async {
    // Remove from in-memory list
    _characters.remove(character);
    notifyListeners();
    
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
      
      // Auto-create a linked world if the card has a lorebook
      if (card.lorebook != null && card.lorebook!.entries.isNotEmpty && worldRepo != null) {
        final world = World(
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


  Future<void> updateCharacter(CharacterCard card) async {
    if (card.imagePath == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final v2Service = V2CardService();
      // Overwrite the existing file with updated data
      await v2Service.saveCardAsPng(card, card.imagePath!, card.imagePath!);
      
      // Update the list entry if needed (references might be same, but good to notify)
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

