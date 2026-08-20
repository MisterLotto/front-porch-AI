// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Slice 2–3: custom start days on a 365-day year, 2–8 named seasons.
// Empty map = Earth months (WeatherEngine.seasonOf). One season may wrap
// New Year. Same start twice, fewer than 2, or more than 8 cannot save.

const List<String> kEarthSeasonIds = ['winter', 'spring', 'summer', 'autumn'];
const int kMinSeasons = 2;
const int kMaxSeasons = 8;

/// Non-leap cumulative days before each month (Jan=0 … Dec=334).
const List<int> kDoyBeforeMonth = [
  0,
  31,
  59,
  90,
  120,
  151,
  181,
  212,
  243,
  273,
  304,
  334,
];

const List<String> kMonthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Northern-hemisphere month mapping as start days: Dec/Mar/Jun/Sep 1.
const Map<String, int> kEarthSeasonStarts = {
  'winter': 335,
  'spring': 60,
  'summer': 152,
  'autumn': 244,
};

int daysInMonth365(int month) {
  if (month < 1 || month > 12) return 0;
  if (month == 12) return 31;
  return kDoyBeforeMonth[month] - kDoyBeforeMonth[month - 1];
}

int dayOfYear365(DateTime date) {
  final day = (date.month == 2 && date.day == 29) ? 28 : date.day;
  return kDoyBeforeMonth[date.month - 1] + day;
}

int doyFromMonthDay(int month, int day) =>
    kDoyBeforeMonth[month - 1] + day.clamp(1, daysInMonth365(month));

(int month, int day) monthDayFromDoy(int doy) {
  final d = doy.clamp(1, 365);
  for (var m = 12; m >= 1; m--) {
    if (d > kDoyBeforeMonth[m - 1]) {
      return (m, d - kDoyBeforeMonth[m - 1]);
    }
  }
  return (1, 1);
}

String formatDoy(int doy) {
  final (m, d) = monthDayFromDoy(doy);
  return '${kMonthShort[m - 1]} $d';
}

DateTime dateFromDoy365(int doy, {int year = 2026}) {
  final (m, d) = monthDayFromDoy(doy);
  return DateTime(year, m, d);
}

/// Last season whose start is on or before [doy], wrapping New Year.
String seasonFromStarts(int doy, Map<String, int> starts) {
  final entries = starts.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  if (entries.isEmpty) return 'spring';
  var current = entries.last.key;
  for (final e in entries) {
    if (doy >= e.value) current = e.key;
  }
  return current;
}

/// Midpoint date inside [season] so the editor preview is not stuck on
/// July 15 after the author moved summer.
DateTime previewDateForSeason(String season, Map<String, int> starts) {
  final map = starts.isEmpty ? kEarthSeasonStarts : starts;
  if (!map.containsKey(season) || map.length < 2) {
    return dateFromDoy365(kEarthSeasonStarts[season] ?? 152);
  }
  final ordered = map.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  final i = ordered.indexWhere((e) => e.key == season);
  if (i < 0) return dateFromDoy365(kEarthSeasonStarts[season] ?? 152);
  final start = ordered[i].value;
  final next = ordered[(i + 1) % ordered.length].value;
  final len = next > start ? next - start : (365 - start) + next;
  final mid = ((start - 1 + (len ~/ 2)) % 365) + 1;
  return dateFromDoy365(mid);
}

Map<String, int> parseSeasonStarts(Map<String, dynamic> json) {
  final raw = json['seasonStarts'] ?? json['season_starts'];
  if (raw is! Map) return const {};
  final out = <String, int>{};
  for (final e in raw.entries) {
    if (e.value is! num) continue;
    final n = (e.value as num).toInt();
    if (n < 1 || n > 365) continue;
    out[e.key.toString()] = n;
  }
  return out;
}

/// Empty = Earth (valid). Otherwise 2–8 seasons, unique days 1..365.
List<String> validateSeasonStarts(Map<String, int> starts) {
  if (starts.isEmpty) return const [];
  final errors = <String>[];
  if (starts.length < kMinSeasons) {
    errors.add('need at least $kMinSeasons seasons');
  }
  if (starts.length > kMaxSeasons) {
    errors.add('at most $kMaxSeasons seasons');
  }
  for (final e in starts.entries) {
    if (e.value < 1 || e.value > 365) {
      errors.add('${e.key}: start must be a day of the year (1–365)');
    }
  }
  final byDay = <int, List<String>>{};
  for (final e in starts.entries) {
    byDay.putIfAbsent(e.value, () => []).add(e.key);
  }
  for (final e in byDay.entries) {
    if (e.value.length < 2) continue;
    errors.add(
      '${e.value.join(' and ')} both start on ${formatDoy(e.key)} — '
      'seasons cannot overlap',
    );
  }
  return errors;
}

bool seasonStartsEqualEarth(Map<String, int> starts) {
  if (starts.isEmpty) return true;
  if (starts.length != kEarthSeasonStarts.length) return false;
  for (final s in kEarthSeasonIds) {
    if (starts[s] != kEarthSeasonStarts[s]) return false;
  }
  return true;
}

/// Calendar order when starts are set; else Earth four, else weight keys.
List<String> seasonIdsOf({
  required Iterable<String> weightKeys,
  required Map<String, int> starts,
}) {
  if (starts.isNotEmpty) {
    final ids = starts.keys.toList()
      ..sort((a, b) => starts[a]!.compareTo(starts[b]!));
    return ids;
  }
  final keys = weightKeys.toList();
  if (keys.length == kEarthSeasonIds.length &&
      kEarthSeasonIds.every(keys.contains)) {
    return List<String>.from(kEarthSeasonIds);
  }
  if (keys.length >= kMinSeasons) return keys;
  return List<String>.from(kEarthSeasonIds);
}

String allocSeasonId(Iterable<String> taken) {
  final have = taken.toSet();
  for (var i = 1; i < 40; i++) {
    final id = 's$i';
    if (!have.contains(id)) return id;
  }
  return 's${taken.length + 1}';
}

/// Midpoint of the longest gap on the year circle, not colliding.
int startInLongestGap(Map<String, int> starts) {
  if (starts.isEmpty) return 1;
  final days = starts.values.toList()..sort();
  var bestLen = -1;
  var bestMid = 1;
  for (var i = 0; i < days.length; i++) {
    final a = days[i];
    final b = days[(i + 1) % days.length];
    final len = i + 1 == days.length ? (365 - a) + b : b - a;
    if (len <= bestLen) continue;
    bestLen = len;
    bestMid = ((a - 1 + (len ~/ 2)) % 365) + 1;
  }
  var d = bestMid;
  for (var n = 0; n < 365; n++) {
    if (!days.contains(d)) return d;
    d = d % 365 + 1;
  }
  return 1;
}
