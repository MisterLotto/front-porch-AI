// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// The legacy-JSON migration swallows a per-item import failure and moves on,
// then marks itself complete and deletes the source files. A chat whose import
// threw was therefore erased from disk AND absent from the database, with no
// retry and no error the user ever saw. cleanupLegacyFiles must never delete a
// file the migration could not import — including on the unconditional
// every-launch call in main.dart, which is why the skip list is persisted.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/data_migration_service.dart';

class _FakeDocsDir extends PathProviderPlatform {
  _FakeDocsDir(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late File kept;
  late File doomed;
  late File world;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('fpai_legacy_cleanup_');
    PathProviderPlatform.instance = _FakeDocsDir(root.path);

    final chatDir = Directory('${root.path}/chats/Nina_123')
      ..createSync(recursive: true);
    kept = File('${chatDir.path}/1700000000.json')..writeAsStringSync('{"m":1}');
    doomed = File('${chatDir.path}/1700000001.json')
      ..writeAsStringSync('{"messages":[]}');

    final worldsDir = Directory('${root.path}/worlds')
      ..createSync(recursive: true);
    world = File('${worldsDir.path}/Ashford.json')..writeAsStringSync('{}');
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('a preserved file survives cleanup while its siblings are deleted',
      () async {
    SharedPreferences.setMockInitialValues({});

    await DataMigrationService.cleanupLegacyFiles(preserve: {kept.path});

    expect(kept.existsSync(), isTrue,
        reason: 'the only copy of an un-imported chat must stay on disk');
    expect(doomed.existsSync(), isFalse);
    expect(world.existsSync(), isFalse);
    // A preserved file also keeps its character directory alive.
    expect(Directory('${root.path}/chats/Nina_123').existsSync(), isTrue);
  });

  test('the every-launch call with no arguments honours the persisted list',
      () async {
    // main.dart calls cleanupLegacyFiles() unconditionally on every launch,
    // long after the DataMigrationService instance is gone. Without the
    // persisted skip list, launch 2 deletes exactly what launch 1 spared.
    SharedPreferences.setMockInitialValues({
      'db_migration_unimported_files': [kept.path],
    });

    await DataMigrationService.cleanupLegacyFiles();

    expect(kept.existsSync(), isTrue);
    expect(doomed.existsSync(), isFalse);
  });
}
