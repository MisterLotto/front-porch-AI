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

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/models/group_chat.dart';
import 'package:front_porch_ai/database/database.dart';
import 'journal_ops.dart';
import 'journal_physics.dart';
import 'journal_store.dart';

/// The Journal — the one periodic background job
/// (docs/design/journal-memory.md §4.2). Replaces BOTH the old SummaryService
/// and FactExtraction with a single fireLLMEval call per diary owner per pass,
/// producing (a) memory-card operations and (b) the per-chat "Where we are"
/// recap (written into the same _summary slot the old summary used, so the
/// injection plumbing, sidebar, web facade, and EvolutionService's summary
/// dependency keep working untouched).
///
/// Plain leaf, callback-wired like its dead siblings. Reuses only existing
/// god state (_summary, _summaryLastIndex, _isSummaryGenerating via cbs) —
/// no new flags, so every existing reset/zeroing hygiene site keeps working.
///
/// Key invariants:
/// - Strictly per-chat: cards are read and written for the CURRENT session
///   only; a session switch mid-pass aborts recap/cursor writes (card writes
///   target the captured session id, which is safe either way).
/// - Salience is deterministic, not judged: the window is pre-annotated with
///   engine-stamped per-message metadata (emotion_label, bond/trust deltas,
///   trust repair, chance-time events). The model writes memories in
///   character; the engine says which lines mattered.
/// - Emotion stamping is read, not asked: a new card's feeling comes from the
///   cited messages' recorded emotion metadata — never from the model.
/// - 1:1 ↔ group parity by construction: the same owner loop runs in both
///   modes (1:1 = one owner). Scene guests never journal (unresolvable ids
///   are skipped — the guest parity guard).
/// - Local-model floor: XML-tag transport (journal_ops.dart), reasoning off +
///   think-strip via the shared LlmEvalEngine plumbing.
class JournalMaintenance {
  final JournalStore store;

  final Future<String?> Function(String prompt) fireLLMEval;
  final String Function(String) stripThinkBlocks;

  final String? Function() getSessionId;
  final CharacterCard? Function() getActiveCharacter;
  final GroupChat? Function() getActiveGroup;
  final List<CharacterCard> Function() getGroupCharacters;
  final String Function(CharacterCard) getCharacterIdFromCard;
  final List<ChatMessage> Function() getMessages;
  final String Function() getUserName;

  /// Pass cursor — reuses the god's _summaryLastIndex scalar (persisted to
  /// Sessions.summaryLastIndex; zeroed on every existing reset site).
  final int Function() getCursor;
  final void Function(int) setCursor;

  /// Recap — reuses the god's _summary scalar (persisted to Sessions.summary).
  final String Function() getRecap;
  final void Function(String) setRecap;

  /// In-flight flag — reuses the god's _isSummaryGenerating (spinners keep
  /// working; no new flag, no new zeroing sites).
  final bool Function() getIsPassRunning;
  final void Function(bool) setIsPassRunning;

  final int Function() getMaxCards;
  final VoidCallback onNotify;
  final Future<void> Function() onSaveChat;

  JournalMaintenance({
    required this.store,
    required this.fireLLMEval,
    required this.stripThinkBlocks,
    required this.getSessionId,
    required this.getActiveCharacter,
    required this.getActiveGroup,
    required this.getGroupCharacters,
    required this.getCharacterIdFromCard,
    required this.getMessages,
    required this.getUserName,
    required this.getCursor,
    required this.setCursor,
    required this.getRecap,
    required this.setRecap,
    required this.getIsPassRunning,
    required this.setIsPassRunning,
    required this.getMaxCards,
    required this.onNotify,
    required this.onSaveChat,
  });

  /// Recap length instruction (words). The recap must stay plain prose —
  /// EvolutionService and the prompt summaryBlock consume it directly.
  static const int kRecapMaxWords = 200;

  /// How many trailing messages to re-read when a force pass finds an empty
  /// window (manual "regenerate" with nothing new since the cursor).
  static const int kForceWindowFallback = 10;

