// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

library;

import 'package:front_porch_ai/services/chat/season_calendar.dart';
import 'package:front_porch_ai/services/chat/season_labels.dart';
import 'package:front_porch_ai/services/chat/weather_biomes.dart';

/// Deterministic story weather (docs/design/living-time-features.md §3).
///
/// Pure math over state the app already has — NOTHING is stored. The same
/// (sessionSeed, dayCount, date) always yields the same weather, on every
/// platform and across app restarts, so save/load, group re-entry, and the
/// web facade all agree for free. Determinism rests on a hand-rolled FNV-1a
/// hash + xorshift PRNG because Dart's String.hashCode is not guaranteed
/// stable across VM versions.
///
/// Day-to-day continuity is a persistence-biased walk from day 1: each day
/// either keeps yesterday's condition (45%) or resamples from the season's
/// weight table, so fronts roll through over a few days instead of strobing.
/// Optional [Biome] parameter (Living Worlds) swaps the season tables;
/// null biome is temperate ≡ historical defaults.
/// The walk is O(dayCount) of integer math — microseconds even for
/// thousand-day chats — so callers just call [weatherFor]; no caching layer
/// is needed (the Riverpod UI provider memoizes by inputs anyway).

enum WeatherCondition { clear, cloudy, overcast, fog, rain, storm, snow }

/// DECLARATION order is storage order, not thermal order: biome JSON persists
/// `baseTemp` as raw indices, and 0..4 (cold..hot) were in users' databases
/// before the extremes existed — so the Phase 2 bands APPEND (indices 5..7)
/// and all ordering arithmetic goes through [TempBandThermal.rank] instead of
/// `.index`. Never reorder this enum.
enum TempBand { cold, cool, mild, warm, hot, cryogenic, furnace, inferno }

/// Thermal ordering for the bands (coldest → hottest):
/// cryogenic < cold < cool < mild < warm < hot < furnace < inferno.
/// The classic span is rank 0..4; extremes are reachable only by biomes that
/// widen [Biome.bandRange] (living-worlds.md §3 Rev.3 determinism guard).
extension TempBandThermal on TempBand {
  /// Delegates to the storage layer's [kTempBandRankByIndex] — one source of
  /// truth shared with Biome.validate (biomes can't import this file back).
  int get rank => kTempBandRankByIndex[index];

  /// True for the bands outside the classic cold..hot span.
  bool get isExtreme =>
      rank < kClassicBandRange.$1 || rank > kClassicBandRange.$2;

  /// Inverse of [rank], derived from the same table so a future band can
  /// never leave the two out of sync (out-of-range input clamps to the
  /// nearest extreme).
  static TempBand fromRank(int rank) {
    final r = rank.clamp(kFullBandRange.$1, kFullBandRange.$2);
    return TempBand.values[kTempBandRankByIndex.indexOf(r)];
  }
}

/// One story day's weather. Value type (== by fields) so Riverpod family
/// consumers rebuild only on real change.
class DailyWeather {
  final WeatherCondition condition;
  final TempBand temp;

  /// 'winter' | 'spring' | 'summer' | 'autumn' (northern-hemisphere months).
  final String season;

  const DailyWeather({
    required this.condition,
    required this.temp,
    required this.season,
  });

  @override
  bool operator ==(Object other) =>
      other is DailyWeather &&
      other.condition == condition &&
      other.temp == temp &&
      other.season == season;

  @override
  int get hashCode => Object.hash(condition, temp, season);

  @override
  String toString() => 'DailyWeather(${condition.name}, ${temp.name}, $season)';
}

class WeatherEngine {
  WeatherEngine._(); // static-only

  /// Persistence chance of keeping yesterday's condition (weather "fronts").
  static const int _stayPermille = 450;

  /// Season condition weights (clear, cloudy, overcast, fog, rain, storm,
  /// snow). Snow weight is only nonzero in winter; a snow draw outside cold
  /// temps demotes to rain in [_conditionFor].
  static const Map<String, List<int>> _seasonWeights = {
    'winter': [20, 20, 20, 10, 10, 2, 18],
    'spring': [30, 25, 15, 8, 18, 4, 0],
    'summer': [45, 22, 8, 2, 12, 11, 0],
    'autumn': [24, 24, 20, 10, 16, 6, 0],
  };

  /// Season base temperature band index into [TempBand.values].
  static const Map<String, int> _seasonBaseTemp = {
    'winter': 0, // cold
    'spring': 2, // mild
    'summer': 3, // warm
    'autumn': 1, // cool
  };

