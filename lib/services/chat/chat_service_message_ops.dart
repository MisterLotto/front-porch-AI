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

/// Message-list mutation operations: swipe navigation, continue, session
/// reload/clear/delete, [deleteMessage] (the needs-refund + group
/// deleted-speaker rewind parity block), generation cancellation, Journal
/// timeline invalidation, and [cancelRealismEval]. Extracted verbatim from
/// `chat_service.dart` — zero behaviour change; `deleteMessage` in
/// particular moves whole, exactly as it was, because the needs-refund
/// arithmetic and the group rewind ordering are pinned by
/// `delete_message_needs_rollback_test.dart`.
extension ChatServiceMessageOps on ChatService {
  /// Navigate swipes on a specific message. direction: -1 = left, +1 = right.
  /// If swiping right past the last swipe on the last bot message, regenerates.
  Future<void> swipeMessage(int messageIndex, int direction) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final msg = _messages[messageIndex];
    if (msg.isUser || msg.sender == 'System') return;

    final newIndex = msg.swipeIndex + direction;

    // Guest-message swipes carry no Realism/Needs, so navigating between them
    // must never touch the active character's state (parity) — true even for a
    // guest who has since left the scene, hence the authoritative check.
    final isGuestMsg = _isGuestAuthoredMessage(msg);

    // Swiping left
    if (direction < 0) {
      if (newIndex >= 0) {
        msg.swipeIndex = newIndex;
        if (!isGuestMsg) _syncRealismStateForSwipe(msg);
        // Pockets follow the selected variant too — this swipe's own
        // post-turn record, or the shared pre-turn base when this variant's
        // pass changed nothing (hostile review 2026-08-11).
        if (!isGuestMsg) _restorePocketsFromStamp(msg, after: true);
        // Timeline integrity: the active variant at this position changed —
        // cards journaled from the other swipe are now phantom.
        _invalidateJournalFrom(messageIndex);
        await _saveChat();
        notifyListeners();
      }
      return;
    }

