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

/// The Journal — XML transport parsing (docs/design/journal-memory.md §4.3).
///
/// Pure functions + value type, no dependencies: the maintenance pass hands
/// the raw (already think-stripped) LLM text to [parseJournalOps] /
/// [parseRecap] and applies the returned operations through one shared
/// applier. The phase-4 tool-calling transport will produce the same
/// [JournalOp] list — one applier, two front doors.
///
/// Forgiving by design (local-model floor): regex-based, tolerates missing
/// or single quotes, unknown attributes, interleaved prose, self-closing
/// tags, and an unclosed final `<recap>`. A garbage response yields zero
/// ops — never an exception (same philosophy as the realism regex
/// extractors in llm_eval_engine.dart).
library;

enum JournalOpAction { add, revise, retire, pin }

/// One memory operation emitted by the maintenance pass.
class JournalOp {
  final JournalOpAction action;

  /// 1-based card handle from the "current entries" list shown in the prompt
  /// (revise/retire/pin). Never a DB id — small models can't echo UUIDs.
  final int? handle;

  /// Normalized category for `add` (about_user / about_us / moment / promise).
  final String category;

  /// Absolute message positions cited via `msgs="12,14"` (provenance and the
  /// deterministic emotion-stamp source; the model is never asked for the
  /// feeling of a new memory).
  final List<int> sourcePositions;

  /// Optional revised feeling on `revise` (the "feelings that heal" hook).
  final String? feeling;

  /// Memory text (add/revise). Empty for retire/pin.
  final String text;

  const JournalOp({
    required this.action,
    this.handle,
    this.category = 'moment',
    this.sourcePositions = const [],
    this.feeling,
    this.text = '',
  });
}

const List<String> kJournalCategories = [
  'about_user',
  'about_us',
  'moment',
  'promise',
];

/// Max stored length of a single memory (keeps cards atomic and the hot-set
/// prompt block small even when a rambly model over-writes).
const int kJournalMemoryMaxChars = 300;

final RegExp _memoryTag = RegExp(
  r'<memory\b([^>]*?)(?:/>|>([\s\S]*?)</memory>)',
  caseSensitive: false,
);
// Quoted (double or single) or bare values; a bare value stops at whitespace
// so `action=delete id=2` parses as two attributes, not one.
final RegExp _attr = RegExp(
  '''(\\w+)\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s"'/>]+))''',
);
final RegExp _recapTag = RegExp(
  r'<recap>\s*([\s\S]*?)\s*</recap>',
  caseSensitive: false,
);
final RegExp _recapOpen = RegExp(r'<recap>\s*([\s\S]*)$', caseSensitive: false);

/// Parse every `<memory .../>` tag into a validated op list. Invalid ops
/// (unknown action, missing handle, empty add/revise text) are dropped.
List<JournalOp> parseJournalOps(String raw) {
  final ops = <JournalOp>[];
  for (final match in _memoryTag.allMatches(raw)) {
    final attrs = <String, String>{};
    for (final a in _attr.allMatches(match.group(1) ?? '')) {
      final value = a.group(2) ?? a.group(3) ?? a.group(4) ?? '';
      attrs[a.group(1)!.toLowerCase()] = value.trim();
    }
    final action = _normalizeAction(attrs['action']);
    if (action == null) continue;

    final handle = int.tryParse(attrs['id'] ?? '');
    var text = (match.group(2) ?? '').trim();
    if (text.length > kJournalMemoryMaxChars) {
      text = text.substring(0, kJournalMemoryMaxChars).trim();
    }

    switch (action) {
      case JournalOpAction.add:
        if (text.isEmpty) continue;
        ops.add(
          JournalOp(
            action: action,
            category: _normalizeCategory(attrs['category']),
            sourcePositions: _parsePositions(attrs['msgs']),
            text: text,
          ),
        );
        break;
      case JournalOpAction.revise:
        if (handle == null || text.isEmpty) continue;
        final feeling = (attrs['feeling'] ?? '').trim().toLowerCase();
        ops.add(
          JournalOp(
            action: action,
            handle: handle,
            feeling: feeling.isEmpty ? null : feeling,
            text: text,
          ),
        );
        break;
      case JournalOpAction.retire:
      case JournalOpAction.pin:
        if (handle == null) continue;
        ops.add(JournalOp(action: action, handle: handle));
        break;
    }
  }
  return ops;
}

/// Extract the `<recap>` paragraph — paired tag first, then the unclosed-tag
/// fallback (mirrors the unclosed-`<think>` trick). Any stray tags inside are
/// stripped so plain prose is guaranteed (EvolutionService and the prompt
/// summaryBlock consume this text directly).
String? parseRecap(String raw) {
  var text = _recapTag.firstMatch(raw)?.group(1);
  text ??= _recapOpen.firstMatch(raw)?.group(1);
  if (text == null) return null;
  text = text.replaceAll(_memoryTag, '').replaceAll(RegExp(r'<[^>]*>'), '');
  text = text.trim();
  return text.isEmpty ? null : text;
}

JournalOpAction? _normalizeAction(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'add':
    case 'new':
    case 'create':
      return JournalOpAction.add;
    case 'revise':
    case 'update':
    case 'edit':
      return JournalOpAction.revise;
    case 'retire':
    case 'delete':
    case 'remove':
      return JournalOpAction.retire;
    case 'pin':
      return JournalOpAction.pin;
    default:
      return null;
  }
}

String _normalizeCategory(String? raw) {
  final c = (raw ?? '').trim().toLowerCase().replaceAll('-', '_');
  if (kJournalCategories.contains(c)) return c;
  switch (c) {
    case 'user':
    case 'about_him':
    case 'about_her':
    case 'about_them':
      return 'about_user';
    case 'us':
    case 'relationship':
      return 'about_us';
    case 'promises':
      return 'promise';
    default:
      return 'moment';
  }
}

List<int> _parsePositions(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'[,\s#]+'))
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toList();
}
