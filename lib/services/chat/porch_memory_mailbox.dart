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

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'porch_memory_models.dart';

/// Disk mailbox where LLMerta drops finished-game porch memory bundles.
/// Design: docs/design/llmerta-porch-memories.md §4.
class PorchMemoryMailbox {
  /// Folder name under KoboldManager (producer contract).
  static const String kDirName = 'llmerta_porch_memories';

  /// Resolve candidate mailbox directories.
  ///
  /// Always includes `{fpaRoot}/KoboldManager/llmerta_porch_memories` when
  /// [fpaRootPath] is set. Also scans LLMerta's hard-coded stable install
  /// paths so a custom/beta FPA root still finds files the producer wrote
  /// under Documents/FrontPorchAI.
  static List<Directory> detectMailboxDirs({String? fpaRootPath}) {
    final seen = <String>{};
    final out = <Directory>[];

    void add(String path) {
      final norm = p.normalize(path);
      if (seen.add(norm)) out.add(Directory(norm));
    }

    if (fpaRootPath != null && fpaRootPath.isNotEmpty) {
      add(p.join(fpaRootPath, 'KoboldManager', kDirName));
    }

    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      add(p.join(home, 'Documents', 'FrontPorchAI', 'KoboldManager', kDirName));
      add(p.join(home, 'FrontPorchAI', 'KoboldManager', kDirName));
      // Beta install (producer may not write here yet — harmless if empty).
      add(
        p.join(home, 'Documents', 'FrontPorchAI-Beta', 'KoboldManager', kDirName),
      );
    }

    return out;
  }

  /// Parse every `*.json` under the candidate dirs. Corrupt / unknown schema
  /// files are skipped (never deleted). Sorted by [PorchMemoryBundle.finishedAt]
  /// ascending (oldest first); missing timestamps sort last.
  ///
  /// De-dupes by [PorchMemoryBundle.gameId] when the same file is visible
  /// under multiple path candidates (first wins = live root preferred).
  static Future<List<PorchMemoryBundle>> listPendingBundles({
    String? fpaRootPath,
    List<Directory>? dirsOverride,
  }) async {
    final dirs = dirsOverride ?? detectMailboxDirs(fpaRootPath: fpaRootPath);
    final byGameId = <String, PorchMemoryBundle>{};

    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      List<FileSystemEntity> entities;
      try {
        entities = await dir.list().toList();
      } catch (e) {
        debugPrint('[PorchMemories] list ${dir.path} failed: $e');
        continue;
      }
      for (final entity in entities) {
        if (entity is! File) continue;
        if (!entity.path.toLowerCase().endsWith('.json')) continue;
        if (entity.path.toLowerCase().endsWith('.bad')) continue;
        try {
          final text = await entity.readAsString();
          if (text.trim().isEmpty) continue;
          final decoded = jsonDecode(text);
          final bundle = PorchMemoryBundle.tryParse(
            decoded,
            sourcePath: entity.path,
          );
          if (bundle == null) {
            debugPrint(
              '[PorchMemories] skip unreadable/unsupported: ${entity.path}',
            );
            continue;
          }
          byGameId.putIfAbsent(bundle.gameId, () => bundle);
        } catch (e) {
          debugPrint('[PorchMemories] parse failed ${entity.path}: $e');
        }
      }
    }

    final list = byGameId.values.toList()
      ..sort((a, b) {
        final af = a.finishedAt;
        final bf = b.finishedAt;
        if (af == null && bf == null) return a.gameId.compareTo(b.gameId);
        if (af == null) return 1;
        if (bf == null) return -1;
        return af.compareTo(bf);
      });
    return list;
  }

  /// Delete a fully consumed bundle file. Failures log only.
  static Future<void> deleteBundleFile(PorchMemoryBundle bundle) async {
    final path = bundle.sourcePath;
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        debugPrint('[PorchMemories] deleted consumed bundle $path');
      }
    } catch (e) {
      debugPrint('[PorchMemories] delete failed $path: $e');
    }
  }
}