  /// Set when a significant event fires outside message metadata (objective
  /// completion, whose check runs pre-generation). Consumed by ChatService's
  /// _maybeRunJournalPass — which runs post-generation, so the event pass
  /// never competes with the main LLM call for the backend.
  bool eventKickPending = false;

  Future<void> runMaintenancePass({bool force = false}) async {
    final sessionToken = getSessionId();
    if (sessionToken == null) return;
    if (getIsPassRunning()) return;
    // Set synchronously before the first await — the only re-entrancy guard
    // for this fire-and-forget per-turn hook.
    setIsPassRunning(true);
    onNotify();

    try {
      final messages = getMessages();
      var start = getCursor().clamp(0, messages.length);
      if (start == 0 && messages.length > JournalPhysics.kFirstPassCap) {
        // Virgin journal on an existing long chat: first pass reads only the
        // recent tail instead of the whole history (older turns stay
        // reachable through RAG; the recap catches the character up fast).
        start = messages.length - JournalPhysics.kFirstPassCap;
      }
      if (start >= messages.length) {
        if (!force) return;
        start = (messages.length - kForceWindowFallback).clamp(
          0,
          messages.length,
        );
      }
      final window = messages.sublist(start);
      if (window.isEmpty) return;

      final owners = _diaryOwners(window);
      if (owners.isEmpty) return;

      var anySucceeded = false;
      for (var i = 0; i < owners.length; i++) {
        final owner = owners[i];
        final ownerId = getCharacterIdFromCard(owner);
        if (ownerId.isEmpty) continue;

        final cards = await store.cardsFor(sessionToken, ownerId);
        final prompt = _buildPrompt(
          owner: owner,
          cards: cards,
          window: window,
          windowStart: start,
          includeRecap: i == 0,
        );

        final raw = await fireLLMEval(prompt);
        if (raw == null || raw.trim().isEmpty) {
          debugPrint('[Journal] ✗ ${owner.name}: empty eval response');
          continue;
        }
        final text = stripThinkBlocks(raw);

        final ops = parseJournalOps(text);
        // Emotional physics: cool the existing cards one step first
        // (flashbulb decay — strong feelings barely fade), so adds and
        // revises land at full heat afterwards. Only on a successful eval —
        // a failed pass retries next interval without double-cooling.
        await store.coolCards(sessionToken, ownerId);
        await _applyOps(
          ops: ops,
          sessionId: sessionToken,
          ownerId: ownerId,
          cards: cards,
          window: window,
          windowStart: start,
        );
        // Vector any cards still missing embeddings (new, revised, or
        // written while the sidecar was down) so cold-card recall can find
        // them later. No-op without the embedder — the no-RAG floor.
        await store.embedMissing(sessionToken, ownerId);

        if (i == 0) {
          final recap = parseRecap(text);
          if (recap != null && getSessionId() == sessionToken) {
            setRecap(recap);
          }
        }
        anySucceeded = true;
        debugPrint(
          '[Journal] ✓ ${owner.name}: ${ops.length} op(s)'
          '${i == 0 ? ' + recap' : ''}',
        );
      }

      // Advance the cursor only when at least one owner call succeeded — an
      // all-failed pass auto-retries next interval (old summary semantics).
      if (anySucceeded && getSessionId() == sessionToken) {
        setCursor(messages.length);
        await onSaveChat();
      }
    } catch (e) {
      debugPrint('[Journal] Maintenance pass failed: $e');
    } finally {
      setIsPassRunning(false);
      onNotify();
    }
  }

