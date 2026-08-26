// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// 1:1 prompt twin of the weekday gate. Tuesday at-work copy stays; Saturday
// is the off-shift identity line. Group skip uses the same onShift helper.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/presence_derive.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/behavioral_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/plan_injection.dart';

import 'prompt_injection_test.dart' show createTestRelSvc;

void main() {
  test('1:1 Tuesday 9-5 still narrates from work', () {
    final txt = BehavioralInjection(
      relationshipService: createTestRelSvc(),
      getRealismEnabled: () => true,
      getOccupation: () => 'clerk',
      getHours: () => '9-5',
      getClockMinutes: () => 14 * 60 + 30,
      getWeekday: () => DateTime.tuesday,
      getIsGroup: () => false,
    ).buildPositionInjection();
    expect(txt, contains('At work as a clerk'));
  });

  test('1:1 Saturday 9-5 is off-shift, not at work', () {
    final txt = BehavioralInjection(
      relationshipService: createTestRelSvc(),
      getRealismEnabled: () => true,
      getOccupation: () => 'clerk',
      getHours: () => '9-5',
      getOccupationBrief: () => 'shelves returns',
      getClockMinutes: () => 14 * 60 + 30,
      getWeekday: () => DateTime.saturday,
      getIsGroup: () => false,
    ).buildPositionInjection();
    expect(txt, isNot(contains('At work')));
    expect(txt, contains('Works as a clerk'));
    expect(txt, contains('Today is Saturday — not a work day'));
    expect(txt, contains('Do not send them to work'));
    expect(groupTurnSkips(PresenceWhere.withYou), isFalse);
  });

  test('Sunday morning loan officer is told it is not a work day', () {
    final txt = BehavioralInjection(
      relationshipService: createTestRelSvc(),
      getRealismEnabled: () => true,
      getOccupation: () => 'Loan Officer',
      getHours: () => '9am–5pm',
      getOccupationBrief: () => 'reviews loan applications at Bank of America',
      getClockMinutes: () => 6 * 60 + 47,
      getWeekday: () => DateTime.sunday,
      getWorkDays: () => kDefaultWorkDays,
      getIsGroup: () => false,
    ).buildPositionInjection();
    expect(txt, isNot(contains('At work')));
    expect(txt, contains('Today is Sunday — not a work day'));
    expect(txt, contains('Do not send them to work'));
  });

  test('weekday before the shift is not at work yet', () {
    final txt = BehavioralInjection(
      relationshipService: createTestRelSvc(),
      getRealismEnabled: () => true,
      getOccupation: () => 'clerk',
      getHours: () => '9am–5pm',
      getOccupationBrief: () => 'shelves returns',
      getClockMinutes: () => 7 * 60,
      getWeekday: () => DateTime.tuesday,
      getIsGroup: () => false,
    ).buildPositionInjection();
    expect(txt, contains('not at work yet'));
    expect(txt, isNot(contains('At work as')));
  });

  test('Saturday afternoon does not suppress the today plan', () {
    final clerk = CharacterCard(
      name: 'Ada',
      frontPorchExtensions: FrontPorchExtensions(
        occupation: 'clerk',
        hours: '9am–5pm',
      ),
    );
    final text = PlanInjection(
      getTodayLine: () => 'Finish the log.',
      getPlannerEnabled: () => true,
      getClockMinutes: () => 14 * 60 + 30,
      getWeekday: () => DateTime.saturday,
      getActiveCharacter: () => clerk,
      getIsGroupNonObserverMode: () => false,
      getCurrentSpeakerIdForRealism: () => '',
      getGroupCharacters: () => const [],
      getCharacterIdFromCard: (c) => c.name,
    ).buildPlanInjection();
    expect(text, contains('Finish the log.'));
  });
}
