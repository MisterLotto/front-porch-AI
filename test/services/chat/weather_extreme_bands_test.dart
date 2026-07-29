// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Living Worlds Phase 2 — extreme temperature bands (living-worlds.md §3
// Rev.3). The determinism half is covered by weather_biome_pins_test (all 7
// built-ins byte-identical); this file covers the NEW surface: thermal rank,
// the per-biome clamp actually reaching extremes, cryogenic snow (no thaw
// demotion), authored display anchors, JSON round-trip, and validation.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/weather_biomes.dart';
import 'package:front_porch_ai/services/chat/weather_engine.dart';
import 'package:front_porch_ai/services/chat/weather_segments.dart';

/// A Mars-like fixture: cryogenic most of the year, snow (CO₂ frost) weight
/// present, full extreme span, authored display anchors.
const _mars = Biome(
  id: 'mars-test',
  displayName: 'Mars (test)',
  description: 't',
  weights: {
    // clear, cloudy, overcast, fog, rain, storm, snow
    'winter': [60, 15, 5, 0, 0, 5, 15],
    'spring': [70, 15, 5, 0, 0, 10, 0],
    'summer': [70, 15, 5, 0, 0, 10, 0],
    'autumn': [65, 15, 5, 0, 0, 5, 10],
  },
  baseTemp: {
    'winter': 5, // cryogenic (declaration index)
    'spring': 5,
    'summer': 0, // cold
    'autumn': 5,
  },
  bandRange: (-1, 4),
  // Summer's base is classic cold, but cryogenic is jitter-reachable from
  // it (range floor -1), so validate demands an anchor for it too.
  displayAnchorsC: {
    'winter': -80,
    'spring': -65,
    'summer': -55,
    'autumn': -70,
  },
  diurnalAmplitude: 2.4,
);

const _volcano = Biome(
  id: 'volcano-test',
  displayName: 'Volcano (test)',
  description: 't',
  weights: {
    'winter': [70, 20, 5, 0, 0, 5, 0],
    'spring': [70, 20, 5, 0, 0, 5, 0],
    'summer': [70, 20, 5, 0, 0, 5, 0],
    'autumn': [70, 20, 5, 0, 0, 5, 0],
  },
  baseTemp: {'winter': 7, 'spring': 7, 'summer': 7, 'autumn': 7}, // inferno
  bandRange: (5, 6),
  displayAnchorsC: {
    'winter': 600,
    'spring': 600,
    'summer': 600,
    'autumn': 600,
  },
);

