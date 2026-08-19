// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// At work is occupation + hours + the period. Fail closed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/presence_derive.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/character_state/presence_word.dart';

const _morning = 9 * 60;
const _lateMorning = 11 * 60 + 30;
const _afternoon = 14 * 60 + 30;
const _evening = 18 * 60 + 30;

PresenceWhere d({
  String occupation = 'clerk',
  String hours = '9-5',
  int clockMinutes = _afternoon,
  bool isGroup = false,
  bool inScene = true,
}) => derivePresence(
  occupation: occupation,
  hours: hours,
  clockMinutes: clockMinutes,
  inScene: inScene,
);

void main() {
  test('empty occupation is With you', () {
    expect(d(occupation: '', hours: '9-5'), PresenceWhere.withYou);
  });

  test('unparseable hours fail closed to With you', () {
    expect(d(occupation: 'baker', hours: 'whenever'), PresenceWhere.withYou);
  });

  test('9-5 in the afternoon is At work', () {
    expect(d(hours: '9-5', clockMinutes: _afternoon), PresenceWhere.atWork);
  });

  test('9-5 in the evening is With you', () {
    expect(d(hours: '9-5', clockMinutes: _evening), PresenceWhere.withYou);
  });

  test('mornings is unparseable and fails closed', () {
    // Period words used to match the named slice of the day. Hours are a
    // clock range now; "mornings" is not one, so At work cannot light.
    expect(
      d(occupation: 'teacher', hours: 'mornings', clockMinutes: _lateMorning),
      PresenceWhere.withYou,
    );
    expect(hoursMatch('mornings', _morning), isFalse);
    expect(parseWorkHoursRange('mornings'), isNull);
  });

  test('evenings at afternoon is With you', () {
    expect(
      d(occupation: 'bartender', hours: 'evenings', clockMinutes: _afternoon),
      PresenceWhere.withYou,
    );
  });

  test('group member not in scene is Away', () {
    expect(
      d(hours: '9-5', clockMinutes: _evening, isGroup: true, inScene: false),
      PresenceWhere.away,
    );
  });

  test('1:1 not-in-scene is Away', () {
    expect(
      d(hours: '9-5', clockMinutes: _evening, isGroup: false, inScene: false),
      PresenceWhere.away,
    );
  });

  test('1:1 on shift is At work', () {
    expect(
      d(hours: '9-5', clockMinutes: _afternoon, isGroup: false, inScene: true),
      PresenceWhere.atWork,
    );
  });

  test('9am-5pm in the morning is At work', () {
    expect(d(hours: '9am-5pm', clockMinutes: _morning), PresenceWhere.atWork);
  });

  test('hh:mm range uses the period default hour', () {
    expect(
      d(hours: '09:00–17:00', clockMinutes: _afternoon),
      PresenceWhere.atWork,
    );
  });

  test('group At work skips the turn', () {
    expect(groupTurnSkips(PresenceWhere.atWork), isTrue);
    expect(groupTurnSkips(PresenceWhere.away), isTrue);
    expect(groupTurnSkips(PresenceWhere.withYou), isFalse);
  });

  test('empty stance is not Away', () {
    expect(stanceSaysAway(''), isFalse);
    expect(stanceSaysAway('  '), isFalse);
  });

  test('here-words stay in scene', () {
    expect(stanceSaysAway('standing by the porch rail'), isFalse);
  });

  test('left-the and next-room mark Away', () {
    expect(stanceSaysAway('She left the kitchen'), isTrue);
    expect(stanceSaysAway('in the next room'), isTrue);
    expect(stanceSaysAway('out of sight down the hall'), isTrue);
  });

  test('1:1 Away and At work never skip; group Away and At work do', () {
    final skipSrc = File(
      'lib/services/chat/chat_service_turn_flow.dart',
    ).readAsStringSync();
    final skipFn = RegExp(
      r'bool _groupSpeakerSkips\(CharacterCard card\) \{([\s\S]*?)\n  \}',
    ).firstMatch(skipSrc);
    expect(
      skipFn,
      isNotNull,
      reason: '_groupSpeakerSkips must stay in turn_flow',
    );
    final skipBody = skipFn!.group(1)!;
    // Goes red if the 1:1 guard is removed from the real method.
    expect(skipBody, contains('if (_activeGroup == null) return false;'));
    expect(skipBody, contains('return groupTurnSkips(where);'));

    final genSrc = File(
      'lib/services/chat/chat_service_generation.dart',
    ).readAsStringSync();
    final genGate = RegExp(
      r'if \(guestSpeaker == null &&\s+'
      r'_activeGroup != null &&\s+'
      r'mode != GenerationMode\.continue_ &&\s+'
      r'forceSpeaker == null &&\s+'
      r'_groupSpeakerSkips\(speakingCharacter\)\)',
    ).firstMatch(genSrc);
    expect(
      genGate,
      isNotNull,
      reason: 'generation must call _groupSpeakerSkips only in a group',
    );

    final atWork = derivePresence(
      occupation: 'clerk',
      hours: '9-5',
      clockMinutes: _afternoon,
      inScene: true,
    );
    final away = derivePresence(
      occupation: 'clerk',
      hours: '9-5',
      clockMinutes: _evening,
      inScene: false,
    );
    expect(atWork, PresenceWhere.atWork);
    expect(away, PresenceWhere.away);

    bool groupSpeakerSkips({
      required bool activeGroup,
      required PresenceWhere where,
    }) {
      if (!activeGroup) return false;
      return groupTurnSkips(where);
    }

    expect(groupSpeakerSkips(activeGroup: false, where: atWork), isFalse);
    expect(groupSpeakerSkips(activeGroup: false, where: away), isFalse);
    expect(groupSpeakerSkips(activeGroup: true, where: atWork), isTrue);
    expect(groupSpeakerSkips(activeGroup: true, where: away), isTrue);
    expect(
      groupSpeakerSkips(activeGroup: true, where: PresenceWhere.withYou),
      isFalse,
    );
  });

  test('hoursMatch 9-5 at 9:00 stays true', () {
    expect(hoursMatch('9-5', _morning), isTrue);
    expect(hoursMatch('9-5', 8 * 60), isFalse);
  });

  test('formatWorkHoursRange writes the card string the parser reads', () {
    expect(formatWorkHoursRange(9 * 60, 17 * 60), '9am–5pm');
    expect(formatWorkHoursRange(9 * 60 + 30, 17 * 60 + 15), '9:30am–5:15pm');
    expect(parseWorkHoursRange('9am–5pm'), (9 * 60, 17 * 60));
    expect(parseWorkHoursRange('9:30am–5:15pm'), (9 * 60 + 30, 17 * 60 + 15));
    expect(parseWorkHoursRange('whenever'), isNull);
    expect(parseWorkHoursRange('dawn–dusk'), isNull);
  });

  test('9:30am start is after 9:00 and on the clock at 10:00', () {
    expect(hoursMatch('9:30am–5pm', _morning), isFalse);
    expect(hoursMatch('9:30am–5pm', 10 * 60), isTrue);
    expect(hoursMatch('9:30am–5pm', _lateMorning), isTrue);
  });

  test('empty group ext falls back to library 9-5 morning At work', () {
    final work = workFieldsForGroupMember(
      copyOccupation: '',
      copyHours: '',
      libraryOccupation: 'meteorologist',
      libraryHours: '9-5',
    );
    expect(
      derivePresence(
        occupation: work.occupation,
        hours: work.hours,
        clockMinutes: _morning,
        inScene: false,
      ),
      PresenceWhere.atWork,
    );
  });
}
