// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards the promise plant-dedup (field incident, 2026-08-04: the eval
// re-planted already-KEPT commitments as "new" — the same pledge landed 4x
// in one evening, 9 promise cards + 8 milestone twins saturating one chat's
// journal with promise talk). Contract: a NEW verdict that substantially
// duplicates ANY existing promise card (open or resolved) is skipped.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isDuplicatePromise (pure)', () {
    test('re-worded restatements of the same pledge are duplicates', () {
      expect(
        PromiseDebtService.isDuplicatePromise(
          'Nadia will film the garden timelapse tomorrow and water the roses',
          ['Nadia promised to film a timelapse of the garden and water every rose'],
        ),
        isTrue,
      );
    });

    test('genuinely different commitments are not duplicates', () {
      expect(
        PromiseDebtService.isDuplicatePromise(
          'bring jam cookies to the coffee shop on Friday',
          ['teach Sam to bake sourdough bread on Sunday'],
        ),
        isFalse,
      );
    });
  });

  group('evaluateTurn plant path', () {
    late AppDatabase db;
    late PromiseDebtService service;
    late String scriptedVerdict;

    setUp(() {
      db = AppDatabase.forTesting();
      scriptedVerdict = 'NONE';
      service = PromiseDebtService(
        journalStore: JournalStore(getDb: () => db),
        fireEval: (_) async => scriptedVerdict,
        getMaxCards: () => 30,
        applyTrustDelta: (_) {},
        applyBondDelta: (_) {},
      );
    });

    tearDown(() => db.close());

    Future<void> turn(String exchange) => service.evaluateTurn(
      sessionId: 's1',
      characterId: 'c1',
      characterName: 'Nadia',
      userName: 'Sam',
      recentExchange: exchange,
    );

    test('a NEW that duplicates a resolved promise is not re-planted',
        () async {
      // Plant + resolve the original pledge.
      scriptedVerdict = 'NEW char film the garden timelapse tomorrow';
      await turn('Nadia: I promise I will film the timelapse tomorrow.');
      final planted = await service.listOpen('s1', 'c1');
      expect(planted, hasLength(1));
      await service.resolveManually(
        sessionId: 's1',
        characterId: 'c1',
        cardId: planted.single.cardId,
        kept: true,
      );

      // The model re-reports the settled pledge as new — must be skipped.
      scriptedVerdict = 'NEW char film the garden timelapse tomorrow';
      await turn('Nadia: remember, the timelapse tomorrow, I promised!');
      expect(
        await service.listOpen('s1', 'c1'),
        isEmpty,
        reason: 'a settled commitment re-reported as NEW must not re-plant — '
            'this exact loop put 9 promise cards in one real chat',
      );
    });

    test('a genuinely new commitment still plants normally', () async {
      scriptedVerdict = 'NEW user bring jam cookies on Friday';
      await turn('Sam: I promise to bring jam cookies on Friday.');
      expect(await service.listOpen('s1', 'c1'), hasLength(1));
    });
  });
}
