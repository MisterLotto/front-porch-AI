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

import 'dart:convert';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chargen/chat_grounding.dart';
import 'package:front_porch_ai/utils/utils.dart';

/// Everything AI Enhance reads from one chat: the raw transcript turns, the
/// Journal "Where we are" recap, and the character's Journal memory cards.
/// Feed it to [buildChatExcerptBlock] under the run's character budget.
class EnhanceContext {
  const EnhanceContext({
    required this.turns,
    required this.recap,
    required this.memoryCards,
  });

  final List<ChatTurn> turns;
  final String recap;
  final List<String> memoryCards;

  /// Real conversational depth of the chat — used by the pre-flight dialog to
  /// warn that a very short chat gives the model little to work with.
  int get userTurnCount => turns.where((t) => t.speaker == 'User').length;
}

/// Load one 1:1 chat's grounding material for [card] straight from the DB.
///
/// - Recap = `Sessions.summary` (the Journal "Where we are" text; empty when
///   the Journal never ran).
/// - Memory cards are keyed by the character's **stableGroupId** — the same
///   key `ChatParticipant.id` uses — NOT the `characters.id` UUID. Joining on
///   the UUID silently returns nothing (the documented identity gotcha).
/// - Message text is `swipes[swipeIndex]`, think-stripped via
///   [ChatMessage.displayText] so reasoning traces never leak into prompts.
///   Blank turns (e.g. think-only replies) are dropped.
Future<EnhanceContext> buildEnhanceContext({
  required AppDatabase db,
  required CharacterCard card,
  required String sessionId,
}) async {
  final session = await db.getSessionById(sessionId);
  final recap = session?.summary?.trim() ?? '';

  final cards = await db.getJournalCards(sessionId, card.stableGroupId);
  final memoryCards = cards
      .map((c) => c.content.trim())
      .where((c) => c.isNotEmpty)
      .toList();

  final rows = await db.getMessagesForSession(sessionId);
  final turns = <ChatTurn>[];
  for (final m in rows) {
    List<String> swipes;
    try {
      swipes = List<String>.from(jsonDecode(m.swipes) as List);
    } catch (_) {
      continue;
    }
    if (swipes.isEmpty) continue;
    final idx = (m.swipeIndex >= 0 && m.swipeIndex < swipes.length)
        ? m.swipeIndex
        : 0;
    // Route through ChatMessage.displayText — the ONE central think-strip —
    // instead of re-implementing its regexes here.
    final text = ChatMessage(
      text: swipes[idx],
      sender: m.sender,
      isUser: m.isUser,
    ).displayText;
    if (text.isEmpty) continue;
    turns.add((speaker: m.isUser ? 'User' : card.name, text: text));
  }

  return EnhanceContext(turns: turns, recap: recap, memoryCards: memoryCards);
}
