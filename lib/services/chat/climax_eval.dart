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

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/services/chat/realism_tools.dart';

/// Climax detection — the one thing that starts Afterglow's refractory.
///
/// WHERE IT RUNS, AND WHY THAT IS NOT NEGOTIABLE. Post-generation, reading the
/// character's actual reply. It has to: the question is "did THIS reply narrate
/// the character's own release", and before generation that reply does not
/// exist. An earlier attempt at this fix moved the check onto the pre-generation
/// arousal eval, which reads the user's message — it would have judged a reply
/// that had not happened yet, lagged a turn behind, re-fired on the same climax
/// still sitting in recent history, and put the pre-gen judge in the business of
/// scoring the character's own words, which the settled rule forbids precisely
/// because a reroll would then reroll it.
///
/// WHY IT IS ITS OWN PASS. It used to ride the needs-impact eval, which opens
/// with `if (!getNeedsSimEnabled() || !getRealismEnabled()) return;`.
/// `CharacterCard.needsSimEnabled` defaults FALSE, so on most cards that eval
/// never ran, climax was never detected, and Afterglow did nothing at all —
/// while the Porch Life row showed its one declared dependency (the engine)
/// satisfied and the switch live. A feature riding another feature's pass
/// silently inherits that pass's gates; that is the same lesson the Pockets
/// ruling records (docs/design/pockets-and-preferences.md).
///
/// Now Afterglow answers to the Realism Engine and its own switch, full stop.
/// The cost of standing alone is one short call per turn while Afterglow is on
/// — stated plainly in the toggle copy, the way Pockets and Promises state
/// theirs.
class ClimaxEval {
  /// Supplied by ChatService: fires through the shared tools-first negotiation
  /// and hands back flat-JSON text, so this leaf owns no transport.
  final Future<String?> Function({
    required String debugLabel,
    required List<Map<String, dynamic>> tools,
    required String Function({required bool toolsMode}) buildPrompt,
  })
  fire;

  const ClimaxEval({required this.fire});

  /// The tool name and schema live in realism_tools.dart, because the
  /// converter's registry there is what makes the tools transport work at all
  /// — a tool it does not know about yields null and falls back to text
  /// silently, forever. Re-exposed here so callers read one name.
  static const kClimaxTool = kClimaxToolName;
  static List<Map<String, dynamic>> get tools => kClimaxEvalTools;

  /// The criteria matter more than the question. Without them the model —
  /// especially a reasoning model, which will not guess at an undefined field —
  /// almost never answers true, and the Lust bar stays pinned at the top
  /// forever. This text is the one that shipped with the original detector,
  /// kept verbatim because it was already tuned.
  /// [recentExchange] is the last few turns, formatted `sender: text` — the
  /// SAME context the needs-impact eval gave this question before Afterglow
  /// stood on its own, and dropping it was a real regression that CI caught.
  ///
  /// It matters because of who narrates a climax. In roleplay the user very
  /// often writes it — "the wave crests over us both" — and the character's own
  /// reply is a half-line of aftermath. Shown only that reply, the model
  /// answers false and the refractory never starts, which is the exact symptom
  /// this whole fix set out to remove. The verdict is still about the
  /// CHARACTER, and still judged on a reply that already exists; the exchange
  /// is context for reading it, not a second thing to score.
  static String buildPrompt({
    required String charName,
    required String reply,
    required String recentExchange,
    required bool toolsMode,
  }) =>
      'Read the scene below and answer one question about $charName.\n\n'
      'CLIMAX DETECTION — "is_climax": true ONLY when $charName THEMSELVES '
      'reaches sexual orgasm / release in THIS scene — i.e. the text explicitly '
      'narrates their own climax (coming, finishing, a shuddering or spasming '
      'release, crying out as they tip over the edge, gushing/ejaculating, '
      'going limp or boneless right after the peak). High arousal, being '
      '"close", edging, begging, grinding, foreplay, or ONLY the partner/user '
      'climaxing are NOT a climax for $charName — answer false in those cases.\n'
      'When (and only when) "is_climax" is true, also give "refractory_turns" '
      'as an int from 3 to 7 for how long the post-orgasm cooldown should last '
      '(~6-7 for an intense, drawn-out or repeated climax; ~3 for a quick one). '
      'When false, 0.\n\n'
      'The scene:\n$reply\n\n'
      '${recentExchange.trim().isEmpty ? '' : 'Recent exchange for context:\n$recentExchange\n\n'}'
      '${toolsMode ? 'Report by calling the $kClimaxTool tool. Use ONLY the tool — no plain-text reply.' : 'Respond with ONLY a flat JSON object containing "is_climax" and '
            '"refractory_turns". Do NOT use markdown code blocks — raw JSON only.'}';

  /// Forgiving on purpose (local-model floor): tools mode yields a real bool,
  /// text mode may quote it, and a missing refractory falls back to the middle
  /// of the range rather than dropping a climax that was actually reported.
  static int? parseRefractory(String? raw) {
    if (raw == null) return null;
    final m = RegExp(
      r'"is_climax"\s*:\s*"?(true|false)"?',
      caseSensitive: false,
    ).firstMatch(raw);
    if (m == null || m.group(1)!.toLowerCase() != 'true') return null;
    final t = RegExp(r'"refractory_turns"\s*:\s*"?(-?\d+)"?').firstMatch(raw);
    return (int.tryParse(t?.group(1) ?? '') ?? 5).clamp(1, 10);
  }

  /// Returns the refractory length when the character climaxed, else null.
  ///
  /// The caller decides whether to run at all (the engine, the Afterglow
  /// switch, a non-empty reply); this leaf consults no settings, so there is
  /// exactly one place the feature is gated.
  Future<int?> detect({
    required String charName,
    required String reply,
    String recentExchange = '',
  }) async {
    if (reply.trim().isEmpty) return null;
    try {
      return parseRefractory(
        await fire(
          debugLabel: 'climax',
          tools: tools,
          buildPrompt: ({required bool toolsMode}) => buildPrompt(
            charName: charName,
            reply: reply,
            recentExchange: recentExchange,
            toolsMode: toolsMode,
          ),
        ),
      );
    } catch (e) {
      // Never fail a turn over bookkeeping: the reply already happened and the
      // refractory simply does not start. Logged rather than swallowed.
      debugPrint('[Afterglow] climax check failed, no cooldown started: $e');
      return null;
    }
  }
}
