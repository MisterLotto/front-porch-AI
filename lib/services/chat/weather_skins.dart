// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Condition skins made real (living-worlds.md §3, phase 2 step ④): a custom
// climate may RENAME a condition ("rain" → "Dust Squall"), and the rename
// carries a mandatory stance that drives CODE-OWNED behavior text — the
// safety net that stops acid rain being danced in. Pure helpers shared by
// the prompt injection, the sidebar chip, and the web facade, so every
// surface renames identically (parity by construction). Words only — the
// prompt contract holds for skinned weather too.

import 'package:front_porch_ai/services/chat/weather_biomes.dart';
import 'package:front_porch_ai/services/chat/weather_engine.dart';
import 'package:front_porch_ai/services/chat/weather_segments.dart';

/// The active skin for [c] under [biome], or null when the condition keeps
/// its normal identity (no skin, or a skin without a real rename).
ConditionSkin? skinFor(Biome biome, WeatherCondition c) {
  final skin = biome.conditionSkin[c.name];
  if (skin == null || skin.label.trim().isEmpty) return null;
  return skin;
}

/// Display label for a condition — the skin's rename or the stock word.
String skinnedConditionLabel(Biome biome, WeatherCondition c) {
  final skin = skinFor(biome, c);
  if (skin != null) return skin.label.trim();
  return switch (c) {
    WeatherCondition.clear => 'Clear',
    WeatherCondition.cloudy => 'Partly cloudy',
    WeatherCondition.overcast => 'Overcast',
    WeatherCondition.fog => 'Foggy',
    WeatherCondition.rain => 'Rain',
    WeatherCondition.storm => 'Storm',
    WeatherCondition.snow => 'Snow',
  };
}

/// Chip emoji — the skin's emoji or the stock one.
String skinnedEmoji(Biome biome, WeatherCondition c) {
  final skin = skinFor(biome, c);
  final e = skin?.emoji?.trim();
  return (e != null && e.isNotEmpty) ? e : WeatherEngine.emoji(c);
}

/// Chip text: skinned condition label + numeric temperature.
String skinnedChipLabel(
  SegmentWeather w,
  Biome biome, {
  required bool fahrenheit,
}) {
  final skin = skinFor(biome, w.condition);
  if (skin == null) return WeatherSegments.label(w, fahrenheit: fahrenheit);
  return '${skin.label.trim()} · '
      '${WeatherSegments.formatTemp(w.tempC, fahrenheit: fahrenheit)}';
}

/// Code-owned stance behavior — never author prose (the author gets one
/// flavour line on top; behavior comes from here so a minimal-effort skin
/// still behaves).
String? stanceLine(WeatherStance s) => switch (s) {
  WeatherStance.pleasant || WeatherStance.ordinary => null,
  WeatherStance.harsh =>
    'It is rough out in this — being outside is unpleasant and people cut '
        'it short.',
  WeatherStance.dangerous =>
    'Being caught out in this is genuinely harmful; characters shelter, '
        'and going outside is a deliberate risk.',
  WeatherStance.deadly =>
    'Exposure to this kills. Nobody goes out unprotected, and shelter is '
        'the only sane plan.',
};

/// Author flavour, capped — it sits adjacent to a behavioral directive in
/// the prompt, so it gets tighter limits than lorebook prose.
String? _cappedFlavour(ConditionSkin skin) {
  final f = skin.flavour?.trim();
  if (f == null || f.isEmpty) return null;
  return f.length > 140 ? f.substring(0, 140).trimRight() : f;
}

/// Prompt prose for the current segment under [biome]. Unskinned conditions
/// keep the stock sentence verbatim; a skinned condition speaks by its new
/// name with its stance's code-owned behavior, and at dangerous+ the stance
/// REPLACES the dressing-cue phrasing entirely (the surface that failed in
/// the doc's cardigan-into-acid example).
String skinnedProse(SegmentWeather w, Biome biome) {
  final skin = skinFor(biome, w.condition);
  if (skin == null) return WeatherSegments.prose(w);

  final label = skin.label.trim();
  final when = switch (w.segment) {
    DaySegment.morning => 'this morning',
    DaySegment.afternoon => 'this afternoon',
    DaySegment.evening => 'this evening',
    DaySegment.night => 'tonight',
  };
  final parts = <String>[];
  final behaviour = stanceLine(skin.stance);
  final dangerous = skin.stance == WeatherStance.dangerous ||
      skin.stance == WeatherStance.deadly;
  if (!dangerous) {
    parts.add('Outside it is ${WeatherSegments.dressCue(w.day.temp)}.');
  }
  parts.add('$label $when.');
  final flavour = _cappedFlavour(skin);
  if (flavour != null) parts.add(flavour);
  if (behaviour != null) parts.add(behaviour);
  return parts.join(' ');
}

/// Within-day transition, skin-aware: when either side is renamed the stock
/// sentence would leak the old word ("the rain has eased" on a world where
/// rain is Dust Squall), so renamed shifts get a neutral labelled sentence.
String skinnedTransition(
  SegmentWeather prev,
  SegmentWeather now,
  Biome biome,
) {
  if (prev.condition == now.condition) return '';
  final prevSkin = skinFor(biome, prev.condition);
  final nowSkin = skinFor(biome, now.condition);
  if (prevSkin == null && nowSkin == null) {
    return WeatherSegments.transition(prev, now);
  }
  final from = skinnedConditionLabel(biome, prev.condition);
  final to = skinnedConditionLabel(biome, now.condition);
  return 'The $from has given way to $to since earlier.';
}

/// Tomorrow's sign, skin-aware. A skinned dangerous/deadly tomorrow becomes
/// a DEADLINE — the payoff the design names: exact foreshadowing composes
/// with stance, so dangerous weather is narrative structure, not scenery.
/// Returns the stock foreshadow otherwise.
String skinnedForeshadow(
  DailyWeather today,
  DailyWeather tomorrow,
  Biome biome,
) {
  if (tomorrow.condition != today.condition) {
    final skin = skinFor(biome, tomorrow.condition);
    if (skin != null) {
      final label = skin.label.trim();
      if (skin.stance == WeatherStance.dangerous ||
          skin.stance == WeatherStance.deadly) {
        return 'The signs say the $label comes tomorrow — whatever matters '
            'outside happens today, and cover is arranged before it arrives.';
      }
      // Milder renames still speak by their new name — the stock foreshadow
      // would leak "rain"/"storm" on a world that renamed them.
      return 'The signs point to $label tomorrow.';
    }
  }
  return WeatherEngine.foreshadow(today, tomorrow);
}
