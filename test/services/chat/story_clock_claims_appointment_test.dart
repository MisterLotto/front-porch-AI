// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A named hour is only the PRESENT moment when the reply says so. Appointments
// ("I'll pick you up at 5 p.m."), schedules ("the train leaves at 4 p.m.") and
// memories ("the call at 9 a.m. that morning") used to reach the clock as
// present-tense claims, and _restampRealismSnapshotPostGen fed them straight
// into TimeService.applyReconciledClock — so an ordinary line of dialogue moved
// the story clock (and the persisted sessions.story_clock) by up to ±6 hours.
//
// The second group is the other half of the guard: the fix must not silence the
// claims the feature exists for.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  final onePm = DateTime.utc(2026, 8, 14, 13, 0);
  final eightOhFive = DateTime.utc(2026, 8, 14, 8, 5);

  group('clockNamedInReply — plans and memories are not the present', () {
    test('an appointment inside dialogue does not move the clock', () {
      for (final reply in const [
        '"I\'ll pick you up at 5 p.m.," she said.',
        '"Dinner is at 6 p.m., don\'t be late."',
        '"Meet me at 7 p.m.," she whispered.',
        '"The train leaves at 4 p.m. sharp."',
      ]) {
        expect(
          clockNamedInReply(reply, onePm),
          isNull,
          reason: 'plan, not the present: $reply',
        );
      }
    });

    test('a remembered hour does not drag the clock backwards', () {
      expect(
        clockNamedInReply(
          'She remembered the call at 9 a.m. that morning.',
          onePm,
        ),
        isNull,
      );
      expect(
        clockNamedInReply('I woke up at 7 a.m. this morning.', onePm),
        isNull,
      );
    });

    test('other non-present leads stay rejected too', () {
      expect(clockNamedInReply('she waited till 5 p.m.', onePm), isNull);
      expect(clockNamedInReply("nothing since 9 a.m.", onePm), isNull);
      expect(clockNamedInReply('open from 10 a.m.', onePm), isNull);
    });
  });

  group('clockNamedInReply — present claims still land', () {
    test('"It is 6am" still sets the clock', () {
      expect(
        clockNamedInReply('It is 6am and the street is empty.', eightOhFive),
        DateTime.utc(2026, 8, 14, 6, 0),
      );
    });

    test('the spoken Senjumaru form survives the word-boundary rule', () {
      // "footpath " ends in "at " — a boundary-less rejection list would kill
      // the exact claim this whole file was written for.
      const reply =
          'a Royal Guard who is standing on a human footpath at six '
          'in the morning with a half-built Senkaimon';
      expect(
        clockNamedInReply(reply, eightOhFive),
        DateTime.utc(2026, 8, 14, 6, 0),
      );
    });

    test('a later present claim still overrides an earlier one', () {
      expect(
        clockNamedInReply('I thought it was 5am. It is 6:15 AM now.',
            eightOhFive),
        DateTime.utc(2026, 8, 14, 6, 15),
      );
    });
  });
}
