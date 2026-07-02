// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/services/llm_service.dart';

/// Plain (non-ChangeNotifier) leaf sibling to LlmEvalEngine / realism_evals / objective_proposal / journal_maintenance owning the character evolution (trait development) feature (LLM-driven growth, layered effective injection with [Character Growth]/[Current Situation] blocks, group per-char counts, manual trigger, status/error). (Extracted as step 14 of the chat_service modularization; its former siblings summary_service/fact_extraction were later replaced by the Journal — docs/design/journal-memory.md.) Evolution trigger (cadence decision inside the _maybeRunPeriodicEvals thin coordinator + enabled guard also in leaf trigger/manual) + target selection (last non-user speaker for group, implemented in leaf using getGroupCharacters/getMessages/getCharacterIdFromCard cbs when !target + normalized name match for robustness; god thins pass no target for auto, dance/impersonation for manual/active; timing: messages snapshot at call (post speaker for periodic); qualify) + load/save of evolved maps + reset/zero of transients + public surface stay thin/coordinated in god ("thin delegation here; full character evolution in step 14"). Flags/maps/counts/status/error god-owned; leaf uses cbs (god closures update+notify); clears via cbs in finally/!ready. LLM stream (heuristic maxLen, temp 0.4, central strip cb) + JSON parse (codeblock/greedy/truncated *success* path covered in ded) + persist cb (god: 1:1 vs group DB+mem) + effective layering owned here. God late final + thins at *every* prior call site ( _maybeRunPeriodicEvals / _trigger / triggerNow / _getEffective* / getters / loadGroup ) with *full excision*. 0 @Deprecated shims.
/// (Fix Round 1 for 6aafc9cf review: ... ; Fix Round 2 for 6aafc9cf re-review residuals: A/B/C stabilized (already-evolving return aligned to public API true + no side-effect, truncated forced success input + Growth assert, ded clean); D qualified (see below + god/leaf/MD).)
/// Group count note (D): count persistence for group is mem-only per current thin god load/save (1:1 has DB column; parity for effective layering/trigger target preserved; group count UI uses mem snapshot per plan "public surface stay thin in god"). Pre-existing, untouched, explicitly qualified.
///
/// Granular cbs (~16: getLlmService + strip; getUserName; getActive/getGroup/getMessages (target selection last non-user for group via cbs when !target + context); getCharacterIdFromCard (per-char under impersonation); getSummary; getIsNewChat; fetchRecentMemoryChunksForEvolution (RAG, closure sees god _get*); getCharacterEvolutionEnabled; get/setEvolvedPersonality/Scenario (per charId); get/setEvolutionCountFor; get/setIsEvolving; setStatus/setError; persistEvolvedForCharacter (god closure: patch+mem+count+notify)). Live god closures for test+group (last-speaker target).
///
/// 0 *new* god private _ methods (live `grep -c '^\s*void _[a-zA-Z]' lib/services/chat_service.dart` *must stay exactly 15* after every edit + final; thins + late final + reset comment syncs only). Dedicated test `test/services/chat/evolution_service_test.dart` using factory (`createTestEvolutionService`) with *live* closures over group maps + cbs (real dispatch without forcing god internals); 15 `test()` bodies via live `grep -c '^\s*test('` *post mandatory dead noop/placeholder/vestigial/factory-setup deletion as part of task*.
///
/// aug/integration tests receive *only* qualified passive notes in headers/comments (exact: "aug exercising only passive/qualified (no evolution-specific aug file edits; full in dedicated + manual; exercised via god thins _maybeRunPeriodicEvals/_triggerCharacterEvolution ; qualified notes only in dedicated header + god + MD per precedent)"); no leaf edits. Strict 1:1 vs group parity (per-char counts + layering + trigger target under impersonation identical; dispatch via cbs + god dance; timing qualified). Stateless/prompt-only (no owned reset/seed/load for maps/flags — god owns; no reset calls needed on leaf); god reset "keep blocks in sync" expanded at *all* ~15+ sites (full list + evolution_service (stateless or prompt-only; no reset calls needed) + "incomplete zeroing of secondary config on group/0-session/new-chat now complete" + *both* startNew explicit + cross-refs e.g. setActiveCharacter:1572). Anti-accumulation: explicit greps in god (no new _Evol/*Evol/Evolution privates); deletion of moved + vestigial as part of task. Barrel not added (internal only; per "unless 3+ locations"). Some coordination / enabled / sequence / load/save of maps / target thin in god per plan (cadence decision vs evolutionInterval lives in god _maybe thin coordinator; qualify: "thin delegation here; full character evolution in step 14"). Update headers/comments attributing evolution to god (now step 14 leaf; god cbs + thins).
class EvolutionService {
  final LLMService Function() getLlmService;
  final String Function(String) stripThinkBlocks;

