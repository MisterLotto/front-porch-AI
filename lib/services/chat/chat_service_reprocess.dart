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

/// Message reprocess / revert / regenerate flows — manualReprocessNeeds,
/// revertNeedsReprocess, regenerateLastMessage. These replay a turn with the
/// per-speaker realism dance (load → re-eval → save) and the time-travel
/// realism rollback. Extracted verbatim from `chat_service.dart` (zero behaviour
/// change) to shrink the god file; as `part of` it reaches the private services,
/// messages, and dance helpers exactly as before.

extension ChatServiceReprocess on ChatService {

  /// Which cast member said [msg]. See [resolveGroupSpeakerForMessage].
  CharacterCard? _resolveGroupSpeakerForMessage(ChatMessage msg) =>
      resolveGroupSpeakerForMessage(_groupCharacters, msg);

  /// Regenerate the main character's (host's) most recent message when it has
  /// been buried under Scene Guest (Lite NPC) chime-in replies — the case the
  /// last-message-only [regenerateLastMessage] button can no longer reach (the
  /// guest spoke last). The guest replies were reactions to the host text we are
  /// about to discard, so they are removed from the chat (UI + context) first;
  /// the host message is then regenerated as a new swipe via
  /// [regenerateLastMessage] (so realism is reverted to the previous accepted
  /// baseline exactly as for a normal regen — no parallel logic); finally the
  /// guest chime gate is re-run against the NEW host reply, so a guest speaks
  /// again only if it is still warranted (mention / relevance), never blindly.
  ///
  /// When the host message is already last (no trailing guests) this simply
  /// delegates to [regenerateLastMessage].
  Future<void> regenerateMainCharacter() async {
    if (_messages.isEmpty || _isTurnBusy || _sceneGuest.busy) return;
    // Backend gate BEFORE any guest-tail splice — same restore problem as
    // regenerateLastMessage (see _abortIfBackendDown).
    if (await _abortIfBackendDown()) return;

    // Walk back past the trailing guest replies to the host message beneath them.
    int hostIndex = -1;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.isUser || m.sender == 'System') {
        return; // user/System tail — nothing to regen
      }
      // Narration banners (dreams, Chance Time) look like character messages
      // (isUser false, character-name sender) but are not regen targets —
      // regenerating one would replace a rollover artifact with a chat reply.
      if (m.activeMetadata?['is_dream'] == true ||
          m.activeMetadata?['is_chance_time_narration'] == true) {
        return;
      }
      if (!_isGuestAuthoredMessage(m)) {
        hostIndex = i;
        break;
      }
    }
    if (hostIndex < 0) return; // only guest messages present — no host to regen

    // Host already last → plain regen (no guests to pop).
    if (hostIndex == _messages.length - 1) {
      await regenerateLastMessage();
      return;
    }

    // Reconstruct the user text that prompted the host turn for the re-chime gate.
    String userText = '';
    for (int i = hostIndex - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        userText = _messages[i].text;
        break;
      }
    }

    // Remove the now-stale trailing guest replies from UI + context, then regen
    // the (now last) host message and re-run the chime gate on the new reply.
    _messages.removeRange(hostIndex + 1, _messages.length);
    await _saveChat();
    notifyListeners();
    await regenerateLastMessage();
    await _maybeRunSceneGuestChimeIns(userText: userText);
  }

  Future<void> regenerateLastMessage() async {
    if (_messages.isEmpty || _isTurnBusy || _sceneGuest.busy) return;
    // Hold the settling flag across the WHOLE regen — the realism revert +
    // eval replay before generation and the swipe-merge after it both run
    // outside _generateResponse, and used to run with every guard open: a
    // send/delete/chat-switch landing there operated on a timeline with the
    // last message popped or the merge half-done (the same interleave class
    // the in-generate settling fix closed). _generateResponse restores the
    // caller's hold on exit instead of hard-clearing, so this survives the
    // nested call; the finally makes a wedged flag impossible. The body is
    // extracted (not inlined in the try) purely so its early returns and
    // this hold compose without re-indenting the whole flow.
    _isPostGenerating = true;
    try {
      await _regenerateLastMessageHeld();
    } finally {
      _isPostGenerating = false;
    }
  }

  Future<void> _regenerateLastMessageHeld() async {
    // Backend gate BEFORE the pop below — aborting after removeLast would
    // drop the popped reply (the deep guard in _generateResponse cannot
    // restore it; see _abortIfBackendDown).
    if (await _abortIfBackendDown()) return;

    // A failed turn leaves `user -> System(error banner)`, and that matched
    // NEITHER branch below: not a character message (the first), not a user
    // message (the second). So regenerate was a silent no-op after any failed
    // generation, and the only recovery a user could find was to copy their
    // own text out, delete the message, and retype it.
    //
    // Drop the banner when a USER turn is sitting directly behind it — the
    // "last message is a user turn" branch below then regenerates from that
    // prompt, which is precisely the intent. The test is structural rather
    // than tagged by producer because that is what makes it safe: all three
    // System banners (generation error, backend-down, failed entrance) are
    // only discardable when there is an unanswered user turn behind them. A
    // banner following a CHARACTER message is left alone.
    if (_messages.length >= 2 &&
        !_messages.last.isUser &&
        _messages.last.sender == 'System' &&
        _messages[_messages.length - 2].isUser) {
      _messages.removeLast();
      await _saveChat();
    }

    // Check if the last message is from the character. Narration banners
    // (dreams, Chance Time) carry a character-name sender but must never be
    // regen targets — a regen would swipe a chat reply into the banner.
    if (!_messages.last.isUser &&
        _messages.last.sender != 'System' &&
        _messages.last.activeMetadata?['is_dream'] != true &&
        _messages.last.activeMetadata?['is_chance_time_narration'] != true) {
      // Instead of removing the message, we generate a new swipe
      // Temporarily remove the last message so the prompt doesn't include it
      final lastMsg = _messages.removeLast();
      // Timeline integrity: the regen replaces this position's active
      // content — journal cards citing it (or anything after) are phantom
      // (smoke-test bug 2026-07-21). regenerateMainCharacter's guest-pop
      // path is covered too: it delegates here with an even lower position.
      _invalidateJournalFrom(_messages.length);
      // Is this a Scene Guest message? If so the whole regen must stay a
      // parity-safe GUEST turn: skip every Realism/Needs revert + re-eval below
      // and regenerate spoken as the guest (guestSpeaker), exactly like the
      // normal guest turn path. A host message keeps the existing behaviour.
      final regenGuest = _sceneGuestForMessage(lastMsg);
      // If the message was authored by a guest who has since LEFT the scene (or
      // had their card deleted), we can neither regenerate as them nor run the
      // host realism block on their text (that would perturb the host's
      // bond/trust/emotion/needs from guest-authored content). Refuse cleanly.
      if (regenGuest == null && _isGuestAuthoredMessage(lastMsg)) {
        _messages.add(lastMsg); // put it back untouched
        notifyListeners();
        _setGuestStatus(
          'Can’t regenerate "${lastMsg.sender}" — they have left the scene.',
          isError: true,
        );
        return;
      }
      // Snapshot the rejected swipe's metadata (e.g. manual needs reprocess) before
      // we add a new swipe — regen must not clobber prior swipe timelines.
      final rejectedSwipeIndex = lastMsg.swipeIndex;
      Map<String, dynamic>? preservedRejectedMeta;
      if (rejectedSwipeIndex >= 0) {
        if (rejectedSwipeIndex < lastMsg.swipeMetadata.length &&
            lastMsg.swipeMetadata[rejectedSwipeIndex] != null) {
          preservedRejectedMeta = Map<String, dynamic>.from(
            lastMsg.swipeMetadata[rejectedSwipeIndex]!,
          );
        } else if (lastMsg.activeMetadata != null) {
          preservedRejectedMeta = Map<String, dynamic>.from(
            lastMsg.activeMetadata!,
          );
        }
      }
      notifyListeners();

      // Resolve the rejected turn's speaker once (exact name match) — used to
      // force the turn manager AND to target the realism revert below. If the
      // member was renamed/removed, BOTH sites skip rather than fall back to
      // the first member: forcing or reverting the wrong character corrupts
      // that character's state and attribution.
      CharacterCard? regenSpeakerCard;
      String regenSpeakerSid = '';
      if (_activeGroup != null && regenGuest == null) {
        final idx = _groupCharacters.indexWhere(
          (c) => c.name == lastMsg.sender,
        );
        if (idx >= 0) {
          regenSpeakerCard = _groupCharacters[idx];
          regenSpeakerSid = _getCharacterIdFromCard(regenSpeakerCard);
        }
      }

      // In group mode, force the turn manager to the *original* speaker of the
      // removed message before generation. This prevents regen from picking a
      // different character (the core of the "speaker changed after regen" bug).
      if (regenSpeakerCard != null) {
        _groupManager?.setNextSpeaker(regenSpeakerCard);
      }

      // Roll back objective mutations recorded for the rejected turn (eval
      // proposals + completion-check side effects) BEFORE the eval replay, so
      // the new turn re-derives objectives from a clean baseline instead of
      // stacking on the invalidated turn's (and dedup can't suppress a fresh
      // proposal because the rejected turn's copy still exists). Runs with or
      // without realism (completion checks also run realism-off); id-addressed
      // ops keep 1:1 and group identical. Guest turns never touch objectives.
      if (regenGuest == null) {
        await _revertObjectiveTurnOps(lastMsg);
      }

      // Revert realism state from the rejected swipe and re-evaluate.
      // Guest messages carry no Realism/Needs state (regenGuest != null skips).
      //
      // GROUP parity: the revert must operate on the rejected SPEAKER's
      // _groupRealism entry, not on whichever member's state happens to be in
      // the scalar fields. Impersonate + load their map state (the same
      // load/save dance _evaluateRealismForUpcomingSpeaker uses), run the SAME
      // revert as 1:1, then persist the reverted scalars back to the map. The
      // per-speaker eval inside _generateResponse then replays decay + eval
      // from this clean baseline — previously nothing was reverted, so every
      // group regen stacked the new turn's deltas on top of the rejected
      // turn's, plus a second decay tick.
      final isGroupHostRegen =
          _activeGroup != null &&
          regenGuest == null &&
          regenSpeakerSid.isNotEmpty;
      // In a group, an unresolvable speaker (renamed/removed member) skips the
      // revert entirely — reverting the wrong member would corrupt THEIR state.
      final canRevertRealism = _activeGroup == null || isGroupHostRegen;

      CharacterCard? preRegenActiveCharacter;
      if (_realismEnabled && regenGuest == null && canRevertRealism) {
        if (isGroupHostRegen) {
          preRegenActiveCharacter = _activeCharacter;
          _activeCharacter = regenSpeakerCard;
          _loadGroupRealismIntoScalars(regenSpeakerSid);
        }
        // CRITICAL FIX: Find the baseline realism state from the previous accepted message.
        // We want to use the final state of the LAST ACCEPTED character message as our baseline,
        // not just blindly revert deltas and re-evaluate from scratch.
        // 1:1: one character, one lookback. GROUP: the per-speaker fields must
        // come from the rejected speaker's own last stamped message, while the
        // session-level clock baseline comes from the most recent stamped bot
        // message of ANY speaker (time is shared).
        Map<String, dynamic>? previousMessageState;
        Map<String, dynamic>? previousSessionState;
        if (_messages.length >= 2) {
          // Look back through messages to find the last bot message before the one we're regenerating
          for (int i = _messages.length - 1; i >= 0; i--) {
            if (!_messages[i].isUser && _messages[i].sender != 'System') {
              final meta = _messages[i].activeMetadata;
              if (meta != null && meta.containsKey('realism_state')) {
                final state = meta['realism_state'] as Map<String, dynamic>;
                previousSessionState ??= state;
                if (!isGroupHostRegen ||
                    _messages[i].sender == lastMsg.sender) {
                  previousMessageState = state;
                  debugPrint(
                    '[Realism:Regen] Found previous accepted message baseline state at message index $i',
                  );
                  break;
                }
              }
            }
          }
        }

        bool wasNudged = false;
        if (lastMsg.activeMetadata != null &&
            lastMsg.activeMetadata!['realism_state'] is Map) {
          wasNudged =
              lastMsg.activeMetadata!['realism_state']['time_nudged'] == true;
        }

        // Did we restore needs from the rejected message's OWN needs_pre_turn_vector
        // just below? That is the accurate "needs right before this turn" baseline
        // (always stamped: 1:1 in sendMessage pre-tick, group in the realism dance).
        // If so, the previous-accepted-message baseline restore further down must NOT
        // overwrite it — that snapshot's needs vector is the PREVIOUS turn's PRE-impact
        // needs, and clobbering with it silently reverted the last accepted turn's needs
        // deltas (e.g. a bath's +Hygiene snapping back to 0). The realism_state needs
        // snapshot stays a fallback only for messages with no needs_pre_turn_vector.
        bool restoredNeedsFromPreTurn = false;

        if (lastMsg.activeMetadata != null) {
          final bondDelta = lastMsg.activeMetadata!['bond_delta'] as int? ?? 0;
          final arousalDelta =
              lastMsg.activeMetadata!['arousal_delta'] as int? ?? 0;
          final trustDelta =
              lastMsg.activeMetadata!['trust_delta'] as int? ?? 0;

          if (bondDelta != 0) {
            // recordMilestone: false — undoing a rejected reply must not plant
            // reverse "Bond cooled…" story beats in Our Story (Living Time v1.5).
            _relationshipService.applyScoreDelta(
              -bondDelta,
              recordMilestone: false,
            );
          }
          if (trustDelta != 0) {
            _relationshipService.setTrustLevelForRevert(
              (_relationshipService.trustLevel - trustDelta).clamp(-100, 100),
            );
          }

          // Revert climax state if this response triggered refractory cooldown.
          // The climax checker stores the pre-climax arousal so we can restore it.
          final climaxTriggered =
              lastMsg.activeMetadata!['climax_triggered'] as bool? ?? false;
          if (climaxTriggered && _nsfwService.nsfwCooldownEnabled) {
            final preClimaxArousal =
                lastMsg.activeMetadata!['pre_climax_arousal'] as int? ?? 0;
            _nsfwService.setArousalLevel(preClimaxArousal);
            _nsfwService.setCooldownTurnsRemaining(0);
            _nsfwService.setCooldownTurnsTotal(0);
            debugPrint(
              '[Realism:Regen] Reverted climax state: arousal restored to $preClimaxArousal, cooldown cleared',
            );
          } else if (arousalDelta != 0 && _nsfwService.nsfwCooldownEnabled) {
            // Normal arousal delta revert (no climax involved)
            _nsfwService.setArousalLevel(
              (_nsfwService.arousalLevel - arousalDelta).clamp(-100, 100),
            );
          }

          // Needs pre-turn vector revert — mirrors the bond/trust/arousal delta
          // system so regen can undo the decay + fulfillment that ran for this
          // user turn, even when the previous message's realism_state snapshot
          // lacks a 'needs' entry (e.g. needs was enabled mid-chat).
          final preTurnNeeds =
              lastMsg.activeMetadata!['needs_pre_turn_vector'] as Map?;
          if (preTurnNeeds != null && _needsSimEnabled) {
            _needsSimulation.restoreFromSnapshot({
              'vector': Map<String, int>.from(preTurnNeeds),
            });
            restoredNeedsFromPreTurn = true;
            debugPrint(
              '[Realism:Regen] Restored needs vector from pre-turn snapshot on rejected message',
            );
          }
        }

        // CRITICAL FIX: Restore the baseline state from the previous accepted message.
        // This ensures the new regenerated message is evaluated against the correct baseline,
        // not from scratch which would produce wildly different realism values.
        if (previousMessageState != null) {
          // groupSpeakerId is what lets the revert rewind the two registers
          // that ride the group map rather than the scalar set — the hidden
          // inter-character feelings and the decay cadence. Without it a group
          // regen left both drifted, which is why repeated group regens
          // returned different bond/trust numbers while 1:1 regens returned
          // the same ones. Null in 1:1: there is no map, and the cadence there
          // is a scalar the same call restores.
          _relationshipService.restoreFromMessageState(
            previousMessageState,
            groupSpeakerId: isGroupHostRegen ? regenSpeakerSid : null,
          );
          _characterEmotion =
              previousMessageState['characterEmotion'] as String? ??
              _characterEmotion;
          _emotionIntensity =
              previousMessageState['emotionIntensity'] as String? ??
              _emotionIntensity;

          _nsfwService.restoreNsfwFromMessageState(previousMessageState);

          // Needs simulation snapshot (clean port)
          // Guard + no enabled override: prevents stale resurrection on regen after toggle-off.
          // Only fall back to the previous accepted message's realism_state needs
          // vector when step 1 above found no needs_pre_turn_vector on the rejected
          // message. Otherwise this would clobber the accurate pre-turn baseline with
          // the previous turn's PRE-impact needs (the "Hygiene reverts on regen" bug).
          if (!restoredNeedsFromPreTurn &&
              previousMessageState.containsKey('needs') &&
              previousMessageState['needs'] is Map &&
              _needsSimEnabled) {
            final needsData = previousMessageState['needs'] as Map;
            if (needsData['vector'] is Map) {
              final vector = Map<String, int>.from(needsData['vector'] as Map);
              _needsSimulation.restoreFromSnapshot({'vector': vector});
            }
          }

          debugPrint(
            '[Realism:Regen] ✓ Restored baseline from previous accepted message: bond=${_relationshipService.affectionScore}, emotion=$_characterEmotion, trust=${_relationshipService.trustLevel}, arousal=${_nsfwService.arousalLevel}',
          );
        } else {
          debugPrint(
            '[Realism:Regen] ⚠ No previous message baseline found, continuing with current reverted state',
          );
        }

        // Session-level baseline (the shared story clock) comes from the most
        // recent stamped bot message of ANY speaker — identical to
        // previousMessageState in 1:1. The decay cadence is NOT session-level:
        // it is per-character, so it rides previousMessageState above instead.
        if (previousSessionState != null) {
          _timeService.restoreTimeForSwipeOrRegen(
            previousSessionState,
            wasNudged: wasNudged,
          );
        }

        // ── Where she was BEFORE the reply being discarded ────────────────
        //
        // Last, so it wins: everything above rebuilds the baseline from the
        // PREVIOUS accepted message, and for spatial stance that is a
        // second-hand copy at best and missing entirely at worst. Posture is
        // written after generation, so the rejected message's own snapshot
        // was overwritten with where its reply left her — the receipt stamped
        // beside it (see kSpatialStancePreTurn) is the only surviving record
        // of where the turn began, and it belongs to THIS turn rather than
        // the one before it.
        //
        // It is also the only baseline the FIRST reply of a chat has. The
        // look-back above needs a previous accepted bot message carrying a
        // realism snapshot; on turn one there is only the greeting, and the
        // greeting is stamped on exactly one entry path (1:1 + startNewChat +
        // a card with no frontPorchExtensions). Every other opening — the
        // ordinary open-a-character path, any Front Porch or Stoop card, any
        // group — found nothing to restore and left the discarded reply's
        // position standing, so each reroll wrote the next attempt from a
        // place invented by the reply the user had just rejected. Two rerolls
        // from one point disagreed, which CLAUDE.md names as a rewind bug by
        // definition.
        //
        // 1:1 and group alike: the receipt rides the message, and in a group
        // the persist immediately below files the restored value into the
        // rejected speaker's own _groupRealism entry.
        final preTurnStance = lastMsg.activeMetadata?[kSpatialStancePreTurn];
        if (preTurnStance is String) {
          _relationshipService.setSpatialStance(preTurnStance);
          debugPrint(
            '[Realism:Regen] Rewound spatial stance to the pre-reply '
            'position: "${_relationshipService.spatialStance}"',
          );
        }

        if (isGroupHostRegen) {
          // Persist the reverted baseline into the speaker's _groupRealism
          // entry and drop the impersonation. Decay + re-eval for the regen
          // turn happen inside _generateResponse via
          // _evaluateRealismForUpcomingSpeaker (forced to this speaker above),
          // exactly like the turn being replaced did.
          _saveScalarsIntoGroupRealism(regenSpeakerSid);
          _activeCharacter = preRegenActiveCharacter;
        }
      }

      // 1:1 only: replay decay + the realism eval inline here (groups replay
      // via the per-speaker dance inside _generateResponse).
      if (_realismEnabled && _activeGroup == null && regenGuest == null) {
        // Set UI streaming state
        _isEvaluatingRealism = true;
        _realismEvalStreamText = '';
        notifyListeners();

        void handleChunk(String chunk) {
          _realismEvalStreamText += chunk;
          // Debounce: coalesce rapid token arrivals into one rebuild per 150 ms
          _evalChunkTimer?.cancel();
          _evalChunkTimer = Timer(const Duration(milliseconds: 150), () {
            try {
              notifyListeners();
            } catch (_) {
              // Widget was deactivated — timer fired after navigation
            }
          });
        }

        // Record the (restored) needs baseline as the pre-turn vector BEFORE
        // the decay tick below — sendMessage stamps pre-tick and the group
        // dance stamps preDecay, so a regen's chips must count the decay the
        // same way or they understate the turn by exactly the decay component
        // (and deleting the regenerated reply under-refunds by it — caught by
        // regen_chip_attach_test: the original showed a hygiene chip, the
        // regen didn't).
        if (_needsSimEnabled && _needsSimulation.vector.isNotEmpty) {
          _pendingRealismMetadata ??= {};
          _pendingRealismMetadata!['needs_pre_turn_vector'] =
              Map<String, int>.from(_needsSimulation.vector);
        }

        // Apply decay and cooldown — mirrors the normal path, which decays
        // AFTER capturing the baseline so the chips record decay + impact.
        _applyMoodDecay();
        _needsSimulation.tickDecay();
        _nsfwService.decrementCooldownIfActive();

        if (_oneShotActive) {
          await _evaluateOneShotCall(onChunk: handleChunk);
        } else {
          _realismEvals.beginCollectForBatchedVerification();
          await _fireStaggeredRealismEvals(handleChunk);
          await _realismEvals.finalizeBatchedRealismVerifications();

          // Mirror of the primary send path: apply the one director batch (or the cheap
          // accepted-originals path) so relationship/emotional/narrative deltas and side
          // effects (bond/trust/arousal chips, fixation, autonomous objectives, emotion)
          // are produced for swiped/regenerated assistant messages too.
          final collected = _realismEvals.getCollectedForBatch();
          if (collected.isNotEmpty) {
            final items = collected
                .map(
                  (p) => (
                    evalKind: p['kind'] as String,
                    rawOutput: p['raw'] as String,
                    sceneResponse: p['scene'] as String,
                    preState: null,
                    activeChar: _activeCharacter,
                    activeGroup: _activeGroup,
                    recentMessages: _messages,
                    promptText: p['prompt'] as String?,
                    injections: (p['injections'] as Map?)
                        ?.cast<String, String>(),
                    strictnessOverride: null,
                    maxPassesOverride: null,
                  ),
                )
                .toList();
            final batchRes = await _realismVerifier.verifyBatch(items);
            await _realismEvals.applyBatchResults(batchRes);
          }
        }

        // Check for cancellation after evals complete
        if (_realismEvalCancelled) {
          debugPrint(
            '[Realism] Evaluation cancelled during regenerate, aborting',
          );
          // Put the popped reply back BEFORE bailing. The regen removed it at
          // the top so the outbound prompt wouldn't contain it, and
          // _generateResponse — the thing that appends the replacement — is
          // still below us. Returning without this destroys the message and
          // every swipe it carried. It is the same hazard the backend gate
          // further up already guards ("aborting after removeLast would drop
          // the popped reply"); the cancel path just never learned it.
          _messages.add(lastMsg);
          _realismEvalCancelled = false;
          _evalChunkTimer?.cancel();
          _evalChunkTimer = null;
          _isEvaluatingRealism = false;
          notifyListeners();
          await _saveChat();
          return;
        }

        // Cancel any pending debounce notify before closing the overlay
        _evalChunkTimer?.cancel();
        _evalChunkTimer = null;
        _isEvaluatingRealism = false;
        notifyListeners();
      }

      // In group mode the per-speaker realism eval (and its metadata / needs deltas)
      // happens inside _generateResponse via _evaluateRealismForUpcomingSpeaker
      // for the correctly-forced speaker. Skip the 1:1 scalar synthesis here.
      Map<String, int>? regenPreTurn;
      if (_activeGroup == null && regenGuest == null) {
        // Save pre-turn vector BEFORE _generateResponse (which clears
        // _pendingRealismMetadata).
        regenPreTurn =
            _pendingRealismMetadata?['needs_pre_turn_vector']
                as Map<String, int>?;

        // Synthesize metadata after all regen evals complete — mirrors the
        // normal path (line 4020) so emotion_label and realism_state are in
        // _pendingRealismMetadata before _generateResponse consumes it.
        _pendingRealismMetadata ??= {};
        _pendingRealismMetadata!['emotion_label'] = _characterEmotion;
        _pendingRealismMetadata!['realism_state'] = _captureRealismState(
          preTurn: regenPreTurn,
        );

        // If cancellation was requested during realism evaluation, abort
        // generation — restoring the popped reply first, for the same reason
        // as the cancel point above: _generateResponse has still not run, so
        // this local is the only place the message still exists.
        if (_realismEvalCancelled) {
          _messages.add(lastMsg);
          _realismEvalCancelled = false;
          notifyListeners();
          await _saveChat();
          return;
        }
      }

      // Invalidate ONNX cache for the new response (delegated)
      _expressionService.invalidateOnnxCacheForNewResponse();

      // Generate into a new message — it will be appended by _generateResponse.
      // For a guest message we pass guestSpeaker so the new swipe is spoken as
      // the guest and the entire Realism/Needs post-gen block is skipped (the
      // `guestSpeaker == null` guard). For a host message regenGuest is null and
      // this is the unchanged host path: _generateResponse runs the post-gen
      // needs checks AND the chip attach — a regen runs in normal mode, so
      // needs_deltas land on the streamed message exactly like a fresh turn
      // (1:1 and group alike) and ride newMetadata into the swipe-merge below.
      // The duplicate post-generation recompute that used to live here was a
      // second source of truth for the same numbers; deleted 2026-08-04.
      await _generateResponse(GenerationMode.normal, guestSpeaker: regenGuest);

      // After generation, merge the new response as a swipe on the original message
      if (_messages.isNotEmpty &&
          !_messages.last.isUser &&
          _messages.last.sender != 'System') {
        final newText = _messages.last.text;
        final newMetadata = _messages.last.activeMetadata != null
            ? Map<String, dynamic>.from(_messages.last.activeMetadata!)
            : null;
        _messages.removeLast();
        lastMsg.swipes.add(newText);
        while (lastMsg.swipeDurations.length < lastMsg.swipes.length) {
          lastMsg.swipeDurations.add(0);
        }
        final newSwipeIndex = lastMsg.swipes.length - 1;
        if (preservedRejectedMeta != null && rejectedSwipeIndex >= 0) {
          while (lastMsg.swipeMetadata.length <= rejectedSwipeIndex) {
            lastMsg.swipeMetadata.add(null);
          }
          lastMsg.swipeMetadata[rejectedSwipeIndex] = preservedRejectedMeta;
        }
        while (lastMsg.swipeMetadata.length <= newSwipeIndex) {
          lastMsg.swipeMetadata.add(null);
        }
        lastMsg.swipeIndex = newSwipeIndex;
        // New swipe metadata only — prior swipes (incl. manual reprocess) stay
        // intact. newMetadata already carries this swipe's needs_deltas: the
        // chip attach inside _generateResponse is the one source of truth.
        if (newMetadata != null) {
          lastMsg.swipeMetadata[newSwipeIndex] = newMetadata;
        }
        _messages.add(lastMsg);
        // Host messages restore the active character's Realism/Needs from the
        // accepted swipe (in groups: the speaker's own _groupRealism entry);
        // guest messages carry none, so leave host state intact.
        if (regenGuest == null) _restoreRealismStateForSpeaker(lastMsg);
        await _saveChat();
        notifyListeners();

        // In group mode, advance the turn pointer past the regenerated speaker
        // so the next natural generation continues the correct rotation instead
        // of repeating the same character.
        if (_activeGroup != null) {
          // Same resolution rule: advancing past the WRONG member would make
          // the next natural turn repeat a character or skip one.
          final originalSpeaker = _resolveGroupSpeakerForMessage(lastMsg);
          if (originalSpeaker != null) {
            _groupManager?.advanceAfterRegeneration(originalSpeaker);
          }
        }
      }
    } else if (_messages.last.isUser) {
      // The last message is the user's prompt (e.g. the AI reply was deleted),
      // so there is no swipe to add — generate a fresh response from it. Mirrors
      // triggerNextCharacter()/the normal send path (_generateResponse consumes
      // no new user turn, so needs decay is NOT re-ticked — that already ran
      // when the user turn was first sent). Applies identically to 1:1 and group.
      await _generateResponse(GenerationMode.normal);
    }
  }
}
