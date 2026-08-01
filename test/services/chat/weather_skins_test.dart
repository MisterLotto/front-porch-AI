// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Condition skins (phase 2 step ④): renames + stance-driven code-owned
// behavior. The doc's canonical failure — "acid rain gets a cardigan" —
// is the contract under test: at dangerous+ the stance REPLACES the
// dressing cue and behavior text always rides the rename.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/weather_biomes.dart';
import 'package:front_porch_ai/services/chat/weather_engine.dart';
import 'package:front_porch_ai/services/chat/weather_segments.dart';
import 'package:front_porch_ai/services/chat/weather_skins.dart';

const _acidWorld = Biome(
  id: 'acid-test',
  displayName: 'Venusia',
  description: '',
  weights: {
    'winter': [40, 20, 10, 0, 30, 0, 0],
    'spring': [40, 20, 10, 0, 30, 0, 0],
    'summer': [40, 20, 10, 0, 30, 0, 0],
    'autumn': [40, 20, 10, 0, 30, 0, 0],
  },
  baseTemp: {'winter': 2, 'spring': 2, 'summer': 3, 'autumn': 2},
  conditionSkin: {
    'rain': ConditionSkin(
      label: 'Acid Rain',
      emoji: '🧪',
      stance: WeatherStance.deadly,
      flavour: 'It hisses where it lands.',
    ),
    'storm': ConditionSkin(
      label: 'Caustic Squall',
      stance: WeatherStance.dangerous,
    ),
    'cloudy': ConditionSkin(
      label: 'Amber Haze',
      stance: WeatherStance.ordinary,
    ),
  },
);

SegmentWeather _seg(WeatherCondition c, {TempBand band = TempBand.mild}) =>
    SegmentWeather(
      day: DailyWeather(condition: c, temp: band, season: 'spring'),
      segment: DaySegment.afternoon,
      condition: c,
      tempC: 15,
    );

void main() {
  group('labels + emoji', () {
    test('skinned condition renames on chip label and emoji', () {
      expect(
        skinnedChipLabel(_seg(WeatherCondition.rain), _acidWorld,
            fahrenheit: false),
        'Acid Rain · 15°C',
      );
      expect(skinnedEmoji(_acidWorld, WeatherCondition.rain), '🧪');
      // No emoji on the skin → stock emoji, renamed label.
      expect(skinnedEmoji(_acidWorld, WeatherCondition.storm), '⛈️');
      expect(
        skinnedConditionLabel(_acidWorld, WeatherCondition.storm),
        'Caustic Squall',
      );
    });

    test('unskinned conditions are byte-identical to stock', () {
      expect(
        skinnedChipLabel(_seg(WeatherCondition.clear), _acidWorld,
            fahrenheit: false),
        WeatherSegments.label(_seg(WeatherCondition.clear),
            fahrenheit: false),
      );
      expect(
        skinnedProse(_seg(WeatherCondition.clear), _acidWorld),
        WeatherSegments.prose(_seg(WeatherCondition.clear)),
      );
      // Built-ins carry no renames: everything passes through stock.
      expect(
        skinnedProse(_seg(WeatherCondition.rain), Biome.temperate),
        WeatherSegments.prose(_seg(WeatherCondition.rain)),
      );
    });
  });

  group('stance behavior (the cardigan-into-acid guard)', () {
    test('deadly rain: no dress cue, behavior line + flavour present', () {
      final prose = skinnedProse(_seg(WeatherCondition.rain), _acidWorld);
      expect(prose, contains('Acid Rain'));
      expect(prose, contains('Exposure to this kills'));
      expect(prose, contains('hisses'));
      expect(prose, isNot(contains('light-layers')),
          reason: 'dangerous+ replaces the temperature phrasing');
      expect(prose, isNot(matches(RegExp(r'\d'))),
          reason: 'words-only contract holds for skins');
    });

    test('ordinary rename keeps the dress cue and adds no behavior', () {
      final prose = skinnedProse(_seg(WeatherCondition.cloudy), _acidWorld);
      expect(prose, contains('Amber Haze'));
      expect(prose, contains('light-layers'));
      expect(prose, isNot(contains('harmful')));
    });

    test('long flavour is capped near 140 chars', () {
      final biome = Biome(
        id: 'x',
        displayName: 'x',
        description: '',
        weights: _acidWorld.weights,
        baseTemp: _acidWorld.baseTemp,
        conditionSkin: {
          'rain': ConditionSkin(
            label: 'Gunk',
            stance: WeatherStance.harsh,
            flavour: 'y' * 400,
          ),
        },
      );
      final prose = skinnedProse(_seg(WeatherCondition.rain), biome);
      expect(prose.length, lessThan(400));
    });
  });

  group('transitions + foreshadow', () {
    test('renamed shift never leaks the stock word', () {
      final t = skinnedTransition(
        _seg(WeatherCondition.rain),
        _seg(WeatherCondition.clear),
        _acidWorld,
      );
      expect(t, contains('Acid Rain'));
      expect(t.toLowerCase(), isNot(contains('the rain ')));
    });

    test('unskinned shift falls through to the stock sentence', () {
      final t = skinnedTransition(
        _seg(WeatherCondition.fog),
        _seg(WeatherCondition.clear),
        _acidWorld,
      );
      expect(t, WeatherSegments.transition(
        _seg(WeatherCondition.fog),
        _seg(WeatherCondition.clear),
      ));
    });

    test('dangerous tomorrow becomes a deadline, not scenery', () {
      const today = DailyWeather(
        condition: WeatherCondition.clear,
        temp: TempBand.mild,
        season: 'spring',
      );
      const tomorrow = DailyWeather(
        condition: WeatherCondition.rain,
        temp: TempBand.mild,
        season: 'spring',
      );
      final sign = skinnedForeshadow(today, tomorrow, _acidWorld);
      expect(sign, contains('Acid Rain'));
      expect(sign, contains('cover'));
      // Unskinned biome keeps the stock foreshadow.
      expect(
        skinnedForeshadow(today, tomorrow, Biome.temperate),
        WeatherEngine.foreshadow(today, tomorrow),
      );
    });
  });
}
