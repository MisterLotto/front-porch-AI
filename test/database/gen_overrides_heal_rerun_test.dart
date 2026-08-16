// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// The v38→v39 heal deletes every key in sessions.generation_settings except
// the two output_sanitizer_* ones. That rule is only true BEFORE v39 shipped.
// Drift rewrites user_version even when an OLDER binary opens a NEWER database
// (a rollback, or the Windows beta+nightly pair that share one data folder),
// so the block can legally re-enter with from = 38 — and on that second pass
// it erases the per-chat temperature / repeat-penalty / DRY / stop-sequence
// overrides the user has deliberately set since. This drives exactly that
// sequence against a real database file.

import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File dbFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fpai_v39_rerun_');
    dbFile = File('${dir.path}/rollback.db');
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<String?> genSettingsOf(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          'SELECT generation_settings AS g FROM sessions WHERE id = ?',
          variables: [Variable(id)],
        )
        .getSingle();
    return row.data['g'] as String?;
  }

  test('a rollback and re-upgrade keeps per-chat sampler overrides', () async {
    // 1. A current-schema database with a per-chat override the user set.
    var db = AppDatabase.forReunification(dbFile);
    await db.insertSession(SessionsCompanion.insert(id: 'chat-1'));
    await db.customUpdate(
      'UPDATE sessions SET generation_settings = ? WHERE id = ?',
      variables: [
        Variable('{"temperature":0.62,"repeat_penalty":1.08}'),
        Variable('chat-1'),
      ],
    );
    expect(await genSettingsOf(db, 'chat-1'), contains('temperature'));

    // 2. An older binary opens it: drift stamps user_version back down.
    await db.customStatement('PRAGMA user_version = 38');
    await db.close();

    // 3. The newer build launches again — onUpgrade(38 → current) re-enters
    //    the v39 block on a database that was healed long ago.
    db = AppDatabase.forReunification(dbFile);
    final after = await genSettingsOf(db, 'chat-1');
    await db.close();

    expect(
      after,
      contains('temperature'),
      reason: 'the v39 heal must not re-run on a database already past v39',
    );
    expect(after, contains('repeat_penalty'));
  });
}
