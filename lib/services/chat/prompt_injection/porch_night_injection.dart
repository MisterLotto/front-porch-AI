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

/// One-shot "Mafia night" force-ack prompt block (Chance Time register).
/// Design: docs/design/llmerta-porch-memories.md §7b.
///
/// Pure text builder — no I/O. Callers place the result in a high-recency
/// prompt slot (next to Chance Time / needs catastrophe) and clear
/// `porchAckPending` after the reacting message is done.
class PorchNightInjection {
  PorchNightInjection._();

  /// Max feeling bullets so the block stays short for local models.
  static const int kMaxBullets = 6;

  /// Build the SCENE / RECENT CANON block. Uses `{{user}}` / `{{char}}`
  /// placeholders — resolve with MacroResolver before the model sees it.
  ///
  /// [bullets] are `(emotionLabel, content)` from planted porch cards,
  /// already sorted by salience (caller). Empty → empty string.
  static String build({
    required List<({String emotion, String content})> bullets,
    String? townName,
  }) {
    if (bullets.isEmpty) return '';

    final taken = bullets.take(kMaxBullets).toList();
    final town = (townName != null && townName.trim().isNotEmpty)
        ? ' in ${townName.trim()}'
        : '';

    final lines = StringBuffer();
    lines.writeln(
      '[RECENT CANON — already happened between {{user}} and {{char}}, '
      'not optional:',
    );
    lines.writeln();
    lines.writeln(
      '{{user}} and {{char}} played a game of Mafia together earlier$town.',
    );
    lines.writeln('{{char}} still feels this about that night:');
    for (final b in taken) {
      final emotion = b.emotion.trim().isEmpty ? 'reflective' : b.emotion.trim();
      final content = b.content.trim();
      if (content.isEmpty) continue;
      lines.writeln('- ($emotion) $content');
    }
    lines.writeln();
    lines.writeln(
      'Open the reply with {{char}} bringing this up or reacting to it as '
      'lived history with {{user}} — do not skip it, pretend it never '
      'happened, or bury it under unrelated small talk. Write {{char}}\'s '
      'feelings in their own voice first, then let the scene continue. '
      'Never mention game apps, exports, journals, or systems.]',
    );
    return '\n${lines.toString()}\n';
  }
}

/// Session-scoped one-shot delivery state (Chance Time pattern: re-inject on
/// regen until the next user turn clears it).
class PorchNightAckState {
  /// diaryCharacterId → rendered injection text (pre-macro).
  final Map<String, String> _pending = {};

  /// diaryCharacterIds whose injection was used in a generation this window.
  final Set<String> _delivered = {};

  /// diaryCharacterId → journal card ids that still need porchAckPending cleared.
  final Map<String, List<String>> _cardIdsByDiary = {};

  bool get hasAnyPending => _pending.isNotEmpty;

  void arm({
    required String diaryCharacterId,
    required String injectionText,
    required List<String> journalCardIds,
  }) {
    if (injectionText.trim().isEmpty) return;
    _pending[diaryCharacterId] = injectionText;
    _delivered.remove(diaryCharacterId);
    _cardIdsByDiary[diaryCharacterId] = List<String>.from(journalCardIds);
  }

  /// Return the block for this diary owner and mark delivered (regen-safe).
  String takeForPrompt(String diaryCharacterId) {
    final text = _pending[diaryCharacterId];
    if (text == null || text.isEmpty) return '';
    _delivered.add(diaryCharacterId);
    return text;
  }

  /// Card ids for owners whose injection was delivered (for metadata clear).
  List<String> deliveredCardIds() {
    final ids = <String>[];
    for (final diaryId in _delivered) {
      final list = _cardIdsByDiary[diaryId];
      if (list != null) ids.addAll(list);
    }
    return ids;
  }

  /// Clear in-memory state for delivered owners (call on next user send).
  void clearDelivered() {
    for (final diaryId in _delivered) {
      _pending.remove(diaryId);
      _cardIdsByDiary.remove(diaryId);
    }
    _delivered.clear();
  }

  void clearAll() {
    _pending.clear();
    _delivered.clear();
    _cardIdsByDiary.clear();
  }
}
