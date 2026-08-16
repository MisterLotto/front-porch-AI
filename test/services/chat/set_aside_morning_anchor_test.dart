// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// SET-ASIDE CLOTHES SURVIVE MIDNIGHT (1.3 sweep, maintainer-approved
// 2026-08-15).
//
// Set-aside expiry was keyed on the CALENDAR day (StoryClock.dayCountFor,
// which flips at 00:00), while every doc on the feature promises expiry at
// the next story MORNING. A scene running past midnight deleted the outfit
// she set aside at 23:00, stranding the character mid-scene with nothing to
// put back on. morningDayCountFor keeps the small hours on the previous
// story day (same 08:00 anchor as nextMorning); every set-aside surface —
// the pockets pass, reply-facts expiry, prompt injection, both sidebar rows
// and the web facade — rides ChatService.storyDayCount, which now forwards
// to it.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  final start = DateTime.utc(2026, 3, 1, 9); // story starts day 1, 09:00

  test('the small hours still belong to the previous story day', () {
    // 23:00 on day 2.
    expect(
      StoryClock.morningDayCountFor(DateTime.utc(2026, 3, 2, 23), start),
      2,
    );
    // 00:30 the same NIGHT — calendar day 3, story day still 2: the outfit
    // set aside at 23:00 must remain recoverable.
    expect(
      StoryClock.morningDayCountFor(DateTime.utc(2026, 3, 3, 0, 30), start),
      2,
      reason: 'dayCountFor flips at 00:00 and deleted the outfit mid-scene',
    );
    // 08:01 — the story morning has come; NOW it is day 3 and yesterday's
    // set-aside clothing expires.
    expect(
      StoryClock.morningDayCountFor(DateTime.utc(2026, 3, 3, 8, 1), start),
      3,
    );
  });

  test('daytime hours agree with the calendar day', () {
    final noonDay2 = DateTime.utc(2026, 3, 2, 12);
    expect(
      StoryClock.morningDayCountFor(noonDay2, start),
      StoryClock.dayCountFor(noonDay2, start),
    );
  });

  test('the clamp still holds before the story anchor', () {
    expect(
      StoryClock.morningDayCountFor(DateTime.utc(2026, 2, 27, 3), start),
      1,
    );
  });

  test('expiry through the real record honors the morning anchor', () {
    final p = Pockets(worn: [const PocketItem('red sundress')]);
    // She sets it aside at 23:00 on story day 2.
    applyPocketOps(
      p,
      [const PocketOpReport(kind: PocketOpKind.remove, item: 'red sundress')],
      day: StoryClock.morningDayCountFor(DateTime.utc(2026, 3, 2, 23), start),
    );
    expect(p.setAside, hasLength(1));

    // 00:30 — same scene, past midnight: still there.
    p.expireSetAside(
      StoryClock.morningDayCountFor(DateTime.utc(2026, 3, 3, 0, 30), start),
    );
    expect(p.setAside, hasLength(1),
        reason: 'midnight must not strand her without an outfit');

    // 08:01 — story morning: gone.
    p.expireSetAside(
      StoryClock.morningDayCountFor(DateTime.utc(2026, 3, 3, 8, 1), start),
    );
    expect(p.setAside, isEmpty);
  });
}
