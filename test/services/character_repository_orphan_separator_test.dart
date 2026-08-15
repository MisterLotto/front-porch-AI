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

// THE ORPHAN SWEEP MUST NOT DEPEND ON PATH SPELLING.
//
// `_resolveImagePath` builds every loaded card's imagePath with a literal '/'
// while `Directory.list()` hands back the PLATFORM separator. On Windows that
// is '\', so the sweep's referenced-path set and the listing could never
// intersect: every live portrait was classified as an orphan and deleted by
// the reunification / stable-DB-import rebind. The sibling suite
// (character_repository_media_test.dart) builds its fixture with p.join and
// runs on POSIX, where both spellings coincide — it can never catch this.
//
// This test transplants the Windows failure onto POSIX by storing the
// referenced path with backslashes, which no POSIX listing will ever produce.
// Red-proved: comparing whole path strings again makes the "referenced PNG
// survives" expectation fail (the file is gone and the count is 2).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart' show AppDatabase;
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/storage_service.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_orphan_sep_').path;
        }
        return null;
      });
}

Uint8List _realPng({int seed = 0}) {
  final image = img.Image(width: 16, height: 16);
  img.fill(image, color: img.ColorRgb8(20 + seed, 40 + seed, 60 + seed));
  return img.encodePng(image);
}

Future<void> _waitUntilNotLoading(CharacterRepository r) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (r.isLoading) {
    if (DateTime.now().isAfter(deadline)) {
      fail('loadCharacters did not complete in time');
    }
    await Future.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a referenced portrait whose stored path uses the other separator is kept '
    '(the Windows wipe), while a genuine orphan is still deleted',
    () async {
      _setupPathProviderMock();
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.initialized;
      final db = AppDatabase.forTesting();
      final repo = CharacterRepository(db, storage);
      await _waitUntilNotLoading(repo);

      final charDir = storage.charactersDir;
      await charDir.create(recursive: true);

      // Referenced, but spelled the way Windows spells it — a listing on this
      // platform can never produce this exact string.
      final onDisk = p.join(charDir.path, 'kept_windows_style.png');
      await File(onDisk).writeAsBytes(_realPng(seed: 1));
      final card = CharacterCard(
        name: 'Kept',
        imagePath: '${charDir.path.replaceAll('/', r'\')}\\kept_windows_style.png',
      );
      await repo.addCharacter(card);

      final orphan = p.join(charDir.path, 'nobody_points_here.png');
      await File(orphan).writeAsBytes(_realPng(seed: 2));

      final deleted = await repo.cleanOrphanedPngs();

      expect(
        File(onDisk).existsSync(),
        isTrue,
        reason: 'a live portrait must never be deleted over path spelling',
      );
      expect(File(orphan).existsSync(), isFalse);
      expect(deleted, 1);

      await db.close();
    },
  );
}
