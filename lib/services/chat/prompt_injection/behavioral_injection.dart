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

import 'package:front_porch_ai/services/chat/relationship_service.dart';

/// Fixation + spatial-stance fragments for the words-only state block
/// (docs/design/prompt-state-injection.md §3). Both are free-text fields (may
/// legitimately contain digits); both are salience-gated to silence.
///
/// GROUP-SAFETY CONTRACT: this leaf reads RelationshipService SCALARS, which
/// are per-speaker-valid at assembly time because `_loadGroupRealismIntoScalars`
/// (chat_service_realism_dance.dart) calls
/// `loadRelationshipScalarsForSpeaker(charId)` — which copies activeFixation,
/// fixationLifespan, AND spatialStance for the upcoming speaker — before any
/// prompt is built. If that dance ever stops covering these fields, this
/// fragment must switch to defensive group-map reads like
/// relationship_injection's tiers.
///
/// The old BLIND TRUST / MISTRUST "Behavioral Anchor" blocks are DELETED:
/// they fired on raw trustLevel thresholds (±100 scale) that map to only
/// moderate tiers, directly contradicting the trust-calibration ladder
/// rendered beside them ("absolute, unconditional trust" at a level the
/// ladder calls "genuinely trusts"). The calibration ladder in
/// relationship_injection.dart is now the single trust voice.
class BehavioralInjection {
  final RelationshipService relationshipService;
  final bool Function() getRealismEnabled;

  BehavioralInjection({
    required this.relationshipService,
    required this.getRealismEnabled,
  });

  /// The background thought — MENTAL state, and it says so itself: "colors
  /// mood and reactions". It belongs beside the mood and emotion lines it
  /// claims to colour.
  String buildFixationInjection() {
    if (!getRealismEnabled()) return '';
    if (relationshipService.activeFixation.isEmpty ||
        relationshipService.fixationLifespan <= 0) {
      return '';
    }
    return 'On the mind lately: "${relationshipService.activeFixation}" — a '
        'background thought that colors mood and reactions; it never '
        'overrides the scene, surfacing openly only if conversation '
        'naturally touches it.';
  }

  /// Where she physically is — SCENE staging, and it says so itself: "ground
  /// actions in this". It belongs with the time and weather lines, because the
  /// model needs to know where everyone is standing before it decides what
  /// happens, not after it has already written the scene.
  String buildPositionInjection() {
    if (!getRealismEnabled()) return '';
    if (relationshipService.spatialStance.isEmpty) return '';
    return 'Position: ${relationshipService.spatialStance} — ground actions in '
        'this, but moving and changing position is fine as the scene demands.';
  }

  /// Both mechanics as one fragment — the original shape.
  ///
  /// The composer no longer uses this: the two lines above are unrelated to
  /// each other (one is a thought, one is a floor position) and belong in
  /// different parts of the block, so it emits them separately. Kept because it
  /// is the surface `prompt_injection_test.dart` asserts against, and it
  /// delegates rather than duplicating, so the two paths cannot drift.
  String buildBehavioralMechanicsInjection() => [
    buildFixationInjection(),
    buildPositionInjection(),
  ].where((l) => l.isNotEmpty).join('\n');
}