  final String Function() getUserName;
  final CharacterCard? Function() getActiveCharacter;
  final List<CharacterCard> Function() getGroupCharacters;
  final List<ChatMessage> Function() getMessages;
  final String Function(CharacterCard) getCharacterIdFromCard;
  final String Function() getSummary;
  final bool Function() getIsNewChat;
  final Future<List<String>> Function() fetchRecentMemoryChunksForEvolution;
  final bool Function() getCharacterEvolutionEnabled;

  // Per-char evolved lookups (god owns maps; live closure for group/1:1)
  final String? Function(String charId) getEvolvedPersonality;
  final void Function(String charId, String value) setEvolvedPersonality;
  final String? Function(String charId) getEvolvedScenario;
  final void Function(String charId, String value) setEvolvedScenario;
  final int Function(String charId) getEvolutionCountFor;
  final void Function(String charId, int value) setEvolutionCountFor;

  final bool Function() getIsEvolvingCharacter;
  final void Function(bool) setIsEvolvingCharacter;
  final void Function(String) setEvolutionStatus;
  final void Function(String) setEvolutionError;

  // Persist after successful LLM parse (god closure handles 1:1 vs group DB patch
  // to evolvedPersonality/evolvedScenario or groupEvolved* JSON + mem update + count + notify)
  final Future<void> Function(
    String charId,
    String newPersonality,
    String newScenario,
    int newCount,
  )
  persistEvolvedForCharacter;

  EvolutionService({
    required this.getLlmService,
    required this.stripThinkBlocks,
    required this.getUserName,
    required this.getActiveCharacter,
    required this.getGroupCharacters,
    required this.getMessages,
    required this.getCharacterIdFromCard,
    required this.getSummary,
    required this.getIsNewChat,
    required this.fetchRecentMemoryChunksForEvolution,
    required this.getCharacterEvolutionEnabled,
    required this.getEvolvedPersonality,
    required this.setEvolvedPersonality,
    required this.getEvolvedScenario,
    required this.setEvolvedScenario,
    required this.getEvolutionCountFor,
    required this.setEvolutionCountFor,
    required this.getIsEvolvingCharacter,
    required this.setIsEvolvingCharacter,
    required this.setEvolutionStatus,
    required this.setEvolutionError,
    required this.persistEvolvedForCharacter,
  });

  /// Manually trigger character evolution now (for imported/existing chats).
  /// In group mode, pass a target character. Returns true if evolution was triggered.
  /// (Min history guard + already-evolving here in leaf; llm ready inside extract; god thins are pure delegates per "thin delegation here; full character evolution in step 14".)
  Future<bool> triggerEvolutionNow({CharacterCard? target}) async {
    final card = target ?? getActiveCharacter();
    if (card == null) return false;
    if (getMessages().length < 4) return false; // need some history

    debugPrint('[Evolution] ▶ Manual evolution triggered for ${card.name}');
    await _extractCharacterEvolution(targetCharacter: card);
    return true;
  }

  /// Trigger evolution check after each generation (or manual).
  /// Accepts optional target for group per-speaker.
  /// Full trigger/extract/LLM/persist/layering owned here.
  Future<void> triggerCharacterEvolution({
    CharacterCard? targetCharacter,
  }) async {
    await _extractCharacterEvolution(targetCharacter: targetCharacter);
  }

