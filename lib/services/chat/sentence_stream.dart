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

// Sentence-boundary splitting for the live TTS sentence stream — extracted
// verbatim from the ChatService generation loop (god-file ratchet).

final RegExp _sentenceEndRe = RegExp(r'[.!?]\s|[.!?]$|\n');
final RegExp _clauseEndRe = RegExp(r',\s|;\s|\s[—–-]\s');

/// Emit every complete sentence (and, for long tails, clause chunk) in
/// [buffer] through [emit], returning the unfinished remainder.
///
/// Split strategy:
/// 1. Always split at sentence boundaries: . ! ? followed by space, or \n
/// 2. For long buffers (>80 chars / ~15 words), also split at clause
///    boundaries: ", " "; " " — " " - " to keep TTS chunks short (~1-3s)
String drainCompleteSentences(String buffer, void Function(String) emit) {
  bool emitted = true;
  while (emitted) {
    emitted = false;

    // First try sentence boundaries
    if (_sentenceEndRe.hasMatch(buffer)) {
      final match = _sentenceEndRe.firstMatch(buffer)!;
      final sentence = buffer.substring(0, match.end).trim();
      buffer = buffer.substring(match.end);
      if (sentence.isNotEmpty) {
        emit(sentence);
        emitted = true;
      }
      continue;
    }

    // For long buffers, split at clause boundaries to keep TTS fast
    if (buffer.length > 80) {
      if (_clauseEndRe.hasMatch(buffer)) {
        // Find the LAST clause boundary to maximize chunk size
        Match? lastMatch;
        for (final m in _clauseEndRe.allMatches(buffer)) {
          if (m.start > 30) lastMatch = m; // at least 30 chars per chunk
        }
        if (lastMatch != null) {
          final chunk = buffer.substring(0, lastMatch.end).trim();
          buffer = buffer.substring(lastMatch.end);
          if (chunk.isNotEmpty) {
            emit(chunk);
            emitted = true;
          }
        }
      }
    }
  }
  return buffer;
}
