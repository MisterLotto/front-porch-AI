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

part of 'relationship_service.dart';

// ── Reset / seed / load helpers (support "keep reset blocks in sync" in parent) ──

extension RelationshipServicePersistence on RelationshipService {
  void resetForFreshChat() {
    _affectionScore = 0;
    _relationshipTier = 0;
    _longTermScore = 0;
    _longTermTier = 0;
    _turnsSinceLongTermCheck = 0;
    _shortTermDeltasSummary = 0;
    _turnsSinceDecayCheck = 0;
    _trustLevel = 0;
    _activeFixation = '';
    _fixationLifespan = 0;
    _spatialStance = '';
    _withUser = null;
    pendingTrustRepair = false;
  }

  /// Card V2/Ext seed path: plain clamp (current ±300 scale authored by V2.5 cards
  /// and the creator UI). No legacy *2 migration. Tiers computed after. Used by the
  /// two fresh ext-seed sites in ChatService (setActiveCharacter 0-session path and
  /// startNewChat 1:1 ext branch). Group paths untouched (never used the doubling).
  /// See god comments for "card-seed bypass" + cross-refs.
  void seedFromCardV2OrExt({
    required int shortTermBond,
    required int longTermBond,
    required int trustLevel,
  }) {
    _affectionScore = shortTermBond.clamp(-300, 300);
    _longTermScore = longTermBond.clamp(-300, 300);
    _trustLevel = trustLevel.clamp(-100, 100);
    _relationshipTier = _calculateTier(_affectionScore);
    _longTermTier = _calculateTier(_longTermScore);
  }

  /// Load per-speaker relationship scalars (affection/trust/fixation/tiers/spatial)
  /// from the group's _groupRealism map into this service's 1:1-style scalars so
  /// eval/delta/injection paths can operate on them. Mirrors needs pattern.
  void loadRelationshipScalarsForSpeaker(String charId) {
    final aff = getGroupAffectionScore(charId);
    _affectionScore = aff;
    _longTermScore = getGroupLongTermScore(charId, defaultValue: aff);
    _trustLevel = getGroupTrustLevel(charId);
    _activeFixation = getGroupFixation(charId);
    _fixationLifespan = getGroupFixationLifespan(charId, defaultValue: 0);
    _spatialStance = getGroupSpatialStance(charId);
    _withUser = getGroupWithUser?.call(charId);

    final relT = getGroupRelationshipTier(charId, defaultValue: 0);
    _relationshipTier = relT != 0 ? relT : _calculateTier(_affectionScore);
    final ltT = getGroupLongTermTier(charId, defaultValue: 0);
    _longTermTier = ltT != 0 ? ltT : _calculateTier(_longTermScore);

    // Per-speaker long-term cadence (parity): each member's growth check runs
    // on THEIR OWN eval count and THEIR OWN delta history. With the shared
    // registers, the growth-check threshold was hit by the whole group's evals
    // and the long-term bump landed on whichever member happened to be loaded.
    if (getGroupCounter != null) {
      _turnsSinceLongTermCheck = getGroupCounter!(
        charId,
        'turnsSinceLongTermCheck',
        defaultValue: 0,
      );
      _shortTermDeltasSummary = getGroupCounter!(
        charId,
        'shortTermDeltasSummary',
        defaultValue: 0,
      );
    }
  }

  /// Write current scalars back into the target group character's _groupRealism
  /// entry (for affection/long/trust/fixation/tiers/spatial). Does not touch needs
  /// or emotion (owned elsewhere).
  void saveRelationshipScalarsToGroup(String charId) {
    setGroupAffectionScore(charId, _affectionScore);
    setGroupLongTermScore(charId, _longTermScore);
    setGroupTrustLevel(charId, _trustLevel);

    // Persist fixation/spatial UNCONDITIONALLY (including clears) so the
    // per-character store is a faithful snapshot of the working registers.
    // Previously these were guarded behind non-empty checks, which meant a
    // cleared fixation/spatial never propagated through save/load — fine while
    // only group members used this path (fixation re-set each turn), but it would
    // silently break fixation-clearing once the always-loaded 1:1 host is unified
    // onto the same store. See relationship_service_test round-trip coverage.
    setGroupFixation(charId, _activeFixation);
    setGroupFixationLifespan(charId, _fixationLifespan);
    setGroupSpatialStance(charId, _spatialStance);
    setGroupWithUser?.call(charId, _withUser);

    setGroupRelationshipTier(charId, _relationshipTier);
    setGroupLongTermTier(charId, _longTermTier);

    // Per-speaker long-term cadence counters (see the load-side comment).
    if (setGroupCounter != null) {
      setGroupCounter!(
        charId,
        'turnsSinceLongTermCheck',
        _turnsSinceLongTermCheck,
      );
      setGroupCounter!(
        charId,
        'shortTermDeltasSummary',
        _shortTermDeltasSummary,
      );
    }
  }
}