void main() {
  group('TempBandThermal', () {
    test('rank orders thermally while declaration order stays storage order', () {
      expect(TempBand.cryogenic.rank, lessThan(TempBand.cold.rank));
      expect(TempBand.hot.rank, lessThan(TempBand.furnace.rank));
      expect(TempBand.furnace.rank, lessThan(TempBand.inferno.rank));
      // Storage indices 0..4 unchanged — biome JSON in the wild depends on it.
      expect(TempBand.cold.index, 0);
      expect(TempBand.hot.index, 4);
      expect(TempBand.cryogenic.index, 5);
    });

    test('fromRank round-trips every band and clamps out-of-range', () {
      for (final b in TempBand.values) {
        expect(TempBandThermal.fromRank(b.rank), b);
      }
      expect(TempBandThermal.fromRank(-9), TempBand.cryogenic);
      expect(TempBandThermal.fromRank(99), TempBand.inferno);
    });

    test('isExtreme marks exactly the non-classic bands', () {
      expect(
        TempBand.values.where((b) => b.isExtreme),
        [TempBand.cryogenic, TempBand.furnace, TempBand.inferno],
      );
    });
  });

  group('extreme bands in the walk', () {
    test('Mars winters are cryogenic and keep their snow (no thaw demotion)',
        () {
      // Every sampled walk ends on the fixed Jan 30 date, so every returned
      // day is a winter day — 120 walk lengths, 120 winter observations.
      var cryoDays = 0;
      var snowDays = 0;
      for (int day = 1; day <= 120; day++) {
        final w = WeatherEngine.weatherFor(
          sessionSeed: 'mars-session',
          dayCount: day,
          date: DateTime(2026, 1, 30),
          biome: _mars,
        );
        if (w.temp == TempBand.cryogenic) cryoDays++;
        if (w.condition == WeatherCondition.snow) snowDays++;
        // The old !=cold rule would have demoted every cryogenic snow to
        // rain; Mars has 0 rain weight, so ANY rain day proves a regression.
        expect(w.condition, isNot(WeatherCondition.rain));
      }
      expect(cryoDays, greaterThan(0));
      expect(snowDays, greaterThan(0), reason: 'CO₂ frost must survive');
    });

    test('legacy OUT-OF-SPEC baseTemp reproduces the old engine exactly', () {
      // Old imports accepted unvalidated biome JSON; stored baseTemp 5 used
      // to saturate to hot, negative bases floored to cold AFTER jitter.
      // The classic-span byte-identity path must reproduce that — the rank
      // decode (index 5 = cryogenic) flipped such chats hot→cold before the
      // adversarial-review fix.
      final hotBiome = Biome.fromJson({
        'id': 'legacy-5',
        'weights': Biome.temperate.toJson()['weights'],
        'baseTemp': {'winter': 5, 'spring': 5, 'summer': 5, 'autumn': 5},
      });
      final coldBiome = Biome.fromJson({
        'id': 'legacy-neg',
        'weights': Biome.temperate.toJson()['weights'],
        'baseTemp': {'winter': -3, 'spring': -3, 'summer': -3, 'autumn': -3},
      });
      for (int day = 1; day <= 120; day++) {
        final h = WeatherEngine.weatherFor(
          sessionSeed: 'legacy-session',
          dayCount: day,
          date: DateTime(2026, 7, 10),
          biome: hotBiome,
        );
        // Old formula: (5 + jitter).clamp(0, 4) — hot on every draw.
        expect(h.temp, TempBand.hot, reason: 'day $day');
        final c = WeatherEngine.weatherFor(
          sessionSeed: 'legacy-session',
          dayCount: day,
          date: DateTime(2026, 7, 10),
          biome: coldBiome,
        );
        // Old formula: (-3 + jitter).clamp(0, 4) — cold on every draw,
        // including jitter-up days (floor applies AFTER jitter).
        expect(c.temp, TempBand.cold, reason: 'day $day');
      }
    });

    test('negative-width bandRange cannot crash the walk', () {
      const backwards = Biome(
        id: 'backwards',
        displayName: 'x',
        description: '',
        weights: {
          'winter': [50, 50, 0, 0, 0, 0, 0],
          'spring': [50, 50, 0, 0, 0, 0, 0],
          'summer': [50, 50, 0, 0, 0, 0, 0],
          'autumn': [50, 50, 0, 0, 0, 0, 0],
        },
        baseTemp: {'winter': 7, 'spring': 7, 'summer': 7, 'autumn': 7},
        bandRange: (6, 5), // programmatic mistake — must not throw
      );
      // Domain-invalid spans reject to classic (same as garbage JSON), so
      // the out-of-spec base saturates classically instead of pinning an
      // extreme the author never validly declared.
      final w = WeatherEngine.weatherFor(
        sessionSeed: 's',
        dayCount: 5,
        date: DateTime(2026, 7, 1),
        biome: backwards,
      );
      expect(w.temp, TempBand.hot);
    });

    test('extreme→extreme season flips still warn (no generic warm-front)',
        () {
      DailyWeather d(TempBand t) => DailyWeather(
            condition: WeatherCondition.clear,
            temp: t,
            season: 'winter',
          );
      expect(
        WeatherEngine.foreshadow(d(TempBand.cryogenic), d(TempBand.furnace)),
        contains('beyond anything survivable'),
      );
      expect(
        WeatherEngine.foreshadow(d(TempBand.furnace), d(TempBand.cryogenic)),
        contains('killing kind'),
      );
      // Same extreme both days: no repeated alarm.
      expect(
        WeatherEngine.foreshadow(d(TempBand.inferno), d(TempBand.inferno)),
        '',
      );
    });

    test('a string element in baseTemp/weights degrades, never nulls the biome',
        () {
      final b = Biome.tryParse(
        '{"id":"x","weights":{"winter":[50,"x",0,0,0,0,0]},'
        '"baseTemp":{"winter":"oops","summer":2}}',
      );
      expect(b, isNotNull);
      expect(b!.baseTemp['summer'], 2);
      expect(b.baseTemp.containsKey('winter'), isFalse);
    });

    test('a rain draw below cold freezes out as snow (no -80° liquid rain)',
        () {
      const rainyCryo = Biome(
        id: 'rainy-cryo',
        displayName: 'x',
        description: '',
        weights: {
          'winter': [10, 10, 10, 0, 70, 0, 0], // rain-dominant
          'spring': [10, 10, 10, 0, 70, 0, 0],
          'summer': [10, 10, 10, 0, 70, 0, 0],
          'autumn': [10, 10, 10, 0, 70, 0, 0],
        },
        baseTemp: {'winter': 5, 'spring': 5, 'summer': 5, 'autumn': 5},
        bandRange: (-1, -1),
        displayAnchorsC: {
          'winter': -80,
          'spring': -80,
          'summer': -80,
          'autumn': -80,
        },
      );
      var snow = 0;
      for (int day = 1; day <= 60; day++) {
        final w = WeatherEngine.weatherFor(
          sessionSeed: 'rain-cryo',
          dayCount: day,
          date: DateTime(2026, 7, 1),
          biome: rainyCryo,
        );
        expect(w.condition, isNot(WeatherCondition.rain),
            reason: 'day $day: liquid rain at cryogenic');
        if (w.condition == WeatherCondition.snow) snow++;
      }
      expect(snow, greaterThan(0), reason: 'rain weight must land as snow');
    });

    test('classic biomes can never wobble into an extreme (clamp guard)', () {
      for (final biome in Biome.builtIns) {
        for (int day = 1; day <= 400; day++) {
          final w = WeatherEngine.weatherFor(
            sessionSeed: 'clamp-guard',
            dayCount: day,
            date: DateTime(2026, 6, 1),
            biome: biome,
          );
          expect(w.temp.isExtreme, isFalse,
              reason: '${biome.id} day $day reached ${w.temp.name}');
        }
      }
    });

    test('volcano days sit in the furnace..inferno span', () {
      for (int day = 1; day <= 60; day++) {
        final w = WeatherEngine.weatherFor(
          sessionSeed: 'volcano-session',
          dayCount: day,
          date: DateTime(2026, 7, 1),
          biome: _volcano,
        );
        expect(w.temp.rank, inInclusiveRange(5, 6));
      }
    });
  });

  group('authored display anchors', () {
    test('anchored season shows the authored °C (±3 wobble + diurnal)', () {
      final w = WeatherSegments.segmentWeatherFor(
        sessionSeed: 'mars-session',
        dayCount: 12,
        date: DateTime(2026, 1, 30),
        hour: 13, // afternoon: +2 offset × amp 2.4 ≈ +5
        biome: _mars,
      );
      expect(w.day.temp, TempBand.cryogenic);
      // -80 anchor, ±3 base wobble, +5 afternoon diurnal → [-78, -72].
      expect(w.tempC, inInclusiveRange(-83 + 5, -77 + 5));
    });

    test('volcano chip reads ~600°C, and °F conversion holds', () {
      final w = WeatherSegments.segmentWeatherFor(
        sessionSeed: 'volcano-session',
        dayCount: 3,
        date: DateTime(2026, 7, 1),
        hour: 12,
        biome: _volcano,
      );
      expect(w.tempC, inInclusiveRange(594, 606));
      expect(WeatherSegments.tempF(600), 1112);
    });

    test('anchors are ignored while the day is classic-banded', () {
      // Mars summer is cold (classic) and has NO anchor — °C must come from
      // the cold band's own range, not any anchor.
      final w = WeatherSegments.segmentWeatherFor(
        sessionSeed: 'mars-session',
        dayCount: 200,
        date: DateTime(2026, 7, 15),
        hour: 12,
        biome: _mars,
      );
      expect(w.day.temp.isExtreme, isFalse);
      expect(w.tempC, inInclusiveRange(-8 - 8, 2 + 5)); // band ± diurnal(amp)
    });
  });

  group('JSON + validation', () {
    test('bandRange + anchors round-trip; classic biomes omit both keys', () {
      final json = _mars.toJson();
      final back = Biome.fromJson(json);
      expect(back.bandRange, (-1, 4));
      expect(back.displayAnchorsC['winter'], -80);
      // Built-ins stay byte-compatible with pre-extremes readers.
      expect(Biome.temperate.toJson().containsKey('bandRange'), isFalse);
      expect(Biome.temperate.toJson().containsKey('displayAnchorsC'), isFalse);
    });

    test('garbage bandRange degrades to the classic span, never INTO extremes',
        () {
      for (final garbage in [
        ['broken'],
        ['a', 'b'], // string elements must not throw (hard-cast trap)
        [10, 20], // out-of-domain must NOT clamp into permanent inferno
        [-100, 100],
        [4, 0], // backwards
        null,
        'nope',
      ]) {
        final b = Biome.fromJson({
          'id': 'x',
          'weights': _mars.weights,
          'baseTemp': {'winter': 2},
          'bandRange': ?garbage,
        });
        expect(b.bandRange, (0, 4), reason: 'input: $garbage');
      }
    });

    test('validate: jitter-reachable extreme without an anchor is rejected',
        () {
      // Base is classic hot, but the widened range lets jitter reach
      // furnace — the season still needs a display °C.
      const b = Biome(
        id: 'x',
        displayName: 'x',
        description: '',
        weights: {
          'winter': [50, 50, 0, 0, 0, 0, 0],
          'spring': [50, 50, 0, 0, 0, 0, 0],
          'summer': [50, 50, 0, 0, 0, 0, 0],
          'autumn': [50, 50, 0, 0, 0, 0, 0],
        },
        baseTemp: {'winter': 4, 'spring': 2, 'summer': 2, 'autumn': 2},
        bandRange: (0, 6),
      );
      expect(
        b.validate().any((e) => e.contains('winter') && e.contains('°C')),
        isTrue,
      );
    });

    test('lethal transitions foreshadow; classic swings keep old text', () {
      const winter = 'winter';
      DailyWeather d(TempBand t) => DailyWeather(
            condition: WeatherCondition.clear,
            temp: t,
            season: winter,
          );
      expect(
        WeatherEngine.foreshadow(d(TempBand.cold), d(TempBand.cryogenic)),
        contains('killing kind'),
      );
      expect(
        WeatherEngine.foreshadow(d(TempBand.hot), d(TempBand.furnace)),
        contains('beyond anything survivable'),
      );
      expect(
        WeatherEngine.foreshadow(d(TempBand.cryogenic), d(TempBand.cold)),
        contains('finally break'),
      );
      // Classic two-band swing keeps its historical phrasing.
      expect(
        WeatherEngine.foreshadow(d(TempBand.mild), d(TempBand.cold)),
        contains('cold snap'),
      );
    });

    test('validate: extreme base without a display °C is rejected', () {
      const b = Biome(
        id: 'x',
        displayName: 'x',
        description: '',
        weights: {
          'winter': [50, 50, 0, 0, 0, 0, 0],
          'spring': [50, 50, 0, 0, 0, 0, 0],
          'summer': [50, 50, 0, 0, 0, 0, 0],
          'autumn': [50, 50, 0, 0, 0, 0, 0],
        },
        baseTemp: {'winter': 5, 'spring': 2, 'summer': 2, 'autumn': 2},
        bandRange: (-1, 4),
      );
      expect(
        b.validate().any((e) => e.contains('display °C')),
        isTrue,
      );
    });

    test('validate: base outside the band range is rejected', () {
      const b = Biome(
        id: 'x',
        displayName: 'x',
        description: '',
        weights: {
          'winter': [50, 50, 0, 0, 0, 0, 0],
          'spring': [50, 50, 0, 0, 0, 0, 0],
          'summer': [50, 50, 0, 0, 0, 0, 0],
          'autumn': [50, 50, 0, 0, 0, 0, 0],
        },
        baseTemp: {'winter': 7, 'spring': 2, 'summer': 2, 'autumn': 2},
        // classic-only span, but winter asks for inferno
      );
      expect(
        b.validate().any((e) => e.contains('band range')),
        isTrue,
      );
    });

    test('Mars and volcano fixtures validate clean', () {
      expect(_mars.validate(), isEmpty);
      expect(_volcano.validate(), isEmpty);
    });
  });

  group('prose never leaks numbers', () {
    test('extreme dress cues are survival text, words only', () {
      for (final b in [TempBand.cryogenic, TempBand.furnace, TempBand.inferno]) {
        final cue = WeatherSegments.dressCue(b);
        expect(cue, isNot(matches(RegExp(r'\d'))));
        expect(WeatherEngine.tempWord(b), isNot(matches(RegExp(r'\d'))));
      }
    });
  });
}
