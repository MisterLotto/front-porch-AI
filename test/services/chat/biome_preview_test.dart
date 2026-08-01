// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Preview-as-validation harness (custom climate editor). The preview runs
// the REAL engine, so these tests double as distribution envelopes for the
// editor's promises ("what you tuned is what plays").

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/biome_preview.dart';
import 'package:front_porch_ai/services/chat/weather_biomes.dart';

void main() {
  test('desert previews clear-dominant with zero snow', () {
    final p = previewBiome(Biome.desert, seeds: 10, daysPerSeason: 30);
    expect(p.errors, isEmpty);
    for (final s in p.seasons) {
      expect(s.conditionShare['clear'] ?? 0, greaterThan(0.5),
          reason: '${s.season} should be mostly clear');
      expect(s.conditionShare.containsKey('snow'), isFalse);
    }
    expect(p.sampleWeek, hasLength(7));
  });

  test('warm-world snow weight warns about demotion to rain', () {
    const warmSnowy = Biome(
      id: 'warm-snowy',
      displayName: 'x',
      description: '',
      weights: {
        // snow weighted in a season whose temps never reach cold
        'winter': [40, 20, 0, 0, 0, 0, 40],
        'spring': [60, 40, 0, 0, 0, 0, 0],
        'summer': [60, 40, 0, 0, 0, 0, 0],
        'autumn': [60, 40, 0, 0, 0, 0, 0],
      },
      baseTemp: {'winter': 3, 'spring': 3, 'summer': 4, 'autumn': 3},
    );
    final p = previewBiome(warmSnowy, seeds: 10, daysPerSeason: 30);
    expect(
      p.warnings.any((w) => w.contains('snow') && w.contains('rain')),
      isTrue,
      reason: 'the preview must explain where the snow went',
    );
  });

  test('validation errors surface as blocking errors', () {
    const broken = Biome(
      id: 'broken',
      displayName: 'x',
      description: '',
      weights: {
        'winter': [0, 0, 0, 0, 0, 0, 0], // zero-sum
        'spring': [50, 50, 0, 0, 0, 0, 0],
        'summer': [50, 50, 0, 0, 0, 0, 0],
        'autumn': [50, 50, 0, 0, 0, 0, 0],
      },
      baseTemp: {'winter': 0, 'spring': 2, 'summer': 3, 'autumn': 1},
    );
    final p = previewBiome(broken, seeds: 4, daysPerSeason: 10);
    expect(p.errors, isNotEmpty);
  });

  test('preview is deterministic for the same candidate', () {
    final a = previewBiome(Biome.highland, seeds: 6, daysPerSeason: 20);
    final b = previewBiome(Biome.highland, seeds: 6, daysPerSeason: 20);
    expect(
      a.seasons.first.conditionShare,
      b.seasons.first.conditionShare,
    );
    expect(
      [for (final d in a.sampleWeek) d.toString()],
      [for (final d in b.sampleWeek) d.toString()],
    );
  });
}
