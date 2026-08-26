// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// wear("nothing") must not mint a garment. Same class as wear("clothes")
// minting a literal item named clothes (2026-08-11). Nude is remove, not wear.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/pockets.dart';

PocketOpReport op(PocketOpKind kind, String item) =>
    PocketOpReport(kind: kind, item: item);

void main() {
  test('wear nothing on a dressed character undresses, it does not mint', () {
    final p = Pockets(
      worn: [
        const PocketItem('white sundress with red and pink accents'),
        const PocketItem('white panties'),
      ],
    );
    final r = applyPocketOps(p, [op(PocketOpKind.wear, 'nothing')]);
    expect(p.worn, isEmpty);
    expect(
      [for (final e in p.setAside) e.item.name],
      ['white sundress with red and pink accents', 'white panties'],
    );
    expect(r, isNot(contains('put on: nothing')));
    expect(r, contains('took off: white panties'));
  });

  test('wear nothing when already nude is a no-op', () {
    final p = Pockets();
    final r = applyPocketOps(p, [op(PocketOpKind.wear, 'naked')]);
    expect(r, isEmpty);
    expect(p.worn, isEmpty);
  });

  test('named removes then wear nothing does not mint a leftover garment', () {
    final p = Pockets(
      worn: [
        const PocketItem('white sundress with red and pink accents'),
        const PocketItem('white panties'),
      ],
    );
    final r = applyPocketOps(p, [
      op(PocketOpKind.remove, 'white sundress with red and pink accents'),
      op(PocketOpKind.remove, 'white panties'),
      op(PocketOpKind.wear, 'nothing'),
    ]);
    expect(p.worn, isEmpty, reason: 'the screenshot: Wearing "nothing"');
    expect(r, isNot(contains('put on: nothing')));
    expect(
      [for (final e in p.setAside) e.item.name],
      ['white sundress with red and pink accents', 'white panties'],
    );
  });

  test('editor save drops a wearing chip named nothing', () {
    expect(
      Pockets.cardJsonFrom(worn: ['nothing', 'red sundress'], carrying: []),
      {
        'worn': [
          {'name': 'red sundress'},
        ],
        'carrying': [],
      },
    );
  });

  test('bare feet is a real item, bare alone is not', () {
    expect(isEmptyWardrobeRef('nothing'), isTrue);
    expect(isEmptyWardrobeRef('nude'), isTrue);
    expect(isEmptyWardrobeRef('bare'), isTrue);
    expect(isEmptyWardrobeRef('bare feet'), isFalse);
    final p = Pockets();
    applyPocketOps(p, [op(PocketOpKind.wear, 'bare feet')]);
    expect([for (final i in p.worn) i.name], ['bare feet']);
  });
}
