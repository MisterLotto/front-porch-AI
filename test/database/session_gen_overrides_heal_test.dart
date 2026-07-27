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

// Tests for the schema v39 data heal (healBledSessionGenOverrides): the
// generation-settings bleed wrote stale per-chat sampler overrides into
// session rows the user never configured, and the bleed FIX activated them
// (models suddenly looping / repeating old messages). The heal must strip
// every bleed-era key, keep the post-bleed output_sanitizer_* keys, and
// leave clean rows untouched.

import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/database/session_gen_overrides_heal.dart';
import 'package:front_porch_ai/models/chat_generation_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertSession(String id, String? genSettings) async {
    await db.insertSession(
      SessionsCompanion.insert(id: id, generationSettings: Value(genSettings)),
    );
  }

  Future<String?> readGenSettings(String id) async {
    final row = await db
        .customSelect(
          'SELECT generation_settings FROM sessions WHERE id = ?',
          variables: [Variable(id)],
        )
        .getSingle();
    return row.read<String?>('generation_settings');
  }

  test('strips bleed-era sampler keys, keeps sanitizer keys', () async {
    await insertSession(
      's1',
      jsonEncode({
        'temperature': 0.4,
        'repeat_penalty': 1.0,
        'rep_pen_tokens': 64,
        'dry_multiplier': 0.0,
        'stop_sequences': <String>[],
        'output_sanitizer_enabled': true,
        'output_sanitizer_rules': [
          {'id': 1, 'find': 'foo', 'replace': 'bar'},
        ],
      }),
    );

    final healed = await healBledSessionGenOverrides(db);
    expect(healed, 1);

    final after =
        jsonDecode((await readGenSettings('s1'))!) as Map<String, dynamic>;
    expect(after.keys.toSet(), kPostBleedGenSettingsKeys);
    expect(after['output_sanitizer_enabled'], true);

    // The healed row must round-trip through the real model: samplers fall
    // back to global (null override), the sanitizer override survives.
    final settings = ChatGenerationSettings.fromJsonString(
      await readGenSettings('s1'),
    );
    expect(settings.temperature, isNull);
    expect(settings.repeatPenalty, isNull);
    expect(settings.dryMultiplier, isNull);
    expect(settings.stopSequences, isNull);
    expect(settings.outputSanitizerEnabled, true);
    expect(settings.outputSanitizerRules, hasLength(1));
  });

  test('row with only bleed-era keys becomes {}', () async {
    await insertSession('s1', jsonEncode({'temperature': 1.8, 'top_k': 5}));

    expect(await healBledSessionGenOverrides(db), 1);
    expect(await readGenSettings('s1'), '{}');
  });

  test('clean rows are untouched and not counted', () async {
    await insertSession('empty', '{}');
    await insertSession('nullrow', null);
    await insertSession(
      'sanitizer-only',
      jsonEncode({'output_sanitizer_enabled': false}),
    );

    expect(await healBledSessionGenOverrides(db), 0);
    expect(await readGenSettings('empty'), '{}');
    expect(await readGenSettings('nullrow'), isNull);
    expect(
      await readGenSettings('sanitizer-only'),
      jsonEncode({'output_sanitizer_enabled': false}),
    );
  });

  test('unparseable JSON is reset to {}', () async {
    await insertSession('corrupt', 'not json at all');
    await insertSession('wrong-shape', jsonEncode(['a', 'list']));

    expect(await healBledSessionGenOverrides(db), 2);
    expect(await readGenSettings('corrupt'), '{}');
    expect(await readGenSettings('wrong-shape'), '{}');
  });

  test('heals every poisoned row, not just the first', () async {
    for (var i = 0; i < 5; i++) {
      await insertSession('s$i', jsonEncode({'temperature': 0.1 * i + 0.1}));
    }
    expect(await healBledSessionGenOverrides(db), 5);
    for (var i = 0; i < 5; i++) {
      expect(await readGenSettings('s$i'), '{}');
    }
  });
}
