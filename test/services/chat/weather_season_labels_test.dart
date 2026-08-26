// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Slice 1: optional season display names. Ids stay winter/spring/summer/autumn.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/season_labels.dart';
import 'package:front_porch_ai/services/chat/weather_biomes.dart';
import 'package:front_porch_ai/services/chat/weather_engine.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/weather_injection.dart';
import 'package:front_porch_ai/services/chat/weather_segments.dart';

Biome _labeled() => Biome(
  id: 'custom',
  displayName: 'Alien',
  description: '',
  weights: Map.from(Biome.temperate.weights),
  baseTemp: Map.from(Biome.temperate.baseTemp),
  seasonLabels: const {'summer': 'High Sun', 'winter': '  '},
);

void main() {
  test('temperate JSON still omits seasonLabels', () {
    expect(Biome.temperate.toJson().containsKey('seasonLabels'), isFalse);
  });

  test('blank and missing labels keep the English id', () {
    expect(seasonDisplayName('summer'), 'summer');
    expect(seasonDisplayName('winter', {'winter': '  '}), 'winter');
    expect(seasonDisplayName('summer', {'summer': 'High Sun'}), 'High Sun');
  });

  test('prompt stock words stay midwinter / high-summer without a label', () {
    expect(seasonPromptName('winter'), 'midwinter');
    expect(seasonPromptName('summer'), 'high-summer');
    expect(seasonPromptName('summer', {'summer': 'High Sun'}), 'High Sun');
  });

  test('round-trip writes only non-empty labels', () {
    final json = _labeled().toJson();
    expect(json['seasonLabels'], {'summer': 'High Sun'});
    final back = Biome.fromJson(json);
    expect(back.seasonLabels['summer'], 'High Sun');
    expect(back.seasonLabels.containsKey('winter'), isFalse);
  });

  test('WeatherEngine.prose uses the custom name when given', () {
    const w = DailyWeather(
      condition: WeatherCondition.clear,
      temp: TempBand.warm,
      season: 'summer',
    );
    expect(WeatherEngine.prose(w), contains('high-summer'));
    expect(
      WeatherEngine.prose(w, seasonLabels: {'summer': 'High Sun'}),
      contains('High Sun'),
    );
    expect(
      WeatherEngine.prose(w, seasonLabels: {'summer': 'High Sun'}),
      isNot(contains('high-summer')),
    );
  });

  test(
    'weather injection mentions a custom season and stays quiet otherwise',
    () {
      const day = DailyWeather(
        condition: WeatherCondition.clear,
        temp: TempBand.warm,
        season: 'summer',
      );
      final seg = SegmentWeather(
        day: day,
        segment: DaySegment.afternoon,
        condition: WeatherCondition.clear,
        tempC: 22,
      );
      String inj(Biome? b) => WeatherInjection(
        getWeather: () => seg,
        getPreviousSegment: () => null,
        getUpcoming: () => null,
        getBiome: b == null ? null : () => b,
      ).buildWeatherInjection();

      expect(inj(null), isNot(contains('High Sun')));
      expect(inj(Biome.temperate), isNot(contains('It is summer')));
      expect(inj(_labeled()), contains('It is High Sun.'));
    },
  );
}
