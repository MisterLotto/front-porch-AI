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

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/services/chat/pockets.dart';

/// The Pockets detection pass — ONE short post-generation call that asks a
/// single question: what did this reply change about what the character is
/// wearing and carrying?
///
/// WHY ITS OWN EVAL, and do not re-open this (settled ruling, 2026-08-07;
/// docs/design/pockets-and-preferences.md). An earlier plan had Pockets ride
/// the post-generation needs-impact eval as one extra JSON field, advertised as
/// "zero new LLM calls". That was retracted for a reason of principle and a
/// technical fact, and the fact alone is decisive:
/// `NeedsImpactEvaluator.evaluateAndApply` opens with
/// `if (!getNeedsSimEnabled() || !getRealismEnabled())`, and realismEnabled
/// DEFAULTS FALSE. Riding it would have meant an inventory feature that does
/// nothing until you switch on a bond/trust engine it has no relationship with.
/// "Zero new calls" was only ever true for users who had already opted into
/// both.
///
/// The principle: interleaving one feature's data into another feature's pass
/// is what produced the mess docs/design/feature-independence.md took a day to
/// untangle. Pockets stands alone or it repeats that.
///
/// It reuses INFRASTRUCTURE, which is the correct kind of sharing — the same
/// tools-first negotiation (`fireStructuredEval` + `ToolTransportProbe`) that
/// the realism evals, the Journal pass and Growth all use, so a tool-less
/// backend falls back to the forgiving flat-JSON floor exactly as they do.
class PocketsEval {
  /// Fires the eval and returns the raw text (tools converted to flat JSON, or
  /// the model's own text). Supplied by ChatService so this leaf owns no
  /// transport of its own.
  final Future<String?> Function({
    required String debugLabel,
    required List<Map<String, dynamic>> tools,
    required String Function({required bool toolsMode}) buildPrompt,
  })
  fire;

  const PocketsEval({required this.fire});

  /// The tool schema. One array of ops, nothing else — the narrower the ask,
  /// the better a small local model answers it.
  static List<Map<String, dynamic>> get tools => [
    {
      'type': 'function',
      'function': {
        'name': kPocketsTool,
        'description':
            'Report changes to what the character is wearing or carrying.',
        'parameters': {
          'type': 'object',
          'properties': {
            'inventory_ops': {
              'type': 'array',
              'description':
                  'Every change this reply made. Empty when nothing changed.',
              'items': {
                'type': 'object',
                'properties': {
                  'op': {
                    'type': 'string',
                    'enum': [
                      for (final k in PocketOpKind.values) k.name,
                    ],
                  },
                  'item': {'type': 'string'},
                  'to': {
                    'type': 'string',
                    'description': 'Who received it (give only).',
                  },
                  'state': {
                    'type': 'string',
                    'description':
                        'New condition (update), or what it became (transform).',
                  },
                },
                'required': ['op', 'item'],
              },
            },
          },
          'required': ['inventory_ops'],
        },
      },
    },
  ];

  static const kPocketsTool = 'report_inventory';

