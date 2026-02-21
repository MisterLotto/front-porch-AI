import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CharacterFolder {
  final String id;
  String name;
  final String? parentId; // null = top-level folder
  final List<String> characterPaths; // imagePath references

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

  factory CharacterFolder.fromJson(Map<String, dynamic> json) {
    return CharacterFolder(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      parentId: json['parentId'],
      characterPaths: List<String>.from(json['characterPaths'] ?? []),
    );
  }
}

class FolderService extends ChangeNotifier {
  final List<CharacterFolder> _folders = [];
  File? _storageFile;

  List<CharacterFolder> get folders => List.unmodifiable(_folders);

  FolderService() {
    _init();
  }

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    _storageFile = File('${directory.path}/KoboldManager/character_folders.json');
    await _load();
  }

  Future<void> _load() async {
    if (_storageFile == null || !await _storageFile!.exists()) return;
    try {
      final json = jsonDecode(await _storageFile!.readAsString());
      _folders.clear();
      for (final item in (json['folders'] as List? ?? [])) {
        _folders.add(CharacterFolder.fromJson(item));
      }
      notifyListeners();
    } catch (e) {
      print('Error loading folders: $e');
    }
  }

  Future<void> _save() async {
    if (_storageFile == null) return;
    await _storageFile!.parent.create(recursive: true);
    final json = {
      'folders': _folders.map((f) => f.toJson()).toList(),
    };
    await _storageFile!.writeAsString(jsonEncode(json));
  }

  Future<CharacterFolder> createFolder(String name, {String? parentId}) async {
    final folder = CharacterFolder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      parentId: parentId,
    );
    _folders.add(folder);
    await _save();
    notifyListeners();
    return folder;
  }

  Future<void> renameFolder(String folderId, String newName) async {
    final folder = _folders.firstWhere((f) => f.id == folderId);
    folder.name = newName;
    await _save();
    notifyListeners();
  }

  Future<void> deleteFolder(String folderId) async {
    // Also delete child folders recursively
    final childIds = _folders.where((f) => f.parentId == folderId).map((f) => f.id).toList();
    for (final childId in childIds) {
      await deleteFolder(childId);
    }
    _folders.removeWhere((f) => f.id == folderId);
    await _save();
    notifyListeners();
  }

  Future<void> addToFolder(String folderId, String characterPath) async {
    final folder = _folders.firstWhere((f) => f.id == folderId);
    if (!folder.characterPaths.contains(characterPath)) {
      folder.characterPaths.add(characterPath);
      // Remove from any other folder
      for (final other in _folders) {
        if (other.id != folderId) {
          other.characterPaths.remove(characterPath);
        }
      }
      await _save();
      notifyListeners();
    }
  }

  Future<void> removeFromFolder(String folderId, String characterPath) async {
    final folder = _folders.firstWhere((f) => f.id == folderId);
    folder.characterPaths.remove(characterPath);
    await _save();
    notifyListeners();
  }

  /// Get the folder a character belongs to (if any)
  CharacterFolder? getFolderForCharacter(String characterPath) {
    for (final folder in _folders) {
      if (folder.characterPaths.contains(characterPath)) {
        return folder;
      }
    }
    return null;
  }

  /// Get characters in a specific folder
  List<String> getCharactersInFolder(String folderId) {
    final folder = _folders.firstWhere(
      (f) => f.id == folderId,
      orElse: () => CharacterFolder(id: '', name: ''),
    );
    return folder.characterPaths;
  }

  /// Get characters in a folder AND all its subfolders recursively
  List<String> getCharactersInFolderRecursive(String folderId) {
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

  /// Get characters not in any folder
  Set<String> getUnfolderedCharacterPaths() {
    final folderedPaths = <String>{};
    for (final folder in _folders) {
      folderedPaths.addAll(folder.characterPaths);
    }
    return folderedPaths;
  }
}
