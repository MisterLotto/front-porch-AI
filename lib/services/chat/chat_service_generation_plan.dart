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

/// Phase 2 of `_generateResponse` (see chat_service_generation.dart):
/// Continue-mode message pop, the macro resolution pass, the realism/world/
/// Chance Time/porch-night/objective/catastrophe state blocks, PromptPlan
/// registration (the "wheel hub" every section renders from), and the
/// fixed-token/history-budget walk. Extracted verbatim (mechanical `x` →
/// `t.x` carrier rename only — see `_GenTurn`) from the single ~1.9k-line
/// `_generateResponse` method during the god-file split
/// (docs/design/god-file-elimination.md). Zero behaviour change.
extension ChatServiceGenerationPlan on ChatService {
  Future<void> _buildGenerationPlan(_GenTurn t) async {
    // ── Continue mode: remove the last message from history ──
    // For continue mode, we exclude the last message from the chat history
    // and place it as the prompt suffix so the LLM continues from it naturally.
    // Wrapped in try-finally to guarantee restoration even on exception.
    ChatMessage? _continuePoppedMessage;
    if (t.mode == GenerationMode.continue_ && _messages.isNotEmpty) {
      _continuePoppedMessage = _messages.removeLast();
      final partial = _continuePoppedMessage.text;
      // For Continue: feed straight existing messages as the prompt (per user request).
      // The suffix is the raw text of the message being continued (no re-added "Sender: " label).
      // This makes the continuation prompt contain the plain previous messages + the exact
      // partial text to extend, so the model continues the string directly without beginning
      // the output with "Rachel:" or the speaker name.
      // CRITICAL RULE: Strictly forbid the model from writing *anything* for {{user}} (actions, dialogue, thoughts, "he said", "you feel", etc.).
      // This is a cardinal sin in AI RP. Only extend the provided partial text from the current speaker's POV and voice.
      // The user's name is interpolated directly (not {{user}}): this rule
      // rides the suffix together with the partial message text, and running
      // the macro resolver over user/model-authored content would
      // double-process any {{...}} it happens to contain. Sanitized so a
      // name carrying brackets/newlines can't break the [rule] framing.
      final safeUser = t.userName.replaceAll(RegExp(r'[\n\r\[\]]'), ' ').trim();
      final ruleUser = safeUser.isEmpty ? 'the user' : safeUser;
      t.suffix =
          "\n[CRITICAL RULE: The text below is an incomplete response from the *current speaker only*. You MUST ONLY generate more text that continues *this exact response* in the speaker's voice, style, and perspective. NEVER write any dialogue, actions, thoughts, narration, or descriptions for $ruleUser or from $ruleUser's point of view. NEVER add new speaker labels or switch characters. Only append to the text below. Stop if it would require $ruleUser content.]\n" +
          partial;
    }

    // ── Macro resolution pass ──
    // Full chat context: card fields, group roster, last messages, idle
    // clock, and the {{setvar}}/{{getvar}} stores.
    final macroCtx = _buildChatMacroContext(
      t.speakingCharacter,
      scenario: t.scenario,
    );
    t.systemPrompt = _macroResolver.resolve(
      t.systemPrompt,
      macroCtx,
      section: 'systemPrompt',
    );
    // Lore buckets are macro-resolved individually (same 'lore' section
    // seeding the old single block used).
    String loreMacro(String s) =>
        s.isEmpty ? s : _macroResolver.resolve(s, macroCtx, section: 'lore');
    t.loreBefore = loreMacro(t.loreBefore);
    t.loreAfter = loreMacro(t.loreAfter);
    t.loreAnTop = loreMacro(t.loreAnTop);
    t.loreAnBottom = loreMacro(t.loreAnBottom);
    t.loreExTop = loreMacro(t.loreExTop);
    t.loreExBottom = loreMacro(t.loreExBottom);
    t.loreDepth = [
      for (final d in t.loreDepth)
        LoreDepthEntry(
          depth: d.depth,
          role: d.role,
          content: loreMacro(d.content),
        ),
    ];
    final loreDepthJoined = t.loreDepth.map((d) => d.content).join('\n');
    // personaBlock and group-mode examples are resolved per-character above
    t.scenario = _macroResolver.resolve(
      t.scenario,
      macroCtx,
      section: 'scenario',
    );
    if (_activeGroup == null && t.mesExampleBlock.isNotEmpty) {
      t.mesExampleBlock = _macroResolver.resolve(
        t.mesExampleBlock,
        macroCtx,
        section: 'mesExample',
      );
    }
    if (t.postHistoryBlock.isNotEmpty) {
      t.postHistoryBlock = _macroResolver.resolve(
        t.postHistoryBlock,
        macroCtx,
        section: 'postHistory',
      );
    }

    // Ensure the popped message is always restored, even if prompt assembly throws
    try {
      t.history = _buildChatHistory(depthLore: t.loreDepth);

      // ── Context Shift: budget-aware history trimming ──

      // Realism / internal state block — the words-only composer
      // (lib/services/chat/prompt_injection/realism_state_injection.dart):
      // salience-gated natural language only, no simulation scalars. Macro-
      // resolved HERE (spec §5a) — the fragments carry {{user}}, and this
      // block previously reached the model with the braces literal.
      String realismBlock = '';
      if (_realismActiveThisMode) {
        final rawRealism = _getRealismStateInjection();
        realismBlock = rawRealism.isEmpty
            ? ''
            : _macroResolver.resolve(
                rawRealism,
                macroCtx,
                section: 'realism',
              );
      }

      // Living Worlds — place prose from attached worlds (budget-capped).
      final attachedWorlds = [
        for (final id in _chatWorldIds)
          if (_worldRepository.resolveWorld(id) != null)
            _worldRepository.resolveWorld(id)!,
      ];
      // Fallback: group template worlds when chat_worlds not yet seeded.
      if (attachedWorlds.isEmpty && _activeGroup != null) {
        for (final ref in _activeGroup!.worldIds) {
          final w = _worldRepository.resolveWorld(ref);
          if (w != null) attachedWorlds.add(w);
        }
      }
      final rawWorld = buildWorldInjection(attachedWorlds);
      final worldBlock = rawWorld.isEmpty
          ? ''
          : _macroResolver.resolve(rawWorld, macroCtx, section: 'world');

      // Chance Time injection — independent of realism mode
      final chanceTimeBlock = _getChanceTimeInjection();

      // LLMerta Mafia-night force-ack (Chance Time register). Re-arms from
      // diary if needed; stays armed through regen of this AI message until
      // the *next* user send clears it.
      final porchDiaryId = _getCharacterIdFromCard(t.speakingCharacter);
      final porchSessionId = _currentSessionId;
      if (porchSessionId != null) {
        await _porchMemoryImport.ensureArmedForDiary(
          sessionId: porchSessionId,
          diaryCharacterId: porchDiaryId,
        );
      }
      final porchNightRaw = _porchMemoryImport.takeInjectionForDiary(
        porchDiaryId,
      );
      final porchNightBlock = porchNightRaw.isEmpty
          ? ''
          : _macroResolver.resolve(
              porchNightRaw,
              macroCtx,
              section: 'realism',
            );

      // Objective injection — always injected regardless of realism mode
      // Must sit in a fixed prompt section so it is NEVER trimmed by the budget system.
      // (thin delegation to author_note_builder per step 8; state/CRUD in god)
      final objectiveBlock = _getObjectiveInjection();

      // Mandatory Needs Catastrophe — when a hard-event need hit 0 during the
      // decay tick, the character's body/state fails in a specific way and the
      // reply must open on it. The narrative carries its own evidence, so this
      // wrapper stays generic: firm but short (heavy "YOU MUST" walls read as
      // jailbreak-fight energy and can backfire), and it never puppets {{user}}.
      String needsCatastropheBlock = '';
      if (_needsSimulation.pendingCatastrophe != null) {
        // Macro-resolved (spec §5a): previously the {{user}}/{{char}}
        // placeholders in this wrapper reached the model literally.
        needsCatastropheBlock = _macroResolver.resolve(
          '[SCENE EVENT — CANON, happening this turn]\n'
          '${_needsSimulation.pendingCatastrophe}\n'
          'Open the reply with this event as it happens; do not skip it, '
          'soften it to a near-miss, or fade past it. Narrate only what this '
          'specific event makes observable, then let the scene continue from '
          'its consequences. Do NOT decide {{user}}\'s actions, words, or '
          'feelings — write only {{char}} and the surroundings.]\n',
          macroCtx,
          section: 'realism',
        );
        // Consume it for this generation
        _needsSimulation.consumePendingCatastrophe();
      }

      // Register every section with the plan, in render order. This ONE
      // list is what the system message, user message, fixed-token count,
      // and Context Viewer budget map are all rendered from — every lore
      // bucket is counted (including @depth entries, which are spliced
      // into history later WITHOUT re-counting, via rendered:false), and
      // history/memories are budget-fitted afterwards (counted:false).
      final plan = t.plan = PromptPlan();
      // ── system message ──
      plan.add(
        id: 'system',
        label: 'System Prompt',
        inSystem: true,
        text: '${t.systemPrompt}\n',
      );
      plan.add(
        id: 'lore.before',
        label: 'Lorebook',
        inSystem: true,
        text: t.loreBefore,
      );
      plan.add(
        id: 'persona',
        label: 'Persona',
        inSystem: true,
        text: '${t.personaBlock}\n',
      );
      plan.add(
        id: 'lore.after',
        label: 'Lorebook',
        inSystem: true,
        text: t.loreAfter,
      );
      plan.add(id: 'user_persona', inSystem: true, text: t.userPersonaBlock);
      plan.add(
        id: 'scenario',
        label: 'Scenario',
        inSystem: true,
        text: ScenarioFade.wrapForChat(t.scenario, _messages),
      );
      plan.add(
        id: 'lore.ex_top',
        label: 'Lorebook',
        inSystem: true,
        text: t.loreExTop,
      );
      plan.add(
        id: 'examples',
        label: 'Examples',
        inSystem: true,
        text: t.mesExampleBlock,
      );
      plan.add(
        id: 'lore.ex_bottom',
        label: 'Lorebook',
        inSystem: true,
        text: t.loreExBottom,
      );
      // ── user message (transcript + tail) ──
      plan.add(id: 'start', text: '<START>\n');
      plan.add(
        id: 'history',
        label: 'Chat History',
        text: '',
        counted: false, // budget-fitted against fixedCountText
      );
      // Retrieved memories sit AFTER the transcript (Phase 3, measured):
      // retrieval changes this block every turn, and a changing block
      // BEFORE the history rewrote the prompt's middle each turn — a full
      // re-prefill of the whole transcript on every model (ContextShift
      // can't fix a middle edit). Measured on Gemma-4-31B (SWA): 2.62s →
      // 0.40s mean prompt-process, ~15s → ~1.2s wall on typical turns.
      // The echo risk of sitting nearer the generation point is carried by
      // the block's own framing ("reference only, do not revisit").
      plan.add(
        id: 'memories',
        label: 'Retrieved Memories',
        text: '',
        counted: false, // budget-fitted by the RAG joint cap below
      );
      // The recap and the Journal ALSO sit after the transcript (audit
      // finding #4's remainder, same mechanism as memories above): the
      // journal block re-sorts with the speaker's mood and re-warms cold
      // cards EVERY turn, and the recap rewrites every journal pass — as
      // pre-history sections they rewrote the prompt's head, forcing a
      // full re-prefill of the whole transcript on every local backend
      // (KoboldCpp, oMLX, LM Studio; prefix caches need byte-identical
      // heads). Post-history, mood re-ordering is cache-free. Render order
      // memories → recap → journal puts the feelings channel closest to
      // the generation point, matching its "truer guide" role frame.
      // Their fixed-count slot is unchanged (history/memories are excluded
      // from fixedCountText); the only fixed-count delta is each block's
      // new separator newline (≤1 token), so history budgeting is intact.
      plan.add(id: 'summary', label: 'Summary', text: t.summaryBlock);
      plan.add(id: 'journal', label: 'Journal', text: t.journalBlock);
      plan.add(
        id: 'post_history',
        label: 'Post-History',
        text: t.postHistoryBlock,
      );
      plan.add(id: 'lore.an_top', label: 'Lorebook', text: t.loreAnTop);
      plan.add(
        id: 'author_note',
        label: 'Author\'s Note',
        text: t.authorNoteBlock,
      );
      plan.add(id: 'lore.an_bottom', label: 'Lorebook', text: t.loreAnBottom);
      plan.add(
        id: 'lore.depth',
        label: 'Lorebook',
        text: loreDepthJoined,
        rendered: false, // spliced into the history lines, paid for here
      );
      plan.add(id: 'objectives', label: 'Objectives', text: objectiveBlock);
      plan.add(id: 'world', label: 'World / Place', text: worldBlock);
      plan.add(id: 'realism', label: 'Realism Mode', text: realismBlock);
      plan.add(
        id: 'catastrophe',
        label: 'Needs Catastrophe',
        text: needsCatastropheBlock,
      );
      plan.add(
        id: 'idle_cue',
        text: '',
        counted: false, // set after budgeting; rides the +50 reserve margin
      );
      plan.add(id: 'suffix', text: t.suffix);
      plan.add(id: 'chance_time', text: chanceTimeBlock);
      // High-recency with Chance Time so the first post-import reply
      // cannot bury the Mafia night (docs/design/llmerta-porch-memories.md §7b).
      plan.add(id: 'porch_night', text: porchNightBlock);

      final fixedTokens = await _countTokens(plan.fixedCountText);
      final contextBudget = _sessionGenSettings.resolveContextSize(
        _storageService,
      );
      final generationReserve =
          _sessionGenSettings.resolveMaxLength(_storageService) +
          50; // +50 safety margin
      t.historyBudget = contextBudget - fixedTokens - generationReserve;

      if (t.historyBudget > 0) {
        final result = await _buildChatHistoryWithBudget(
          t.historyBudget,
          depthLore: t.loreDepth,
        );
        t.history = result.history;
        t.droppedMessages = result.droppedCount;
      }
      // If budget is zero or negative, fixed sections already fill the context — use minimal history
      if (t.historyBudget <= 0 && _messages.isNotEmpty) {
        // Include at least the last message for continuity
        final lastMsg = _messages.last;
        t.history = lastMsg.characterId == '__director__'
            ? '[Director: ${lastMsg.text}]'
            : '${lastMsg.sender}: ${lastMsg.text}';
        t.droppedMessages = _messages.length - 1;
      }
    } finally {
      // ── Restore the popped continue message back into the list ──
      if (_continuePoppedMessage != null) {
        _messages.add(_continuePoppedMessage);
      }
    }

    final plan = t.plan;
    if (t.mode == GenerationMode.continue_) {
      // Drop the needs/realism/relationship/chaos/objective/catastrophe state injections
      // for Continue. Per user request: the continue prompt should be straight existing
      // messages (the plain history transcript + the partial text to continue from).
      // The runtime state blocks make the continuation feel injected and discordant.
      plan.section('realism').text = '';
      plan.section('chance_time').text = '';
      plan.section('objectives').text = '';
      plan.section('catastrophe').text = '';
      // Also skip RAG "earlier memories" for pure straight continuation.
      t.droppedMessages = 0;
    }
  }
}
