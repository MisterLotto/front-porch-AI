// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Slice 1 season display names. Ids stay winter/spring/summer/autumn.

/// Shown name for a season id. Custom label wins; blank/missing keeps [id]
/// (`winter`) so stock climates do not change a character.
String seasonDisplayName(String id, [Map<String, String> labels = const {}]) {
  final custom = labels[id]?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  return id;
}

/// Prompt word. Custom label wins; else the stock midwinter/high-summer
/// register so existing prose tests stay byte-identical.
String seasonPromptName(String id, [Map<String, String> labels = const {}]) {
  final custom = labels[id]?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  return switch (id) {
    'winter' => 'midwinter',
    'summer' => 'high-summer',
    _ => id,
  };
}

Map<String, String> parseSeasonLabels(Map<String, dynamic> json) {
  final raw = json['seasonLabels'] ?? json['season_labels'];
  if (raw is! Map) return const {};
  final out = <String, String>{};
  for (final e in raw.entries) {
    final v = e.value?.toString().trim() ?? '';
    if (v.isEmpty) continue;
    out[e.key.toString()] = v;
  }
  return out;
}
