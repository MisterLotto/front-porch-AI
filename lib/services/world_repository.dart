import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:kobold_character_card_manager/models/world.dart';
import 'package:kobold_character_card_manager/services/storage_service.dart';

class WorldRepository extends ChangeNotifier {
  final StorageService _storageService;
  final List<World> _worlds = [];
  bool _isLoading = false;

  List<World> get worlds => List.unmodifiable(_worlds);
  bool get isLoading => _isLoading;

  WorldRepository(this._storageService) {
    loadWorlds();
  }

  Future<void> loadWorlds() async {
    _isLoading = true;
    notifyListeners();

    try {
      final worldsDir = _storageService.worldsDir;
      if (await worldsDir.exists()) {
        _worlds.clear();
        await for (final entity in worldsDir.list()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
            try {
              final content = await entity.readAsString();
              final world = World.fromJson(jsonDecode(content));
              _worlds.add(world);
            } catch (e) {
              print('Failed to load world ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error loading worlds: $e');
    } finally {
      _isLoading = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveWorld(World world) async {
    final fileName = '${world.name.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_')}.json';
    final file = File('${_storageService.worldsDir.path}/$fileName');
    await file.writeAsString(jsonEncode(world.toJson()));
    
    // Refresh list
    final index = _worlds.indexWhere((w) => w.name == world.name);
    if (index != -1) {
      _worlds[index] = world;
    } else {
      _worlds.add(world);
    }
    notifyListeners();
  }

  Future<void> deleteWorld(World world) async {
    final fileName = '${world.name.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_')}.json';
    final file = File('${_storageService.worldsDir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
    _worlds.remove(world);
    notifyListeners();
  }

  Future<void> importWorld(File file) async {
    try {
      final content = await file.readAsString();
      final world = World.fromJson(jsonDecode(content));
      await saveWorld(world);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> exportWorld(World world, String outputPath) async {
    final file = File(outputPath);
    await file.writeAsString(jsonEncode(world.toJson()));
  }
}
