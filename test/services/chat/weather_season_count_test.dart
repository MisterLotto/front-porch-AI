// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Slice 3: 2–8 seasons. Still a 365-day year.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/season_calendar.dart';
import 'package:front_porch_ai/services/chat/weather_biomes.dart';
import 'package:front_porch_ai/services/chat/weather_engine.dart';

Biome _five() {
  final weights = Map<String, List<int>>.from(Biome.temperate.weights);
  final base = Map<String, int>.from(Biome.temperate.baseTemp);
  weights['monsoon'] = List<int>.from(weights['summer']!);
  base['monsoon'] = base['summer']!;
  return Biome(
    id: 'custom',
    displayName: 'Alien',
    description: '',
    weights: weights,
    baseTemp: base,
    seasonLabels: const {'monsoon': 'Monsoon'},
    seasonStarts: {
      'winter': 335,
      'spring': 60,
      'summer': 152,
      'monsoon': 180,
      'autumn': 244,
    },
  );
}

void main() {
  test('five seasons: July 15 is monsoon, not summer', () {
    final w = WeatherEngine.weatherFor(
      sessionSeed: 's',
      dayCount: 1,
      date: DateTime(2026, 7, 15),
      biome: _five(),
    );
    expect(w.season, 'monsoon');
  });

  test('five-season JSON round-trips monsoon', () {
    final back = Biome.fromJson(_five().toJson());
    expect(back.seasonIds, contains('monsoon'));
    expect(back.seasonStarts['monsoon'], 180);
    expect(back.seasonLabels['monsoon'], 'Monsoon');
    expect(back.validate(), isEmpty);
  });

  test('temperate still omits seasonStarts and stays four', () {
    expect(Biome.temperate.seasonIds, kSeasons);
    expect(Biome.temperate.toJson().containsKey('seasonStarts'), isFalse);
  });

  test('nine seasons cannot save', () {
    final starts = {for (var i = 1; i <= 9; i++) 's$i': i * 10};
    expect(
      validateSeasonStarts(starts).any((e) => e.contains('at most')),
      isTrue,
    );
  });

  test('new season start lands in a gap, not on an existing day', () {
    final d = startInLongestGap(kEarthSeasonStarts);
    expect(kEarthSeasonStarts.values.contains(d), isFalse);
    expect(d, inInclusiveRange(1, 365));
  });

  test('allocSeasonId skips taken ids', () {
    expect(allocSeasonId(['s1', 'winter']), 's2');
  });

  test('two seasons is the floor', () {
    final b = Biome(
      id: 'custom',
      displayName: 'Binary',
      description: '',
      weights: {
        'hot': Biome.temperate.weights['summer']!,
        'cold': Biome.temperate.weights['winter']!,
      },
      baseTemp: {'hot': 3, 'cold': 0},
      seasonStarts: {'hot': 1, 'cold': 183},
    );
    expect(b.validate(), isEmpty);
    expect(b.seasonIds.length, 2);
  });
}
