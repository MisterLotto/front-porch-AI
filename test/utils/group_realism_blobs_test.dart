// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/utils/group_realism_blobs.dart';

void main() {
  // A representative two-member seed set, matching the shape the group creator
  // builds in `_memberRealismSeeds`: scalars + needs map + intragroup
  // relationships (targetId -> feeling) + per-need baselines.
  Map<String, Map<String, dynamic>> sampleSeeds() => {
    'alice': {
      'affection': 75,
      'trust': 60,
      'emotion': 'affection',
      'emotionIntensity': 'strong',
      'needs': {'hunger': 80, 'social': 65},
      'relationships': {'bob': 40},
      'needsBaselineHunger': 80,
      'needsDecayHunger': 5,
    },
    'bob': {
      'affection': 35,
      'trust': 40,
      'emotion': 'neutral',
      'emotionIntensity': 'mild',
      'needs': {'hunger': 80},
      'relationships': {'alice': -20},
    },
  };

  group('buildGroupRealismBlobs — canonical group-creator contract', () {
    test('defaultMemberRealismState wraps the FULL seed under perChar[id] '
        '(what the realism engine reads)', () {
      final blobs = buildGroupRealismBlobs(
        seeds: sampleSeeds(),
        needsEnabled: true,
        timeOfDay: 'evening',
        dayCount: 3,
      );
      final dm = jsonDecode(blobs.defaultMemberJson) as Map<String, dynamic>;
      final perChar = dm['perChar'] as Map<String, dynamic>;

      expect(perChar.keys, containsAll(['alice', 'bob']));
      expect((perChar['alice'] as Map)['affection'], 75);
      expect((perChar['alice'] as Map)['trust'], 60);
      // Needs + per-need baseline/decay survive.
      expect(((perChar['alice'] as Map)['needs'] as Map)['hunger'], 80);
      expect((perChar['alice'] as Map)['needsDecayHunger'], 5);
      // Intragroup dynamics (relationships) survive — the whole point.
      expect(((perChar['alice'] as Map)['relationships'] as Map)['bob'], 40);
      expect(((perChar['bob'] as Map)['relationships'] as Map)['alice'], -20);
    });

    test('baselineRealismState is scalars-only + global time/day '
        '(no needs, no relationships)', () {
      final blobs = buildGroupRealismBlobs(
        seeds: sampleSeeds(),
        needsEnabled: true,
        timeOfDay: 'evening',
        dayCount: 3,
      );
      final base = jsonDecode(blobs.baselineJson) as Map<String, dynamic>;

      expect(base['alice'], {
        'affection': 75,
        'trust': 60,
        'emotion': 'affection',
        'emotionIntensity': 'strong',
        'timeOfDay': 'evening',
        'dayCount': 3,
      });
      expect((base['alice'] as Map).containsKey('needs'), isFalse);
      expect((base['alice'] as Map).containsKey('relationships'), isFalse);
    });

    test('missing scalars fall back to the documented defaults (35/40/neutral/mild)',
        () {
      final blobs = buildGroupRealismBlobs(
        seeds: {
          'x': {'relationships': <String, int>{}},
        },
        needsEnabled: true,
        timeOfDay: 'morning',
        dayCount: 1,
      );
      final base = (jsonDecode(blobs.baselineJson) as Map)['x'] as Map;
      expect(base['affection'], 35);
      expect(base['trust'], 40);
      expect(base['emotion'], 'neutral');
      expect(base['emotionIntensity'], 'mild');
    });

    test('needs disabled strips the needs map from both blobs '
        'but keeps relationships', () {
      final blobs = buildGroupRealismBlobs(
        seeds: sampleSeeds(),
        needsEnabled: false,
        timeOfDay: 'noon',
        dayCount: 1,
      );
      final perChar =
          (jsonDecode(blobs.defaultMemberJson) as Map)['perChar'] as Map;
      expect((perChar['alice'] as Map).containsKey('needs'), isFalse);
      expect(((perChar['alice'] as Map)['relationships'] as Map)['bob'], 40);
    });

    test('stripping needs does NOT mutate the caller\'s seed map', () {
      final seeds = sampleSeeds();
      buildGroupRealismBlobs(
        seeds: seeds,
        needsEnabled: false,
        timeOfDay: 'noon',
        dayCount: 1,
      );
      // The original seed still has its needs — build worked on a copy.
      expect(seeds['alice']!.containsKey('needs'), isTrue);
    });
  });

  group('parseGroupRealismSeeds — inverse (editor load)', () {
    test('round-trips: parse(build(seeds).defaultMemberJson) == seeds', () {
      final seeds = sampleSeeds();
      final blobs = buildGroupRealismBlobs(
        seeds: seeds,
        needsEnabled: true,
        timeOfDay: 'morning',
        dayCount: 1,
      );
      final back = parseGroupRealismSeeds(blobs.defaultMemberJson);
      expect(back, seeds); // deep equality — lossless load↔save
    });

    test('blank / absent state yields an empty map', () {
      expect(parseGroupRealismSeeds(''), isEmpty);
      expect(parseGroupRealismSeeds('{}'), isEmpty);
      expect(parseGroupRealismSeeds('{"perChar":{}}'), isEmpty);
    });

    test('tolerates a legacy blob with no perChar wrapper', () {
      expect(parseGroupRealismSeeds('{"alice":{"affection":10}}'), isEmpty);
    });
  });
}
