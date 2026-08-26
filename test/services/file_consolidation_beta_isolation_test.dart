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
      expect(
        FileConsolidationService.isAlreadyNested('FrontPorchAI-Beta'),
        isTrue,
      );
      expect(FileConsolidationService.isAlreadyNested('FrontPorchAI'), isTrue);
      expect(FileConsolidationService.isAlreadyNested('Documents'), isFalse);
    });
  });

  group('consolidate()', () {
    test(
      'a pre-release build never touches the stable root or its data',
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
          reason:
              'nothing may be aggregated under the stable root by a beta run',
        );
      },
    );

    test(
      'a stable build still consolidates its own scattered folders',
      () async {
        // The wrap exists for files dumped in the OS Documents folder, not
        // for a folder the user already picked as the data directory.
        Directory(p.join(docs.path, 'chats')).createSync(recursive: true);
        SharedPreferences.setMockInitialValues({'root_path': docs.path});

        await FileConsolidationService.consolidate(preRelease: false);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('root_path'), p.join(docs.path, 'FrontPorchAI'));
        expect(
          Directory(p.join(docs.path, 'FrontPorchAI', 'chats')).existsSync(),
          isTrue,
        );
      },
    );

    test(
      'a user-chosen data directory is not wrapped in FrontPorchAI (#206)',
      () async {
        // Settings → Data Directory writes the picked folder as the root.
        // The consolidator used to treat any basename other than FrontPorchAI
        // as "scattered Documents" and nest FrontPorchAI under it on the next
        // launch, leaving groups/ and custom_backgrounds behind.
        final custom = Directory(p.join(docs.path, '.frontporchai'))
          ..createSync(recursive: true);
        Directory(
          p.join(custom.path, 'KoboldManager'),
        ).createSync(recursive: true);
        Directory(p.join(custom.path, 'chats')).createSync(recursive: true);
        Directory(p.join(custom.path, 'groups')).createSync(recursive: true);
        Directory(
          p.join(custom.path, 'custom_backgrounds'),
        ).createSync(recursive: true);
        File(
          p.join(custom.path, 'groups', 'portrait.png'),
        ).writeAsStringSync('mine');
        SharedPreferences.setMockInitialValues({'root_path': custom.path});

        await FileConsolidationService.consolidate(preRelease: false);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('root_path'),
          custom.path,
          reason: 'the folder the user picked is the root — do not nest',
        );
        expect(
          Directory(p.join(custom.path, 'FrontPorchAI')).existsSync(),
          isFalse,
          reason: 'nothing may be aggregated under a user-chosen root',
        );
        expect(
          File(
            p.join(custom.path, 'groups', 'portrait.png'),
          ).readAsStringSync(),
          'mine',
          reason: 'group portraits stay where the move put them',
        );
        expect(Directory(p.join(custom.path, 'chats')).existsSync(), isTrue);
      },
    );

    test(
      'a pre-release build consolidates under its OWN root and key',
      () async {
        // Scatter in Documents (the only place the wrap still runs). A
        // user-chosen beta folder is left alone — same rule as #206.
        Directory(p.join(docs.path, 'chats')).createSync(recursive: true);
        SharedPreferences.setMockInitialValues({
          'root_path': p.join(docs.path, 'StableData'),
        });

        await FileConsolidationService.consolidate(preRelease: true);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('root_path_beta'),
          p.join(docs.path, 'FrontPorchAI-Beta'),
        );
        expect(
          prefs.getString('root_path'),
          p.join(docs.path, 'StableData'),
          reason: 'the stable key must be left alone',
        );
        expect(
          Directory(
            p.join(docs.path, 'FrontPorchAI-Beta', 'chats'),
          ).existsSync(),
          isTrue,
        );
      },
    );
  });
}
