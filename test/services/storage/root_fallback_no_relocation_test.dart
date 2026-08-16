// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// StorageService used to RELOCATE itself to Documents/FrontPorchAI whenever it
// could not create one of the six data subdirectories under the persisted root.
// That was worse than the failure it was recovering from.
//
// By the time StorageService is built, main() has already opened
// `<persisted root>/KoboldManager/front_porch.db` (a failure there ends the
// launch in DbInitErrorApp), so reaching the fallback proves the persisted root
// took the database. Relocating then split the app in two: the library listed
// the database's rows while every portrait, chat file, world and background
// resolved under a different tree that has none of them — a full-looking
// library with blank avatars, and no warning anywhere, because the
// `rootUnavailableFellBack` flag had no reader.
//
// Now the failure is swallowed and recorded (rootDirectoriesUnavailable) and
// the root stays put, so files and rows stay on one root.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/services/storage_service.dart';

late Directory _fakeDocs;

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return _fakeDocs.path;
        }
        return null;
      });
}

/// Both key shapes: stable builds read `root_path`, pre-release builds read
/// `root_path_beta` (beta isolation), and this test must pin the behaviour on
/// whichever channel it is compiled for.
Map<String, Object> _rootPrefs(String value) => {
  'root_path': value,
  'beta_root_path': value,
  'root_path_beta': value,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _fakeDocs = Directory.systemTemp.createTempSync('fpai_docs_');
    _setupPathProviderMock();
  });

  test('a subdirectory that cannot be created does not move the root', () async {
    final root = Directory.systemTemp.createTempSync('fpai_root_');
    // A plain FILE sitting where the `chats` folder belongs — the stray-file /
    // per-folder-ACL shape of the failure, reproducible on all three desktops.
    File('${root.path}${Platform.pathSeparator}chats').writeAsStringSync('x');

    SharedPreferences.setMockInitialValues(_rootPrefs(root.path));
    final service = StorageService();
    addTearDown(service.dispose);

    await service.initialized.timeout(const Duration(seconds: 10));

    // The whole point: still the persisted root, NOT the documents fallback.
    expect(service.rootPath, root.path);
    expect(service.binDir.path.startsWith(root.path), isTrue);
    expect(service.rootDirectoriesUnavailable, isTrue);
    // The folders that COULD be made were still made, on the same root.
    expect(Directory('${root.path}/worlds').existsSync(), isTrue);
    expect(Directory('${root.path}/groups').existsSync(), isTrue);
  });

  test('a healthy root reports no directory problem', () async {
    final root = Directory.systemTemp.createTempSync('fpai_root_ok_');
    SharedPreferences.setMockInitialValues(_rootPrefs(root.path));
    final service = StorageService();
    addTearDown(service.dispose);

    await service.initialized.timeout(const Duration(seconds: 10));

    expect(service.rootPath, root.path);
    expect(service.rootDirectoriesUnavailable, isFalse);
    expect(Directory('${root.path}/chats').existsSync(), isTrue);
  });
}
