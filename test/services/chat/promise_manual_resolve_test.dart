// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards PromiseDebtService.resolveManually — the diary "Mark kept / broken"
// escape hatch for fulfillments the post-turn eval missed. Contract: it
// routes through the SAME applier as automatic detection, so the status
// flips, the promise leaves the open list, the trust/bond deltas fire, and
// a milestone card is written.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late PromiseDebtService service;
  late int trustDelta;
  late int bondDelta;
  late bool salienceKicked;

  setUp(() {
    db = AppDatabase.forTesting();
    trustDelta = 0;
    bondDelta = 0;
    salienceKicked = false;
    service = PromiseDebtService(
      journalStore: JournalStore(getDb: () => db),
      // Scripted eval: plants one user promise on the first pass.
      fireEval: (_) async => 'NEW user bring the telescope on Friday',
      getMaxCards: () => 30,
      applyTrustDelta: (d) => trustDelta += d,
      applyBondDelta: (d) => bondDelta += d,
      onSalienceKick: () => salienceKicked = true,
    );
  });

  tearDown(() => db.close());

  Future<OpenPromise> plantOne() async {
    await service.evaluateTurn(
      sessionId: 's1',
      characterId: 'c1',
      characterName: 'Jennifer',
      userName: 'Sam',
      recentExchange: 'Sam: I promise I will bring the telescope on Friday.',
    );
    final open = await service.listOpen('s1', 'c1');
    expect(open, hasLength(1), reason: 'setup: the eval plants one promise');
    return open.single;
  }

  test('mark kept: closes the promise and applies the automatic-path deltas',
      () async {
    final promise = await plantOne();

    final ok = await service.resolveManually(
      sessionId: 's1',
      characterId: 'c1',
      cardId: promise.cardId,
      kept: true,
    );

    expect(ok, isTrue);
    expect(await service.listOpen('s1', 'c1'), isEmpty,
        reason: 'a kept promise must leave the open list — the injection '
            'and the every-turn eval both key off it');
    expect(trustDelta, PromiseDebtService.kKeptUserTrust,
        reason: 'manual resolution restores what the missed automatic '
            'detection should have applied');
    expect(bondDelta, PromiseDebtService.kKeptUserBond);
    expect(salienceKicked, isTrue,
        reason: 'kept/broken is journal/growth-salient, same as automatic');
  });

  test('mark broken applies the negative deltas', () async {
    final promise = await plantOne();
    await service.resolveManually(
      sessionId: 's1',
      characterId: 'c1',
      cardId: promise.cardId,
      kept: false,
    );
    expect(trustDelta, PromiseDebtService.kBrokenUserTrust);
    expect(bondDelta, PromiseDebtService.kBrokenUserBond);
  });

  test('unknown or already-resolved card returns false and changes nothing',
      () async {
    final promise = await plantOne();
    expect(
      await service.resolveManually(
        sessionId: 's1',
        characterId: 'c1',
        cardId: 'not-a-card',
        kept: true,
      ),
      isFalse,
    );
    await service.resolveManually(
      sessionId: 's1',
      characterId: 'c1',
      cardId: promise.cardId,
      kept: true,
    );
    final again = await service.resolveManually(
      sessionId: 's1',
      characterId: 'c1',
      cardId: promise.cardId,
      kept: true,
    );
    expect(again, isFalse, reason: 'resolving twice must not double-apply');
    expect(trustDelta, PromiseDebtService.kKeptUserTrust,
        reason: 'deltas applied exactly once');
  });
}
