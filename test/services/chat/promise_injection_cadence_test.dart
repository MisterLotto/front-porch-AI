// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards the promise-injection anti-nag cadence (maintainer report
// 2026-08-04: with any open promise the injection line rode EVERY prompt, so
// characters brought promises up every single turn — and a stuck-open one
// made them DENY ever keeping it). Contract: ledger activity injects for the
// next kFreshBuilds builds, then the line goes quiet and resurfaces every
// kReminderEvery-th build.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late PromiseDebtService service;

  setUp(() {
    db = AppDatabase.forTesting();
    service = PromiseDebtService(
      journalStore: JournalStore(getDb: () => db),
      fireEval: (_) async => 'NONE',
      getMaxCards: () => 30,
      applyTrustDelta: (_) {},
      applyBondDelta: (_) {},
    );
  });

  tearDown(() => db.close());

  List<bool> drive(int builds) =>
      [for (var i = 0; i < builds; i++) service.shouldInjectNow('s1', 'c1')];

  test('cold start injects once, then reminds every Nth build', () {
    final seen = drive(1 + PromiseDebtService.kReminderEvery * 2);
    expect(seen.first, isTrue, reason: 'an existing open promise must still '
        'reach the prompt after an app restart');
    // Exactly one reminder per kReminderEvery quiet stretch — never every turn.
    final rest = seen.skip(1).toList();
    expect(rest.where((b) => b).length, 2);
    expect(rest[PromiseDebtService.kReminderEvery - 1], isTrue);
    expect(rest[PromiseDebtService.kReminderEvery * 2 - 1], isTrue);
  });

  test('never injects on consecutive builds outside the fresh window', () {
    final seen = drive(PromiseDebtService.kReminderEvery * 3);
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i] && seen[i - 1], isFalse,
          reason: 'build $i re-injected back-to-back — that is the every-'
              'turn nagging this cadence exists to stop');
    }
  });

  test('cadence state is per-diary (session|character keyed)', () {
    expect(service.shouldInjectNow('s1', 'c1'), isTrue);
    expect(service.shouldInjectNow('s1', 'c1'), isFalse);
    // A different character in the same session has its own cadence.
    expect(service.shouldInjectNow('s1', 'c2'), isTrue);
  });
}
