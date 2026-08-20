// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Preview-as-validation for the custom climate editor (living-worlds.md §3):
// run the candidate biome across MANY seeds × days and report what actually
// comes out — the preview is simultaneously the tuning tool, the test, and
// the explanation ("you asked for snowy summers, but summer is warm, so
// every draw demoted to rain"). Pure math over the real engine — no state,
// no I/O — so the editor can call it freely off a debounce.

import 'package:front_porch_ai/services/chat/season_calendar.dart';
import 'package:front_porch_ai/services/chat/weather_biomes.dart';
import 'package:front_porch_ai/services/chat/weather_engine.dart';
import 'package:front_porch_ai/services/chat/weather_segments.dart';

/// One season's simulated outcome distribution.
class SeasonDistribution {
  final String season;

  /// condition name → share of days (0..1), post demotion/promotion.
  final Map<String, double> conditionShare;

  /// band name → share of days (0..1).
  final Map<String, double> bandShare;

  /// Representative display °C for the season — the authored anchor when
  /// present, else the dominant band's range midpoint. UI number only.
  final int typicalTempC;

  const SeasonDistribution({
    required this.season,
    required this.conditionShare,
    required this.bandShare,
    required this.typicalTempC,
  });
}

/// The full preview result the editor renders.
class BiomePreview {
  final List<SeasonDistribution> seasons;

  /// Hard errors from [Biome.validate] — saving must be blocked on these.
  final List<String> errors;

  /// Soft warnings from simulation ("snow always demotes", "rain never
  /// fires", "liquid conditions at cryogenic became snow").
  final List<String> warnings;

  /// A deterministic 7-day sample strip (winter, midday) for the editor's
  /// week row — segment weather so each day carries its display °C.
  final List<SegmentWeather> sampleWeek;

  const BiomePreview({
    required this.seasons,
    required this.errors,
    required this.warnings,
    required this.sampleWeek,
  });
}

/// Season → a fixture date inside it. Custom starts use the midpoint of
/// that slice so a moved summer is not still sampled on July 15.
const Map<String, (int, int)> _seasonDates = {
  'winter': (1, 15),
  'spring': (4, 15),
  'summer': (7, 15),
  'autumn': (10, 15),
};

/// Simulate [biome] across [seeds] independent chats × [daysPerSeason] days
/// in each season. Deterministic (fixed seed strings) so the same candidate
/// always previews identically.
BiomePreview previewBiome(
  Biome biome, {
  int seeds = 40,
  int daysPerSeason = 50,
}) {
  final errors = biome.validate();
  final warnings = <String>[];
  final seasons = <SeasonDistribution>[];

  for (final season in biome.seasonIds) {
    final date =
        biome.seasonStarts.isNotEmpty || !_seasonDates.containsKey(season)
        ? previewDateForSeason(season, biome.seasonStarts)
        : DateTime(2026, _seasonDates[season]!.$1, _seasonDates[season]!.$2);
    final condCounts = <String, int>{};
    final bandCounts = <String, int>{};
    var total = 0;
    var subColdDays = 0;

    for (var s = 0; s < seeds; s++) {
      for (var d = 1; d <= daysPerSeason; d++) {
        final w = WeatherEngine.weatherFor(
          sessionSeed: 'preview-$s',
          dayCount: d,
          date: date,
          biome: biome,
        );
        condCounts.update(w.condition.name, (v) => v + 1, ifAbsent: () => 1);
        bandCounts.update(w.temp.name, (v) => v + 1, ifAbsent: () => 1);
        total++;
        if (w.temp.rank < TempBand.cold.rank) subColdDays++;
      }
    }

    // Representative display temp: authored anchor first, else the
    // midpoint of the season's DOMINANT sampled band.
    String dominantBand = TempBand.mild.name;
    var best = -1;
    for (final e in bandCounts.entries) {
      if (e.value > best) {
        best = e.value;
        dominantBand = e.key;
      }
    }
    final domBand = TempBand.values.firstWhere(
      (b) => b.name == dominantBand,
      orElse: () => TempBand.mild,
    );
    final typicalTempC =
        biome.displayAnchorsC[season] ?? WeatherSegments.typicalBaseC(domBand);

    seasons.add(
      SeasonDistribution(
        season: season,
        conditionShare: {
          for (final e in condCounts.entries) e.key: e.value / total,
        },
        bandShare: {for (final e in bandCounts.entries) e.key: e.value / total},
        typicalTempC: typicalTempC,
      ),
    );

    // Demotion visibility, SHARE-based so intentional rain+snow mixes don't
    // false-alarm: compare each outcome's observed share against what its
    // raw weights alone would predict.
    final weights = biome.weights[season];
    if (weights != null && weights.length == kWeatherConditions.length) {
      final wTotal = weights.fold<int>(0, (a, b) => a + b);
      if (wTotal > 0) {
        final snowWeight = weights[WeatherCondition.snow.index];
        final intendedRain = weights[WeatherCondition.rain.index] / wTotal;
        final observedRain = (condCounts['rain'] ?? 0) / total;
        if (snowWeight > 0 && (condCounts['snow'] ?? 0) == 0) {
          warnings.add(
            '$season: you gave snow a chance, but the temperatures never '
            'get cold enough — every snow draw fell as rain.',
          );
        } else if (snowWeight > 0 && observedRain > intendedRain + 0.05) {
          warnings.add(
            '$season: a share of snow draws are falling as rain — the '
            'season may be warmer than you intended.',
          );
        }
        if (weights[WeatherCondition.rain.index] > 0 && subColdDays > 0) {
          warnings.add(
            '$season: rain at sub-cold temperatures freezes out as snow — '
            'rename or drop the rain column if that is not what you meant.',
          );
        }
      }
    }
  }

  // Dead columns: a condition weighted zero in EVERY season could simply be
  // removed from the author's mental model.
  for (final cond in WeatherCondition.values) {
    final everUsed = biome.seasonIds.any(
      (s) => (biome.weights[s]?[cond.index] ?? 0) > 0,
    );
    if (!everUsed && cond == WeatherCondition.rain) {
      warnings.add(
        'Rain is zero in every season — fine for a dry world; the rain '
        'column can stay empty.',
      );
    }
  }

  final sampleWeek = [
    for (var d = 1; d <= 7; d++)
      WeatherSegments.segmentWeatherFor(
        sessionSeed: 'preview-week',
        dayCount: d,
        date: previewDateForSeason(
          biome.seasonIds.contains('winter') ? 'winter' : biome.seasonIds.first,
          biome.seasonStarts,
        ),
        hour: 13, // midday — the number the chip would lead with
        biome: biome,
      ),
  ];

  return BiomePreview(
    seasons: seasons,
    errors: errors,
    warnings: warnings,
    sampleWeek: sampleWeek,
  );
}
