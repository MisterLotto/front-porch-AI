// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Unit tests for the pure avatar-gallery ("looks") logic — filtering,
// plain-chat display resolution, and chevron flipping. Storage-agnostic (the
// per-chat selection is an input), so no DB/session dependency.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/avatar_image.dart';
import 'package:front_porch_ai/services/avatar_gallery.dart';

AvatarImage _look(String id, {int order = 0}) => AvatarImage(
  id: id,
  characterId: 'c1',
  filename: '$id.png',
  label: AvatarImage.lookLabel,
  displayOrder: order,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);

AvatarImage _expr(String id, String emotion, {int order = 0}) => AvatarImage(
  id: id,
  characterId: 'c1',
  filename: '$id.png',
  label: emotion,
  displayOrder: order,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);

void main() {
  group('AvatarImage look tagging + folder resolution', () {
    test('isLook + subfolder distinguish looks from expressions', () {
      expect(_look('a').isLook, isTrue);
      expect(_look('a').subfolder, 'looks');
      expect(_expr('b', 'joy').isLook, isFalse);
      expect(_expr('b', 'joy').subfolder, 'avatars');
      // A null-label (legacy) avatar is NOT a look — the sentinel is required.
      final legacy = AvatarImage(
        id: 'x',
        characterId: 'c1',
        filename: 'x.png',
        displayOrder: 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(legacy.isLook, isFalse);
      expect(legacy.subfolder, 'avatars');
    });

    test('resolveFile picks looks/ vs avatars/ off the character base folder', () {
      expect(
        _look('a').resolveFile('/chars/Carly').path,
        '/chars/Carly/looks/a.png',
      );
      expect(
        _expr('b', 'joy').resolveFile('/chars/Carly').path,
        '/chars/Carly/avatars/b.png',
      );
    });
  });

  group('looksFrom / expressionsFrom partitioning', () {
    final mixed = [
      _expr('e1', 'joy', order: 0),
      _look('l2', order: 2),
      _expr('e2', 'anger', order: 1),
      _look('l1', order: 1),
    ];

    test('looksFrom keeps only looks, ordered by displayOrder', () {
      final looks = looksFrom(mixed);
      expect(looks.map((l) => l.id), ['l1', 'l2']);
    });

    test('expressionsFrom keeps only expressions (looks partitioned out)', () {
      final exprs = expressionsFrom(mixed);
      expect(exprs.map((e) => e.id).toSet(), {'e1', 'e2'});
      expect(exprs.every((e) => !e.isLook), isTrue);
    });

    test('null list → empty', () {
      expect(looksFrom(null), isEmpty);
      expect(expressionsFrom(null), isEmpty);
    });
  });

  group('resolveLookDisplay (plain-chat portrait choice)', () {
    final looks = [_look('l1', order: 0), _look('l2', order: 1)];

    test('expressions ON → passthrough, no look, no chevrons', () {
      final d = resolveLookDisplay(
        expressionEnabled: true,
        looks: looks,
        hasImagePath: true,
        selectedLookId: 'l1',
      );
      expect(d, LookDisplay.passthrough);
      expect(d.look, isNull);
      expect(d.showChevrons, isFalse);
    });

    test('expressions OFF + valid selection → that look; chevrons when >1', () {
      final d = resolveLookDisplay(
        expressionEnabled: false,
        looks: looks,
        hasImagePath: true,
        selectedLookId: 'l2',
      );
      expect(d.look?.id, 'l2');
      expect(d.showChevrons, isTrue);
    });

    test('stale selection → falls back to imagePath (null look), not blank', () {
      final d = resolveLookDisplay(
        expressionEnabled: false,
        looks: looks,
        hasImagePath: true,
        selectedLookId: 'deleted-id',
      );
      expect(d.look, isNull); // caller shows imagePath
      expect(d.showChevrons, isTrue);
    });

    test('no selection + no imagePath → first look', () {
      final d = resolveLookDisplay(
        expressionEnabled: false,
        looks: looks,
        hasImagePath: false,
      );
      expect(d.look?.id, 'l1');
    });

    test('single look → no chevrons', () {
      final d = resolveLookDisplay(
        expressionEnabled: false,
        looks: [_look('only')],
        hasImagePath: true,
        selectedLookId: 'only',
      );
      expect(d.showChevrons, isFalse);
    });
  });

  group('flipLook (chevron navigation)', () {
    final looks = [_look('a'), _look('b'), _look('c')];

    test('next / prev / wrap', () {
      expect(flipLook(looks, 'a', 1), 'b');
      expect(flipLook(looks, 'c', 1), 'a'); // wrap forward
      expect(flipLook(looks, 'a', -1), 'c'); // wrap backward
    });

    test('current isn\'t a look (imagePath showing) → step in from the end', () {
      expect(flipLook(looks, null, 1), 'a'); // forward → first
      expect(flipLook(looks, null, -1), 'c'); // backward → last
    });

    test('no looks → null', () {
      expect(flipLook(const [], 'x', 1), isNull);
    });
  });
}
