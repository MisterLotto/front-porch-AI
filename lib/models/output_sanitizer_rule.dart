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

/// A single find/replace rule for the output sanitizer.
///
/// Applied to model output text before it enters chat history,
/// allowing procedural normalisation of character sequences
/// (e.g. em dash → " - ", smart quotes → straight quotes).
///
/// When [stopAfterMatch] is true, no subsequent rules are applied after
/// this rule **changed the text** (a match replaced by identical text does
/// not stop the chain — deliberate; see the toggle test).
class OutputSanitizerRule {
  final int id;
  final String find;
  final String replace;
  final bool stopAfterMatch;

  const OutputSanitizerRule({
    required this.id,
    required this.find,
    required this.replace,
    this.stopAfterMatch = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'find': find,
        'replace': replace,
        if (stopAfterMatch) 'stop_after_match': true,
      };

  factory OutputSanitizerRule.fromJson(Map<String, dynamic> json) =>
      OutputSanitizerRule(
        id: json['id'] as int? ?? 0,
        find: json['find'] as String? ?? '',
        replace: json['replace'] as String? ?? '',
        stopAfterMatch: json['stop_after_match'] as bool? ?? false,
      );

  /// Parses a JSON list of rules, healing legacy ids: rules saved before the
  /// [id] field existed all parse to id 0, and duplicate ids break the rule
  /// editor's identity-keyed ReorderableListView. On any collision the whole
  /// list is renumbered sequentially — order is preserved (it's load-bearing:
  /// rules run top to bottom and stopAfterMatch halts the chain).
  static List<OutputSanitizerRule> listFromJson(List<dynamic> json) {
    final rules = [
      for (final e in json)
        OutputSanitizerRule.fromJson(e as Map<String, dynamic>),
    ];
    if (rules.map((r) => r.id).toSet().length == rules.length) return rules;
    return [
      for (var i = 0; i < rules.length; i++)
        OutputSanitizerRule(
          id: i,
          find: rules[i].find,
          replace: rules[i].replace,
          stopAfterMatch: rules[i].stopAfterMatch,
        ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutputSanitizerRule &&
          runtimeType == other.runtimeType &&
          find == other.find &&
          replace == other.replace &&
          stopAfterMatch == other.stopAfterMatch;

  @override
  int get hashCode => find.hashCode ^ replace.hashCode ^ stopAfterMatch.hashCode;
}
