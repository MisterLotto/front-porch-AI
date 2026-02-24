import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/world.dart' as model;
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/services/storage_service.dart';

class WorldRepository extends ChangeNotifier {
  final StorageService _storageService;
  AppDatabase _db;
  final List<model.World> _worlds = [];
  bool _isLoading = false;

  List<model.World> get worlds => List.unmodifiable(_worlds);
  bool get isLoading => _isLoading;

  WorldRepository(this._storageService, this._db) {
    loadWorlds();
  }

  /// Update the database reference (e.g. after cloud sync replaces the DB file).
  void updateDatabase(AppDatabase db) { _db = db; }

  Future<void> loadWorlds() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.initialized;
      final dbWorlds = await _db.getAllWorlds();
      _worlds.clear();

      for (final w in dbWorlds) {
        Lorebook lorebook;
        if (w.lorebook != null) {
          try {
            lorebook = Lorebook.fromJson(jsonDecode(w.lorebook!));
          } catch (_) {
            lorebook = Lorebook(entries: []);
          }
        } else {
          lorebook = Lorebook(entries: []);
        }

        _worlds.add(model.World(
          name: w.name,
          description: w.description,
          lorebook: lorebook,
          linkedCharacterName: w.linkedCharacterName,
        ));
      }
    } catch (e) {
      print('Error loading worlds: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveWorld(model.World world) async {
    // Check if exists
    final existing = await _db.getWorldByName(world.name);
    
    if (existing != null) {
      await _db.updateWorld(WorldsCompanion(
        id: Value(existing.id),
        name: Value(world.name),
        description: Value(world.description),
        lorebook: Value(jsonEncode(world.lorebook.toJson())),
        linkedCharacterName: Value(world.linkedCharacterName),
      ));
    } else {
      await _db.insertWorld(WorldsCompanion.insert(
        name: world.name,
        description: Value(world.description),
        lorebook: Value(jsonEncode(world.lorebook.toJson())),
        linkedCharacterName: Value(world.linkedCharacterName),
      ));
    }

    // Refresh list
    final index = _worlds.indexWhere((w) => w.name == world.name);
    if (index != -1) {
      _worlds[index] = world;
    } else {
      _worlds.add(world);
    }
    notifyListeners();
  }

  Future<void> deleteWorld(model.World world) async {
    final existing = await _db.getWorldByName(world.name);
    if (existing != null) {
      await _db.deleteWorldById(existing.id);
    }
    _worlds.remove(world);
    notifyListeners();
  }

  Future<void> importWorld(File file) async {
    try {
      final content = await file.readAsString();
      final world = model.World.fromJson(jsonDecode(content));
      await saveWorld(world);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> exportWorld(model.World world, String outputPath) async {
    final file = File(outputPath);
    await file.writeAsString(jsonEncode(world.toJson()));
  }
}