  /// Core extract evolved personality + scenario from conversation memories.
  /// Accepts an optional [targetCharacter] for group mode support.
  Future<void> _extractCharacterEvolution({
    CharacterCard? targetCharacter,
  }) async {
    if (getIsEvolvingCharacter()) {
      debugPrint('[Evolution] ⚠ Already evolving, skipping');
      return;
    }
    if (!getCharacterEvolutionEnabled()) {
      debugPrint('[Evolution] disabled in settings, skipping');
      setEvolutionError('Character evolution is disabled in settings.');
      setIsEvolvingCharacter(false);
      return;
    }
    setIsEvolvingCharacter(true);
    setEvolutionStatus('Preparing evolution...');
    setEvolutionError('');

    try {
      final llmService = getLlmService();
      debugPrint(
        '[Evolution] ▶ Backend: ${llmService.backendName}, isReady: ${llmService.isReady}',
      );
      if (!llmService.isReady) {
        debugPrint(
          '[Evolution] ✗ LLM not ready — backend=${llmService.backendName}',
        );
        setEvolutionError(
          'LLM backend is not ready. Please check your connection.',
        );
        return;
      }

      // Target resolution: if explicit target (manual/group impersonation), use it.
      // Otherwise for group (getGroupCharacters non-empty), pick last non-user speaker from messages (using getMessages + normalized name match via getGroupCharacters + getCharacterIdFromCard for per-char under cbs/impersonation dance in god callers).
      // Fallback to active (1:1 or no prior non-user). Timing qualified: uses snapshot of messages at call time (post-gen for periodic cadence, so last non-user is the just-spoken char in group); god _runPeriodic/_trigger thins pass no target (dispatch via leaf cbs + active fallback); 1:1 vs group per-char target/layering/counts parity preserved exactly when target provided or resolved.
      // Note: name-based (with trim/lower normalization for basic robustness); name collisions in groups are a known edge (recommend unique names or stable ids in cards); charId from cb used for all subsequent per-char (persist, evolved maps, counts).
      CharacterCard? card = targetCharacter;
      if (card == null) {
        final groupChars = getGroupCharacters();
        if (groupChars.isNotEmpty) {
          final msgs = getMessages();
          for (final m in msgs.reversed) {
            if (!m.isUser) {
              final sender = m.sender.trim().toLowerCase();
              card = groupChars.firstWhere(
                (c) => c.name.trim().toLowerCase() == sender,
                orElse: () => groupChars.first,
              );
              break;
            }
          }
        }
        card ??= getActiveCharacter();
      }
      if (card == null) {
        debugPrint('[Evolution] ✗ No character');
        setEvolutionError('No active character found.');
        return;
      }

      final charName = card.name;
      final userName = getUserName();
      final originalPersonality = card.personality;
      final originalScenario = card.scenario;
      final charId = getCharacterIdFromCard(card);

      debugPrint(
        '[Evolution] Character: $charName (charId=$charId, dbId=${card.dbId})',
      );
      debugPrint(
        '[Evolution] Personality length: ${originalPersonality.length}, Scenario length: ${originalScenario.length}',
      );

      // Get current evolved versions (or originals if first time) via cbs (god owns maps)
      final currentPersonality =
          (getEvolvedPersonality(charId)?.isNotEmpty == true)
          ? getEvolvedPersonality(charId)!
          : originalPersonality;
      final currentScenario = (getEvolvedScenario(charId)?.isNotEmpty == true)
          ? getEvolvedScenario(charId)!
          : originalScenario;

      // Gather context: RAG memories + summary + recent messages (via cbs)
      String memoryContext = '';
      final chunks = await fetchRecentMemoryChunksForEvolution();
      if (chunks.isNotEmpty) {
        setEvolutionStatus('Gathering memories...');
        debugPrint('[Evolution] RAG: ${chunks.length} memory chunks retrieved');
        // Take last 10 chunks to keep prompt reasonable
        final recent = chunks.length > 10
            ? chunks.sublist(chunks.length - 10)
            : chunks;
        memoryContext = 'Conversation memories:\n${recent.join('\n---\n')}\n\n';
      } else {
        debugPrint(
          '[Evolution] RAG not available or new chat (isNewChat=${getIsNewChat()})',
        );
      }

      String summaryContext = '';
      final summary = getSummary();
      if (summary.isNotEmpty) {
        summaryContext = 'Chat summary: $summary\n\n';
        debugPrint('[Evolution] Summary context: ${summary.length} chars');
      }

      // Recent messages for immediate context
      final messages = getMessages();
      final recentMsgs = messages.length > 10
          ? messages.sublist(messages.length - 10)
          : messages;
      final recentContext = recentMsgs
          .map((m) => '${m.sender}: ${m.displayText}')
          .join('\n');

      debugPrint(
        '[Evolution] Messages: ${messages.length} total, using ${recentMsgs.length} recent',
      );

      final prompt =
          'CRITICAL: Output ONLY structured data for the two fields below. No other text before or after.\n'
          'Preferred format: a single JSON object {"personality": "...", "scenario": "..."} with the full texts as values.\n'
          'If emitting a perfect JSON object is difficult for this long creative rewrite, use this exact labeled format instead (no extra sentences):\n'
          'PERSONALITY:\n<the complete rewritten personality here, using {{char}} and {{user}}>\n\n'
          'SCENARIO:\n<the complete rewritten scenario here>\n\n'
          'You are analyzing how a roleplay character has evolved through their interactions. '
          'Based on the conversation history and memories below, rewrite the character\'s personality '
          'and scenario to reflect how they have grown, changed, or been affected by events.\n\n'
          'IMPORTANT RULES:\n'
          '- Preserve the character\'s core identity — don\'t change who they fundamentally are\n'
          '- Add or modify traits based on what actually happened in conversations\n'
          '- Update the scenario to reflect the current state of the story/relationship\n'
          '- REFINE, do not accumulate: keep the total length CLOSE TO THE ORIGINAL. '
          'Do not pile on new text each time or let the description grow longer with every evolution — '
          'tighten and replace, do not append\n'
          '- Do NOT repeat the same phrases, sentences, or recurring motifs the previous version already used. '
          'State an evolved trait once, in fresh wording — never re-echo a signature line\n'
          '- Use {{char}} for the character name and {{user}} for the user name\n'
          '- The personality and scenario values may contain newlines and {{char}}/{{user}} macros\n\n'
          'Character name: $charName\n'
          'User name: $userName\n\n'
          'Original personality:\n$originalPersonality\n\n'
          'Current personality:\n$currentPersonality\n\n'
          'Original scenario:\n$originalScenario\n\n'
          'Current scenario:\n$currentScenario\n\n'
          '$memoryContext'
          '$summaryContext'
          'Recent conversation:\n$recentContext\n\n'
          'Output the structured PERSONALITY and SCENARIO (JSON object preferred, or the labeled format above).';

      debugPrint('[Evolution] Prompt built: ${prompt.length} chars');

      setEvolutionStatus('Analyzing conversation with LLM...');

      // Dynamic maxLength: the model must reproduce personality + scenario in
      // full, and think blocks can double the output.  Use a generous multiplier
      // with a 4096-token floor so short descriptions still get plenty of room.
      // Rough heuristic: 1 token ≈ 4 chars, so chars/4 ≈ tokens needed.
      final estimatedOutputTokens =
          ((currentPersonality.length + currentScenario.length) / 4 * 3).ceil();
      final maxLen = estimatedOutputTokens.clamp(4096, 16384);

      final params = GenerationParams(
        prompt: prompt,
        maxLength: maxLen,
        temperature: 0.4,
        stopSequences: [],
        reasoningEnabled: false,
      );

      debugPrint('[Evolution] Sending to LLM (maxLength=$maxLen, temp=0.4)...');

      String responseText = '';
      int chunkCount = 0;
      await for (final chunk in llmService.generateStream(params)) {
        responseText += chunk;
        chunkCount++;
      }

      debugPrint(
        '[Evolution] LLM responded: $chunkCount chunks, ${responseText.length} chars total',
      );

      // Strip think blocks (central via cb; for thinking models)
      final preStripLength = responseText.length;
      final stripped = stripThinkBlocks(responseText);
      responseText = stripped.isNotEmpty ? stripped : responseText.trim();
      if (responseText.length != preStripLength) {
        debugPrint(
          '[Evolution] Stripped think blocks: ${preStripLength - responseText.length} chars removed',
        );
      }

      if (responseText.isEmpty) {
        debugPrint('[Evolution] ✗ LLM returned empty response after stripping');
        setEvolutionError(
          'The LLM returned an empty response. Try again or check your backend.',
        );
        return;
      }

      // Log the full response for debugging (truncate for very long responses)
      debugPrint('[Evolution] ── Response start ──');
      if (responseText.length <= 500) {
        debugPrint(responseText);
      } else {
        debugPrint(responseText.substring(0, 250));
        debugPrint('[...${responseText.length - 500} chars omitted...]');
        debugPrint(responseText.substring(responseText.length - 250));
      }
      debugPrint('[Evolution] ── Response end ──');

      setEvolutionStatus('Parsing evolved traits...');

      // Parse JSON from response — robust strategies tolerant of reasoning
      // preamble from remote/thinking models, {{char}} macros inside the *content*
      // of personality/scenario text, code fences, truncation, and stray braces.
      String? newPersonality;
      String? newScenario;

      // Strategy 1: Extract from markdown code block (preferred when present)
      var jsonStr = responseText;
      if (jsonStr.contains('```')) {
        final match = RegExp(
          r'```(?:json)?\s*\n?(.*?)\n?```',
          dotAll: true,
        ).firstMatch(jsonStr);
        if (match != null) {
          jsonStr = match.group(1)!.trim();
          debugPrint(
            '[Evolution] Extracted JSON from code block (${jsonStr.length} chars)',
          );
        }
      }

      // Strategy 2: Find best JSON object. Anchor on the last structural key
      // ("personality" / "scenario") so we don't start the span at a data '{'
      // from {{char}} / {{user}} or other prose the model echoed or wrote.
      // Falls back to simple outer { ... } when no key anchor is present.
      final jsonCandidate = _extractBestJsonObject(
        jsonStr,
        requiredKeys: ['personality', 'scenario'],
      );

      if (jsonCandidate != null && jsonCandidate.isNotEmpty) {
        debugPrint(
          '[Evolution] Found JSON candidate (${jsonCandidate.length} chars)',
        );
        try {
          final parsed = jsonDecode(jsonCandidate) as Map<String, dynamic>;
          newPersonality = _asString(parsed['personality']);
          newScenario = _asString(parsed['scenario']);
          debugPrint(
            '[Evolution] JSON parsed OK — personality=${newPersonality?.length ?? 0} chars, scenario=${newScenario?.length ?? 0} chars',
          );
        } catch (e) {
          debugPrint('[Evolution] JSON parse attempt failed: $e');
          // Log preview of the bad candidate (helps diagnose future model quirks)
          final preview = jsonCandidate.length > 400
              ? '${jsonCandidate.substring(0, 200)}...${jsonCandidate.substring(jsonCandidate.length - 200)}'
              : jsonCandidate;
          debugPrint('[Evolution] Bad candidate preview (first/last): $preview');

          debugPrint('[Evolution] Attempting truncated JSON recovery...');
          try {
            final repaired = _repairTruncatedJson(jsonCandidate);
            final parsed = jsonDecode(repaired) as Map<String, dynamic>;
            newPersonality = _asString(parsed['personality']);
            newScenario = _asString(parsed['scenario']);
            if ((newPersonality?.isNotEmpty ?? false) &&
                (newScenario?.isNotEmpty ?? false)) {
              debugPrint('[Evolution] Truncated JSON recovery succeeded');
            }
          } catch (_) {
            debugPrint('[Evolution] Truncated JSON recovery failed');
          }
        }
      } else {
        debugPrint(
          '[Evolution] ✗ No JSON object containing personality/scenario found in response',
        );
      }

      // ── Labeled sections fallback (for models that partially follow the prompt) ──
      if ((newPersonality == null || newPersonality.isEmpty) ||
          (newScenario == null || newScenario.isEmpty)) {
        final labeled = _tryParseLabeledSections(responseText);
        if (labeled != null) {
          newPersonality ??= labeled.$1;
          newScenario ??= labeled.$2;
          if (newPersonality.isNotEmpty && newScenario.isNotEmpty) {
            debugPrint('[Evolution] Parsed using labeled PERSONALITY:/SCENARIO: sections');
          }
        }
      }

      // ── Prose salvage fallback (for models that completely ignore JSON/labels and just write the rewrite) ──
      // This is the path that catches the exact failure mode where the model produces good
      // evolved personality text (often starting with "{{char}} is ...") but no wrapper at all.
      if (newPersonality == null || newPersonality.isEmpty) {
        // Prefer a bad JSON candidate that turned out to be prose, otherwise the full response.
        final proseSource = (jsonCandidate != null &&
                jsonCandidate.length > 400 &&
                jsonCandidate.contains('{{char}}'))
            ? jsonCandidate
            : responseText;
        final salvaged = _salvagePersonalityFromProse(proseSource);
        if (salvaged != null && salvaged.length > 80) {
          newPersonality = salvaged;
          // Scenario evolution is secondary when the model gave us no structure;
          // reuse the most recent known version (or original) so we don't lose it.
          newScenario ??= (currentScenario.isNotEmpty ? currentScenario : originalScenario);
          debugPrint(
            '[Evolution] ⚠ Model emitted raw prose instead of structured output — salvaged personality directly (${newPersonality.length} chars). Reused prior scenario for safety.',
          );
        }
      }

      if (newPersonality == null ||
          newPersonality.isEmpty ||
          newScenario == null ||
          newScenario.isEmpty) {
        debugPrint(
          '[Evolution] ✗ Missing fields — personality=${newPersonality != null ? "${newPersonality.length} chars" : "null"}, scenario=${newScenario != null ? "${newScenario.length} chars" : "null"}',
        );
        setEvolutionError(
          newPersonality == null && newScenario == null
              ? 'Could not parse the LLM response as JSON. Check the terminal for the raw response.'
              : 'The LLM response was missing ${newPersonality == null || newPersonality.isEmpty ? "personality" : "scenario"} field.',
        );
        return;
      }

      // Compute new count (god owns via cb)
      final oldCount = getEvolutionCountFor(charId);
      final newCount = oldCount + 1;
      debugPrint(
        '[Evolution] Saving to session (charId=$charId, count $oldCount → $newCount)',
      );

      // Persist via god cb (handles 1:1 vs group DB + mem maps + count + notify)
      await persistEvolvedForCharacter(
        charId,
        newPersonality,
        newScenario,
        newCount,
      );

      debugPrint(
        '[Evolution] ✅ $charName evolved successfully (count: $newCount)',
      );
      debugPrint(
        '[Evolution] Personality preview: ${newPersonality.substring(0, newPersonality.length.clamp(0, 100))}...',
      );
      debugPrint(
        '[Evolution] Scenario preview: ${newScenario.substring(0, newScenario.length.clamp(0, 100))}...',
      );
    } catch (e, stack) {
      debugPrint('[Evolution] ✗ Evolution failed with exception: $e');
      debugPrint('[Evolution] Stack trace: $stack');
      setEvolutionError('Evolution failed: $e');
    } finally {
      setIsEvolvingCharacter(false);
      setEvolutionStatus('');
      // error left for UI if set; cleared on next success start or explicit
    }
  }

