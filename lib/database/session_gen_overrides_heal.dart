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

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

/// The `sessions.generation_settings` JSON keys that survive the v39 heal.
///
/// The output-sanitizer keys are the ONLY per-chat generation fields that
/// did not exist while the generation-settings bleed bug was live (they
/// shipped in the same PR that fixed the bleed), so a stored value can only
/// have been set intentionally by the user. Every other key in that column
/// may be bled-in junk from another chat — see [healBledSessionGenOverrides].
const Set<String> kPostBleedGenSettingsKeys = {
  'output_sanitizer_enabled',
  'output_sanitizer_rules',
};

/// One-time v39 data heal for the per-chat generation-settings bleed.
///
/// Before the bleed fix, `_saveChat` persisted whatever
/// `ChatGenerationSettings` happened to be in memory into EVERY session row
/// it saved — so any user who ever touched the per-chat Generation sliders
/// had those overrides silently copied into unrelated chats' rows. The junk
/// sat inert because the common open path (`_loadLastSession`) never read
/// the column. The bleed fix made that path load the column, which activated
/// the stale rows: sampler overrides (repeat penalty, DRY, temperature,
/// stop sequences) the user never set for that chat silently shadowed their
/// global settings, and models started looping / regurgitating earlier
/// messages with no visible cause.
///
/// Bled rows are indistinguishable from intentionally-set ones, so this
/// clears every bleed-era key from every session row, keeping only
/// [kPostBleedGenSettingsKeys]. Unparseable JSON is reset to `{}` (the
/// loader already treated it as empty). Returns the number of rows changed.
///
/// Runs from the schema v38→v39 `onUpgrade` block; also reusable by tests.
/// Takes [DatabaseConnectionUser] (not AppDatabase) so this file has no
/// import cycle with database.dart.
Future<int> healBledSessionGenOverrides(DatabaseConnectionUser db) async {
  final rows = await db
      .customSelect(
        'SELECT id, generation_settings FROM sessions '
        'WHERE generation_settings IS NOT NULL '
        "AND generation_settings != '' AND generation_settings != '{}'",
      )
      .get();

  int healed = 0;
  for (final row in rows) {
    final id = row.read<String>('id');
    final raw = row.read<String>('generation_settings');

    String cleaned;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        decoded.removeWhere((k, _) => !kPostBleedGenSettingsKeys.contains(k));
        cleaned = jsonEncode(decoded);
      } else {
        cleaned = '{}';
      }
    } catch (e) {
      debugPrint('[DB] v39 heal: unparseable gen settings on session $id: $e');
      cleaned = '{}';
    }

    if (cleaned == raw) continue;
    await db.customUpdate(
      'UPDATE sessions SET generation_settings = ? WHERE id = ?',
      variables: [Variable(cleaned), Variable(id)],
    );
    healed++;
  }
  return healed;
}