  static String seasonOf(DateTime date) {
    switch (date.month) {
      case 12:
      case 1:
      case 2:
        return 'winter';
      case 3:
      case 4:
      case 5:
        return 'spring';
      case 6:
      case 7:
      case 8:
        return 'summer';
      default:
        return 'autumn';
    }
  }

  /// The weather for story day [dayCount] of the chat whose stable identity
  /// is [sessionSeed] (the session id), where [date] is the story-clock date
  /// of that day (used for seasons — day d in the walk is dated
  /// `date - (dayCount - d)` days).
  ///
  /// Living Worlds: [biome] applies to every day (null ⇒ temperate ≡ historical
  /// tables). [biomeAtDay] (when set) selects the climate for each walk day so
  /// mid-chat switches keep days before the changeover byte-identical — RNG is
  /// keyed by day index, not a running stream. Prefer one or the other;
  /// [biomeAtDay] wins when both are provided.
  static DailyWeather weatherFor({
    required String sessionSeed,
    required int dayCount,
    required DateTime date,

    /// Living Worlds biome. Null ⇒ temperate (byte-identical to pre-biome).
    Biome? biome,

    /// Per-day climate (mid-chat spans). When null, [biome] is used for all days.
    Biome Function(int day)? biomeAtDay,
  }) {
    final days = dayCount < 1 ? 1 : dayCount;
    final base = _fnv1a(sessionSeed);
    // Fixed climate path keeps a single reference so temperate/null stays
    // bit-identical to the pre-span engine (acceptance gate).
    final Biome? fixed = biomeAtDay == null ? (biome ?? Biome.temperate) : null;

    WeatherCondition cond = WeatherCondition.clear;
    TempBand temp = TempBand.mild;
    String season = 'spring';
    for (int d = 1; d <= days; d++) {
      final climate = fixed ?? biomeAtDay!(d);
      final dayDate = date.subtract(Duration(days: days - d));
      season = climate.seasonStarts.isEmpty
          ? seasonOf(dayDate)
          : seasonOnDate(dayDate, climate.seasonStarts);
      final rng = WeatherRng(base ^ (d * 0x9E3779B9));
      final stay = d > 1 && rng.nextPermille() < _stayPermille;
      temp = _tempFor(season, rng, climate);
      if (!stay) {
        cond = _conditionFor(season, temp, rng, climate);
      } else if (cond == WeatherCondition.snow &&
          temp.rank > TempBand.cold.rank) {
        // Thaw: persisted snow melts to rain when WARMER than cold. Rank
        // comparison (not != cold) so cryogenic keeps its snow — CO₂ frost
        // does not melt. Identical to the old check for classic bands.
        cond = WeatherCondition.rain;
      } else if (cond == WeatherCondition.rain &&
          temp.rank < TempBand.cold.rank) {
        // Symmetric promotion: liquid rain cannot fall below cold — a
        // persisted rain front at cryogenic freezes out as snow. (Storm is
        // deliberately left alone: it is generic violent weather that skins
        // rename — a Martian dust storm must not become a blizzard.)
        cond = WeatherCondition.snow;
      }
    }
    return DailyWeather(condition: cond, temp: temp, season: season);
  }

  static TempBand _tempFor(String season, WeatherRng rng, Biome biome) {
    final baseMap = biome.baseTemp.isNotEmpty
        ? biome.baseTemp
        : _seasonBaseTemp;
    final jitter = rng.nextPermille() < 250
        ? -1
        : rng.nextPermille() < 250
        ? 1
        : 0;
    final raw = baseMap[season] ?? 2;
    // Domain-invalid spans (backwards, out of (-1..6)) REJECT to classic —
    // the same semantics fromJson applies to garbage JSON — so a programmatic
    // Biome that skipped validate() can neither crash the walk nor pin
    // itself into a permanent extreme.
    var (lo, hi) = biome.bandRange;
    if (lo > hi || lo < kFullBandRange.$1 || hi > kFullBandRange.$2) {
      (lo, hi) = kClassicBandRange;
    }
    if ((lo, hi) == kClassicBandRange) {
      // BYTE-IDENTITY PATH — every pre-extremes biome (and any JSON without
      // an explicitly widened range) reproduces the ORIGINAL formula on the
      // RAW stored int, including out-of-spec values old imports accepted
      // unvalidated: negative bases floor AFTER jitter (always cold), >4
      // saturates to hot. Adversarial review proved a rank decode here
      // rewrites such chats' history (stored 5 = cryogenic's index flipped
      // permanent-hot chats to permanent-cold). Do not "clean this up".
      final idx = (raw + jitter).clamp(
        kClassicBandRange.$1,
        kClassicBandRange.$2,
      );
      return TempBand.values[idx];
    }
    // WIDENED-RANGE PATH (explicitly authored extremes, no legacy data):
    // decode the declaration index to its thermal rank, jitter, clamp to the
    // authored span.
    final baseIdx = raw.clamp(0, TempBand.values.length - 1);
    final rank = (TempBand.values[baseIdx].rank + jitter).clamp(lo, hi);
    return TempBandThermal.fromRank(rank);
  }

