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

/// Minimum messages between salient-event kicks. An emotionally hot SCENE
/// clears the ±12 bond bar turn after turn, and each cleared bar used to
/// fire an immediate full Journal pass AND a full Growth pass — ~95k chars
/// and ~26 seconds of background LLM per kick in the maintainer's own
/// EvalTraffic capture, mostly re-reading what the previous kick's pass had
/// already covered (a kick-fired pass moves the cursor). Two exchanges of
/// cooldown keeps the immediacy for the MOMENT while a sustained scene
/// falls back to the ordinary scheduled cadence.
const int kSalienceKickMinGapMessages = 4;

/// Rate limiter for the salient-event kick — the mechanism by which a big
/// bond/trust swing, a trust repair, Chance Time, or a completed objective
/// requests an IMMEDIATE Journal + Growth pass instead of waiting for the
/// scheduled interval.
///
/// The throttle sits UPSTREAM of both features, at the kick origins in the
/// god wiring, before either service's `eventKickPending` flag is set: both
/// features receive identical treatment and neither's switch appears
/// anywhere near the other's gate (the feature-independence rule). A
/// suppressed kick loses nothing but immediacy — the next scheduled pass
/// reads everything since the cursor regardless.
///
/// The FIRST kick of a session always fires (the protected journal_review /
/// growth_rings E2E fixtures each fire exactly one — they hold by
/// construction). Session switches reset the window: a fresh chat's first
/// moment must never be muffled by the previous chat's.
class SalienceKickGate {
  String? _sessionId;
  int? _lastAllowedAt;

  /// True when a kick at [messageCount] messages into [sessionId] may fire.
  /// Allowing CLAIMS the slot — call only when a kick is actually requested.
  bool allow({required String? sessionId, required int messageCount}) {
    if (sessionId != _sessionId) {
      _sessionId = sessionId;
      _lastAllowedAt = null;
    }
    final last = _lastAllowedAt;
    if (last != null && (messageCount - last) < kSalienceKickMinGapMessages) {
      return false;
    }
    _lastAllowedAt = messageCount;
    return true;
  }
}
