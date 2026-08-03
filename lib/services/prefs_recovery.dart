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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detects and self-heals a corrupt settings store at startup.
///
/// On Windows and Linux, shared_preferences keeps everything in a single
/// `shared_preferences.json` with no atomic-write or fsync protection, so a
/// crash or power loss mid-write can leave the file full of NUL bytes. The
/// next `SharedPreferences.getInstance()` then throws
/// `FormatException: Unexpected character (at character 1)` — and because
/// startup's very first prefs read happens inside the database-open guard,
/// the app died on the "couldn't open its database" screen with advice that
/// could never fix it (the field-reported failure this class exists for).
///
/// [healIfCorrupt] probes the store before anything else reads it; on the
/// corruption signature it moves the broken file aside (kept as
/// `shared_preferences.json.corrupt` for diagnosis) and retries once, so the
/// app boots with default settings instead of not booting at all. macOS uses
/// NSUserDefaults rather than this JSON file, so there is nothing to heal
/// there and the probe simply passes the error through to the startup guard.
class PrefsRecovery {
  PrefsRecovery._();

  /// True when this launch recovered from a corrupt settings file — settings
  /// were reset to defaults. main.dart shows a one-time notice so the reset
  /// (and a possibly forgotten custom storage folder) is never silent.
  static bool recovered = false;

  /// Probes SharedPreferences and heals the JSON store if it is corrupt.
  /// Never throws: if healing is impossible the original error simply
  /// resurfaces at the next `getInstance()` call, where the startup guard
  /// reports it accurately.
  static Future<void> healIfCorrupt() async {
    try {
      await SharedPreferences.getInstance();
      return;
    } on FormatException catch (e) {
      // The corruption signature. getInstance() clears its cached completer
      // on failure, so a retry after repair genuinely re-reads the file.
      debugPrint('[Prefs] settings file is corrupt: $e');
    } catch (e) {
      // Not a parse failure (permissions, platform channel, …) — moving the
      // file aside can't help, and might destroy a readable store.
      debugPrint('[Prefs] settings probe failed (not corruption): $e');
      return;
    }

    if (!Platform.isWindows && !Platform.isLinux) return;
    final File file;
    try {
      final dir = await getApplicationSupportDirectory();
      file = File(p.join(dir.path, 'shared_preferences.json'));
    } catch (e) {
      debugPrint('[Prefs] could not locate settings file: $e');
      return;
    }

    if (!await moveCorruptFileAside(file)) return;

    try {
      await SharedPreferences.getInstance();
      recovered = true;
      debugPrint(
        '[Prefs] recovered from corrupt settings — broken file kept at '
        '${file.path}.corrupt, defaults in use',
      );
    } catch (e) {
      debugPrint('[Prefs] settings still unreadable after recovery: $e');
    }
  }

  /// Moves [file] to `<name>.corrupt`, replacing any previous backup, so the
  /// broken content is preserved for diagnosis instead of deleted. Returns
  /// false (without throwing) when the file is missing or cannot be moved.
  /// Public and pure file I/O so tests can exercise it directly.
  static Future<bool> moveCorruptFileAside(File file) async {
    try {
      if (!await file.exists()) return false;
      final backup = File('${file.path}.corrupt');
      if (await backup.exists()) await backup.delete();
      await file.rename(backup.path);
      return true;
    } catch (e) {
      debugPrint('[Prefs] could not move corrupt settings file aside: $e');
      return false;
    }
  }
}
