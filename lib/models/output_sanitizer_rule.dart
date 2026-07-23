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
class OutputSanitizerRule {
  final String find;
  final String replace;

  const OutputSanitizerRule({required this.find, required this.replace});

  Map<String, dynamic> toJson() => {'find': find, 'replace': replace};

  factory OutputSanitizerRule.fromJson(Map<String, dynamic> json) =>
      OutputSanitizerRule(
        find: json['find'] as String? ?? '',
        replace: json['replace'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutputSanitizerRule &&
          runtimeType == other.runtimeType &&
          find == other.find &&
          replace == other.replace;

  @override
  int get hashCode => find.hashCode ^ replace.hashCode;
}
