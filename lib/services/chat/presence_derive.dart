// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// At work is occupation + hours + the clock. Fail closed on hours.
// With you / Away is last. Never a yes/no switch.

import 'package:front_porch_ai/ui/chat_components/sidebar/character_state/presence_word.dart';
export 'package:front_porch_ai/ui/chat_components/sidebar/character_state/presence_word.dart'
    show PresenceWhere;

/// Group copies often drop occupation/hours (fromJson only reads
/// realism_engine.*). Blank copy fields fall back to the origin library card.
({String occupation, String hours}) workFieldsForGroupMember({
  required String copyOccupation,
  required String copyHours,
  String? libraryOccupation,
  String? libraryHours,
}) {
  final occ = copyOccupation.trim();
  final hrs = copyHours.trim();
  return (
    occupation: occ.isNotEmpty ? occ : (libraryOccupation ?? '').trim(),
    hours: hrs.isNotEmpty ? hrs : (libraryHours ?? '').trim(),
  );
}

/// Derive the glance word.
///
/// Order: at work (occupation + hours contain the live clock) → Away
/// (not in this scene) → With you. 1:1 may be Away or At work. Skip is
/// group-only. [inScene] fails toward true.
PresenceWhere derivePresence({
  required String occupation,
  required String hours,
  required int clockMinutes,
  required bool inScene,
}) {
  if (occupation.trim().isNotEmpty &&
      hours.trim().isNotEmpty &&
      hoursMatch(hours, clockMinutes)) {
    return PresenceWhere.atWork;
  }
  if (!inScene) return PresenceWhere.away;
  return PresenceWhere.withYou;
}

/// Group Away / At work: no user-action reply. Clock still runs.
/// 1:1 never uses this — they stay in the turn.
bool groupTurnSkips(PresenceWhere where) =>
    where == PresenceWhere.away || where == PresenceWhere.atWork;

String presenceGlanceLabel(PresenceWhere where) => switch (where) {
  PresenceWhere.withYou => 'With you',
  PresenceWhere.away => 'Away',
  PresenceWhere.atWork => 'At work',
};

/// Empty stance fails toward in-scene. Away-words mean they left.
bool stanceSaysAway(String spatialStance) {
  final s = spatialStance.toLowerCase().trim();
  if (s.isEmpty) return false;
  const marks = [
    'left the',
    'has left',
    'walked off',
    'walked away',
    'gone from',
    'not here',
    'elsewhere',
    'in another',
    'next room',
    'other room',
    'down the hall',
    'out of the room',
    'out of sight',
  ];
  return marks.any(s.contains);
}

/// Fail-closed: a parseable clock range that contains [clockMinutes]
/// (minutes from midnight on the live story clock). Period words
/// ("mornings") and other free text are not hours — they return false.
bool hoursMatch(String hours, int clockMinutes) {
  final range = parseWorkHoursRange(hours);
  if (range == null) return false;
  return _minutesInRange(clockMinutes, range.$1, range.$2);
}

final _rangeRe = RegExp(
  r'(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?'
  r'\s*(?:[-–—]|\s+to\s+)\s*'
  r'(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?',
);

/// Start/end as minutes from midnight. Null for empty, period words
/// ("mornings"), or anything else that is not a clock range.
(int, int)? parseWorkHoursRange(String hours) {
  final h = hours.toLowerCase().trim();
  if (h.isEmpty) return null;
  final m = _rangeRe.firstMatch(h);
  if (m == null) return null;
  final start = _toMinutes(
    int.tryParse(m.group(1) ?? ''),
    m.group(2),
    m.group(3),
  );
  final end = _toMinutes(
    int.tryParse(m.group(4) ?? ''),
    m.group(5),
    m.group(6),
  );
  if (start == null || end == null) return null;
  var s = start;
  var e = end;
  // 9-5 → 9:00–17:00. Overnight 22-6 stays a wrap.
  if (m.group(3) == null &&
      m.group(6) == null &&
      e <= s &&
      (e ~/ 60) <= 12 &&
      (s ~/ 60) <= 12) {
    e += 12 * 60;
  }
  return (s, e);
}

/// Card `hours` from two minute-of-day values: "9am–5pm" / "9:30am–5:15pm".
/// The pickers write this; [parseWorkHoursRange] reads it back.
String formatWorkHoursRange(int startMin, int endMin) =>
    '${_fmtMin(startMin)}–${_fmtMin(endMin)}';

int? _toMinutes(int? h, String? minuteStr, String? ampm) {
  if (h == null || h < 0 || h > 24) return null;
  if (h == 24) {
    if (minuteStr != null && minuteStr != '00') return null;
    return 0;
  }
  final minute = minuteStr == null || minuteStr.isEmpty
      ? 0
      : int.tryParse(minuteStr);
  if (minute == null || minute < 0 || minute > 59) return null;
  var hour = h;
  if (ampm != null) {
    final pm = ampm.startsWith('p');
    if (h == 12) {
      hour = pm ? 12 : 0;
    } else if (h > 12) {
      return null;
    } else {
      hour = pm ? h + 12 : h;
    }
  } else if (h > 23) {
    return null;
  }
  return hour * 60 + minute;
}

String _fmtMin(int minutes) {
  final clamped = ((minutes % 1440) + 1440) % 1440;
  final h = clamped ~/ 60;
  final m = clamped % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final suffix = h < 12 ? 'am' : 'pm';
  if (m == 0) return '$h12$suffix';
  return '$h12:${m.toString().padLeft(2, '0')}$suffix';
}

bool _minutesInRange(int minutes, int start, int end) {
  if (start == end) return minutes == start;
  if (start < end) return minutes >= start && minutes < end;
  return minutes >= start || minutes < end;
}
