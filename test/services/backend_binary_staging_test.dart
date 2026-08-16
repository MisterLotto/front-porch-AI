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

// THE ENGINE FILE ONLY EVER APPEARS WHOLE.
//
// The KoboldCpp download used to stream straight onto `koboldcpp(.exe)`. Quit
// the app (or lose power) at 60% and a 700 MB stub sat where the engine lives
// — and checkBackendAvailability() only tests existence, so the app reported
// "Ready" and Start spawned a corrupt binary with no explanation. The download
// now writes a sibling `.part` and calls [BackendManager.swapStagedBinary],
// which is the moment the file becomes live.
//
// These run against the real filesystem: renames are what the bug was about.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/backend_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fpai_binstage_');
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('a staged download becomes the live binary and leaves no .part behind',
      () async {
    final live = p.join(dir.path, 'koboldcpp');
    final staged = File('$live.part')..writeAsStringSync('WHOLE-BINARY');

    await BackendManager.swapStagedBinary(staged, live);

    expect(File(live).readAsStringSync(), 'WHOLE-BINARY');
    expect(
      staged.existsSync(),
      isFalse,
      reason: 'the staging file is renamed, not copied',
    );
  });

  test('an update replaces the previous engine in one move', () async {
    final live = p.join(dir.path, 'koboldcpp');
    File(live).writeAsStringSync('OLD-ENGINE-v1');
    final staged = File('$live.part')..writeAsStringSync('NEW-ENGINE-v2');

    await BackendManager.swapStagedBinary(staged, live);

    expect(File(live).readAsStringSync(), 'NEW-ENGINE-v2');
    expect(staged.existsSync(), isFalse);
  });

  test('an unreplaceable target fails in plain words and keeps the download',
      () async {
    // A DIRECTORY at the live path is the portable stand-in for "the OS will
    // not let this file be replaced" (on Windows that is a running .exe).
    final live = p.join(dir.path, 'koboldcpp');
    Directory(live).createSync();
    File(p.join(live, 'occupied.txt')).writeAsStringSync('keeps it non-empty');
    final staged = File('$live.part')..writeAsStringSync('NEW-ENGINE-v2');

    await expectLater(
      BackendManager.swapStagedBinary(staged, live),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(
            contains('KoboldCpp is still running'),
            contains('Press Stop'),
            isNot(contains('errno')),
          ),
        ),
      ),
    );
    expect(
      staged.existsSync(),
      isTrue,
      reason: 'a failed swap must not throw away a finished download',
    );
  });
}