  /// Get the effective personality for a character.
  /// When evolution exists, returns a layered block: original as foundation,
  /// evolved traits as additive growth. This prevents contradictions.
  /// (Layering owned in leaf per plan; uses enabled cb + evolved cb lookups.)
  String getEffectivePersonality(CharacterCard card) {
    // Combine description (physical traits, background) with personality
    final base = [
      if (card.description.isNotEmpty) card.description,
      if (card.personality.isNotEmpty) card.personality,
    ].join('\n');
    if (!getCharacterEvolutionEnabled()) return base;
    final charId = getCharacterIdFromCard(card);
    final evolved = getEvolvedPersonality(charId);
    if (evolved == null || evolved.isEmpty) return base;
    // Layered: original is ground truth, evolved is additive growth
    return '$base\n\n'
        '[Character Growth — the following reflects how ${card.name} has changed through interactions. '
        'These traits build on the original personality above. If there is a contradiction, '
        'the growth represents genuine character development, not a replacement of core identity.]\n'
        '$evolved';
  }

  /// Get the effective scenario for a character.
  /// When evolution exists, returns both original scenario and evolved situation.
  /// (Layering owned in leaf per plan.)
  String getEffectiveScenario(CharacterCard card) {
    if (!getCharacterEvolutionEnabled()) return card.scenario;
    final charId = getCharacterIdFromCard(card);
    final evolved = getEvolvedScenario(charId);
    if (evolved == null || evolved.isEmpty) return card.scenario;
    // Layered: original scenario + evolved current situation
    return '${card.scenario}\n\n'
        '[Current Situation — the scenario has evolved through interactions:]\n'
        '$evolved';
  }

