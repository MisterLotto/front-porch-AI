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

part of '../chat_service.dart';

/// Afterglow's post-generation climax check — the one place it is gated, fired
/// and applied.
///
/// Sits beside `_runPocketsPass` in the same post-gen phase and for the same
/// reason: it reads the reply that was just written. See the class doc on
/// [ClimaxEval] for why it must be post-generation and why it stands alone
/// instead of riding the needs-impact eval.
extension ChatServiceClimax on ChatService {
  /// Whether Afterglow can run at all this turn.
  ///
  /// The Realism Engine and the Afterglow switch. NOT Needs — that dependency
  /// was never declared anywhere, and it is what made the feature dead on most
  /// cards while its row showed green.
  bool get _afterglowActive =>
      _realismEnabled && _nsfwService.nsfwCooldownEnabled;

  /// Ask whether the reply narrated the character's own climax, and start the
  /// refractory if it did.
  ///
  /// On Continue the caller passes the NEW text only (2026-08-12; the pass
  /// used to be skipped outright): a climax the first half already registered
  /// is not re-claimed by its aftermath, and one the continuation adds
  /// finally starts its refractory. `applyClimaxEffects` is absolute
  /// (remaining = turns, arousal = 0), so even a re-affirmation cannot
  /// stack; the metadata guard below keeps the FIRST reading's
  /// pre-climax arousal, because by the second reading it is already 0.
  Future<void> _runClimaxPass(String reply) async {
    if (!_afterglowActive) return;
    if (reply.trim().isEmpty) return;

    final speaker = _activeCharacter;
    if (speaker == null) return;

    // On a fused reply-facts turn the question was already asked (one call
    // for all three bookkeeping passes) — read this pass's slice through the
    // SAME parser the standalone call feeds. A fused answer without a
    // verdict skips, exactly as a failed standalone call does.
    final fused = _replyFactsRaw;
    final turns = fused != null
        ? ClimaxEval.parseRefractory(fused)
        : await _climaxEval.detect(
            charName: speaker.name,
            // Clamped like every judge window (eval diet, hostile
            // review 2026-08-11).
            reply: clampEvalMessage(reply),
            // The same window the needs eval uses, from the one shared helper —
            // this was a hand-rolled copy until Pockets needed a third.
            recentExchange: recentExchange(_messages),
          );
    if (turns == null) return;

    // Metadata first, then the effect — applyClimaxEffects zeroes arousal, so
    // reading it afterwards would record 0 as the pre-climax level and the
    // chip would say the character peaked from nothing.
    final preClimaxArousal = _nsfwService.arousalLevel;
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      final msg = _messages.last;
      final meta = Map<String, dynamic>.from(msg.activeMetadata ?? {});
      if (meta['climax_triggered'] != true) {
        meta['climax_triggered'] = true;
        meta['pre_climax_arousal'] = preClimaxArousal;
        // Through the setter, never `swipeMetadata[swipeIndex] = ...`: the
        // list is persisted only when some entry is non-null, so a reloaded
        // (or imported) message that has 4 swipes and no metadata comes back
        // with a ONE-element list and swipeIndex 3. The raw write threw
        // RangeError inside the post-gen phase, which surfaced as a bogus
        // "generation failed" banner and skipped pockets/posture/restamp.
        // The setter pads first (chat_message.dart).
        msg.activeMetadata = meta;
      }
    }
    _nsfwService.applyClimaxEffects(turns: turns);

    debugPrint(
      '[Afterglow] climax detected (arousal was $preClimaxArousal) — '
      'refractory $turns turns',
    );
    notifyListeners();
  }
}