  /// Distinct diary owners appearing in the window. 1:1 = the active
  /// character; group = every group member who spoke (order of first
  /// appearance), falling back to the active character for user-only windows.
  /// Ids that don't resolve to a group member (scene guests, director) are
  /// skipped — guests never journal.
  List<CharacterCard> _diaryOwners(List<ChatMessage> window) {
    if (getActiveGroup() == null) {
      final active = getActiveCharacter();
      return active == null ? const [] : [active];
    }
    final members = getGroupCharacters();
    final owners = <CharacterCard>[];
    final seen = <String>{};
    for (final m in window) {
      if (m.isUser || m.characterId == '__director__') continue;
      final id = m.characterId;
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      for (final c in members) {
        if (getCharacterIdFromCard(c) == id) {
          owners.add(c);
          seen.add(id);
          break;
        }
      }
    }
    if (owners.isEmpty) {
      final active = getActiveCharacter();
      if (active != null && members.contains(active)) return [active];
    }
    return owners;
  }

  String _buildPrompt({
    required CharacterCard owner,
    required List<JournalMemoryData> cards,
    required List<ChatMessage> window,
    required int windowStart,
    required bool includeRecap,
  }) {
    final userName = getUserName();
    final b = StringBuffer();

    b.writeln(
      'You are ${owner.name}. You privately keep a journal about this '
      'conversation with $userName. Below are your current journal entries '
      'and what has happened since you last wrote. Update your journal.',
    );
    b.writeln();

    final recap = getRecap();
    b.writeln('Your current recap of where things stand:');
    b.writeln(recap.isEmpty ? '(you have not written a recap yet)' : recap);
    b.writeln();

    b.writeln('Your current journal entries:');
    if (cards.isEmpty) {
      b.writeln('(none yet)');
    } else {
      for (var i = 0; i < cards.length; i++) {
        final c = cards[i];
        final feeling = c.emotionLabel == null ? '' : ', felt ${c.emotionLabel}';
        b.writeln(
          '[${i + 1}] (${c.category}$feeling'
          '${c.pinned ? ', pinned' : ''}) ${c.content}',
        );
      }
    }
    b.writeln();

    b.writeln('New events since you last wrote:');
    for (var i = 0; i < window.length; i++) {
      final m = window[i];
      if (m.characterId == '__director__') continue;
      b.writeln('#${windowStart + i} ${m.sender}: ${m.displayText}');
      final salience = _salienceLine(m);
      if (salience != null) b.writeln('    ($salience)');
    }
    b.writeln();

    b.writeln('Rules:');
    b.writeln(
      '- Edit in place: add new entries, revise entries that changed, retire '
      'entries that became wrong or irrelevant. Never restate an existing '
      'entry as a new one — revise it instead.',
    );
    b.writeln(
      '- Only add durable memories: promises made, things learned about '
      '$userName, relationship shifts, moments that mattered. The annotated '
      'lines above are the significant ones. Skip small talk.',
    );
    b.writeln(
      '- Each memory is one sentence, first person, at most 40 words. '
      'Cite the message numbers it came from with msgs="...".',
    );
    b.writeln(
      '- Categories: about_user (things learned about $userName), about_us '
      '(the relationship), moment (something that happened), promise.',
    );
    b.writeln('- Emit only the tags below. No other commentary.');
    b.writeln();

    b.writeln('Format — one tag per operation:');
    b.writeln(
      '<memory action="add" category="moment" msgs="12,14">first-person '
      'memory text</memory>',
    );
    b.writeln(
      '<memory action="revise" id="3" feeling="proud">replacement '
      'text</memory>',
    );
    b.writeln('<memory action="retire" id="2"/>');
    b.writeln('<memory action="pin" id="5"/>');
    if (includeRecap) {
      b.writeln(
        '<recap>Where things stand now — present tense, your voice, at most '
        '$kRecapMaxWords words.</recap>',
      );
      b.writeln();
      b.writeln('End with exactly one <recap> tag.');
    } else {
      b.writeln();
      b.writeln('Do not write a <recap> tag.');
    }

    return b.toString();
  }