    // Swiping right
    if (newIndex < msg.swipes.length) {
      // Navigate to existing swipe
      msg.swipeIndex = newIndex;
      if (!isGuestMsg) _syncRealismStateForSwipe(msg);
      // Same pockets rewind as the left branch.
      if (!isGuestMsg) _restorePocketsFromStamp(msg, after: true);
      // Timeline integrity — same as the left-swipe branch above.
      _invalidateJournalFrom(messageIndex);
      await _saveChat();
      notifyListeners();
    } else if (messageIndex == _messages.length - 1 && !_isTurnBusy) {
      // Past last swipe on last message — regenerate
      await regenerateLastMessage();
    }
  }

  void _syncRealismStateForSwipe(ChatMessage msg) {
    if (!_realismEnabled) return;

    // Natively restore the frozen runtime variables for the selected alternate
    // timeline — in groups, into the swiped speaker's own _groupRealism entry.
    _restoreRealismStateForSpeaker(msg);
  }

  Future<void> continueGeneration() async {
    if (_messages.isEmpty || _isTurnBusy || _sceneGuest.busy) return;

    // Only continue if the last message is from a bot (non-user, non-system).
    // Narration banners (dreams, Chance Time) are excluded: continue_ streams
    // straight into _messages.last, which would append a chat reply to the
    // banner (the dream-corruption class, 2026-07-28).
    if (!_messages.last.isUser &&
        _messages.last.sender != 'System' &&
        _messages.last.activeMetadata?['is_dream'] != true &&
        _messages.last.activeMetadata?['is_chance_time_narration'] != true) {
      await _generateResponse(GenerationMode.continue_);
    }
  }

  /// Reload the current session from the database without clearing messages first.
  /// Used after cloud sync or DB migration updates the database — preserves the
  /// user's active chat instead of wiping it.
  Future<void> reloadCurrentSession() async {
    if (_currentSessionId == null) return;
    debugPrint(
      '[ChatService] 🔄 reloadCurrentSession: reloading session $_currentSessionId '
      '(currently ${_messages.length} messages in memory)',
    );
    await loadSession(_currentSessionId!);
  }

  void clearChat() async {
    debugPrint(
      '[ChatService] 🟡 clearChat: clearing ${_messages.length} messages',
    );
    _messages.clear();
    await _saveChat();
    notifyListeners();
  }

  /// Delete a specific chat session and its messages.
  /// If it's the current session, switches to the most recent remaining one.
  Future<void> deleteSession(String sessionId) async {
    await _db.deleteMessagesForSession(sessionId);
    await _db.deleteSessionById(sessionId);

    // If we deleted the current session, switch to another
    if (sessionId == _currentSessionId) {
      final remaining = await getSessions();
      if (remaining.isNotEmpty) {
        await loadSession(remaining.first['id']);
      } else {
        // No sessions left — start fresh
        debugPrint(
          '[ChatService] 🟡 deleteSession: no sessions left, clearing messages',
        );
        _messages.clear();
        _currentSessionId = null;
        await startNewChat();
      }
    }
    notifyListeners();
  }

  void deleteMessage(int index) async {
    // No deletes while a generation is live: removing entries shifts every
    // position the active turn still relies on (chip attach, lorebook scan,
    // journal invalidation) — and made a dream banner the last message,
    // where the aborted turn's writes landed (2026-07-28). Stop first.
    if (_isTurnBusy) return;
    if (index >= 0 && index < _messages.length) {
      final deleted = _messages[index];
      final wasTail = index == _messages.length - 1;

      // Pockets rewind on TAIL deletes only (hostile review 2026-08-11):
      // deleting the last reply un-happens its turn, so the record returns
      // to its pre-turn state — the same tail-only semantics the realism
      // time-travel below has always had. Deleting an OLDER message leaves
      // the record alone on purpose: later turns built on its changes, and
      // rewinding past them would invent history (the needs refund solves
      // this with arithmetic; pocket ops have no arithmetic inverse).
      if (wasTail && !deleted.isUser && deleted.sender != 'System') {
        _restorePocketsFromStamp(deleted, after: false);
      }

      // Needs are refunded by ARITHMETIC (subtract this message's own chips),
      // not by the realism time-travel below — that only ever rewinds the
      // tail, so deleting anything older left its needs cost applied forever.
      // Capture the deleted speaker's needs BEFORE the restore runs; the
      // refund is settled from this baseline afterwards.
      final String? deletedSid =
          (_activeGroup != null &&
              !deleted.isUser &&
              deleted.sender != 'System' &&
              _groupCharacters.where((c) => c.name == deleted.sender).length ==
                  1)
          ? _getCharacterIdFromCard(
              _groupCharacters.firstWhere((c) => c.name == deleted.sender),
            )
          : null;
      // In a group, refund ONLY when the speaker resolved unambiguously —
      // falling back to the live scalars there would credit whichever member
      // happens to be loaded, i.e. refund the wrong character. An empty
      // baseline makes the revert a no-op.
      final Map<String, int> needsBeforeDelete =
          (!_needsSimEnabled || (_activeGroup != null && deletedSid == null))
          ? const <String, int>{}
          : (deletedSid != null
                ? Map<String, int>.from(_getGroupNeeds(deletedSid))
                : Map<String, int>.from(_needsSimulation.vector));

      _messages.removeAt(index);

      // Timeline integrity: the delete rewrites history from [index] on
      // (later positions shift down), so cards citing that region and the
      // pass cursor both roll back — replaces the old cursor-decrement drift
      // fix, which kept phantom cards alive (smoke-test bug 2026-07-21).
      // (Growth uses a DB-backed per-session cursor; it re-reads its stored
      // index on the next pass.)
      _invalidateJournalFrom(index);

      // Time-travel rollback for realism when deleting a character message.
      // Restore from the new last message if it has a snapshot, regardless
      // of whether this was the last message. This ensures needs state
      // (and all realism fields) reset to their previous saved values — in
      // groups, inside the NEW LAST speaker's own _groupRealism entry.
      if (_messages.isNotEmpty) {
        final newLast = _messages.last;
        _restoreRealismStateForSpeaker(newLast);
      }

      // Group: also roll back the DELETED speaker's OWN _groupRealism entry to
      // their previous stamped turn — otherwise that member's bond/trust/needs
      // deltas from the removed message stand forever (the state machine only
      // rewinds whoever is now last). Guards:
      //   • the deleted message must itself carry a realism_state — otherwise
      //     it applied no deltas and rewinding would INVENT older history;
      //   • the sender name must be unambiguous in the roster — restore resolves
      //     by name (_restoreRealismStateForSpeaker), so with two same-named
      //     members it could rewind the wrong one; skip that rare case rather
      //     than corrupt state;
      //   • skip when the deleted speaker is already the new-last (handled
      //     above) or has no earlier stamped turn.
      if (_activeGroup != null &&
          !deleted.isUser &&
          deleted.sender != 'System' &&
          deleted.activeMetadata?['realism_state'] is Map &&
          _groupCharacters.where((c) => c.name == deleted.sender).length == 1 &&
          (_messages.isEmpty || _messages.last.sender != deleted.sender)) {
        for (int i = _messages.length - 1; i >= 0; i--) {
          final m = _messages[i];
          if (m.sender == deleted.sender &&
              m.activeMetadata?['realism_state'] is Map) {
            _restoreRealismStateForSpeaker(m);
            break;
          }
        }
      }

      // Settle needs LAST so it wins over whatever the snapshot restores did
      // to the vector (see _revertNeedsForDeletedMessage).
      _revertNeedsForDeletedMessage(
        deleted,
        needsBeforeDelete,
        groupSid: deletedSid,
      );

      await _saveChat();
      notifyListeners();
    }
  }

  void stopGeneration() {
    if (_isGenerating) {
      _cancelRequested = true;
      // Abort the in-flight HTTP request so we don't have to wait for the next token
      (testLlmServiceOverride ?? _llmProvider?.activeService)
          ?.abortGeneration();
    }
  }

  /// Cancel any in-flight generation and wait for it to fully stop.
  Future<void> _cancelAndWaitForGeneration() async {
    if (!_isGenerating) return;
    _cancelRequested = true;
    // Spin until _generateResponse finishes its cleanup
    while (_isGenerating) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Timeline-integrity invalidation (Journal): content at [position] was
  /// rewritten — regen, swipe navigation, edit, or delete. Cards citing
  /// positions ≥ [position] describe events that no longer happened, so they
  /// are removed (all diary owners), the pass cursor rolls back so the next
  /// pass re-reads the rewritten window, and a salience kick refreshes the
  /// recap soon. Cheap no-op when the pass never consumed the region: cards
  /// only ever cite positions below the cursor. The recap TEXT may still
  /// carry a stale sentence until the next pass rewrites it — a full recap
  /// rewind is deliberately out of scope (documented, not silent).
  void _invalidateJournalFrom(int position) {
    final sessionId = _currentSessionId;
    if (sessionId == null || position >= _summaryLastIndex) return;
    _summaryLastIndex = position;
    unawaited(
      _journalStore.invalidateCardsCitingFrom(sessionId, position).then((
        removed,
      ) {
        if (removed > 0 && !_disposed) {
          _journalMaintenance.eventKickPending = true;
          debugPrint(
            '[Journal] Timeline rewrite at $position — removed $removed '
            'card(s) citing the discarded region',
          );
          notifyListeners();
        }
      }),
    );
  }

  /// Cancel an in-progress Realism evaluation stream (if any).
  ///
  /// Behavior:
  /// - If there is no active realism evaluation and no post-greeting processing,
  ///   this is a no-op.
  /// - Mark cancelling flag, attempt to abort the underlying generation, then
  ///   reset all related UI/state and emit a final notification.
  /// - Do not restart any ongoing flow automatically after cancellation.
  Future<void> cancelRealismEval() async {
    // No-op if there is nothing to cancel
    if (!_isEvaluatingRealism && !_isProcessingGreeting) {
      debugPrint('[Realism] Cancel request ignored — no active realism eval.');
      return;
    }

    _isCancellingRealismEval = true;
    // Signal to any ongoing realism evaluation that a cancel has been requested.
    _realismEvalCancelled = true;
    notifyListeners();

    // Transient banner only — NEVER a chat message. The old code appended an
    // "evaluation interrupted" line attributed to the character, which then
    // permanently rode chat history, prompts, RAG, and journal windows.
    _setGuestStatus(
      'Realism evaluation cancelled — no reply was generated. '
      'Regenerate (or send again) to retry.',
    );

    final llmService =
        testLlmServiceOverride ?? _llmProvider?.activeService ?? _koboldService;
    debugPrint('[Realism] Realism eval cancel requested');
    try {
      llmService.abortGeneration();
      debugPrint('[Realism] abortGeneration invoked');
    } catch (e) {
      // Ensure we always proceed to reset state even if abortion fails unexpectedly
      debugPrint('[Realism cancel] Unexpected error during abort: $e');
    } finally {
      // Reset all realism-related state
      _realismEvalStreamText = '';
      _pendingRealismMetadata = null;
      _isEvaluatingRealism = false;
      _isProcessingGreeting = false;
      _isCancellingRealismEval = false;
      // NOTE: Do NOT reset _realismEvalCancelled here. It must remain true so that
      // sendMessage() can detect the cancellation and return early. The flag is only
      // reset in sendMessage() after the cancellation is properly handled.
      notifyListeners();
    }
  }
}
