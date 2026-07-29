// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Living Worlds repository: UUID identity, .fpworld export/import, chat
// attachment (chat_worlds), biome fields. Rename no longer cascades — refs
// are ids.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/fp_world_package.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/models/lorebook_codec.dart';
import 'package:front_porch_ai/models/lorebook_export.dart';
import 'package:front_porch_ai/models/world.dart' as model;
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/chat/weather_biomes.dart';
import 'package:front_porch_ai/services/group_chat_repository.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/utils/character_linked_world.dart';
import 'package:front_porch_ai/utils/world_ref_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorldRepository extends ChangeNotifier {
  final StorageService _storageService;
  AppDatabase _db;
  final List<model.World> _worlds = [];
  bool _isLoading = false;
  CharacterRepository? _characterRepository;
  GroupChatRepository? _groupRepository;
  static const _uuid = Uuid();
  static const _purgePrefKey = 'purged_character_linked_worlds_v1';

  List<model.World> get worlds => List.unmodifiable(_worlds);
  bool get isLoading => _isLoading;

  /// Places only — excludes legacy character-lore clones (should be empty after purge).
  List<model.World> get placeWorlds => List.unmodifiable(
        _worlds.where((w) => !isCharacterLinkedWorld(w)),
      );

  WorldRepository(this._storageService, this._db) {
    loadWorlds();
  }

  void setCharacterRepository(CharacterRepository repo) {
    _characterRepository = repo;
    loadWorlds();
  }

  void setGroupChatRepository(GroupChatRepository repo) {
    _groupRepository = repo;
  }

  void updateDatabase(AppDatabase db) {
    _db = db;
  }

  model.World? worldById(String id) {
    for (final w in _worlds) {
      if (w.id == id) return w;
    }
    return null;
  }

  model.World? worldByName(String name) {
    for (final w in _worlds) {
      if (w.name == name) return w;
    }
    return null;
  }

  /// Resolve by UUID first, then by name (character.worldNames still use names).
  model.World? resolveWorld(String idOrName) {
    return worldById(idOrName) ?? worldByName(idOrName);
  }

  void _resolveAvatarPaths(List<model.World> worlds) {
    if (_characterRepository == null) return;
    for (final world in worlds) {
      CharacterCard? character;
      final charId = world.linkedCharacterId;
      if (charId != null && charId.isNotEmpty) {
        character = _characterRepository!.characters
            .where((c) => c.dbId == charId)
            .firstOrNull;
      }
      if (character == null && world.linkedCharacterName != null) {
        character = _characterRepository!.characters
            .where((c) => c.name == world.linkedCharacterName)
            .firstOrNull;
      }
      if (character != null && character.imagePath != null) {
        world.avatarPath = character.imagePath;
      }
    }
  }

  model.World _fromRow(World row) {
    Lorebook lorebook;
    if (row.lorebook != null) {
      try {
        lorebook = Lorebook.fromJson(jsonDecode(row.lorebook!));
      } catch (_) {
        lorebook = Lorebook(entries: []);
      }
    } else {
      lorebook = Lorebook(entries: []);
    }
    return model.World(
      id: row.id,
      name: row.name,
      description: row.description,
      lorebook: lorebook,
      linkedCharacterName: row.linkedCharacterName,
      linkedCharacterId: row.linkedCharacterId,
      coverImage: row.coverImage,
      sourceId: row.sourceId,
      formatVersion: row.formatVersion,
      biomeId: row.biomeId,
      biomeJson: row.biomeJson,
      injectDescription: row.injectDescription,
    );
  }

  WorldsCompanion _toCompanion(model.World world) {
    return WorldsCompanion(
      id: Value(world.id),
      name: Value(world.name),
      description: Value(world.description),
      lorebook: Value(jsonEncode(world.lorebook.toJson())),
      linkedCharacterName: Value(world.linkedCharacterName),
      linkedCharacterId: Value(world.linkedCharacterId),
      coverImage: Value(world.coverImage),
      sourceId: Value(world.sourceId),
      formatVersion: Value(world.formatVersion),
      biomeId: Value(world.biomeId),
      biomeJson: Value(world.biomeJson),
      injectDescription: Value(world.injectDescription),
    );
  }

  Future<void> loadWorlds() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _storageService.initialized;
      final dbWorlds = await _db.getAllWorlds();
      _worlds
        ..clear()
        ..addAll(dbWorlds.map(_fromRow));
      _resolveAvatarPaths(_worlds);
      // One-time: drop legacy "Aerin's Lorebook" clones so Worlds = places.
      await _maybePurgeCharacterLinkedWorlds();
    } catch (e) {
      debugPrint('Error loading worlds: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _maybePurgeCharacterLinkedWorlds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_purgePrefKey) == true) return;
      final n = await purgeCharacterLinkedWorlds();
      await prefs.setBool(_purgePrefKey, true);
      if (n > 0) {
        debugPrint(
          '[Worlds] Purged $n character-linked lore clones '
          '(lore remains on character cards)',
        );
      }
    } catch (e) {
      debugPrint('[Worlds] character-linked purge skipped: $e');
    }
  }

  /// Delete every legacy character-world clone and strip references from
  /// characters / groups / chat_worlds. Character card lorebooks are untouched.
  /// Returns how many worlds were deleted.
  Future<int> purgeCharacterLinkedWorlds() async {
    final doomed = _worlds.where(isCharacterLinkedWorld).toList();
    if (doomed.isEmpty) return 0;

    final ids = {for (final w in doomed) w.id};
    final names = {for (final w in doomed) w.name};

    for (final w in doomed) {
      await _db.deleteChatWorldLinksForWorld(w.id);
      await _db.deleteWorldById(w.id);
    }
    _worlds.removeWhere((w) => ids.contains(w.id));

    await _db.stripWorldRefsFromCharactersAndGroups(ids: ids, names: names);

    // Keep in-memory character/group lists in sync without a full app restart.
    final charRepo = _characterRepository;
    if (charRepo != null) {
      for (final c in charRepo.characters) {
        final before = c.worldNames.length;
        c.worldNames = [
          for (final ref in c.worldNames)
            if (!ids.contains(ref) && !names.contains(ref)) ref,
        ];
        if (c.worldNames.length != before) {
          try {
            await charRepo.updateCharacter(c);
          } catch (e) {
            debugPrint('[Worlds] strip worldNames on ${c.name}: $e');
          }
        }
      }
    }
    final groupRepo = _groupRepository;
    if (groupRepo != null) {
      for (final g in List.of(groupRepo.groups)) {
        final before = g.worldIds.length;
        g.worldIds = [
          for (final ref in g.worldIds)
            if (!ids.contains(ref) && !names.contains(ref)) ref,
        ];
        if (g.worldIds.length != before) {
          try {
            await groupRepo.save(g);
          } catch (e) {
            debugPrint('[Worlds] strip worldIds on group ${g.name}: $e');
          }
        }
      }
    }

    notifyListeners();
    return doomed.length;
  }

  /// Rename display name only — attachments use UUID and need no cascade.
  Future<void> renameWorld(model.World world, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == world.name) return;
    if (await _db.getWorldByName(trimmed) != null) {
      throw StateError('A world named "$trimmed" already exists.');
    }
    world.name = trimmed;
    await _db.updateWorld(_toCompanion(world));
    notifyListeners();
  }

  Future<void> saveWorld(model.World world) async {
    if (world.id.isEmpty) {
      world.id = _uuid.v4();
    }
    // Places only — never re-create character-linked clones via save.
    world.linkedCharacterName = null;
    world.linkedCharacterId = null;
    if (world.description
        .trim()
        .toLowerCase()
        .startsWith('auto-imported from character card')) {
      world.description = '';
    }
    final existing = await _db.getWorldById(world.id);
    if (existing != null) {
      await _db.updateWorld(_toCompanion(world));
    } else {
      // Name collision on create → auto-rename (Keep both).
      final taken = await _db.getWorldByName(world.name);
      if (taken != null && taken.id != world.id) {
        world.name = uniqueWorldName(
          world.name,
          (n) => _worlds.any((w) => w.name == n && w.id != world.id),
        );
      }
      await _db.insertWorld(_toCompanion(world));
    }

    final index = _worlds.indexWhere((w) => w.id == world.id);
    if (index != -1) {
      _worlds[index] = world;
    } else {
      _worlds.add(world);
    }
    if (world.linkedCharacterName != null || world.linkedCharacterId != null) {
      _resolveAvatarPaths([world]);
    }
    notifyListeners();
  }

  Future<void> deleteWorld(model.World world) async {
    await _db.deleteWorldById(world.id);
    await _db.deleteChatWorldLinksForWorld(world.id);
    _worlds.removeWhere((w) => w.id == world.id);
    notifyListeners();
  }

  /// Import .fpworld or bare lorebook. Always creates a new row (Keep both on
  /// name collision). Preserves package id as [sourceId]; assigns a new local id.
  Future<model.World> importWorld(File file) async {
    final content = await file.readAsString();
    final package = decodeFpWorldString(content);
    final world = package.world;

    // Fresh local identity; remember provenance.
    world.sourceId ??= world.id.isNotEmpty ? world.id : null;
    world.id = _uuid.v4();
    world.name = uniqueWorldName(
      world.name,
      (n) => _worlds.any((w) => w.name == n),
    );

    if (package.biome != null) {
      final biome = Biome.fromJson(package.biome!);
      if (Biome.builtInById(biome.id) != null) {
        world.biomeId = biome.id;
        world.biomeJson = null;
      } else {
        world.biomeId = biome.id;
        world.biomeJson = biome.toJsonString();
      }
    }

    // Validate we got something useful for bare lore imports.
    if (world.lorebook.entries.isEmpty &&
        detectLorebookFormat(
              jsonDecode(content) is Map
                  ? Map<String, dynamic>.from(jsonDecode(content) as Map)
                  : <String, dynamic>{},
            ) ==
            LorebookFormat.fpaiOrSt) {
      // Still save empty worlds from intentional empty packages.
    }

    await saveWorld(world);
    return world;
  }

  /// Export as .fpworld (full place package). Prefer this over ST-only.
  Future<void> exportFpWorld(model.World world, String outputPath) async {
    Map<String, dynamic>? biomeMap;
    final biome = Biome.resolve(
      biomeId: world.biomeId,
      biomeJson: world.biomeJson,
    );
    // Always embed resolved biome so importers get climate without built-ins.
    biomeMap = biome.toJson();
    final file = File(outputPath);
    await file.writeAsString(encodeFpWorldString(world: world, biome: biomeMap));
  }

  /// Legacy ST world-info export (lore only).
  Future<void> exportWorld(model.World world, String outputPath) async {
    final file = File(outputPath);
    await file.writeAsString(jsonEncode(encodeStWorldInfo(
      world.lorebook,
      name: world.name,
      description: world.description,
    )));
  }

  // ── Chat attachments ────────────────────────────────────────────────

  Future<List<String>> getChatWorldIds(String chatId) =>
      _db.getWorldIdsForChat(chatId);

  Future<List<model.World>> getChatWorlds(String chatId) async {
    final ids = await getChatWorldIds(chatId);
    return [
      for (final id in ids)
        if (worldById(id) != null) worldById(id)!,
    ];
  }

  Future<void> setChatWorlds(String chatId, List<String> worldIds) async {
    await _db.setChatWorlds(chatId, worldIds);
    notifyListeners();
  }

  Future<void> attachWorldToChat(String chatId, String worldId) async {
    final ids = await getChatWorldIds(chatId);
    if (ids.contains(worldId)) return;
    await setChatWorlds(chatId, [...ids, worldId]);
  }

  Future<void> detachWorldFromChat(String chatId, String worldId) async {
    final ids = await getChatWorldIds(chatId);
    await setChatWorlds(chatId, [for (final id in ids) if (id != worldId) id]);
  }

  /// Copy group template world ids onto a new chat (session).
  Future<void> applyGroupTemplateToChat(
    String chatId,
    List<String> templateWorldIds,
  ) async {
    final unresolved = <String>[];
    final ids = resolveWorldRefsToIds(
      refs: templateWorldIds,
      nameToId: {for (final w in _worlds) w.name: w.id},
      validIds: {for (final w in _worlds) w.id},
      unresolved: unresolved,
    );
    if (unresolved.isNotEmpty) {
      debugPrint(
        '[Worlds] template had unresolved refs for chat $chatId: $unresolved',
      );
    }
    await setChatWorlds(chatId, ids);
  }

  // ── Biome spans (phase 1) ───────────────────────────────────────────

  Future<void> setChatBiome({
    required String chatId,
    required int dayCount,
    required Biome biome,
  }) async {
    await _db.insertBiomeSpan(
      chatId: chatId,
      effectiveFromDay: dayCount,
      biomeJson: biome.toJsonString(),
    );
  }

  Future<Biome> biomeAt({
    required String chatId,
    required int day,
    Biome? worldDefault,
  }) async {
    final spans = await _db.getBiomeSpansForChat(chatId);
    ChatBiomeSpan? active;
    for (final s in spans) {
      if (s.effectiveFromDay <= day) {
        active = s;
      } else {
        break;
      }
    }
    if (active != null) {
      return Biome.tryParse(active.biomeJson) ??
          worldDefault ??
          Biome.temperate;
    }
    return worldDefault ?? Biome.temperate;
  }
}
