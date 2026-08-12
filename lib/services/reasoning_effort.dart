// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// App-facing thinking strength (low / medium / high) and how it maps onto
// whatever ladder a remote model actually accepts. Shared by the remote
// payload builder and the settings UI so the labels users see match the
// wire behaviour.

/// App surface values — what the user picks in Settings / chat settings.
const List<String> kAppReasoningEfforts = ['low', 'medium', 'high'];

/// Full ladder any provider has used (for nearest-match math).
const Map<String, int> kReasoningEffortRank = {
  'none': 0,
  'minimal': 1,
  'low': 2,
  'medium': 3,
  'high': 4,
  'max': 5,
};

/// Short display title for a strength id.
String reasoningEffortTitle(String id) => switch (id) {
      'none' => 'Off',
      'minimal' => 'Minimal',
      'low' => 'Low',
      'medium' => 'Medium',
      'high' => 'High',
      'max' => 'Max',
      _ => id,
    };

/// One-line blurb under a strength chip.
String reasoningEffortBlurb(String id) => switch (id) {
      'low' => 'Light think — faster, cheaper',
      'medium' => 'Balanced — default',
      'high' => 'Deep think — slower, richer',
      'none' => 'No thinking tokens',
      'max' => 'Full thinking budget',
      'minimal' => 'Bare-minimum thinking',
      _ => '',
    };

/// Models whose provider taught us a supported set (process lifetime).
/// Written by [OpenRouterService] when a 400 lists supported values.
final Map<String, Set<String>> kLearnedReasoningEffortsByModel =
    <String, Set<String>>{};

/// Nano-style `:thinking` suffix often only accepts none / high / max.
const Set<String> kThinkingSuffixEffortHint = {'none', 'high', 'max'};

/// Hint (not a hard table): ids with `:thinking` commonly lack low/medium.
Set<String>? reasoningEffortHintForModel(String model) {
  if (model.toLowerCase().contains(':thinking')) {
    return kThinkingSuffixEffortHint;
  }
  return null;
}

/// Supported set for [model]: learned 400 > `:thinking` hint > null (verbatim).
Set<String>? reasoningEffortSupportedFor(String model) {
  if (model.isEmpty) return null;
  return kLearnedReasoningEffortsByModel[model] ??
      reasoningEffortHintForModel(model);
}

/// Closest supported stand-in. Keeps thinking ON — never maps to `none` when
/// any thinking tier exists.
String nearestReasoningEffort(String requested, Set<String> supported) {
  if (supported.contains(requested)) return requested;
  final req = kReasoningEffortRank[requested] ?? kReasoningEffortRank['medium']!;
  final thinking = supported.where((s) => s != 'none');
  final pool = (thinking.isNotEmpty ? thinking : supported)
      .where(kReasoningEffortRank.containsKey);
  if (pool.isEmpty) return requested;
  return pool.reduce((a, b) {
    final da = (kReasoningEffortRank[a]! - req).abs();
    final db = (kReasoningEffortRank[b]! - req).abs();
    if (da != db) return da < db ? a : b;
    return kReasoningEffortRank[a]! < kReasoningEffortRank[b]! ? a : b;
  });
}

/// Value that will go on the wire for [model] given the user's [requested].
String wireReasoningEffort(String model, String requested) {
  final supported = reasoningEffortSupportedFor(model);
  if (supported == null) return requested;
  return nearestReasoningEffort(requested, supported);
}

/// True when the app pick differs from what the model will receive.
bool reasoningEffortIsRemapped(String model, String requested) {
  if (model.isEmpty || requested.isEmpty) return false;
  return wireReasoningEffort(model, requested) != requested;
}

/// User-facing caption: what this strength becomes on the current model.
///
/// Empty when there is no model context or no remap.
String reasoningEffortMappingCaption(String model, String requested) {
  if (model.isEmpty || requested.isEmpty) return '';
  final supported = reasoningEffortSupportedFor(model);
  if (supported == null) {
    return 'Sent as ${reasoningEffortTitle(requested).toLowerCase()}. '
        'If this model only accepts other levels, Front Porch maps to the '
        'closest one automatically.';
  }
  final wire = nearestReasoningEffort(requested, supported);
  final allowed = supported
      .where((s) => s != 'none')
      .map(reasoningEffortTitle)
      .join(' · ');
  if (wire == requested) {
    return 'This model accepts: $allowed. '
        'Your pick matches — sent as ${reasoningEffortTitle(wire).toLowerCase()}.';
  }
  return 'This model accepts: $allowed. '
      '${reasoningEffortTitle(requested)} → sent as '
      '${reasoningEffortTitle(wire).toLowerCase()}.';
}

/// Parse "Supported values are: none, high, max" from a provider error body.
Set<String>? supportedReasoningEffortsFromError(String msg) {
  final m = msg.toLowerCase();
  if (!m.contains('reasoning.effort') && !m.contains('reasoning effort')) {
    return null;
  }
  final listing = m.indexOf('supported values');
  if (listing < 0) return null;
  final colon = m.indexOf(':', listing);
  if (colon < 0) return null;
  final values = RegExp(r'[a-z]+')
      .allMatches(m.substring(colon + 1))
      .map((x) => x.group(0)!)
      .where(kReasoningEffortRank.containsKey)
      .toSet();
  return values.isEmpty ? null : values;
}

/// Remember a provider's supported set for [model] (process lifetime).
void rememberReasoningEffortsForModel(String model, Set<String> supported) {
  if (model.isEmpty || supported.isEmpty) return;
  kLearnedReasoningEffortsByModel[model] = Set<String>.from(supported);
}
