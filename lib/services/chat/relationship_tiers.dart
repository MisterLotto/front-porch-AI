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

/// Pure bond/trust tier + progress-bar scale math, extracted verbatim out of
/// [RelationshipService] in the 2026-08 god-file split. Zero field access —
/// every member is a static function of a raw score/tier index, which is why
/// this is a standalone leaf rather than another `part` of the shell: it is
/// also the read-only surface read-only per-member consumers reach for
/// directly (the web group-stats panel, `ui/widgets/group_member_card.dart`).
/// `RelationshipService` still exposes six one-line delegating statics with
/// the original names so no existing call site needed to change.
class RelationshipTiers {
  /// 0..1 progress within the current bond / long-term tier band (±300 scale).
  static double bondScalePercent(int score) {
    final abs = score.abs();
    final base = bondScaleBase(abs);
    final total = bondScaleTarget(abs) - base;
    // At the TOP band there is no next tier to fill toward, so base == target
    // and this used to return 0.0 — the bar read EMPTY at a maxed-out score,
    // which looks like the relationship reset. Maxed means full.
    return total <= 0 ? 1.0 : ((abs - base) / total).clamp(0.0, 1.0);
  }

  static int bondScaleBase(int abs) {
    if (abs < 15) return 0;
    if (abs < 30) return 15;
    if (abs < 50) return 30;
    if (abs < 80) return 50;
    if (abs < 120) return 80;
    if (abs < 160) return 120;
    if (abs < 200) return 160;
    if (abs < 250) return 200;
    return 250;
  }

  static int bondScaleTarget(int abs) {
    if (abs < 15) return 15;
    if (abs < 30) return 30;
    if (abs < 50) return 50;
    if (abs < 80) return 80;
    if (abs < 120) return 120;
    if (abs < 160) return 160;
    if (abs < 200) return 200;
    if (abs < 250) return 250;
    return 300; // max for ±300 range
  }

  /// 0..1 progress within the current trust tier band (±100 scale).
  static double trustScalePercent(int level) {
    final abs = level.abs();
    final base = trustScaleBase(abs);
    final total = trustScaleTarget(abs) - base;
    // At the TOP band there is no next tier to fill toward, so base == target
    // and this used to return 0.0 — the bar read EMPTY at a maxed-out score,
    // which looks like the relationship reset. Maxed means full.
    return total <= 0 ? 1.0 : ((abs - base) / total).clamp(0.0, 1.0);
  }

  static int trustScaleBase(int abs) {
    if (abs < 10) return 0;
    if (abs < 25) return 10;
    if (abs < 45) return 25;
    if (abs < 70) return 45;
    if (abs < 100) return 70;
    return 100;
  }

  static int trustScaleTarget(int abs) {
    if (abs < 10) return 10;
    if (abs < 25) return 25;
    if (abs < 45) return 45;
    if (abs < 70) return 70;
    return 100;
  }

  /// Pure bond/short-term tier name for a tier index (-10..10). Shared by the
  /// live getter and read-only per-member consumers (web group stats panel).
  static String bondTierLabel(int tier) {
    switch (tier) {
      case 10:
        return 'Devoted';
      case 9:
        return 'Enamored';
      case 8:
        // Was 'Devoted', which tier 10 also returns — so a bond of 200 and a
        // bond of 300 printed the same word and the top of the ladder read as
        // broken. 'Inseparable' sits between Intimate (7) and Enamored (9) and
        // does not presume romance, which bond does not either.
        return 'Inseparable';
      case 7:
        return 'Intimate';
      case 6:
        return 'Close';
      case 5:
        return 'Amiable';
      case 4:
        return 'Friendly';
      case 3:
        return 'Warm';
      case 2:
        return 'Receptive';
      case 1:
        return 'Cordial'; // was 'Neutral' — collided with tier 0 (see 2026-08-03)
      case 0:
        return 'Neutral';
      case -1:
        return 'Reserved';
      case -2:
        return 'Cool';
      case -3:
        return 'Unimpressed';
      case -4:
        return 'Annoyed';
      case -5:
        return 'Disliked';
      case -6:
        return 'Hostile';
      case -7:
        return 'Adversarial';
      case -8:
        return 'Disdain';
      case -9:
        return 'Contempt';
      case -10:
        return 'Vitriolic';
      default:
        return 'Unknown';
    }
  }

  /// Pure long-term tier name for a tier index (-10..10).
  static String longTermTierLabel(int tier) {
    switch (tier) {
      case 10:
        return 'Soulmate / Devoted';
      case 9:
        return 'Life Partner';
      case 8:
        return 'Devoted';
      case 7:
        return 'Deeply Attached';
      case 6:
        return 'Intimate';
      case 5:
        return 'Close';
      case 4:
        return 'Friendly';
      case 3:
        return 'Warm';
      case 2:
        return 'Receptive';
      case 1:
        return 'Cordial'; // was 'Neutral' — collided with tier 0 (see 2026-08-03)
      case 0:
        return 'Neutral';
      case -1:
        return 'Reserved';
      case -2:
        return 'Cool';
      case -3:
        return 'Disappointed';
      case -4:
        return 'Fractured';
      case -5:
        return 'Broken Trust';
      case -6:
        return 'Deep Resentment';
      case -7:
        return 'Hostile';
      case -8:
        return 'Adversarial';
      case -9:
        return 'Contempt';
      case -10:
        return 'Vitriolic';
      default:
        return 'Unknown';
    }
  }

  /// Pure trust tier name for a trust tier index.
  static String trustTierLabel(int tier) {
    switch (tier) {
      case 7:
        return 'Blind Trust';
      case 6:
        return 'Implicit Trust';
      case 5:
        return 'Deeply Trusting';
      case 4:
        return 'Confident Trust';
      case 3:
        return 'Trusting';
      case 2:
        return 'Leaning Positive';
      case 1:
        return 'Warming';
      case 0:
        return 'Neutral';
      case -1:
        return 'Cautious';
      case -2:
        return 'Guarded';
      case -3:
        return 'Skeptical';
      case -4:
        return 'Wary';
      case -5:
        return 'Suspicious';
      case -6:
        return 'Distrustful';
      case -7:
        return 'Paranoid';
      default:
        return 'Unknown';
    }
  }

  /// The canonical bond tier ladder. THE one definition — `TierColors.calcTier`
  /// used to carry a second, hand-copied version of this that had drifted at
  /// three rungs (75/110/150 instead of 80/120/160), so a bond of 76 was tier 4
  /// to the engine and tier 5 on the group member card. Anything that needs a
  /// tier from a bond score calls this.
  static int bondTierFor(int score) {
    final absScore = score.abs();
    if (absScore < 5) return 0;
    if (absScore < 15) return score > 0 ? 1 : -1;
    if (absScore < 30) return score > 0 ? 2 : -2;
    if (absScore < 50) return score > 0 ? 3 : -3;
    if (absScore < 80) return score > 0 ? 4 : -4;
    if (absScore < 120) return score > 0 ? 5 : -5;
    if (absScore < 160) return score > 0 ? 6 : -6;
    if (absScore < 200) return score > 0 ? 7 : -7;
    if (absScore < 250) return score > 0 ? 8 : -8;
    if (absScore < 300) return score > 0 ? 9 : -9;
    return score > 0 ? 10 : -10;
  }
}
