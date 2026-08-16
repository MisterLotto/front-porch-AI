// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Long-term bond check is every 3 applies going forward. Stored
// longTermScore is never recomputed from history (maintainer 2026-08-15).

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

import 'relationship_service_test.dart' show createTestRelationship;

void main() {
  test('kLongTermCheckEvery is 3', () {
    expect(kLongTermCheckEvery, 3);
  });

  test('long-term growth fires on the 3rd apply, not the 2nd', () {
    final svc = createTestRelationship();
    // Tier 4 (≥4) → +2 per check. Check runs BEFORE this apply's ST delta.
    svc.loadScalars(
      affectionScore: 50,
      longTermScore: 9,
      trustLevel: 0,
      turnsSinceLongTermCheck: 0,
    );

    svc.applyScoreDelta(1);
    expect(svc.longTermScore, 9);
    expect(svc.turnsSinceLongTermCheck, 1);

    svc.applyScoreDelta(1);
    expect(svc.longTermScore, 9);
    expect(svc.turnsSinceLongTermCheck, 2);

    svc.applyScoreDelta(1);
    expect(svc.longTermScore, 11); // 9 + 2
    expect(svc.turnsSinceLongTermCheck, 0);
  });

  test('loaded long-term score is not replayed from history', () {
    final svc = createTestRelationship();
    // A live chat already at LT 9 stays 9 until the NEXT window completes.
    svc.loadScalars(
      affectionScore: 50,
      longTermScore: 9,
      trustLevel: 0,
      turnsSinceLongTermCheck: 0,
    );
    svc.applyScoreDelta(1);
    svc.applyScoreDelta(1);
    expect(svc.longTermScore, 9);
  });

  test('a leftover counter uses the new window going forward', () {
    final svc = createTestRelationship();
    svc.loadScalars(
      affectionScore: 50,
      longTermScore: 9,
      trustLevel: 0,
      turnsSinceLongTermCheck: 2,
    );
    svc.applyScoreDelta(1);
    expect(svc.longTermScore, 11);
    expect(svc.turnsSinceLongTermCheck, 0);
  });
}
