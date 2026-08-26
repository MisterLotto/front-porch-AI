// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Hygiene at 0: they notice they reek (catastrophe beat) but the meter
// does NOT rebound to 55 — only washing restores it. A second tick while
// still at 0 must not re-fire the canon scene event. Enjoys-low-hygiene
// skips the beat (0 is comfort).

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/needs_simulation.dart';

import 'needs_simulation_test.dart' show createTestSim;

Map<String, int> get _bottomHygiene => {
  'hunger': 60,
  'bladder': 60,
  'energy': 60,
  'social': 60,
  'fun': 60,
  'hygiene': 0,
  'comfort': 60,
};

void main() {
  test('hygiene at 0 is acknowledged and does not rebound', () {
    final sim = createTestSim();
    sim.initializeFresh();
    sim.restoreFromSnapshot({'vector': _bottomHygiene});
    sim.applyCatastropheIfNeeded();
    expect(sim.pendingCatastrophe, isNotNull);
    expect(sim.pendingCatastrophe, contains('smell themselves'));
    expect(sim.pendingCatastrophe, contains('embarrassed'));
    expect(sim.vector['hygiene'], 0);
    expect(
      NeedsSimulation.needPostCatastropheFloor.containsKey('hygiene'),
      isFalse,
    );
  });

  test('still filthy next tick does not re-fire the wash-now event', () {
    final sim = createTestSim();
    sim.initializeFresh();
    sim.restoreFromSnapshot({'vector': _bottomHygiene});
    sim.applyCatastropheIfNeeded();
    expect(sim.pendingCatastrophe, isNotNull);
    sim.consumePendingCatastrophe();
    sim.applyCatastropheIfNeeded();
    expect(sim.pendingCatastrophe, isNull);
    expect(sim.vector['hygiene'], 0);
  });

  test('washing clears the ack so hitting 0 again is noticed', () {
    final sim = createTestSim();
    sim.initializeFresh();
    sim.restoreFromSnapshot({'vector': _bottomHygiene});
    sim.applyCatastropheIfNeeded();
    sim.consumePendingCatastrophe();
    sim.restoreFromSnapshot({
      'vector': {..._bottomHygiene, 'hygiene': 80},
    });
    sim.applyCatastropheIfNeeded();
    expect(sim.pendingCatastrophe, isNull);
    sim.restoreFromSnapshot({'vector': _bottomHygiene});
    sim.applyCatastropheIfNeeded();
    expect(sim.pendingCatastrophe, isNotNull);
    expect(sim.vector['hygiene'], 0);
  });

  test('enjoys-low-hygiene at 0 does not catastrophe', () {
    final sim = createTestSim(enjoysFn: () => true);
    sim.initializeFresh();
    sim.restoreFromSnapshot({'vector': _bottomHygiene});
    sim.applyCatastropheIfNeeded();
    expect(sim.pendingCatastrophe, isNull);
    expect(sim.vector['hygiene'], 0);
  });
}