  // Note: getEvolved*For / getEvolutionCountFor public surface are thin delegates in god
  // (they use the same cbs internally or direct god map access for UI/sidebar; parity
  // via cbs for per-char in group).

  // ── Robust JSON extraction helpers (fix for reasoning-preamble + {{char}} false starts + truncation) ──

  /// Extract the best JSON object substring that is likely to contain the
  /// required structural keys. Anchors on the *last* occurrence of a key like
  /// "personality" so that { characters appearing inside the *data* (e.g.
  /// {{char}} / {{user}} macros the model is rewriting, or prose) do not cause
  /// us to start the span too early and produce unparseable garbage.
  String? _extractBestJsonObject(
    String text, {
    required List<String> requiredKeys,
  }) {
    if (text.isEmpty) return null;

    // Prefer anchoring on the last structural key we care about.
    int bestAnchor = -1;
    for (final key in requiredKeys) {
      final idx = text.lastIndexOf('"$key"');
      if (idx > bestAnchor) bestAnchor = idx;
    }

    int start;
    if (bestAnchor != -1) {
      // Walk backward from the key to a plausible opening brace.
      start = text.lastIndexOf('{', bestAnchor);
      if (start == -1) start = text.indexOf('{');
    } else {
      // No key found — fall back to the outermost object span.
      start = text.indexOf('{');
    }
    if (start != -1) {
      final end = text.lastIndexOf('}');
      if (end > start) {
        return text.substring(start, end + 1);
      } else {
        // Truncation (no closing } in the text yet). Return from the opening {
        // to the end of the string so the caller can run repair which will
        // supply the missing closers. This is the key fix for the old
        // "truncated recovery" cases in tests and real remote responses.
        return text.substring(start);
      }
    }
    return null;
  }