  static WeatherCondition _conditionFor(
    String season,
    TempBand temp,
    WeatherRng rng,
    Biome biome,
  ) {
    final weightMap = biome.weights.isNotEmpty ? biome.weights : _seasonWeights;
    final weights =
        weightMap[season] ?? weightMap['spring'] ?? _seasonWeights['spring']!;
    final total = weights.fold(0, (a, b) => a + b);
    if (total <= 0) {
      return WeatherCondition.clear; // defensive: zero-sum weights
    }
    var roll = rng.next() % total;
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        final cond = WeatherCondition.values[i];
        if (cond == WeatherCondition.snow && temp.rank > TempBand.cold.rank) {
          return WeatherCondition.rain; // demote only when warmer than cold
        }
        if (cond == WeatherCondition.rain && temp.rank < TempBand.cold.rank) {
          return WeatherCondition.snow; // no liquid rain below cold
        }
        return cond;
      }
    }
    return WeatherCondition.clear; // unreachable; weights are non-empty
  }

  // ── Shared display helpers (single source for desktop UI, injection, web) ──

  static String emoji(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.clear:
        return '☀️';
      case WeatherCondition.cloudy:
        return '⛅';
      case WeatherCondition.overcast:
        return '☁️';
      case WeatherCondition.fog:
        return '🌫️';
      case WeatherCondition.rain:
        return '🌧️';
      case WeatherCondition.storm:
        return '⛈️';
      case WeatherCondition.snow:
        return '❄️';
    }
  }

  static String label(DailyWeather w) {
    final cond = switch (w.condition) {
      WeatherCondition.clear => 'Clear',
      WeatherCondition.cloudy => 'Partly cloudy',
      WeatherCondition.overcast => 'Overcast',
      WeatherCondition.fog => 'Foggy',
      WeatherCondition.rain => 'Rain',
      WeatherCondition.storm => 'Storm',
      WeatherCondition.snow => 'Snow',
    };
    return '$cond · ${_tempWord(w.temp)}';
  }

  /// One banded prose phrase for the prompt state block — words only, no
  /// numbers (prompt-state-injection.md contract).
  static String prose(DailyWeather w, {Map<String, String>? seasonLabels}) {
    final t = _tempWord(w.temp);
    final s = seasonPromptName(w.season, seasonLabels ?? const {});
    switch (w.condition) {
      case WeatherCondition.clear:
        return 'The sky is clear and the air is $t — a bright $s day.';
      case WeatherCondition.cloudy:
        return 'Broken clouds drift over a $t $s day.';
      case WeatherCondition.overcast:
        return 'A flat grey overcast hangs over this $t $s day.';
      case WeatherCondition.fog:
        return 'Fog has settled in, $t and muffling — deep $s.';
      case WeatherCondition.rain:
        return 'A $t, steady rain is falling — $s weather.';
      case WeatherCondition.storm:
        return 'A storm is rolling through, $t wind and hard rain — wild $s weather.';
      case WeatherCondition.snow:
        return 'Snow is falling in the $t air — deep $s.';
    }
  }

  /// One words-only "sign in the sky" of tomorrow's weather, or '' when
  /// nothing notable is coming (same condition, minor cloud shuffle).
  /// Because [weatherFor] is a prefix-stable deterministic walk, tomorrow is
  /// already decided today — so this foreshadowing never lies, and characters
  /// can see fronts rolling in instead of being ambushed by every change.
  /// Only meaningful transitions speak: incoming precipitation/fog, a real
  /// clear-up after grey or wet weather, or a two-band temperature swing.
  static String foreshadow(DailyWeather today, DailyWeather tomorrow) {
    // Crossing into (or out of) a lethal band outranks every other sign —
    // "a storm is coming" is trivia next to "tomorrow kills the unprotected".
    // Unreachable for classic biomes (isExtreme is never true there), so
    // legacy foreshadow text is untouched.
    if (tomorrow.temp.isExtreme && tomorrow.temp != today.temp) {
      // Any move INTO a lethal band — or BETWEEN them (an authored
      // cryogenic-winter/furnace-summer world flips across a season edge) —
      // gets the survival warning for tomorrow's side.
      return tomorrow.temp.rank < TempBand.cold.rank
          ? 'The cold coming tomorrow is the killing kind — whatever needs '
                'doing outside happens today.'
          : 'Tomorrow\'s heat will be beyond anything survivable in the '
                'open — plan for cover before it arrives.';
    }
    if (today.temp.isExtreme && !tomorrow.temp.isExtreme) {
      return today.temp.rank < TempBand.cold.rank
          ? 'The deep cold should finally break by tomorrow.'
          : 'The lethal heat should finally ease by tomorrow.';
    }
    const wet = {
      WeatherCondition.rain,
      WeatherCondition.storm,
      WeatherCondition.snow,
      WeatherCondition.fog,
    };
    final from = today.condition;
    final to = tomorrow.condition;
    if (to != from) {
      switch (to) {
        case WeatherCondition.storm:
          return 'The air is heavy and electric — a storm is building and '
              'should break by tomorrow.';
        case WeatherCondition.snow:
          return 'There is a raw bite to the wind — snow is on its way.';
        case WeatherCondition.rain:
          return from == WeatherCondition.storm
              ? 'The worst of the storm should pass by tomorrow, easing into '
                    'steady rain.'
              : 'Clouds are banking on the horizon — it smells like rain '
                    'coming.';
        case WeatherCondition.fog:
          return 'The air is turning damp and still — fog will likely settle '
              'in overnight.';
        case WeatherCondition.clear:
          if (wet.contains(from) || from == WeatherCondition.overcast) {
            return 'The weather looks ready to break — clear skies are on '
                'the way.';
          }
        case WeatherCondition.cloudy:
          if (wet.contains(from)) {
            return 'The weather should ease by tomorrow, breaking up into '
                'scattered clouds.';
          }
        case WeatherCondition.overcast:
          if (from == WeatherCondition.clear ||
              from == WeatherCondition.cloudy) {
            return 'High clouds are thickening — tomorrow looks flat and '
                'grey.';
          }
      }
    }
    final swing = tomorrow.temp.rank - today.temp.rank;
    if (swing <= -2) {
      return 'A cold snap is moving in — tomorrow will feel much colder.';
    }
    if (swing >= 2) {
      return 'A warm front is pushing through — tomorrow should feel a good '
          'deal warmer.';
    }
    return '';
  }

  /// Public banded temperature word — shared with the intra-day segment
  /// layer (weather_segments.dart) so the two files can't drift apart.
  static String tempWord(TempBand t) => _tempWord(t);

  /// Stable seed for [sessionSeed] — the same FNV-1a base the daily walk
  /// uses, exposed so the segment layer derives its own INDEPENDENT RNG
  /// streams from it (never drawing from the walk's RNG, which would
  /// perturb the pinned daily sequences of existing chats).
  static int seedFor(String sessionSeed) => _fnv1a(sessionSeed);

  static String _tempWord(TempBand t) {
    switch (t) {
      case TempBand.cryogenic:
        return 'lethally cold';
      case TempBand.cold:
        return 'cold';
      case TempBand.cool:
        return 'cool';
      case TempBand.mild:
        return 'mild';
      case TempBand.warm:
        return 'warm';
      case TempBand.hot:
        return 'hot';
      case TempBand.furnace:
        return 'furnace-hot';
      case TempBand.inferno:
        return 'incinerating';
    }
  }

  /// FNV-1a 32-bit — stable across platforms/VM versions, unlike
  /// String.hashCode.
  static int _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash == 0 ? 0x811c9dc5 : hash;
  }
}

/// Tiny xorshift32 — deterministic, allocation-free. Public (with a private
/// alias below for the walk) so weather_segments.dart shares the exact PRNG
/// instead of duplicating it; treat as internal to the weather subsystem.
class WeatherRng {
  int _state;
  WeatherRng(int seed)
    : _state = (seed & 0xFFFFFFFF) == 0 ? 0xDEADBEEF : (seed & 0xFFFFFFFF);

  int next() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >>> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state;
  }

  int nextPermille() => next() % 1000;
}
