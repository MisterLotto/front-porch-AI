// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tests for Passage of Time logic extracted from ChatService.
// Covers OOC time-skip detection, manual time nudging, and the
// passageOfTimeEnabled toggle that gates automatic time advancement.

import 'package:flutter_test/flutter_test.dart';

// ── Stub: Minimal passage-of-time tracker ───────────────────────────
// Replicates the time-related fields and transitions from ChatService.

class _PassageOfTimeStub {
  String _timeOfDay = 'morning';
  int _dayCount = 1;
  int _startDayOfWeek = DateTime.now().weekday;
  int _turnsSinceLastTimeAdvance = 0;
  bool _passageOfTimeEnabled = true;
  Map<String, dynamic>? _pendingRealismMetadata;

  String get timeOfDay => _timeOfDay;
  int get dayCount => _dayCount;
  int get startDayOfWeek => _startDayOfWeek;
  int get turnsSinceLastTimeAdvance => _turnsSinceLastTimeAdvance;
  bool get passageOfTimeEnabled => _passageOfTimeEnabled;
  Map<String, dynamic>? get pendingRealismMetadata => _pendingRealismMetadata;

  /// Narrative weekday computed from dayCount and startDayOfWeek.
  /// Mirrors ChatService.narrativeWeekday (lines 630-642).
  String get narrativeWeekday {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final idx = (_startDayOfWeek - 1 + (_dayCount - 1)) % 7;
    return days[idx];
  }

  // ── _detectOocTimeSkip (mirrors ChatService lines 7944-8034) ──────
  void detectOocTimeSkip(String text) {
    if (!_passageOfTimeEnabled) return;

    final lower = text.toLowerCase();

    final hasOocMarker = RegExp(
      r'\(ooc[:\s]|\[ooc|\*ooc\b|ooc:',
    ).hasMatch(lower);
    final hasSkipPhrase = RegExp(
      r'\b(time.?skip|fast.?forward|skip ahead|several hours|a few hours|hours? later|'
      r'the next (morning|day|evening|afternoon|night|dawn)|'
      r'next (morning|day|evening|afternoon|night|dawn)|'
      r'hours? pass|time passes|the following (morning|day)|'
      r'wake up the next|woke up|the next day)\b',
    ).hasMatch(lower);

    if (!hasOocMarker && !hasSkipPhrase) return;

    int periods = 1;

    // Next-day detection
    if (RegExp(
      r'\b(next (morning|day)|the following (morning|day)|wake up|woke up|overnight)\b',
    ).hasMatch(lower)) {
      _dayCount++;
      _timeOfDay = 'dawn';
      _turnsSinceLastTimeAdvance = 0;
      _pendingRealismMetadata ??= {};
      _pendingRealismMetadata!['time_skip_to'] = 'Dawn · Day $_dayCount';
      return;
    }

    if (RegExp(
      r'\b(all day|entire day|full day|day passes|the (whole|entire) day)\b',
    ).hasMatch(lower)) {
      periods = 4;
    } else if (RegExp(
      r'\b(several hours|many hours|a long time|hours? pass)\b',
    ).hasMatch(lower)) {
      periods = 3;
    } else if (RegExp(
      r'\b(a few hours|couple.{0,5}hours|2.{0,5}hours|two hours)\b',
    ).hasMatch(lower)) {
      periods = 2;
    } else if (RegExp(
      r'\b(an hour|1 hour|one hour|a while|some time)\b',
    ).hasMatch(lower)) {
      periods = 1;
    } else if (hasOocMarker) {
      periods = 1;
    }

    if (periods <= 0) return;

    final validTimes = [
      'dawn',
      'morning',
      'late_morning',
      'afternoon',
      'evening',
      'night',
    ];
    int idx = validTimes.indexOf(_timeOfDay);
    for (int i = 0; i < periods; i++) {
      idx++;
      if (idx >= validTimes.length) {
        idx = 0;
        _dayCount++;
      }
    }
    _timeOfDay = validTimes[idx];
    _turnsSinceLastTimeAdvance = 0;
    _pendingRealismMetadata ??= {};
    final displayTime = _timeOfDay
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
    _pendingRealismMetadata!['time_skip_to'] = displayTime;
  }

