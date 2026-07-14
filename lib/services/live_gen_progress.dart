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

/// Live per-request progress for the truthful status bar — the SHARED struct
/// every backend source writes into and both UIs (desktop status bar, web
/// gen_status events) read from:
///
///  * managed KoboldCpp — console lines parsed via [ingest]
///  * oMLX — `/admin/api/stats` poll writes via [setPromptProgress] /
///    [setGenProgress] (omlx_status_poller.dart)
///  * LM Studio — `lms log stream --source runtime` lines via
///    [ingestLmStudioRuntimeLine] (lmstudio_log_streamer.dart)
///
/// All sources report prompt progress only once per BATCH, so consumers use
/// [estimatedPromptFraction] to interpolate between real anchors.
class LiveGenProgress {
  static final RegExp _processRe = RegExp(
    r'Processing Prompt(?:\s*\[[^\]]*\])?\s*\((\d+)\s*/\s*(\d+) tokens\)',
  );
  static final RegExp _generateRe = RegExp(
    r'Generating\s*\((\d+)\s*/\s*(\d+) tokens\)',
  );

  /// LM Studio runtime log: `... prompt processing progress, n_tokens = 512,
  /// batch.n_tokens = 512, progress = 0.168754` (cumulative tokens + exact
  /// fraction; captured empirically 2026-07-14).
  static final RegExp _lmsProgressRe = RegExp(
    r'prompt processing progress, n_tokens = (\d+),.*?progress = ([0-9.]+)',
  );

  int promptCurrent = 0;
  int promptTotal = 0;
  int genCurrent = 0;
  int genTotal = 0;
  DateTime? updatedAt;

  /// How many requests the source reports queued (oMLX `waiting[]`). The
  /// source cannot tell WHOSE they are (ours vs someone waiting on us), so
  /// consumers must state the fact neutrally ("1 request queued") — never
  /// attribute the wait (review finding: attribution here was invertible).
  int waitingCount = 0;

  /// Zero everything — called when a source stops so a backend switch (or
  /// return within the freshness window) can't show a prior request's
  /// counts.
  void reset() {
    promptCurrent = 0;
    promptTotal = 0;
    genCurrent = 0;
    genTotal = 0;
    updatedAt = null;
    waitingCount = 0;
    hintTokensPerSecond = null;
    _carry = '';
  }

  /// Prefill speed hint from the SOURCE (oMLX's avg_prefill_tps), used by
  /// consumers when no Kobold perf poll is available.
  double? hintTokensPerSecond;

  /// Tail of the previous chunk, carried so a progress line split across two
  /// stream chunks ("…(512 / 21" + "23 tokens)") still matches.
  String _carry = '';

  /// Direct write for polled sources (oMLX). Any prompt write invalidates
  /// stale decode counts from a previous request when the pass is new.
  void setPromptProgress(int current, int total, {DateTime? now}) {
    if (total <= 0) return;
    if (current < promptCurrent || total != promptTotal) {
      genCurrent = 0;
      genTotal = 0;
    }
    promptCurrent = current.clamp(0, total);
    promptTotal = total;
    updatedAt = now ?? DateTime.now();
  }

  void setGenProgress(int current, int total, {DateTime? now}) {
    if (promptTotal > 0) promptCurrent = promptTotal;
    genCurrent = current;
    genTotal = total;
    updatedAt = now ?? DateTime.now();
  }

  /// Feed one raw KoboldCpp console chunk. Returns true when anything
  /// changed (Generating lines arrive per token — callers throttle their
  /// notifications).
  bool ingest(String rawChunk, {DateTime? now}) {
    final chunk = _carry + rawChunk;
    var changed = false;
    var lastMatchEnd = 0;
    final p = _processRe.allMatches(chunk).lastOrNull;
    if (p != null) {
      // ANY prompt-progress line means a prompt pass is underway — the
      // previous request's decode is over, so its counts must never linger
      // (a same-size, cache-fast-forwarded prompt can open at "(N / N)").
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

  /// Feed one LM Studio runtime-log line. Returns true when it carried
  /// prompt progress.
  bool ingestLmStudioRuntimeLine(String line, {DateTime? now}) {
    final m = _lmsProgressRe.firstMatch(line);
    if (m == null) return false;
    final tokens = int.parse(m.group(1)!);
    final fraction = double.tryParse(m.group(2)!) ?? 0;
    if (fraction <= 0) return false;
    final total = (tokens / fraction).round();
    setPromptProgress(tokens, total, now: now);
    return true;
  }

  /// 0..1 while a prompt pass is underway, 1.0 when it finished, null when
  /// no data (or stale beyond [freshness] — a request may have been aborted).
  ///
  /// The window is WIDE on purpose: sources report once per BATCH, so with
  /// --batchsize 8192 on slow hardware consecutive updates can be 30-60s
  /// apart — a short window would flicker the truthful display away
  /// mid-prefill. Abandoned data self-heals: the next request's first
  /// progress write resets the counts.
  double? promptFraction({Duration freshness = const Duration(seconds: 120)}) {
    final at = updatedAt;
    if (at == null || promptTotal <= 0) return null;
    if (DateTime.now().difference(at) > freshness) return null;
    return (promptCurrent / promptTotal).clamp(0.0, 1.0);
  }

  bool get isFresh =>
      updatedAt != null &&
      DateTime.now().difference(updatedAt!) < const Duration(seconds: 120);

  /// Smooth, honest estimate of prompt progress BETWEEN batch updates: the
  /// last REAL count advances at the measured prefill speed, capped below
  /// the next unconfirmed token so the bar never claims completion the
  /// source hasn't reported. Returns 1.0 only when a source really said so.
  double? estimatedPromptFraction({
    double? tokensPerSecond,
    DateTime? now,
  }) {
    final raw = promptFraction();
    if (raw == null) return null;
    if (raw >= 1.0) return 1.0;
    final tps = tokensPerSecond ?? hintTokensPerSecond;
    if (tps == null || tps <= 0 || updatedAt == null) {
      return raw;
    }
    final dt =
        (now ?? DateTime.now()).difference(updatedAt!).inMilliseconds / 1000.0;
    final est = promptCurrent + tps * dt;
    final capped = est.clamp(0, promptTotal - 1).toDouble();
    return (capped / promptTotal).clamp(0.0, 0.99);
  }
}
