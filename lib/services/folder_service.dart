import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:front_porch_ai/database/database.dart';

class CharacterFolder {
  final String id;
  String name;
  final String? parentId; // null = top-level folder
  final List<String> characterPaths; // filename-only references (e.g. "Miku_123.png")

  CharacterFolder({
    required this.id,
    required this.name,
    this.parentId,
    List<String>? characterPaths,
  }) : characterPaths = characterPaths ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (parentId != null) 'parentId': parentId,
    'characterPaths': characterPaths,
  };
}

class FolderService extends ChangeNotifier {
  AppDatabase _db;
  final List<CharacterFolder> _folders = [];

  List<CharacterFolder> get folders => List.unmodifiable(_folders);

  FolderService(this._db) {
    _init();
  }

  /// Update the database reference (e.g. after cloud sync replaces the DB file).
  void updateDatabase(AppDatabase db) { _db = db; }

  /// Normalize a character path to just its filename for portable storage.
  static String _normalize(String characterPath) {
    // Use simple split to avoid importing path package
    final parts = characterPath.split(RegExp(r'[/\\]'));
    return parts.last;
  }

  Future<void> _init() async {
    await _load();
  }

  /// Reload folders from DB (e.g. after cloud sync).
  Future<void> reload() async {
    await _load();
  }

  Future<void> _load() async {
    try {
      final dbFolders = await _db.getAllFolders();
      _folders.clear();
      for (final f in dbFolders) {
        // Find characters assigned to this folder
        final chars = await _db.getAllCharacters();
        final charPaths = chars
            .where((c) => c.folderId == f.id && c.imagePath != null)
            .map((c) => _normalize(c.imagePath!))
            .toList();

        _folders.add(CharacterFolder(
          id: f.id.toString(),
          name: f.name,
          parentId: f.parentId?.toString(),
          characterPaths: charPaths,
        ));
      }
      notifyListeners();
    } catch (e) {
      print('Error loading folders: $e');
    }
  }

  /// The path to the local folders JSON file (for cloud sync).
  /// Returns null since folders now live in the DB.
  String? get storagePath => null;

  Future<CharacterFolder> createFolder(String name, {String? parentId}) async {
    final newId = await _db.insertFolder(FoldersCompanion.insert(
      name: name,
      parentId: Value(parentId != null ? int.tryParse(parentId) : null),
    ));
    
    final folder = CharacterFolder(
      id: newId.toString(),
      name: name,
      parentId: parentId,
    );
    _folders.add(folder);
    notifyListeners();
    return folder;
  }

  Future<void> renameFolder(String folderId, String newName) async {
    final id = int.tryParse(folderId);
    if (id == null) return;

    final folder = _folders.firstWhere((f) => f.id == folderId);
    folder.name = newName;
    
    await _db.updateFolder(FoldersCompanion(
      id: Value(id),
      name: Value(newName),
    ));
    notifyListeners();
  }

  Future<void> deleteFolder(String folderId) async {
    final id = int.tryParse(folderId);
    if (id == null) return;

    // Also delete child folders recursively
    final childIds = _folders.where((f) => f.parentId == folderId).map((f) => f.id).toList();
    for (final childId in childIds) {
      await deleteFolder(childId);
    }
    
    // Unassign characters from this folder
    final chars = await _db.getAllCharacters();
    for (final c in chars) {
      if (c.folderId == id) {
        await _db.updateCharacter(CharactersCompanion(
          id: Value(c.id),
          name: Value(c.name),
          folderId: const Value(null),
        ));
      }
    }

    await _db.deleteFolderById(id);
    _folders.removeWhere((f) => f.id == folderId);
    notifyListeners();
  }

  Future<void> addToFolder(String folderId, String characterPath) async {
    final id = int.tryParse(folderId);
    if (id == null) return;

    final filename = _normalize(characterPath);
    
    // Find the character in the DB by matching imagePath
    final chars = await _db.getAllCharacters();
    for (final c in chars) {
      if (c.imagePath != null && _normalize(c.imagePath!) == filename) {
        await _db.updateCharacter(CharactersCompanion(
          id: Value(c.id),
          name: Value(c.name),
          folderId: Value(id),
          updatedAt: Value(DateTime.now()),
        ));
        break;
      }
    }

    // Update in-memory
    await _load();
  }

  Future<void> removeFromFolder(String folderId, String characterPath) async {
    final id = int.tryParse(folderId);
    if (id == null) return;

    final filename = _normalize(characterPath);
    
    // Find the character and clear its folderId
    final chars = await _db.getAllCharacters();
    for (final c in chars) {
      if (c.imagePath != null && _normalize(c.imagePath!) == filename && c.folderId == id) {
        await _db.updateCharacter(CharactersCompanion(
          id: Value(c.id),
          name: Value(c.name),
          folderId: const Value(null),
          updatedAt: Value(DateTime.now()),
        ));
        break;
      }
    }

    await _load();
  }

  /// Get the folder a character belongs to (if any)
  CharacterFolder? getFolderForCharacter(String characterPath) {
    final filename = _normalize(characterPath);
    for (final folder in _folders) {
      if (folder.characterPaths.contains(filename)) {
        return folder;
      }
    }
    return null;
  }

  /// Get character filenames in a specific folder
  List<String> getCharactersInFolder(String folderId) {
    final id = int.tryParse(folderId);
    if (id == null) return [];
    final folder = _folders.firstWhere(
      (f) => f.id == folderId,
      orElse: () => CharacterFolder(id: '0', name: ''),
    );
    return folder.characterPaths;
  }

  /// Get character filenames in a folder AND all its subfolders recursively
  List<String> getCharactersInFolderRecursive(String folderId) {
    final id = int.tryParse(folderId);
    if (id == null) return [];

    final paths = <String>[];
    // Add direct characters
    paths.addAll(getCharactersInFolder(folderId));
    // Add characters from all child folders
    for (final child in _folders.where((f) => f.parentId == folderId)) {
      paths.addAll(getCharactersInFolderRecursive(child.id));
    }
    return paths;
  }

  /// Get subfolders of a given parent (null = top-level folders)
  List<CharacterFolder> getSubfolders(String? parentId) {
    return _folders.where((f) => f.parentId == parentId).toList();
  }

  /// Get all character filenames that are in ANY folder (for filtering unfoldered)
  Set<String> getUnfolderedCharacterPaths() {
    final folderedPaths = <String>{};
    for (final folder in _folders) {
      folderedPaths.addAll(folder.characterPaths);
    }
    return folderedPaths;
  }
}