  /// Deterministic per-message salience annotation from the engine-stamped
  /// metadata that already exists (nothing here asks the model anything).
  String? _salienceLine(ChatMessage m) {
    final meta = m.activeMetadata;
    if (meta == null) return null;
    final parts = <String>[];

    final emotion = meta['emotion_label'];
    if (emotion is String && emotion.isNotEmpty) {
      final intensity = _intensityOf(m);
      parts.add('felt $emotion${intensity == null ? '' : ' ($intensity)'}');
    }
    final bond = meta['bond_delta'];
    if (bond is int && bond != 0) {
      final reason = meta['bond_reason'];
      parts.add(
        'bond ${bond > 0 ? '+' : ''}$bond'
        '${reason is String && reason.isNotEmpty ? ' — $reason' : ''}',
      );
    }
    final trust = meta['trust_delta'];
    if (trust is int && trust != 0) {
      final reason = meta['trust_reason'];
      parts.add(
        'trust ${trust > 0 ? '+' : ''}$trust'
        '${reason is String && reason.isNotEmpty ? ' — $reason' : ''}',
      );
    }
    final repair = meta['trust_repair_verdict'];
    if (repair is String && repair.isNotEmpty) {
      parts.add('trust repair: $repair');
    }
    final chance = meta['chance_time_event'];
    if (chance is String && chance.isNotEmpty) {
      parts.add('unexpected event: $chance');
    }
    if (parts.isEmpty) return null;
    return parts.join('; ');
  }

  Future<void> _applyOps({
    required List<JournalOp> ops,
    required String sessionId,
    required String ownerId,
    required List<JournalMemoryData> cards,
    required List<ChatMessage> window,
    required int windowStart,
  }) async {
    for (final op in ops) {
      switch (op.action) {
        case JournalOpAction.add:
          final stamp = _emotionStamp(op.sourcePositions, window, windowStart);
          await store.addCard(
            sessionId: sessionId,
            characterId: ownerId,
            content: op.text,
            category: op.category,
            emotionLabel: stamp?.$1,
            emotionIntensity: stamp?.$2,
            sourcePositions: op.sourcePositions,
            maxCards: getMaxCards(),
          );
          break;
        case JournalOpAction.revise:
          final card = _cardForHandle(cards, op.handle);
          if (card == null) continue;
          await store.reviseCard(card, content: op.text, feeling: op.feeling);
          break;
        case JournalOpAction.retire:
          final card = _cardForHandle(cards, op.handle);
          if (card == null) continue;
          await store.retireCard(card.id);
          break;
        case JournalOpAction.pin:
          final card = _cardForHandle(cards, op.handle);
          if (card == null) continue;
          await store.setPinned(card.id, true);
          break;
      }
    }
  }

  JournalMemoryData? _cardForHandle(List<JournalMemoryData> cards, int? handle) {
    if (handle == null || handle < 1 || handle > cards.length) return null;
    return cards[handle - 1];
  }

  /// Deterministic emotion stamp for a new card: the strongest recorded
  /// feeling among the cited messages, falling back to the last annotated
  /// message in the window. Returns (label, intensity) or null.
  (String, String?)? _emotionStamp(
    List<int> positions,
    List<ChatMessage> window,
    int windowStart,
  ) {
    (String, String?)? best;
    var bestRank = -1;

    void consider(ChatMessage m) {
      final label = m.activeMetadata?['emotion_label'];
      if (label is! String || label.isEmpty) return;
      final intensity = _intensityOf(m);
      final rank = switch (intensity) {
        'strong' => 3,
        'moderate' => 2,
        'mild' => 1,
        _ => 0,
      };
      if (rank > bestRank) {
        bestRank = rank;
        best = (label, intensity);
      }
    }

    for (final pos in positions) {
      final idx = pos - windowStart;
      if (idx >= 0 && idx < window.length) consider(window[idx]);
    }
    if (best == null) {
      for (final m in window.reversed) {
        consider(m);
        if (best != null) break;
      }
    }
    return best;
  }

  String? _intensityOf(ChatMessage m) {
    final state = m.activeMetadata?['realism_state'];
    if (state is Map) {
      final intensity = state['emotionIntensity'];
      if (intensity is String && intensity.isNotEmpty) return intensity;
    }
    return null;
  }
}
