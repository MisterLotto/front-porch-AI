// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import 'dart:convert';

/// Canonical (de)serialization for a group's per-member realism/needs/dynamics
/// seeds ↔ the two GroupChat blobs (`defaultMemberRealismState`,
/// `baselineRealismState`). Extracted verbatim from the group creator so that
/// the create wizard AND the post-creation group editor produce identical state
/// — one contract, one source of truth, and testable in isolation.
///
/// Shapes (the exact contract the realism engine reads):
/// - `defaultMemberRealismState` = `{ "perChar": { memberId: <full seed> } }`,
///   where the full seed carries `affection`/`trust`/`emotion`/`emotionIntensity`,
///   the `needs` map, the `relationships` map (intragroup feelings, targetId→int),
///   and the per-need baseline/decay fields.
/// - `baselineRealismState` = `{ memberId: {affection, trust, emotion,
///   emotionIntensity, timeOfDay, dayCount} }` — scalars only (no needs/relationships).
class GroupRealismBlobs {
  /// JSON for `GroupChat.defaultMemberRealismState`.
  final String defaultMemberJson;

  /// JSON for `GroupChat.baselineRealismState`.
  final String baselineJson;

  const GroupRealismBlobs({
    required this.defaultMemberJson,
    required this.baselineJson,
  });
}

/// Serialize [seeds] (memberId → seed map) into the two group realism blobs,
/// exactly as the group creator does. When [needsEnabled] is false the `needs`
/// map is stripped from every member (both blobs) — relationships are always kept.
GroupRealismBlobs buildGroupRealismBlobs({
  required Map<String, Map<String, dynamic>> seeds,
  required bool needsEnabled,
  required String timeOfDay,
  required int dayCount,
}) {
  final defaultMember = <String, dynamic>{'perChar': <String, dynamic>{}};
  final baseline = <String, dynamic>{};

  seeds.forEach((id, rawSeed) {
    var seed = rawSeed;
    if (!needsEnabled) {
      seed = Map<String, dynamic>.from(seed)..remove('needs');
    }
    (defaultMember['perChar'] as Map)[id] = seed;
    baseline[id] = {
      'affection': (seed['affection'] as num?)?.toInt() ?? 35,
      'trust': (seed['trust'] as num?)?.toInt() ?? 40,
      'emotion': (seed['emotion'] as String?) ?? 'neutral',
      'emotionIntensity': (seed['emotionIntensity'] as String?) ?? 'mild',
      'timeOfDay': timeOfDay,
      'dayCount': dayCount,
    };
  });

  return GroupRealismBlobs(
    defaultMemberJson: jsonEncode(defaultMember),
    baselineJson: jsonEncode(baseline),
  );
}

/// Inverse of [buildGroupRealismBlobs]: read the per-member seeds back out of a
/// group's `defaultMemberRealismState` (the `perChar` map holds the full seeds).
/// Returns an empty map for absent/blank state.
Map<String, Map<String, dynamic>> parseGroupRealismSeeds(
  String defaultMemberJson,
) {
  if (defaultMemberJson.isEmpty || defaultMemberJson == '{}') return {};
  final decoded = jsonDecode(defaultMemberJson);
  final perChar = decoded is Map ? decoded['perChar'] : null;
  if (perChar is! Map) return {};
  return perChar.map(
    (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
  );
}