  /// Repair a truncated JSON string by closing unterminated strings and
  /// supplying the missing closing brackets/braces. Modeled on the proven
  /// implementation used by StoryPipeline.
  String _repairTruncatedJson(String json) {
    var openBraces = 0;
    var openBrackets = 0;
    var inString = false;
    var escaped = false;

    for (int i = 0; i < json.length; i++) {
      final c = json[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == '\\') {
        escaped = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (c == '{') openBraces++;
      if (c == '}') openBraces--;
      if (c == '[') openBrackets++;
      if (c == ']') openBrackets--;
    }

    var repaired = json;
    if (inString) repaired += '"';
    for (int i = 0; i < openBrackets; i++) {
      repaired += ']';
    }
    for (int i = 0; i < openBraces; i++) {
      repaired += '}';
    }
    return repaired;
  }

  /// Safe cast to String (LLM may emit number / bool / null for a key).
  String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  /// Try to parse "PERSONALITY:\n...\n\nSCENARIO:\n..." (or close variants like
  /// **Personality:**, Personality:, etc.). This is the explicit fallback format
  /// documented in the prompt for models that struggle with raw JSON on long outputs.
  (String, String)? _tryParseLabeledSections(String text) {
    if (text.isEmpty) return null;
    final t = text.trim();

    // Common header variants, case-insensitive, tolerant of **markdown** or extra colons.
    final persRe = RegExp(
      r'(?:^|\n)\s*\*{0,2}(?:PERSONALITY|Personality|personality)\*{0,2}\s*[:：]?\s*\n+',
      dotAll: true,
    );
    final scenRe = RegExp(
      r'(?:^|\n)\s*\*{0,2}(?:SCENARIO|Scenario|scenario)\*{0,2}\s*[:：]?\s*\n+',
      dotAll: true,
    );

    final persMatch = persRe.firstMatch(t);
    final scenMatch = scenRe.firstMatch(t);

    String? pers;
    String? scen;

    if (persMatch != null) {
      final start = persMatch.end;
      int end = t.length;
      if (scenMatch != null && scenMatch.start > start) {
        end = scenMatch.start;
      }
      pers = t.substring(start, end).trim();
    }

    if (scenMatch != null) {
      final start = scenMatch.end;
      scen = t.substring(start).trim();
    }

    if (pers != null && pers.isNotEmpty) {
      // If we only got personality, scenario may be missing — caller will decide reuse.
      return (pers, scen ?? '');
    }
    if (scen != null && scen.isNotEmpty && pers == null) {
      // Uncommon, but allow scenario-only salvage
      return ('', scen);
    }
    return null;
  }

  /// Heuristic salvage when the model completely ignored all structured output
  /// instructions and just wrote the evolved personality as plain prose (often
  /// beginning with "{{char}} is ..." or similar descriptive text using the macros).
  /// We strip obvious leading reasoning, then take the longest descriptive block
  /// that contains {{char}} references. This turns "total failure" into "we at
  /// least captured the creative rewrite the model did".
  String? _salvagePersonalityFromProse(String text) {
    if (text.isEmpty) return null;
    var t = text.trim();

    // Drop common leading meta/reasoning paragraphs the model emits before the actual rewrite.
    t = t.replaceFirst(
      RegExp(
        r'^((The user wants|I (need|will|should|must)|Based on the (conversation|history|memories|provided)|'
        r'After (reviewing|analyzing|looking)|The (conversation|history) shows|Here (is|are)|'
        r'Let me (rewrite|update|craft)|I should (focus|preserve|keep)).{0,400}?[\.\n]{1,3}){1,4}',
        dotAll: true,
        caseSensitive: false,
      ),
      '',
    ).trim();

    // If what's left is substantial and uses the {{char}} style the model was asked to preserve, use it.
    if (t.length > 150 && t.contains('{{char}}')) {
      // Remove any trailing leaked instructions
      t = t.replaceFirst(RegExp(r'\n*(Response:|Return only|Output only).*$', caseSensitive: false, dotAll: true), '').trim();
      return t;
    }

    // Secondary: grab the last substantial chunk that mentions {{char}} (the model often puts the good evolved text at the end).
    final lastMention = t.lastIndexOf('{{char}}');
    if (lastMention >= 0) {
      // Take from a bit before the last {{char}} to the end (captures the final descriptive block)
      final start = (lastMention - 80).clamp(0, t.length);
      final tail = t.substring(start).trim();
      if (tail.length > 150) {
        return tail;
      }
    }

    return null;
  }
}
