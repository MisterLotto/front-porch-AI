// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// The always-on schema repair is the ONLY remedy for a migration ALTER that
// failed and was swallowed (`try { ALTER ... } catch (_) {}` — the ladder is
// byte-verbatim, so those catches cannot be removed). A column that is on the
// ladder but missing from the repair list is therefore unrecoverable: Drift
// names it in the generated SELECT, so the chat load throws "no such column"
// forever. That has already happened twice in this codebase (message_embeddings
// memory_type, and the story-clock/worlds_initialized set).
//
// This pins the invariant mechanically rather than by naming today's columns:
// every column an ALTER adds to a table the repair covers must be in the
// repair's list, unless the live schema no longer has that column at all
// (sessions.relationship_enabled was added in v14 and later removed).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';

/// Extracts the `columnsToEnsure` map literal as {table: {column names}}.
Map<String, Set<String>> _parseRepairList(String source) {
  final start = source.indexOf('columnsToEnsure = {');
  expect(start, greaterThan(0), reason: 'columnsToEnsure literal not found');
  var depth = 0;
  var end = start;
  for (var i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) {
        end = i;
        break;
      }
    }
  }
  final block = source.substring(start, end);
  final tableLine = RegExp(r"^\s*'(\w+)':\s*\[");
  final colLine = RegExp("^\\s*['\"]([a-z_]+) ");
  final out = <String, Set<String>>{};
  String? current;
  for (final line in block.split('\n')) {
    final t = tableLine.firstMatch(line);
    if (t != null) {
      current = t.group(1);
      out[current!] = <String>{};
      continue;
    }
    final c = colLine.firstMatch(line);
    if (c != null && current != null) out[current]!.add(c.group(1)!);
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every ladder-added column of a repaired table is in the repair list',
      () async {
    final ladder =
        await File('lib/database/database.migrations.dart').readAsString() +
            await File(
              'lib/database/database.migrations.data.dart',
            ).readAsString();
    final repairSource =
        await File('lib/database/database.repair.dart').readAsString();

    final repaired = _parseRepairList(repairSource);
    expect(repaired.keys, contains('sessions'));
    expect(repaired.keys, contains('characters'));

    // The live schema, straight from Drift — not a second text parse.
    final db = AppDatabase.forTesting();
    final live = <String, Set<String>>{
      for (final t in db.allTables)
        t.actualTableName: t.$columns.map((c) => c.name).toSet(),
    };
    await db.close();

    final missing = <String>[];
    for (final m in RegExp(
      r'ALTER TABLE (\w+) ADD COLUMN (\w+)',
    ).allMatches(ladder)) {
      final table = m.group(1)!;
      final column = m.group(2)!;
      final covered = repaired[table];
      if (covered == null) continue; // repair does not claim this table
      if (!(live[table]?.contains(column) ?? false)) continue; // column dropped
      if (!covered.contains(column)) missing.add('$table.$column');
    }

    expect(
      missing,
      isEmpty,
      reason: 'these columns can never be healed after a swallowed ALTER',
    );
  });
}
