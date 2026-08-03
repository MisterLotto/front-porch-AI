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

// Pins the file-surgery half of the corrupt-settings self-heal: the broken
// shared_preferences.json must be MOVED aside (kept for diagnosis), never
// deleted, and a missing or immovable file must return false rather than
// throw — startup calls this before any error UI exists.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:front_porch_ai/services/prefs_recovery.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('prefs_recovery_test');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('PrefsRecovery.moveCorruptFileAside', () {
    test('moves a NUL-filled file to .corrupt and reports true', () async {
      final file = File(p.join(tmp.path, 'shared_preferences.json'));
      // The field-reported corruption shape: all NUL bytes after power loss.
      await file.writeAsBytes(List.filled(256, 0));

      final moved = await PrefsRecovery.moveCorruptFileAside(file);

      expect(moved, isTrue);
      expect(await file.exists(), isFalse, reason: 'original must be gone');
      final backup = File('${file.path}.corrupt');
      expect(await backup.exists(), isTrue, reason: 'content kept aside');
      expect((await backup.readAsBytes()).length, 256);
    });

    test('replaces a stale .corrupt backup from an earlier incident', () async {
      final file = File(p.join(tmp.path, 'shared_preferences.json'));
      await file.writeAsString('new garbage');
      final backup = File('${file.path}.corrupt');
      await backup.writeAsString('old garbage');

      final moved = await PrefsRecovery.moveCorruptFileAside(file);

      expect(moved, isTrue);
      expect(await backup.readAsString(), 'new garbage');
    });

    test('returns false for a missing file instead of throwing', () async {
      final file = File(p.join(tmp.path, 'does_not_exist.json'));
      expect(await PrefsRecovery.moveCorruptFileAside(file), isFalse);
    });
  });
}
