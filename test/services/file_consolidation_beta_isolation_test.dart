// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Beta/nightly and stable share ONE SharedPreferences store — that is why
// StorageService prefixes its keys and why both it and AppDatabase pick
// 'root_path_beta' vs 'root_path' by channel. The startup consolidator did
// not: it read the STABLE key on every build and then physically MOVED
// KoboldManager (the live database + backups), chats, worlds and models under
// the root it found, rewriting the stable pref on the way out. Installing the
// nightly next to a stable install with a custom data folder relocated the
// stable installation's data on the nightly's first launch.
//
// `preRelease:` is passed explicitly because a unit test cannot rebuild the app
// with a beta version string.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/services/file_consolidation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory appSupport;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('fpai_consolidate_docs_');
    appSupport = Directory.systemTemp.createTempSync('fpai_consolidate_supp_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
              return docs.path;
            case 'getApplicationSupportDirectory':
              return appSupport.path;
          }
          return null;
        });
  });

  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    if (appSupport.existsSync()) appSupport.deleteSync(recursive: true);
  });

  group('key selection', () {
    test('the channel keys and folders match the rest of the app', () {
      expect(
        FileConsolidationService.rootPathKeyFor(preRelease: false),
        'root_path',
      );
      expect(
        FileConsolidationService.rootPathKeyFor(preRelease: true),
        'root_path_beta',
      );
      expect(
        FileConsolidationService.rootFolderNameFor(preRelease: true),
        'FrontPorchAI-Beta',
      );
      // A beta root must be recognised as already nested, or every beta launch
      // would bury it one level deeper.
      expect(FileConsolidationService.isAlreadyNested('FrontPorchAI-Beta'),
          isTrue);
      expect(FileConsolidationService.isAlreadyNested('FrontPorchAI'), isTrue);
      expect(FileConsolidationService.isAlreadyNested('Documents'), isFalse);
    });
  });

  group('consolidate()', () {
    test('a pre-release build never touches the stable root or its data',
        () async {
      final stableRoot = Directory(p.join(docs.path, 'FPAI'))
        ..createSync(recursive: true);
      final db = Directory(p.join(stableRoot.path, 'KoboldManager'))
        ..createSync(recursive: true);
      File(p.join(db.path, 'front_porch.db')).writeAsStringSync('stable db');
      Directory(p.join(stableRoot.path, 'chats')).createSync(recursive: true);

      SharedPreferences.setMockInitialValues({'root_path': stableRoot.path});

      await FileConsolidationService.consolidate(preRelease: true);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('root_path'),
        stableRoot.path,
        reason: 'the beta build must not rewrite the stable root pref',
      );
      expect(
        File(p.join(db.path, 'front_porch.db')).existsSync(),
        isTrue,
        reason: 'the stable database must stay exactly where stable left it',
      );
      expect(
        Directory(p.join(stableRoot.path, 'chats')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(stableRoot.path, 'FrontPorchAI')).existsSync(),
        isFalse,
        reason: 'nothing may be aggregated under the stable root by a beta run',
      );
    });

    test('a stable build still consolidates its own scattered folders',
        () async {
      final root = Directory(p.join(docs.path, 'FPAI'))
        ..createSync(recursive: true);
      Directory(p.join(root.path, 'chats')).createSync(recursive: true);
      SharedPreferences.setMockInitialValues({'root_path': root.path});

      await FileConsolidationService.consolidate(preRelease: false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('root_path'), p.join(root.path, 'FrontPorchAI'));
      expect(
        Directory(p.join(root.path, 'FrontPorchAI', 'chats')).existsSync(),
        isTrue,
      );
    });

    test('a pre-release build consolidates under its OWN root and key',
        () async {
      final betaRoot = Directory(p.join(docs.path, 'BetaData'))
        ..createSync(recursive: true);
      Directory(p.join(betaRoot.path, 'chats')).createSync(recursive: true);
      SharedPreferences.setMockInitialValues({
        'root_path': p.join(docs.path, 'StableData'),
        'root_path_beta': betaRoot.path,
      });

      await FileConsolidationService.consolidate(preRelease: true);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('root_path_beta'),
        p.join(betaRoot.path, 'FrontPorchAI-Beta'),
      );
      expect(
        prefs.getString('root_path'),
        p.join(docs.path, 'StableData'),
        reason: 'the stable key must be left alone',
      );
      expect(
        Directory(p.join(betaRoot.path, 'FrontPorchAI-Beta', 'chats'))
            .existsSync(),
        isTrue,
      );
    });
  });
}
