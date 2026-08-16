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

/// Per-turn tally of SECONDARY LLM traffic — the evals and passes, never the
/// main generation. Debug instrumentation only: nothing reads it back; its
/// one output is the `[EvalTraffic]` line printed at the end of each turn's
/// post-generation phase (and a `background` line at the start of the next
/// user turn for whatever the fire-and-forget passes spent in between).
///
/// WHY IT EXISTS (eval review §8 — "instrument first"): the state-zone
/// placement won its argument with a measured number (508 vs 5,020
/// re-prefilled tokens). The eval-side optimizations — the reply-facts
/// fusion, the shared judge prefix, the quest-check gate, one-shot Auto —
/// shipped as reasoning about call counts; this line is what lets a real
/// setup SEE those counts move, and what makes a regression ("why are there
/// nine calls again?") visible in the console instead of only in the bill.
///
/// One static instance, on purpose: the recorders are transport chokepoints
/// (LlmEvalEngine.fireLLMEval, the tools door, the two raw objective
/// streams) that live behind layers of granular callbacks, and threading a
/// tally through every ctor for a debug counter would be ceremony. The cost
/// of the global: parallel ChatServices (tests) share it — harmless, since
/// nothing consumes the records but a print.
///
/// Char counts, not tokens: real tokenization per eval would cost a call.
/// The printed token figure is chars ÷ 4, labelled as the estimate it is —
/// the same approximation the remote-path budgeter uses.
///
/// Deliberately NOT recorded: the main generation (LiveGenProgress already
/// covers it), the vision caption, and calls aborted before any HTTP left
/// (backend not ready, cancelled before streaming).
class EvalTraffic {
  static final EvalTraffic current = EvalTraffic();

  final List<
    ({String label, String lane, int promptChars, int outputChars, int ms})
  >
  _records = [];

  void record({
    required String label,
    required String lane,
    required int promptChars,
    required int outputChars,
    required int ms,
  }) {
    _records.add((
      label: label,
      lane: lane,
      promptChars: promptChars,
      outputChars: outputChars,
      ms: ms,
    ));
  }

  /// The turn's summary — call at the end of the post-generation phase.
  /// Clears what it reports, so in a group every speaker's print covers that
  /// speaker's slice. Null when nothing was recorded (engine off).
  String? flushTurn() => _flush('');

  /// Whatever the fire-and-forget passes (journal, growth, promises, cast…)
  /// recorded after the last turn's print — call at the start of a user
  /// turn. Null when the background was quiet.
  String? flushBackground() => _flush('background ');

  String? _flush(String tag) {
    if (_records.isEmpty) return null;
    final calls = _records.length;
    final prompt = _records.fold(0, (a, r) => a + r.promptChars);
    final out = _records.fold(0, (a, r) => a + r.outputChars);
    final ms = _records.fold(0, (a, r) => a + r.ms);
    String k(int chars) => chars >= 1000
        ? '${(chars / 1000).toStringAsFixed(1)}k'
        : '$chars';
    final detail = _records
        .map(
          (r) =>
              '${r.label}(${r.lane}) ${k(r.promptChars)}→${k(r.outputChars)} '
              '${(r.ms / 1000).toStringAsFixed(2)}s',
        )
        .join(' · ');
    _records.clear();
    return '[EvalTraffic] $tag$calls call${calls == 1 ? '' : 's'} · '
        '${k(prompt)} prompt chars (≈${k(prompt ~/ 4)} tok) · '
        '${k(out)} out · ${(ms / 1000).toStringAsFixed(2)}s LLM time | '
        '$detail';
  }
}
