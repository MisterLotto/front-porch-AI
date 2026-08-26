// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Slice 2: custom season start days. Empty = Earth months.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/biome_preview.dart';
import 'package:front_porch_ai/services/chat/season_calendar.dart';
import 'package:front_porch_ai/services/chat/weather_biomes.dart';
import 'package:front_porch_ai/services/chat/weather_engine.dart';

Biome _withStarts(Map<String, int> starts) => Biome(
  id: 'custom',
  displayName: 'Alien',
  description: '',
  weights: Map.from(Biome.temperate.weights),
  baseTemp: Map.from(Biome.temperate.baseTemp),
  seasonStarts: starts,
);

void main() {
  test('temperate JSON still omits seasonStarts', () {
    expect(Biome.temperate.toJson().containsKey('seasonStarts'), isFalse);
  });

  test('Earth starts match the month mapping', () {
    expect(
      seasonFromStarts(dayOfYear365(DateTime(2026, 1, 10)), kEarthSeasonStarts),
      'winter',
    );
    expect(
      seasonFromStarts(dayOfYear365(DateTime(2026, 7, 15)), kEarthSeasonStarts),
      'summer',
    );
    expect(WeatherEngine.seasonOf(DateTime(2026, 7, 15)), 'summer');
  });

  test('empty starts keep July 15 as summer in the engine', () {
    final w = WeatherEngine.weatherFor(
      sessionSeed: 's',
      dayCount: 1,
      date: DateTime(2026, 7, 15),
      biome: Biome.temperate,
    );
    expect(w.season, 'summer');
  });

  test('custom starts move July 15 off summer', () {
    // Summer in January; winter covers July.
    final biome = _withStarts({
      'summer': 1,
      'autumn': 91,
      'winter': 182,
      'spring': 274,
    });
    final w = WeatherEngine.weatherFor(
      sessionSeed: 's',
      dayCount: 1,
      date: DateTime(2026, 7, 15),
      biome: biome,
    );
    expect(w.season, 'winter');
  });

  test('same start day is an overlap error', () {
    final errors = validateSeasonStarts({
      'winter': 1,
      'spring': 1,
      'summer': 152,
      'autumn': 244,
    });
    expect(errors, isNotEmpty);
    expect(errors.single, contains('cannot overlap'));
    expect(errors.single, contains('Jan 1'));
  });

  test('three unique starts cover the year', () {
    expect(
      validateSeasonStarts({'winter': 1, 'summer': 152, 'autumn': 244}),
      isEmpty,
    );
  });

  test('one season cannot cover the year', () {
    expect(validateSeasonStarts({'winter': 1}), isNotEmpty);
  });

  test('empty starts are valid (Earth)', () {
    expect(validateSeasonStarts(const {}), isEmpty);
    expect(
      _withStarts({}).validate().where((e) => e.contains('start')),
      isEmpty,
    );
  });

  test('preview fixture follows the custom midpoint, not July 15', () {
    final biome = _withStarts({
      'summer': 1,
      'autumn': 91,
      'winter': 182,
      'spring': 274,
    });
    final mid = previewDateForSeason('summer', biome.seasonStarts);
    expect(mid.month, lessThan(4), reason: 'summer slice is Jan–Mar');
    final p = previewBiome(biome, seeds: 2, daysPerSeason: 3);
    expect(p.errors, isEmpty);
  });

  test('Biome.validate surfaces the overlap', () {
    final bad = _withStarts({
      'winter': 10,
      'spring': 10,
      'summer': 152,
      'autumn': 244,
    });
    expect(bad.validate().any((e) => e.contains('cannot overlap')), isTrue);
  });

  test('round-trip writes custom starts and drops Earth-equal maps', () {
    final custom = _withStarts({
      'winter': 1,
      'spring': 90,
      'summer': 180,
      'autumn': 270,
    });
    expect(custom.toJson()['seasonStarts'], {
      'winter': 1,
      'spring': 90,
      'summer': 180,
      'autumn': 270,
    });
    expect(Biome.fromJson(custom.toJson()).seasonStarts['summer'], 180);
    final earth = _withStarts(Map.from(kEarthSeasonStarts));
    expect(earth.toJson().containsKey('seasonStarts'), isFalse);
  });
}