  // ── nudgeTimePeriod (mirrors ChatService lines 7909-7934) ─────────
  void nudgeTimePeriod(int delta) {
    final validTimes = [
      'dawn',
      'morning',
      'late_morning',
      'afternoon',
      'evening',
      'night',
    ];
    int idx = validTimes.indexOf(_timeOfDay);

    if (delta < 0 && idx == 0) {
      _dayCount = (_dayCount - 1).clamp(1, 9999);
    } else if (delta > 0 && idx == validTimes.length - 1) {
      _dayCount++;
    }

    idx = (idx + delta) % validTimes.length;
    _timeOfDay = validTimes[idx];
    _turnsSinceLastTimeAdvance = 0;
  }

  // ── setPassageOfTimeEnabled (mirrors ChatService lines 7900-7904) ─
  void setPassageOfTimeEnabled(bool enabled) {
    _passageOfTimeEnabled = enabled;
  }

  // ── Seed from extensions (mirrors ChatService lines 1087-1088) ────
  void seedFromExtensions({
    required bool extPassageOfTime,
    required bool globalPassageOfTimeDefault,
  }) {
    _passageOfTimeEnabled = extPassageOfTime && globalPassageOfTimeDefault;
  }
}

void main() {
  // ─── 3.4: Passage of Time ──────────────────────────────────────────

  group('Passage of Time — OOC time-skip respects global setting', () {
    test('does NOT advance time when passageOfTimeEnabled is false', () {
      final stub = _PassageOfTimeStub();
      stub.setPassageOfTimeEnabled(false);
      expect(stub.passageOfTimeEnabled, isFalse);

      stub.detectOocTimeSkip('time skip');

      expect(stub.timeOfDay, 'morning',
          reason: 'time should NOT advance when passage of time is disabled');
      expect(stub.dayCount, 1,
          reason: 'day should NOT advance when passage of time is disabled');
    });

    test('advances time when passageOfTimeEnabled is true', () {
      final stub = _PassageOfTimeStub();
      stub.setPassageOfTimeEnabled(true);

      stub.detectOocTimeSkip('time skip');

      expect(stub.timeOfDay, 'late_morning',
          reason: 'time advances by 1 period from morning → late_morning');
    });

    test('global setting overrides character card setting', () {
      final stub = _PassageOfTimeStub();

      // Character card says passageOfTime=true, but global default=false
      stub.seedFromExtensions(
        extPassageOfTime: true,
        globalPassageOfTimeDefault: false,
      );

      expect(stub.passageOfTimeEnabled, isFalse,
          reason: 'global setting is a hard ceiling');

      stub.detectOocTimeSkip('time skip');

      expect(stub.timeOfDay, 'morning',
          reason: 'OOC skip should be ignored when global setting is off');
    });
  });

  group('Passage of Time — OOC time-skip advances time when enabled', () {
    test('advances by one period for generic time skip', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'morning';
      stub.detectOocTimeSkip('time skip');

      expect(stub.timeOfDay, 'late_morning');
    });

    test('advances by one period for (ooc: time skip)', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'afternoon';
      stub.detectOocTimeSkip('(ooc: time skip)');

      expect(stub.timeOfDay, 'evening');
    });

    test('advances by one period for [ooc] marker', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'evening';
      stub.detectOocTimeSkip('[ooc] time passes');

      expect(stub.timeOfDay, 'night');
    });

    test('advances by one period for *ooc* marker', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'night';
      stub.detectOocTimeSkip('*ooc* time skip');

      expect(stub.timeOfDay, 'dawn'); // wraps to next day
      expect(stub.dayCount, 2);
    });

    test('advances by one period for "ooc: time skip"', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'dawn';
      stub.detectOocTimeSkip('ooc: time skip');

      expect(stub.timeOfDay, 'morning');
    });
  });

  group('Passage of Time — OOC time-skip period multipliers', () {
    test('"a few hours" advances by 2 periods', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'morning';
      // "a few hours" matches hasSkipPhrase, then the 2-period regex
      stub.detectOocTimeSkip('a few hours later');

      expect(stub.timeOfDay, 'afternoon'); // morning → late_morning → afternoon
    });

    test('"several hours" advances by 3 periods', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'morning';
      stub.detectOocTimeSkip('several hours pass');

      expect(stub.timeOfDay, 'evening'); // morning → late_morning → afternoon → evening
    });

    test('"all day" advances by 4 periods', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'morning';
      // Use OOC marker to trigger the time skip since "all day" alone
      // doesn't match hasSkipPhrase patterns
      stub.detectOocTimeSkip('(ooc: all day passes)');

      expect(stub.timeOfDay, 'night'); // morning → late_morning → afternoon → evening → night
    });

    test('"an hour" advances by 1 period', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'afternoon';
      stub.detectOocTimeSkip('time passes');

      expect(stub.timeOfDay, 'evening');
    });

    test('"two hours" advances by 2 periods', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'late_morning';
      stub.detectOocTimeSkip('two hours later');

      expect(stub.timeOfDay, 'evening');
    });
  });

  group('Passage of Time — next-day transitions', () {
    test('wake up advances to next day at dawn', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'night';
      stub._dayCount = 5;

      stub.detectOocTimeSkip('I wake up the next morning');

      expect(stub.dayCount, 6);
      expect(stub.timeOfDay, 'dawn');
    });

    test('woke up advances to next day at dawn', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'evening';
      stub._dayCount = 10;

      stub.detectOocTimeSkip('I woke up the next day');

      expect(stub.dayCount, 11);
      expect(stub.timeOfDay, 'dawn');
    });

    test('overnight phrase after "woke up" advances to next day at dawn', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'night';
      stub._dayCount = 1;

      stub.detectOocTimeSkip('I woke up overnight');

      expect(stub.dayCount, 2);
      expect(stub.timeOfDay, 'dawn');
    });

    test('the next morning advances to next day at dawn', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'morning';
      stub._dayCount = 3;

      stub.detectOocTimeSkip('The next morning arrived');

      expect(stub.dayCount, 4);
      expect(stub.timeOfDay, 'dawn');
    });

    test('the following day advances to next day at dawn', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'afternoon';
      stub._dayCount = 7;

      stub.detectOocTimeSkip('The following day');

      expect(stub.dayCount, 8);
      expect(stub.timeOfDay, 'dawn');
    });
  });

  group('Passage of Time — time wrapping', () {
    test('wraps from night to dawn', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'night';
      stub.detectOocTimeSkip('(ooc: time skip)');

      expect(stub.timeOfDay, 'dawn');
      expect(stub.dayCount, 2);
    });

    test('multiple wraps advance multiple days', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'night';
      stub._dayCount = 1;

      // Use OOC marker to trigger all-day skip (4 periods)
      // night → dawn(1) → morning(2) → late_morning(3) → afternoon(4)
      stub.detectOocTimeSkip('(ooc: all day)');

      expect(stub.timeOfDay, 'afternoon');
      expect(stub.dayCount, 2);
    });

    test('wraps from dawn backward via nudge', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'dawn';
      stub._dayCount = 5;

      stub.nudgeTimePeriod(-1);

      expect(stub.timeOfDay, 'night');
      expect(stub.dayCount, 4);
    });

    test('wraps from night forward via nudge', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'night';
      stub._dayCount = 5;

      stub.nudgeTimePeriod(1);

      expect(stub.timeOfDay, 'dawn');
      expect(stub.dayCount, 6);
    });
  });

  group('Passage of Time — manual time nudge', () {
    test('nudge forward advances by one period', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'morning';

      stub.nudgeTimePeriod(1);

      expect(stub.timeOfDay, 'late_morning');
    });

    test('nudge backward goes to previous period', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'late_morning';

      stub.nudgeTimePeriod(-1);

      expect(stub.timeOfDay, 'morning');
    });

    test('nudge forward from late_morning', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'late_morning';

      stub.nudgeTimePeriod(1);

      expect(stub.timeOfDay, 'afternoon');
    });

    test('nudge forward from evening', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'evening';

      stub.nudgeTimePeriod(1);

      expect(stub.timeOfDay, 'night');
    });

    test('nudge backward from dawn', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'dawn';
      stub._dayCount = 10;

      stub.nudgeTimePeriod(-1);

      expect(stub.timeOfDay, 'night');
      expect(stub.dayCount, 9);
    });

    test('resets turnsSinceLastTimeAdvance', () {
      final stub = _PassageOfTimeStub();
      stub._turnsSinceLastTimeAdvance = 100;

      stub.nudgeTimePeriod(1);

      expect(stub.turnsSinceLastTimeAdvance, 0);
    });
  });

  group('Passage of Time — narrative weekday', () {
    test('day 1 returns the start weekday', () {
      final stub = _PassageOfTimeStub();
      stub._startDayOfWeek = DateTime.monday;
      stub._dayCount = 1;

      expect(stub.narrativeWeekday, 'Monday');
    });

    test('day 2 returns the next weekday', () {
      final stub = _PassageOfTimeStub();
      stub._startDayOfWeek = DateTime.monday;
      stub._dayCount = 2;

      expect(stub.narrativeWeekday, 'Tuesday');
    });

    test('day 8 wraps to the same weekday as day 1', () {
      final stub = _PassageOfTimeStub();
      stub._startDayOfWeek = DateTime.wednesday;
      stub._dayCount = 8;

      expect(stub.narrativeWeekday, 'Wednesday');
    });

    test('day 15 wraps correctly (14 days = 2 weeks)', () {
      final stub = _PassageOfTimeStub();
      stub._startDayOfWeek = DateTime.friday;
      stub._dayCount = 15;

      expect(stub.narrativeWeekday, 'Friday');
    });

    test('large dayCount wraps correctly', () {
      final stub = _PassageOfTimeStub();
      stub._startDayOfWeek = DateTime.tuesday;
      stub._dayCount = 100;

      // (2 - 1 + 99) % 7 = 100 % 7 = 2 → Wednesday
      expect(stub.narrativeWeekday, 'Wednesday');
    });
  });

  group('Passage of Time — time skip metadata', () {
    test('sets time_skip_to metadata on OOC skip', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'morning';
      stub.detectOocTimeSkip('(ooc: time skip)');

      expect(stub.pendingRealismMetadata, isNotNull);
      expect(stub.pendingRealismMetadata!['time_skip_to'], contains('Late Morning'));
    });

    test('sets time_skip_to metadata for next-day transition', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'night';
      stub._dayCount = 5;
      stub.detectOocTimeSkip('I woke up');

      expect(stub.pendingRealismMetadata, isNotNull);
      expect(stub.pendingRealismMetadata!['time_skip_to'], 'Dawn · Day 6');
    });

    test('resets turns counter on time skip', () {
      final stub = _PassageOfTimeStub();
      stub._turnsSinceLastTimeAdvance = 50;
      stub.detectOocTimeSkip('time skip');

      expect(stub.turnsSinceLastTimeAdvance, 0);
    });
  });

  group('Passage of Time — no matching patterns', () {
    test('does NOT advance time for unrelated text', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'morning';

      stub.detectOocTimeSkip('I walk to the market and buy some bread');

      expect(stub.timeOfDay, 'morning');
      expect(stub.dayCount, 1);
    });

    test('does NOT advance time for text containing "hour" but not time-skip', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'morning';

      stub.detectOocTimeSkip('I have a hourglass on my desk');

      expect(stub.timeOfDay, 'morning');
    });

    test('does NOT advance time when no time-skip language detected', () {
      final stub = _PassageOfTimeStub();
      stub._timeOfDay = 'afternoon';

      stub.detectOocTimeSkip('We talk for a while about the weather');

      expect(stub.timeOfDay, 'afternoon');
    });
  });
}
