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

/// Private prompt chat-history builders and token counting/budgeting. Pure
/// formatting over `_messages` plus token accounting — no orchestration or
/// engine logic — extracted verbatim from `chat_service.dart` (zero behaviour
/// change) to shrink the god file. Private members, so safe to move to an
/// extension (never part of the public interface / fakeable).
extension ChatServiceHistory on ChatService {
  String _buildChatHistory({List<LoreDepthEntry> depthLore = const []}) {
    final lines = _messages.map((m) {
      // Director notes get bracketed so the AI treats them as instructions
      if (m.characterId == '__director__') {
        return '[Director: ${m.text}]';
      }
      return '${m.sender}: ${m.text}';
    }).toList();
    if (lines.any((l) => ChatService._macroPattern.hasMatch(l))) {
      debugPrint('[MacroResolver] ⚠ Unresolved macro detected in chat history');
    }
    return _spliceDepthLore(lines, depthLore).join("\n");
  }

  /// Insert @depth lore entries into a history line list: depth N = N
  /// message-lines up from the end (0 = after the last message), clamped.
  /// Entries sharing a depth keep their bucket order.
  List<String> _spliceDepthLore(
    List<String> lines,
    List<LoreDepthEntry> depthLore,
  ) {
    if (depthLore.isEmpty) return lines;
    final atFromEnd = <int, List<String>>{};
    for (final d in depthLore) {
      final clamped = d.depth > lines.length ? lines.length : d.depth;
      atFromEnd.putIfAbsent(clamped, () => []).add(d.content);
    }
    final out = <String>[];
    for (var i = 0; i <= lines.length; i++) {
      final insert = atFromEnd[lines.length - i];
      if (insert != null) out.addAll(insert);
      if (i < lines.length) out.add(lines[i]);
    }
    return out;
  }

  /// Build chat history that fits within a token budget.
  /// Walks messages newest-to-oldest, dropping the oldest that don't fit.
  /// [depthLore] entries are spliced in AFTER the budget walk (their tokens
  /// were already counted in the fixed content), relative to the included
  /// lines, so lore never evicts the history it positions against.
  /// Returns ({String history, int droppedCount, int tokenCount}).
  Future<({String history, int droppedCount, int tokenCount})>
  _buildChatHistoryWithBudget(
    int tokenBudget, {
    List<LoreDepthEntry> depthLore = const [],
  }) async {
    if (_messages.isEmpty) return (history: '', droppedCount: 0, tokenCount: 0);

    // Format all messages, skipping hidden group realism checkpoints
    final formatted = _messages.map((m) {
      if (m.characterId == '__director__') {
        return '[Director: ${m.text}]';
      }
      return '${m.sender}: ${m.text}';
    }).toList();
    if (formatted.any((l) => ChatService._macroPattern.hasMatch(l))) {
      debugPrint('[MacroResolver] ⚠ Unresolved macro detected in chat history');
    }

    // If budget is very large or negative (unlimited), return everything
    if (tokenBudget <= 0) {
      return (history: formatted.join('\n'), droppedCount: 0, tokenCount: 0);
    }

    // Walk from newest to oldest, accumulating messages that fit
    final included = <String>[];
    int usedTokens = 0;
    int droppedCount = 0;

    for (int i = formatted.length - 1; i >= 0; i--) {
      final msgText = formatted[i];
      final msgTokens = await _countTokens(msgText);
      if (usedTokens + msgTokens > tokenBudget && included.isNotEmpty) {
        // This message would exceed budget — drop it and all older messages
        droppedCount = i + 1;
        break;
      }
      usedTokens += msgTokens;
      included.insert(0, msgText);
    }

    final spliced = _spliceDepthLore(included, depthLore);

    // If messages were dropped, prepend a separator
    String history = spliced.join('\n');
    if (droppedCount > 0) {
      history =
          '[Earlier messages truncated — see summary above for context]\n$history';
    }

    return (
      history: history,
      droppedCount: droppedCount,
      tokenCount: usedTokens,
    );
  }

  /// Count tokens for a text string. Uses KoboldCpp's tokenizer when available,
  /// falls back to chars/4 estimate for remote APIs.
  Future<int> _countTokens(String text) async {
    if (text.isEmpty) return 0;
    // Use the KoboldCpp tokenizer if we're running locally
    if (_llmProvider == null || _llmProvider!.isLocal) {
      return _koboldService.countTokens(text);
    }
    // Fallback for remote APIs
    return (text.length / 4).ceil();
  }
}
