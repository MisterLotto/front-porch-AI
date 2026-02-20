import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:front_porch_ai/models/group_chat.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';

/// Persists group chat definitions to disk.
class GroupChatRepository extends ChangeNotifier {
  final StorageService _storageService;
  final List<GroupChat> _groups = [];

  List<GroupChat> get groups => List.unmodifiable(_groups);

  GroupChatRepository(this._storageService) {
    _load();
  }

  Directory get _groupsDir {
    final dir = Directory('${_storageService.chatsDir.path}/groups');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> _load() async {
    await _storageService.initialized;
    _groups.clear();
    final dir = _groupsDir;

    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(await file.readAsString());
        _groups.add(GroupChat.fromJson(json));
      } catch (e) {
        debugPrint('Failed to load group: ${file.path}: $e');
      }
    }
    notifyListeners();
  }

  Future<void> save(GroupChat group) async {
    final file = File('${_groupsDir.path}/${group.id}.json');
    await file.writeAsString(jsonEncode(group.toJson()));

    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx >= 0) {
      _groups[idx] = group;
    } else {
      _groups.add(group);
    }
    notifyListeners();
  }

  Future<void> delete(String groupId, {CloudSyncService? cloudSyncService}) async {
    final file = File('${_groupsDir.path}/$groupId.json');
    if (await file.exists()) await file.delete();
    _groups.removeWhere((g) => g.id == groupId);

    // Delete associated chat history folder
    try {
      final chatFolder = Directory('${_storageService.chatsDir.path}/group_$groupId');
      if (await chatFolder.exists()) {
        await chatFolder.delete(recursive: true);
        debugPrint('AG_DEBUG: Deleted group chat folder: ${chatFolder.path}');
      }
    } catch (e) {
      debugPrint('Error deleting group chat folder: $e');
    }

    // Delete from cloud storage
    if (cloudSyncService != null) {
      cloudSyncService.deleteRemoteGroupChat(groupId);
    }

    notifyListeners();
  }

  GroupChat? getById(String id) {
    return _groups.where((g) => g.id == id).firstOrNull;
  }
}
