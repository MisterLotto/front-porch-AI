// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A reply-named hour may never move the story onto a NEIGHBOURING calendar
// day. Red-proven 2026-08-15: with the old yesterday/tomorrow candidates in
// _closestOnCalendar, the 00:45 "11 p.m." case returned the previous day's
// 23:00 — which drops the sidebar's Day N and re-fires the day rollover.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  group('clockNamedInReply never crosses midnight', () {
    test('00:45 scene naming 11 p.m. stays put (no rewind to yesterday)', () {
      final current = DateTime.utc(2026, 8, 14, 0, 45);
      expect(
        clockNamedInReply(
          'The clock read 11 p.m. when she finally spoke.',
          current,
        ),
        isNull,
      );
      expect(
        clockNamedInReply('It is 11:30 in the night now.', current),
        isNull,
      );
    });

    test('23:40 scene naming 12:10 a.m. does not jump to tomorrow', () {
      expect(
        clockNamedInReply(
          'It is 12:10 a.m. now, and the porch light is still on.',
          DateTime.utc(2026, 8, 14, 23, 40),
        ),
        isNull,
      );
    });

    test('same-day corrections still land, forwards and backwards', () {
      final current = DateTime.utc(2026, 8, 14, 8, 5);
      expect(
        clockNamedInReply('It is 6am and the street is empty.', current),
        DateTime.utc(2026, 8, 14, 6, 0),
      );
      expect(
        clockNamedInReply('It is 10:30 AM by the time she stands.', current),
        DateTime.utc(2026, 8, 14, 10, 30),
      );
    });

    test('a returned claim is always on the current story day', () {
      for (final hour in List.generate(24, (i) => i)) {
        final current = DateTime.utc(2026, 8, 14, hour, 20);
        for (final named in const [
          'It is 1 a.m. now.',
          'It is 6am now.',
          'It is 11 p.m. now.',
          'It is 5:45 PM now.',
        ]) {
          final got = clockNamedInReply(named, current);
          if (got == null) continue;
          expect(
            DateTime.utc(got.year, got.month, got.day),
            DateTime.utc(current.year, current.month, current.day),
            reason: '$named at $current moved off the story day',
          );
        }
      }
    });
  });
}
