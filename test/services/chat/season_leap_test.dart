// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Leap years are Gregorian, not a custom year length. Feb 29 is a real
// start; on a non-leap story year it lands on Mar 1.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/season_calendar.dart';

void main() {
  test('Feb 29 is its own ordinal, Mar 1 is the next day', () {
    expect(doyFromMonthDay(2, 29), 60);
    expect(monthDayFromDoy(60), (2, 29));
    expect(doyFromMonthDay(3, 1), 61);
    expect(formatDoy(60), 'Feb 29');
  });

  test('Earth Dec/Mar/Jun/Sep 1 still decode as those dates', () {
    expect(monthDayFromDoy(kEarthSeasonStarts['winter']!), (12, 1));
    expect(monthDayFromDoy(kEarthSeasonStarts['spring']!), (3, 1));
    expect(monthDayFromDoy(kEarthSeasonStarts['summer']!), (6, 1));
    expect(monthDayFromDoy(kEarthSeasonStarts['autumn']!), (9, 1));
  });

  test('a Feb 29 start is live on a leap day and rolls to Mar 1 otherwise', () {
    final starts = {
      'thaw': doyFromMonthDay(2, 29),
      'freeze': doyFromMonthDay(12, 1),
    };
    expect(seasonOnDate(DateTime(2024, 2, 29), starts), 'thaw');
    expect(seasonOnDate(DateTime(2023, 2, 28), starts), 'freeze');
    expect(seasonOnDate(DateTime(2023, 3, 1), starts), 'thaw');
  });
}
