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

/// Structured result from the (now simplified) needs impact evaluation.
///
/// Deltas come from the model (verified/corrected by optional Director).
/// Straight decay ticks (in NeedsSimulation) + these scene deltas.
/// fulfillments (optional) drive targeted restores for clear acts.
/// reason for chips; intensity/activities kept minimal for Director narrative checks
/// and any legacy consumers (no buffer semantics).
class NeedsImpact {
  final Map<String, int> deltas;
  final Map<String, bool>? fulfillments;
  final String? reason;
  final int? intensity;
  final List<String> detectedActivities;

  const NeedsImpact({
    required this.deltas,
    this.fulfillments,
    this.reason,
    this.intensity,
    this.detectedActivities = const <String>[],
  });

  @override
  String toString() =>
      'NeedsImpact(deltas: $deltas, reason: $reason, activities: $detectedActivities)';

  NeedsImpact copyWith({
    Map<String, int>? deltas,
    Map<String, bool>? fulfillments,
    String? reason,
    int? intensity,
    List<String>? detectedActivities,
  }) {
    return NeedsImpact(
      deltas: deltas ?? this.deltas,
      fulfillments: fulfillments ?? this.fulfillments,
      reason: reason ?? this.reason,
      intensity: intensity ?? this.intensity,
      detectedActivities: detectedActivities ?? this.detectedActivities,
    );
  }
}
