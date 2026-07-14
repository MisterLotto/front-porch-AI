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

/// Live per-request progress parsed from the managed KoboldCpp process's own
/// console output — the ground truth the status bar was missing. Kobold
/// prints, for EVERY request it works on (ours or a queued background pass):
///
///   `Processing Prompt [BATCH] (512 / 2123 tokens)`  — once per batch
///   `Generating (14 / 512 tokens)`                   — once per token
///
/// (captured empirically from the bundled binary; the bracket tag varies by
/// build — [BATCH]/[BLAS]/absent — and updates arrive WITHOUT newlines, so
/// parsing runs per-chunk with a global regex, last match wins).
///
/// This is deliberately a tiny pure class so the >500-line KoboldService can
/// delegate with two lines and the parsing is unit-testable in isolation.
class KoboldLiveProgress {
  static final RegExp _processRe = RegExp(
    r'Processing Prompt(?:\s*\[[^\]]*\])?\s*\((\d+)\s*/\s*(\d+) tokens\)',
  );
  static final RegExp _generateRe = RegExp(
    r'Generating\s*\((\d+)\s*/\s*(\d+) tokens\)',
  );

  int promptCurrent = 0;
  int promptTotal = 0;
  int genCurrent = 0;
  int genTotal = 0;
  DateTime? updatedAt;

  /// Tail of the previous chunk, carried so a progress line split across two
  /// stream chunks ("…(512 / 21" + "23 tokens)") still matches.
  String _carry = '';

  /// Feed one raw console chunk. Returns true when anything changed (caller
  /// decides whether to notify — Generating lines arrive per token, so
  /// callers should throttle their notifications).
  bool ingest(String rawChunk, {DateTime? now}) {
    final chunk = _carry + rawChunk;
    var changed = false;
    var lastMatchEnd = 0;
    final p = _processRe.allMatches(chunk).lastOrNull;
    if (p != null) {
      // ANY prompt-progress line means a prompt pass is underway — the
      // previous request's decode is over, so its counts must never linger
      // (a same-size, cache-fast-forwarded prompt can open at "(N / N)",
      // which the old decreasing-cur heuristic missed; review finding).
      genCurrent = 0;
      genTotal = 0;
      promptCurrent = int.parse(p.group(1)!);
      promptTotal = int.parse(p.group(2)!);
      lastMatchEnd = p.end;
      changed = true;
    }
    final g = _generateRe.allMatches(chunk).lastOrNull;
    if (g != null) {
      // Decoding implies the prompt pass finished even if we missed its
      // final progress line.
      if (promptTotal > 0) promptCurrent = promptTotal;
      genCurrent = int.parse(g.group(1)!);
      genTotal = int.parse(g.group(2)!);
      if (g.end > lastMatchEnd) lastMatchEnd = g.end;
      changed = true;
    }
    // Carry only the UNMATCHED tail (capped) so a line split across chunks
    // still matches next time, but an already-consumed line can never
    // re-fire and zero live decode counts.
    final tailStart = lastMatchEnd > chunk.length - 64
        ? lastMatchEnd
        : chunk.length - 64;
    _carry = tailStart >= chunk.length
        ? ''
        : chunk.substring(tailStart < 0 ? 0 : tailStart);
    if (changed) updatedAt = now ?? DateTime.now();
    return changed;
  }

  /// 0..1 while a prompt pass is underway, 1.0 when it finished, null when
  /// no data (or stale beyond [freshness] — a request may have been aborted).
  ///
  /// The window is WIDE on purpose: Kobold prints one progress line per
  /// BATCH, so with --batchsize 8192 on slow hardware consecutive lines can
  /// be 30-60s apart — a short window would flicker the truthful display
  /// away mid-prefill. Abandoned data self-heals: the next request's first
  /// progress line resets the counts (see [ingest]'s new-request heuristic).
  double? promptFraction({Duration freshness = const Duration(seconds: 120)}) {
    final at = updatedAt;
    if (at == null || promptTotal <= 0) return null;
    if (DateTime.now().difference(at) > freshness) return null;
    return (promptCurrent / promptTotal).clamp(0.0, 1.0);
  }

  bool get isFresh =>
      updatedAt != null &&
      DateTime.now().difference(updatedAt!) < const Duration(seconds: 120);
}
