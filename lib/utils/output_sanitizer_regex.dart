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

import 'package:front_porch_ai/models/output_sanitizer_rule.dart';

/// Limited regex support for the Output Sanitizer find field.
///
/// Masks (prefixed with `\`):
///   `\a` – any printable character
///   `\w` – any alphanumeric (letter or digit)
///   `\d` – any decimal digit
///   `\l` – any letter (both registers)
///   `\p` – any punctuation, symbol, or space
///   `\\` – literal backslash
///
/// Capture groups:
///   `\(...\)` – creates a regex capture group; the content between `\(` and
///   the matching `)` is passed through as raw regex.  Quantifiers after the
///   closing `)` apply to the whole group (e.g. `\(\d+\)+`).
///
/// Quantifiers (appended after mask or capture group):
///   (none) – exactly one
///   `?`    – zero or one
///   `+`    – one or more
///   `{n}`  – exactly n
///   `{n,m}` – between n and m (inclusive)
///   `{n,}`  – n or more
///
/// Replace field: `\1`, `\2`, etc. are backreferences to capture groups.
/// `\\` is a literal backslash, `$$` is a literal dollar sign.
const _maskRegex = <String, String>{
  'a': r'[^\x00-\x1F\x7F-\x9F]', // any printable
  'w': r'[a-zA-Z0-9]', // alphanumeric
  'd': r'[0-9]', // digit
  'l': r'[a-zA-Z]', // letter
  'p': r'[^a-zA-Z0-9\x00-\x1F\x7F-\x9F]', // punctuation / symbol / space
};

/// Characters that need escaping when treated as literal regex.
const _regexMetaChars = r'.()+*?[]{}^$|';

bool _needsEscape(String ch) =>
    _regexMetaChars.contains(ch) || ch == r'\';

/// Converts the limited `\X` mask syntax into a standard regex pattern.
///
/// Throws [FormatException] if the input contains an unknown escape or
/// malformed quantifier.
String compileFindPattern(String input) {
  final out = StringBuffer();
  var i = 0;
  while (i < input.length) {
    final ch = input[i];
    if (ch == r'\') {
      if (i + 1 >= input.length) {
        throw const FormatException('Trailing backslash');
      }
      final next = input[i + 1];
      if (next == r'\') {
        // literal backslash
        out.write(r'\\');
        i += 2;
      } else if (next == '(') {
        // Capture group: raw regex until matching ).
        // Count nesting to handle inner groups; skip escaped chars.
        var depth = 1;
        var j = i + 2;
        while (j < input.length && depth > 0) {
          if (input[j] == r'\') {
            j += 2; // skip escaped character
          } else if (input[j] == '(') {
            depth++;
            j++;
          } else if (input[j] == ')') {
            depth--;
            if (depth > 0) j++;
          } else {
            j++;
          }
        }
        if (depth != 0) {
          throw const FormatException('Unclosed capture group \\(');
        }
        out.write('(');
        out.write(input.substring(i + 2, j));
        out.write(')');
        i = j + 1;
        // consume optional quantifier
        i = _consumeQuantifier(input, i, out);
      } else {
        final regex = _maskRegex[next];
        if (regex == null) {
          throw FormatException('Unknown mask: \\$next');
        }
        out.write(regex);
        i += 2;
        // consume optional quantifier
        i = _consumeQuantifier(input, i, out);
      }
    } else {
      // literal character — escape for regex
      if (_needsEscape(ch)) {
        out.write(r'\');
      }
      out.write(ch);
      i++;
    }
  }
  return out.toString();
}

/// Tries to consume a quantifier starting at [pos].
/// Returns the new position after the quantifier (or [pos] if none).
int _consumeQuantifier(String input, int pos, StringBuffer out) {
  if (pos >= input.length) return pos;
  final ch = input[pos];
  if (ch == '?' || ch == '+') {
    out.write(ch);
    return pos + 1;
  }
  if (ch == '{') {
    final close = input.indexOf('}', pos);
    if (close == -1) {
      throw const FormatException('Unclosed quantifier {');
    }
    final inner = input.substring(pos + 1, close);
    // validate: digits, or digits,digits, or digits,
    if (!_isValidQuantifier(inner)) {
      throw FormatException('Invalid quantifier: {$inner}');
    }
    out.write(input.substring(pos, close + 1));
    return close + 1;
  }
  return pos;
}

bool _isValidQuantifier(String inner) {
  if (inner.isEmpty) return false;
  final parts = inner.split(',');
  if (parts.length > 2) return false;
  for (final p in parts) {
    if (p.isEmpty) continue; // allows trailing comma for {n,}
    if (!RegExp(r'^\d+$').hasMatch(p)) return false;
  }
  return true;
}

/// Translates the replace-field backreferences (`\1`, `\2`, …) into Dart
/// [RegExp] replacement syntax (`$1`, `$2`, …).
///
/// Escapes:
///   `\\` → literal `\`
///   `$$` → literal `$` (processed first to avoid conflict with backrefs)
String compileReplacePattern(String input) {
  // 1. Replace $$ with a placeholder to protect literal dollar signs
  const placeholder = '\x00DOLLAR\x00';
  var result = input.replaceAll(r'$$', placeholder);
  // 2. Replace \N with $N
  result = result.replaceAllMapped(
    RegExp(r'\\(\d+)'),
    (m) => '\$${m[1]}',
  );
  // 3. Replace \\ with literal \
  result = result.replaceAll(r'\\', r'\');
  // 4. Restore literal dollar signs
  result = result.replaceAll(placeholder, r'$');
  return result;
}

/// Returns `true` if [input] compiles as a valid find pattern.
bool isValidFindPattern(String input) {
  try {
    compileFindPattern(input);
    return true;
  } on FormatException {
    return false;
  }
}

/// Compiles a find/replace rule pair into a [RegExp] and its translated
/// replacement string.  Returns `null` if the find pattern is invalid.
///
/// The returned regex is case-insensitive by default.
({RegExp regex, String replacement})? tryCompileRule(
  String find,
  String replace,
) {
  try {
    final pattern = compileFindPattern(find);
    final compiledReplace = compileReplacePattern(replace);
    return (
      regex: RegExp(pattern, caseSensitive: false),
      replacement: compiledReplace,
    );
  } on FormatException {
    return null;
  }
}

/// Applies output sanitizer rules to [text] using the limited regex syntax.
///
/// Each rule's find pattern is compiled to a case-insensitive [RegExp].
/// Invalid rules are silently skipped (defensive — the UI should prevent
/// them from being saved).
///
/// When a rule has [OutputSanitizerRule.stopAfterMatch] set, no subsequent
/// rules are applied after this rule matches at least once in the text.
String sanitizeOutput(
  String text,
  List<OutputSanitizerRule> rules,
) {
  var result = text;
  for (final rule in rules) {
    if (rule.find.isEmpty) continue;
    final compiled = tryCompileRule(rule.find, rule.replace);
    if (compiled == null) continue;
    final before = result;
    result = result.replaceAllMapped(compiled.regex, (m) {
      var out = compiled.replacement;
      for (var i = 1; i <= m.groupCount; i++) {
        out = out.replaceAll('\$$i', m.group(i) ?? '');
      }
      return out;
    });
    if (rule.stopAfterMatch && result != before) break;
  }
  return result;
}
