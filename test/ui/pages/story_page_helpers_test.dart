// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards for two Porch Stories page helpers that shipped wrong:
//
//  • the Chat History badge counted `[EVENT N]` markers with a
//    double-escaped pattern inside a raw string, so it always read
//    "0 events distilled" no matter how many events the distiller produced;
//  • the scene export ran its file-name sanitizer over the WHOLE absolute
//    path, turning every separator into '_' so the .txt landed in the
//    process working directory instead of Documents.
//
// Both are pure functions now, so the wrong behaviour is directly assertable.

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:front_porch_ai/ui/pages/pages.dart'
    show distilledEventCount, storySceneExportPath;

void main() {
  group('distilledEventCount', () {
    test('counts the [EVENT N] markers the distiller writes', () {
      const timeline =
          '[EVENT 1] They met on the porch.\n'
          '[EVENT 2] She admitted the letter was hers.\n'
          '[EVENT 10] He left before dawn.';
      expect(distilledEventCount(timeline), 3);
    });

    test('an empty timeline is zero, prose without markers is zero', () {
      expect(distilledEventCount(''), 0);
      expect(
        distilledEventCount('EVENT 1 without brackets, and [EVENT] with no n'),
        0,
      );
    });
  });

  group('storySceneExportPath', () {
    test('keeps the directory intact and only sanitizes the file name', () {
      final path = storySceneExportPath(
        p.join('/Users', 'bob', 'Documents'),
        'My: Story',
        'Scene/1',
      );
      expect(p.dirname(path), p.join('/Users', 'bob', 'Documents'));
      expect(p.basename(path), 'My_ Story_Scene_1.txt');
      // The whole-path sanitizer produced a bare relative name — the bug that
      // wrote exports into the process CWD.
      expect(p.isAbsolute(path), isTrue);
    });

    test('a Windows-style directory keeps its drive and separators', () {
      final path = storySceneExportPath(r'C:\Users\bob\Documents', 'S', 'A');
      expect(path.startsWith(r'C:\Users\bob\Documents'), isTrue);
      expect(path.endsWith('S_A.txt'), isTrue);
      expect(path.contains('C__Users'), isFalse);
    });
  });
}
