// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guard for GrowthStore.refresh's session-guarded swap (release sweep _idx
// 115). The [Character Growth] block is built inside SYNCHRONOUS prompt
// assembly, so it reads a cache that is only valid while it is tagged with
// the live session. A refresh that started for chat A and lands after the
// user has already left A must therefore DROP its result — if it stamps the
// cache with A instead, every sync reader for the live chat returns empty and
// the character silently reverts to their un-grown card.
//
// The comment in growth_store.dart claimed this guard long before the code
// had it; these tests fail against the unguarded (unconditional) swap.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/chat/growth_store.dart';

void main() {
  late AppDatabase db;
  late GrowthStore store;

  setUp(() async {
    db = AppDatabase.forTesting();
    store = GrowthStore(getDb: () => db);
    await store.addRing(
      sessionId: 'sA',
      characterId: 'mara',
      content: 'She has started answering the door herself.',
      category: 'behavior',
    );
    await store.addRing(
      sessionId: 'sB',
      characterId: 'mara',
      content: 'She keeps the porch light on for him now.',
      category: 'behavior',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('a context switch mid-load drops the stale swap', () async {
    // Chat A's load is in flight (refresh runs synchronously up to its first
    // DB await, so the epoch is already claimed here).
    final pending = store.refresh('sA', charIds: const ['mara']);

    // The user leaves chat A. Every context switch invalidates the cache.
    store.invalidate();

    await pending;

    // The late loader must NOT have re-tagged the cache with the chat the
    // user already left.
    expect(store.activeRingsFor('sA', 'mara'), isEmpty);
    expect(store.legacyBlobFor('sA', 'mara'), isNull);
    expect(store.cursorCachedFor('sA'), 0);
  });

  test('the live chat still loads normally after a dropped stale swap',
      () async {
    final pending = store.refresh('sA', charIds: const ['mara']);
    store.invalidate();
    await pending;

    await store.refresh('sB', charIds: const ['mara']);

    expect(store.activeRingsFor('sB', 'mara'), hasLength(1));
    expect(
      store.activeRingsFor('sB', 'mara').single.content,
      'She keeps the porch light on for him now.',
    );
    // …and chat A is still not the cache's owner.
    expect(store.activeRingsFor('sA', 'mara'), isEmpty);
  });

  test('the newest refresh wins when two loads overlap', () async {
    final a = store.refresh('sA', charIds: const ['mara']);
    final b = store.refresh('sB', charIds: const ['mara']);
    await Future.wait([a, b]);

    // Whichever future resolved last, only the LATEST-started load may own
    // the cache — sA claimed the older epoch.
    expect(store.activeRingsFor('sA', 'mara'), isEmpty);
    expect(store.activeRingsFor('sB', 'mara'), hasLength(1));
  });
}