  /// The prompt. Deliberately short: this call runs every turn the feature is
  /// on, so it carries the current record and the reply and nothing else — no
  /// dossier, no relationship standing, none of the context the realism judges
  /// need. It is a bookkeeping question, not a judgement.
  /// [others] is the rest of the cast, by name, when hand-offs are on. Empty
  /// otherwise — and then the model is never invited to name a recipient at
  /// all, because a `to` nobody can resolve is a `to` that does nothing.
  /// [recentExchange] is the last few turns. REQUIRED, and the reason is a
  /// bug that shipped twice: an eval given only the character's reply cannot
  /// see a change the USER narrated. "You step out into the downpour" followed
  /// by a half-line of dialogue leaves the red sundress recorded bone-dry
  /// forever, because nothing in the text the eval was shown says otherwise.
  /// Afterglow's climax check had the identical hole and went red on three
  /// platforms for it.
  static String buildPrompt({
    required String charName,
    required Pockets current,
    required String reply,
    required String recentExchange,
    required bool toolsMode,
    List<String> others = const [],
  }) {
    String list(String label, List<PocketItem> items) => items.isEmpty
        ? '$label: (nothing recorded)\n'
        : '$label: ${items.map((i) => i.display).join(', ')}\n';

    return 'You are keeping track of what $charName is wearing and carrying.\n\n'
        '${list('Currently wearing', current.worn)}'
        '${list('Currently carrying', current.carrying)}'
        '\nWhat changed in the reply below? Report ONLY changes that actually '
        'happened in it — not things they merely mentioned, remembered, wanted, '
        'or were offered. If nothing changed, report an empty list; that is the '
        'common answer and it is the right one.\n\n'
        'Each change is one op:\n'
        '  wear / remove — clothing put on or taken off\n'
        '  pickup / drop — something taken up or set down, lost or thrown away\n'
        '${others.isEmpty ? '  give — handed to someone else\n' : '  give — handed to someone else. Put their name in "to", spelled EXACTLY '
              'as it appears here: ${others.join(', ')}. If it went to anyone '
              'else — the person you are talking to, a passer-by, nobody in '
              'particular — leave "to" empty rather than guessing a name from '
              'that list.\n'}'
        '  update — the same item, new condition. Weather, wear and damage '
        'all count, not just food: ("state": "half-eaten"), a dress caught in '
        'the rain ("state": "rain-soaked"), armour after a fight '
        '("state": "dented"), boots after a road ("state": "mud-caked")\n'
        '  transform — the item BECAME something else ("item": "candy bar", '
        '"state": "sweet wrapper")\n\n'
        'Name items the way they are already listed above when they appear '
        'there, so the same thing is not recorded twice.\n\n'
        'The reply:\n$reply\n\n'
        '${recentExchange.trim().isEmpty ? '' : 'Recent exchange for context:\n$recentExchange\n\n'}'
        '${toolsMode ? 'Report by calling the $kPocketsTool tool. Use ONLY the tool — no plain-text reply.' : 'Respond with ONLY a flat JSON object containing "inventory_ops" (an array). '
              'Do NOT use markdown code blocks — return raw JSON only.'}';
  }

  /// Pull the ops out of whatever came back. Forgiving by design: a local model
  /// may wrap the array, prose around it, or hand back a bare list. Anything
  /// unreadable yields no ops rather than an exception — a bookkeeping pass
  /// must never be able to fail a turn.
  static List<PocketOpReport> parseOps(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    Object? decoded;
    // Take the OUTERMOST JSON value, object or array — decided by whichever
    // bracket appears first, not by a fixed preference.
    //
    // Trying `{...}` first looks harmless and is not: given the bare array
    // `[{"op":"drop","item":"x"}]` that a smaller model hands back, the object
    // pattern happily matches the INNER object, decodes a Map with no
    // `inventory_ops` key, and reports that nothing changed. Silently. Caught
    // by the bare-array test below.
    final firstBrace = raw.indexOf('{');
    final firstBracket = raw.indexOf('[');
    final objectFirst =
        firstBrace != -1 && (firstBracket == -1 || firstBrace < firstBracket);
    for (final pattern in objectFirst
        ? [r'\{[\s\S]*\}', r'\[[\s\S]*\]']
        : [r'\[[\s\S]*\]', r'\{[\s\S]*\}']) {
      final m = RegExp(pattern).firstMatch(raw);
      if (m == null) continue;
      try {
        decoded = jsonDecode(m.group(0)!);
        break;
      } catch (_) {
        // Keep trying the other shape rather than giving up on the turn.
      }
    }
    if (decoded == null) return const [];
    final list = decoded is Map ? decoded['inventory_ops'] : decoded;
    return [
      for (final e in list is List ? list : const [])
        ?PocketOpReport.fromJson(e),
    ];
  }

  /// Run the pass and apply what it found, in place. Returns the receipt lines
  /// for the message chips — empty when nothing changed, which is most turns.
  ///
  /// The caller decides whether to run at all (the switch, a non-empty reply);
  /// this leaf does not consult settings, so there is exactly one place the
  /// feature is gated.
  Future<List<String>> evaluateAndApply({
    required String charName,
    required Pockets pockets,
    required String reply,
    required String recentExchange,
    List<String> others = const [],
    void Function(String to, PocketItem item)? onTransfer,
  }) async {
    if (reply.trim().isEmpty) return const [];
    try {
      final raw = await fire(
        debugLabel: 'pockets',
        tools: tools,
        buildPrompt: ({required bool toolsMode}) => buildPrompt(
          charName: charName,
          current: pockets,
          reply: reply,
          recentExchange: recentExchange,
          toolsMode: toolsMode,
          others: others,
        ),
      );
      final ops = parseOps(raw);
      if (ops.isEmpty) return const [];
      return applyPocketOps(pockets, ops, onTransfer: onTransfer);
    } catch (e) {
      // Never surface as a failed turn: the reply already happened and the
      // record simply misses one update. Logged rather than swallowed silently.
      debugPrint('[Pockets] eval failed, record unchanged: $e');
      return const [];
    }
  }
}
