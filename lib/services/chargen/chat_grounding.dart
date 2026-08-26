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

/// Pure helpers for grounding character generation in a real chat.
///
/// Shared by the Scene Guest mint (build a NEW character from in-chat
/// portrayal) and AI Enhance (rebuild an EXISTING character from one of its
/// chats), and by the web facade — desktop and web must produce identical
/// prompts, so everything here is deterministic string/data work with no
/// service dependencies.
library;

/// Which card fields an AI Enhance run should rewrite. The desktop pre-flight
/// checklist and the web `POST /api/chargen/enhance` body both serialize to
/// this shape.
class EnhanceSelection {
  const EnhanceSelection({
    this.description = true,
    this.personality = true,
    this.exampleDialogue = true,
    this.scenario = false,
    this.greetings = false,
    this.lorebook = false,
    this.porchLife = false,
  });

  final bool description;
  final bool personality;
  final bool exampleDialogue;
  final bool scenario;
  final bool greetings;
  final bool lorebook;

  /// Wardrobe, pockets, ambitions, likes — same keep/accept review as
  /// the text fields. Default off so older clients and existing tests
  /// that omit the key do not silently grow a new LLM pass.
  final bool porchLife;

  /// True when the enrichment call (which rewrites description + personality +
  /// scenario in one shot) needs to run at all.
  bool get needsEnrichment => description || personality || scenario;

  bool get anySelected =>
      needsEnrichment || exampleDialogue || greetings || lorebook || porchLife;

  factory EnhanceSelection.fromJson(Map<String, dynamic> json) =>
      EnhanceSelection(
        description: json['description'] as bool? ?? true,
        personality: json['personality'] as bool? ?? true,
        exampleDialogue: json['exampleDialogue'] as bool? ?? true,
        scenario: json['scenario'] as bool? ?? false,
        greetings: json['greetings'] as bool? ?? false,
        lorebook: json['lorebook'] as bool? ?? false,
        porchLife: json['porchLife'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'description': description,
    'personality': personality,
    'exampleDialogue': exampleDialogue,
    'scenario': scenario,
    'greetings': greetings,
    'lorebook': lorebook,
    'porchLife': porchLife,
  };
}

/// One speaker-attributed line of chat transcript.
typedef ChatTurn = ({String speaker, String text});

/// Fold the in-chat portrayal of [name] into the build concept so the
/// generated card reflects how the character actually appeared in the scene,
/// not a generic invention from a bare name. The excerpts are dominated by
/// other characters (the narrator + the user) too, so the instruction is
/// explicit: build ONLY [name] from what describes them, ignore the rest.
///
/// Moved verbatim from `SceneGuestFactory._buildGroundedConcept` so AI Enhance
/// and the guest mint share one grounding voice; the byte-pin test in
/// `test/services/chargen/chat_grounding_test.dart` guards the exact wording.
String groundedConceptFor(String name, String concept, String grounding) {
  final g = grounding.trim();
  if (g.isEmpty) return concept;
  final lead = concept.trim().isEmpty ? '' : '${concept.trim()}\n\n';
  return '${lead}Build "$name" to match EXACTLY how they are portrayed in the '
      'roleplay excerpts below — their appearance, manner, role, speech, and '
      'relationships as actually shown. The excerpts also feature other '
      'characters (the narrator and the user); use ONLY the details that '
      'describe "$name" and ignore traits that clearly belong to someone '
      'else. Do not invent a conflicting identity.\n\n'
      'How "$name" has appeared in the scene so far:\n$g';
}

/// Assemble the chat-grounding block for an AI Enhance run.
///
/// Layout (highest signal per token first):
///   1. the Journal "Where we are" recap, when present,
///   2. the character's Journal memory cards, when present,
///   3. transcript turns as `Speaker: line`, filled NEWEST-first — the recap
///      already covers the old arc, so when the budget forces a choice the
///      recent voice wins. Turns are emitted in chronological order.
///
/// [maxChars] bounds the whole block; recap and cards count against it. Empty
/// inputs produce empty sections, and an all-empty call returns ''.
String buildChatExcerptBlock({
  required List<ChatTurn> turns,
  String recap = '',
  List<String> memoryCards = const [],
  required int maxChars,
}) {
  if (maxChars <= 0) return '';
  final sections = <String>[];
  var used = 0;

  final r = recap.trim();
  if (r.isNotEmpty) {
    final section = 'Where the story is:\n$r';
    if (used + section.length <= maxChars) {
      sections.add(section);
      used += section.length + 2;
    }
  }

  final cards = memoryCards.map((c) => c.trim()).where((c) => c.isNotEmpty);
  if (cards.isNotEmpty) {
    final section = 'Key memories:\n${cards.map((c) => '- $c').join('\n')}';
    if (used + section.length <= maxChars) {
      sections.add(section);
      used += section.length + 2;
    }
  }

  // Fill with transcript lines newest-first, then restore chronological order.
  final kept = <String>[];
  for (final turn in turns.reversed) {
    final text = turn.text.trim();
    if (text.isEmpty) continue;
    final line = '${turn.speaker}: $text';
    if (used + line.length + 1 > maxChars) break;
    kept.add(line);
    used += line.length + 1;
  }
  if (kept.isNotEmpty) {
    sections.add(kept.reversed.join('\n'));
  }

  return sections.join('\n\n');
}

/// Character budget for the grounding block, mirroring the world-lore clamp in
/// `creator_state_engine.core.dart` (`_extractWorldLore`): local KoboldCpp
/// leaves 3K tokens free for generation, remote assumes a 120K window — then a
/// hard 3,000-token ceiling on top, because the block is repeated in every
/// cumulative interview turn (up to 9), so an unbounded block multiplies ~9x
/// across the run. Tokens are estimated at 4 chars each, same as the clamp.
int enhanceGroundingCharBudget({
  required bool isLocalKobold,
  required int contextSize,
}) {
  final freeContextTokens = isLocalKobold ? contextSize - 3000 : 120000;
  final tokens = freeContextTokens.clamp(0, 3000);
  return tokens * 4;
}
