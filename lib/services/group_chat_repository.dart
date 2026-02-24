import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/group_chat.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';

/// Persists group chat definitions to the database.
class GroupChatRepository extends ChangeNotifier {
  final StorageService _storageService;
  final AppDatabase _db;
  final List<GroupChat> _groups = [];

  List<GroupChat> get groups => List.unmodifiable(_groups);

  GroupChatRepository(this._storageService, this._db) {
    _load();
  }

  Future<void> _load() async {
    await _storageService.initialized;
    _groups.clear();

    try {
      final dbGroups = await _db.getAllGroups();
      for (final g in dbGroups) {
        List<String> charIds = [];
        try { charIds = List<String>.from(jsonDecode(g.characterIds)); } catch (_) {}

        _groups.add(GroupChat(
          id: g.id,
          name: g.name,
          characterIds: charIds,
          turnOrder: TurnOrder.values.firstWhere(
            (e) => e.name == g.turnOrder,
            orElse: () => TurnOrder.roundRobin,
          ),
          autoAdvance: g.autoAdvance,
          directorMode: g.directorMode,
          firstMessage: g.firstMessage,
          scenario: g.scenario,
          systemPrompt: g.systemPrompt,
        ));
      }
    } catch (e) {
      debugPrint('Failed to load groups from DB: $e');
    }

    notifyListeners();
  }

  /// Reload groups from DB (e.g. after cloud sync).
  Future<void> reload() async {
    await _load();
  }

  Future<void> save(GroupChat group) async {
    // Save to database
    final existing = await _db.getGroupById(group.id);
    final companion = GroupsCompanion(
      id: Value(group.id),
      name: Value(group.name),
      characterIds: Value(jsonEncode(group.characterIds)),
      turnOrder: Value(group.turnOrder.name),
      autoAdvance: Value(group.autoAdvance),
      directorMode: Value(group.directorMode),
      firstMessage: Value(group.firstMessage),
      scenario: Value(group.scenario),
      systemPrompt: Value(group.systemPrompt),
    );

    if (existing != null) {
      await _db.updateGroup(companion);
    } else {
      await _db.insertGroup(GroupsCompanion.insert(
        id: group.id,
        name: group.name,
        characterIds: Value(jsonEncode(group.characterIds)),
        turnOrder: Value(group.turnOrder.name),
        autoAdvance: Value(group.autoAdvance),
        directorMode: Value(group.directorMode),
        firstMessage: Value(group.firstMessage),
        scenario: Value(group.scenario),
        systemPrompt: Value(group.systemPrompt),
      ));
    }

    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx >= 0) {
      _groups[idx] = group;
    } else {
      _groups.add(group);
    }
    notifyListeners();
  }

  Future<void> delete(String groupId, {CloudSyncService? cloudSyncService}) async {
    // Delete from database
    await _db.deleteGroupById(groupId);
    _groups.removeWhere((g) => g.id == groupId);

    // Delete associated chat sessions from database
    final sessions = await _db.getSessionsForGroup(groupId);
    for (final session in sessions) {
      await _db.deleteMessagesForSession(session.id);
      await _db.deleteSessionById(session.id);
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
