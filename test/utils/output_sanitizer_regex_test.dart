// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Unit tests for the limited regex compiler used by the Output Sanitizer
// find/replace fields. Covers mask expansion, quantifier parsing,
// backreference translation, and end-to-end sanitization.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/output_sanitizer_rule.dart';
import 'package:front_porch_ai/utils/output_sanitizer_regex.dart';

void main() {
  group('compileFindPattern()', () {
    group('masks', () {
      test('\\a matches any printable character', () {
        final pattern = compileFindPattern(r'\a');
        expect(RegExp(pattern).hasMatch('A'), isTrue);
        expect(RegExp(pattern).hasMatch('3'), isTrue);
        expect(RegExp(pattern).hasMatch(' '), isTrue);
        expect(RegExp(pattern).hasMatch('!'), isTrue);
        expect(RegExp(pattern).hasMatch('\x00'), isFalse); // null byte
        expect(RegExp(pattern).hasMatch('\x7f'), isFalse); // DEL
      });

      test('\\w matches alphanumeric', () {
        final pattern = compileFindPattern(r'\w');
        expect(RegExp(pattern).hasMatch('a'), isTrue);
        expect(RegExp(pattern).hasMatch('Z'), isTrue);
        expect(RegExp(pattern).hasMatch('7'), isTrue);
        expect(RegExp(pattern).hasMatch(' '), isFalse);
        expect(RegExp(pattern).hasMatch('!'), isFalse);
      });

      test('\\d matches digits', () {
        final pattern = compileFindPattern(r'\d');
        expect(RegExp(pattern).hasMatch('0'), isTrue);
        expect(RegExp(pattern).hasMatch('9'), isTrue);
        expect(RegExp(pattern).hasMatch('a'), isFalse);
      });

      test('\\l matches letters', () {
        final pattern = compileFindPattern(r'\l');
        expect(RegExp(pattern).hasMatch('a'), isTrue);
        expect(RegExp(pattern).hasMatch('Z'), isTrue);
        expect(RegExp(pattern).hasMatch('5'), isFalse);
        expect(RegExp(pattern).hasMatch(' '), isFalse);
      });

      test('\\p matches punctuation, symbols, space', () {
        final pattern = compileFindPattern(r'\p');
        expect(RegExp(pattern).hasMatch(' '), isTrue);
        expect(RegExp(pattern).hasMatch('!'), isTrue);
        expect(RegExp(pattern).hasMatch('.'), isTrue);
        expect(RegExp(pattern).hasMatch('@'), isTrue);
        expect(RegExp(pattern).hasMatch('a'), isFalse);
        expect(RegExp(pattern).hasMatch('5'), isFalse);
      });

      test('\\\\ matches literal backslash', () {
        final pattern = compileFindPattern(r'\\');
        expect(RegExp(pattern).hasMatch(r'\'), isTrue);
        expect(RegExp(pattern).hasMatch('/'), isFalse);
      });
    });

    group('quantifiers', () {
      // Quantifiers apply to the preceding mask. We anchor with ^…$ via
      // firstMatch to verify exact-length matching (hasMatch would find
      // a substring match even when the quantifier overshoots).
      test('? zero-or-one', () {
        final re = RegExp(compileFindPattern(r'\d?'));
        expect(re.firstMatch(''), isNotNull);
        expect(re.firstMatch('3')!.end, 1);
        // '33' — \d? matches just the first digit (len 1), not both.
        expect(re.firstMatch('33')!.end, 1);
      });

      test('+ one-or-more', () {
        final re = RegExp(compileFindPattern(r'\d+'));
        expect(re.firstMatch(''), isNull);
        expect(re.firstMatch('3')!.end, 1);
        expect(re.firstMatch('123')!.end, 3);
      });

      test('{n} exactly n', () {
        final re = RegExp(compileFindPattern(r'\d{3}'));
        expect(re.firstMatch('123')!.end, 3);
        expect(re.firstMatch('12'), isNull);
        // '1234' — {3} matches exactly 3 digits, leaving '4' unmatched.
        expect(re.firstMatch('1234')!.end, 3);
      });

      test('{n,m} range', () {
        final re = RegExp(compileFindPattern(r'\d{2,4}'));
        expect(re.firstMatch('1'), isNull);
        expect(re.firstMatch('12')!.end, 2);
        expect(re.firstMatch('1234')!.end, 4);
        // '12345' — {2,4} greedily matches 4, leaving '5'.
        expect(re.firstMatch('12345')!.end, 4);
      });

      test('{n,} unbounded', () {
        final re = RegExp(compileFindPattern(r'\d{3,}'));
        expect(re.firstMatch('12'), isNull);
        expect(re.firstMatch('123')!.end, 3);
        expect(re.firstMatch('1234567')!.end, 7);
      });
    });

    group('literal escaping', () {
      test('meta characters are escaped as literals', () {
        // Each of these should produce a regex that matches the literal char.
        for (final ch in [
          '.',
          '(',
          ')',
          '+',
          '*',
          '?',
          '[',
          ']',
          '{',
          '}',
          '^',
          r'$',
          '|',
        ]) {
          final pattern = compileFindPattern(ch);
          expect(
            RegExp(pattern).hasMatch(ch),
            isTrue,
            reason: 'Should match literal "$ch"',
          );
        }
      });

      test('brackets [] are escaped, not character class', () {
        final pattern = compileFindPattern('[test]');
        final re = RegExp(pattern);
        // Should match the literal string "[test]", NOT individual chars.
        expect(re.hasMatch('[test]'), isTrue);
        expect(re.hasMatch('t'), isFalse);
        expect(re.hasMatch('e'), isFalse);
      });
    });

    group('empty and plain text', () {
      test('empty string produces empty pattern', () {
        expect(compileFindPattern(''), isEmpty);
      });

      test('plain text is escaped literally', () {
        final pattern = compileFindPattern('hello');
        expect(RegExp(pattern).hasMatch('hello'), isTrue);
        expect(RegExp(pattern).hasMatch('Hello'), isFalse);
      });
    });

    group('error cases', () {
      test('trailing backslash throws FormatException', () {
        expect(() => compileFindPattern(r'\'), throwsFormatException);
      });

      test('unknown mask throws FormatException', () {
        expect(() => compileFindPattern(r'\x'), throwsFormatException);
        expect(() => compileFindPattern(r'\z'), throwsFormatException);
      });

      test('unclosed quantifier throws FormatException', () {
        expect(() => compileFindPattern(r'\d{3'), throwsFormatException);
      });

      test('empty quantifier throws FormatException', () {
        expect(() => compileFindPattern(r'\d{}'), throwsFormatException);
      });

      test('non-numeric quantifier throws FormatException', () {
        expect(() => compileFindPattern(r'\d{a}'), throwsFormatException);
        expect(() => compileFindPattern(r'\d{a,b}'), throwsFormatException);
      });

      test('too many commas in quantifier throws FormatException', () {
        expect(() => compileFindPattern(r'\d{1,2,3}'), throwsFormatException);
      });
    });

    group('capture groups', () {
      test('\\( + matching ) creates a capture group', () {
        // Content between \\( and ) is raw regex — not re-parsed.
        final pattern = compileFindPattern(r'\(\d+)');
        expect(pattern, r'(\d+)');
        final re = RegExp(pattern);
        final m = re.firstMatch('abc 123 def');
        expect(m, isNotNull);
        expect(m!.group(1), '123');
      });

      test('quantifier on capture group', () {
        final pattern = compileFindPattern(r'\(\d+)+');
        expect(pattern, r'(\d+)+');
        final re = RegExp(pattern);
        expect(re.firstMatch('123')!.end, 3);
        expect(re.firstMatch('12345')!.end, 5);
      });

      test('nested raw regex inside group', () {
        // Inner ( ) are raw regex; paren counting finds the matching ) .
        final pattern = compileFindPattern(r'\((\w+)\s(\d+))');
        expect(pattern, r'((\w+)\s(\d+))');
        final re = RegExp(pattern);
        final m = re.firstMatch('hello world 42');
        expect(m, isNotNull);
        expect(m!.group(1), 'world 42');
        expect(m.group(2), 'world');
        expect(m.group(3), '42');
      });

      test('bare ( without backslash is still a literal', () {
        final pattern = compileFindPattern(r'(');
        expect(pattern, r'\(');
        expect(RegExp(pattern).hasMatch('('), isTrue);
      });

      test('unclosed capture group throws FormatException', () {
        expect(() => compileFindPattern(r'\(\d+'), throwsFormatException);
      });
    });
  });

  group('compileReplacePattern()', () {
    test('backreference \\\\1 becomes \$1', () {
      expect(compileReplacePattern(r'\1'), r'$1');
    });

    test('backreference \\\\12 becomes \$12', () {
      expect(compileReplacePattern(r'\12'), r'$12');
    });

    test('literal backslash \\\\\\\\ becomes single backslash', () {
      expect(compileReplacePattern(r'\\'), r'\');
    });

    test('literal dollar \$\$ becomes single dollar', () {
      expect(compileReplacePattern(r'$$'), r'$');
    });

    test('plain text passes through unchanged', () {
      expect(compileReplacePattern('hello world'), 'hello world');
    });

    test('combined: backref + literal backslash + literal dollar', () {
      final result = compileReplacePattern(r'\1\\$$');
      expect(result, r'$1\$');
    });

    test('dollar without double-dollar is untouched', () {
      expect(compileReplacePattern(r'$1'), r'$1');
    });
  });

  group('isValidFindPattern()', () {
    test('returns true for valid patterns', () {
      expect(isValidFindPattern('hello'), isTrue);
      expect(isValidFindPattern(r'\w+'), isTrue);
      expect(isValidFindPattern(r'\d{3}-\d{4}'), isTrue);
      expect(isValidFindPattern(''), isTrue);
    });

    test('returns false for invalid patterns', () {
      expect(isValidFindPattern(r'\' ), isFalse);
      expect(isValidFindPattern(r'\x'), isFalse);
      expect(isValidFindPattern(r'\d{'), isFalse);
    });

    test('rejects capture-group content RegExp itself refuses', () {
      // Survives the mask compiler but fails RegExp construction — before
      // the RegExp check, this saved fine and was silently skipped at apply
      // time (rule looked active, never ran).
      expect(isValidFindPattern(r'\([)'), isFalse);
      expect(isValidFindPattern(r'\((unclosed)'), isFalse);
      // Sanity: valid raw-group content still accepted.
      expect(isValidFindPattern(r'\((a|b))'), isTrue);
    });
  });

  group('hasNestedQuantifierInGroup()', () {
    test('nested quantifier inside quantified group → true', () {
      expect(hasNestedQuantifierInGroup(r'\((a+))+'), isTrue);
    });

    test('inner quantifier with group quantifier → true', () {
      expect(hasNestedQuantifierInGroup(r'\(\w*)*'), isTrue);
    });

    test('range quantifier on group with inner quantifier → true', () {
      expect(hasNestedQuantifierInGroup(r'\((\d+){2,})+'), isTrue);
    });

    test('simple capture group without nested quantifier → false', () {
      expect(hasNestedQuantifierInGroup(r'\(\d+)'), isFalse);
    });

    test('capture group with no quantifiers at all → false', () {
      expect(hasNestedQuantifierInGroup(r'\(ab)'), isFalse);
    });

    test('no capture groups at all → false', () {
      expect(hasNestedQuantifierInGroup(r'\w+'), isFalse);
    });

    test('unquantified group with inner quantifier → false', () {
      expect(hasNestedQuantifierInGroup(r'\(\d+)'), isFalse);
    });

    test('inner raw nesting flagged even when outer group unquantified', () {
      // The classic ReDoS shape hiding INSIDE the group content — the outer
      // \(...) carries no quantifier, so the outer-only check missed it.
      expect(hasNestedQuantifierInGroup(r'\((a+)+)'), isTrue);
      expect(hasNestedQuantifierInGroup(r'\(x(\w*)*y)'), isTrue);
      expect(hasNestedQuantifierInGroup(r'\(((a+))+)'), isTrue);
    });

    test('safe inner groups stay unflagged', () {
      // Quantified inner group whose content has no quantifier — linear.
      expect(hasNestedQuantifierInGroup(r'\((abc)+)'), isFalse);
      // Two sibling quantified elements, no nesting.
      expect(hasNestedQuantifierInGroup(r'\((a+)(b+))'), isFalse);
      // Escaped parens are literals, not groups.
      expect(hasNestedQuantifierInGroup(r'\(\(a+\)+)'), isFalse);
    });
  });

  group('tryCompileRule()', () {
    test('valid rule returns regex + replacement', () {
      final result = tryCompileRule(r'\w+', r'\1');
      expect(result, isNotNull);
      expect(result!.regex, isA<RegExp>());
      expect(result.replacement, r'$1');
    });

    test('invalid find returns null', () {
      expect(tryCompileRule(r'\x', 'replacement'), isNull);
    });

    test('regex is case-insensitive', () {
      final result = tryCompileRule('hello', 'world')!;
      expect(result.regex.hasMatch('HELLO'), isTrue);
      expect(result.regex.hasMatch('Hello'), isTrue);
    });
  });

  group('sanitizeOutput()', () {
    test('single rule application', () {
      final result = sanitizeOutput(
        'she said \u2014 hello',
        [OutputSanitizerRule(id: 0, find: '\u2014', replace: ' - ')],
      );
      expect(result, 'she said  -  hello');
    });

    test('multiple rules applied in order', () {
      final result = sanitizeOutput(
        'hello world',
        [
          OutputSanitizerRule(id: 1, find: 'hello', replace: 'goodbye'),
          OutputSanitizerRule(id: 2, find: 'world', replace: 'earth'),
        ],
      );
      expect(result, 'goodbye earth');
    });

    test('empty find string skips rule', () {
      final result = sanitizeOutput(
        'text',
        [OutputSanitizerRule(id: 3, find: '', replace: 'x')],
      );
      expect(result, 'text');
    });

    test('invalid find string skips rule silently', () {
      final result = sanitizeOutput(
        'text',
        [OutputSanitizerRule(id: 4, find: r'\x', replace: 'x')],
      );
      expect(result, 'text');
    });

    test('no matches leaves text unchanged', () {
      final result = sanitizeOutput(
        'hello',
        [OutputSanitizerRule(id: 5, find: 'xyz', replace: 'abc')],
      );
      expect(result, 'hello');
    });

    test('empty rules list returns text unchanged', () {
      expect(sanitizeOutput('hello', []), 'hello');
    });

    test('multiple matches in same text', () {
      final result = sanitizeOutput(
        'aaa bbb aaa',
        [OutputSanitizerRule(id: 6, find: 'aaa', replace: 'xxx')],
      );
      expect(result, 'xxx bbb xxx');
    });

    test('backreference expands capture group content', () {
      // \\( in find creates a capture group, \\1 in replace references it.
      final result = sanitizeOutput(
        'abc 123 def',
        [OutputSanitizerRule(id: 7, find: r'\(\d+)', replace: r'[\1]')],
      );
      expect(result, 'abc [123] def');
    });

    test('multiple capture groups with backreferences', () {
      // Two separate \\( groups: group 1 = \\w+, group 2 = \\d+.
      final result = sanitizeOutput(
        'hello 42',
        [OutputSanitizerRule(id: 8, find: r'\(\w+) \(\d+)', replace: r'\2 \1')],
      );
      expect(result, '42 hello');
    });

    test('capture group without backreference works fine', () {
      // The group captures but replace doesn't reference it — no error.
      final result = sanitizeOutput(
        'abc 123 def',
        [OutputSanitizerRule(id: 9, find: r'\(\d+)', replace: 'NUMBER')],
      );
      expect(result, 'abc NUMBER def');
    });

    test('empty replace string deletes matches', () {
      final result = sanitizeOutput(
        'hello 123 world',
        [OutputSanitizerRule(id: 10, find: r'\d+', replace: '')],
      );
      expect(result, 'hello  world');
    });

    test('literal backslash in find matches backslash in text', () {
      final result = sanitizeOutput(
        r'path\to\file',
        [OutputSanitizerRule(id: 11, find: r'\\', replace: '/')],
      );
      expect(result, 'path/to/file');
    });

    test('brackets in find are treated as literals', () {
      final result = sanitizeOutput(
        '[bold] text [/bold]',
        [OutputSanitizerRule(id: 12, find: '[bold]', replace: '**')],
      );
      expect(result, '** text [/bold]');
    });

    test('large text with many rules does not blow up', () {
      final bigText = 'word ' * 2000; // 10k chars
      final rules = List.generate(
        50,
        (i) => OutputSanitizerRule(id: 13 + i, find: 'word', replace: 'w$i'),
      );
      final result = sanitizeOutput(bigText, rules);
      // First rule replaces all "word" → "w0", subsequent rules find nothing.
      expect(result, startsWith('w0 '));
    });
  });

  // ─── OutputSanitizerRule model — stopAfterMatch ─────────────────────

  group('OutputSanitizerRule', () {
    test('stopAfterMatch defaults to false', () {
      final rule = OutputSanitizerRule(id: 0, find: 'a', replace: 'b');
      expect(rule.stopAfterMatch, isFalse);
    });

    test('stopAfterMatch round-trips through JSON', () {
      final rule = OutputSanitizerRule(
        id: 1,
        find: 'em',
        replace: '—',
        stopAfterMatch: true,
      );
      final json = rule.toJson();
      expect(json['stop_after_match'], isTrue);

      final restored = OutputSanitizerRule.fromJson(json);
      expect(restored.stopAfterMatch, isTrue);
      expect(restored.find, 'em');
      expect(restored.replace, '—');
    });

    test('stopAfterMatch false is omitted from JSON', () {
      final rule = OutputSanitizerRule(id: 2, find: 'a', replace: 'b');
      final json = rule.toJson();
      expect(json.containsKey('stop_after_match'), isFalse);
    });

    test('fromJson missing stop_after_match defaults to false', () {
      final rule = OutputSanitizerRule.fromJson({'find': 'x', 'replace': 'y'});
      expect(rule.stopAfterMatch, isFalse);
    });

    test('fromJson generates id when missing', () {
      final rule = OutputSanitizerRule.fromJson({'find': 'x', 'replace': 'y'});
      expect(rule.id, 0);
    });

    test('fromJson preserves id when present', () {
      final rule =
          OutputSanitizerRule.fromJson({'id': 42, 'find': 'x', 'replace': 'y'});
      expect(rule.id, 42);
    });

    test('equality excludes id', () {
      final a = OutputSanitizerRule(id: 1, find: 'x', replace: 'y');
      final b = OutputSanitizerRule(id: 2, find: 'x', replace: 'y');
      expect(a, equals(b));
    });

    test('equality includes stopAfterMatch', () {
      final a = OutputSanitizerRule(id: 0, find: 'x', replace: 'y');
      final b =
          OutputSanitizerRule(id: 0, find: 'x', replace: 'y', stopAfterMatch: true);
      final c = OutputSanitizerRule(id: 0, find: 'x', replace: 'y');

      expect(a, equals(c));
      expect(a == b, isFalse);
    });
  });

  // ─── compiled path (hot loops compile once, apply many) ─────────────

  group('compileSanitizerRules() + sanitizeOutputCompiled()', () {
    test('compiled once, applied to many texts — matches one-shot path', () {
      final rules = [
        OutputSanitizerRule(id: 0, find: '—', replace: ' - '),
        OutputSanitizerRule(id: 1, find: r'foo \(\d+)', replace: r'bar $1'),
      ];
      final compiled = compileSanitizerRules(rules);
      for (final text in ['a—b', 'foo 42', 'plain', 'foo 1—foo 2']) {
        expect(
          sanitizeOutputCompiled(text, compiled),
          sanitizeOutput(text, rules),
          reason: 'compiled and one-shot paths must agree on "$text"',
        );
      }
    });

    test('invalid and empty-find rules are dropped at compile time', () {
      final compiled = compileSanitizerRules([
        OutputSanitizerRule(id: 0, find: '', replace: 'x'),
        OutputSanitizerRule(id: 1, find: r'\d{', replace: 'x'), // malformed
        OutputSanitizerRule(id: 2, find: 'ok', replace: 'fine'),
      ]);
      expect(compiled, hasLength(1));
      expect(sanitizeOutputCompiled('ok', compiled), 'fine');
    });

    test('stopAfterMatch respected through the compiled path', () {
      final compiled = compileSanitizerRules([
        OutputSanitizerRule(id: 0, find: 'a', replace: 'b', stopAfterMatch: true),
        OutputSanitizerRule(id: 1, find: 'b', replace: 'c'),
      ]);
      expect(sanitizeOutputCompiled('a', compiled), 'b');
    });
  });

  // ─── legacy id healing on deserialization ───────────────────────────

  group('OutputSanitizerRule.listFromJson()', () {
    test('legacy rules without ids (all parse to 0) are renumbered', () {
      final rules = OutputSanitizerRule.listFromJson([
        {'find': 'a', 'replace': 'b'},
        {'find': 'c', 'replace': 'd', 'stop_after_match': true},
        {'find': 'e', 'replace': 'f'},
      ]);
      expect(rules.map((r) => r.id), [0, 1, 2]);
      // Order and payloads survive the renumber — order is load-bearing.
      expect(rules.map((r) => r.find), ['a', 'c', 'e']);
      expect(rules[1].stopAfterMatch, isTrue);
    });

    test('distinct ids are preserved untouched', () {
      final rules = OutputSanitizerRule.listFromJson([
        {'id': 7, 'find': 'a', 'replace': 'b'},
        {'id': 3, 'find': 'c', 'replace': 'd'},
      ]);
      expect(rules.map((r) => r.id), [7, 3]);
    });

    test('mixed legacy + new ids with a collision renumber sequentially', () {
      final rules = OutputSanitizerRule.listFromJson([
        {'find': 'a', 'replace': 'b'}, // legacy → 0
        {'id': 0, 'find': 'c', 'replace': 'd'}, // collides with legacy
      ]);
      expect(rules.map((r) => r.id), [0, 1]);
    });

    test('empty list stays empty', () {
      expect(OutputSanitizerRule.listFromJson([]), isEmpty);
    });
  });

  // ─── stopAfterMatch behaviour in sanitizeOutput ─────────────────────

  group('sanitizeOutput with stopAfterMatch', () {
    test('stopAfterMatch=true breaks after first matching rule', () {
      final rules = [
        OutputSanitizerRule(id: 0, find: 'foo', replace: 'bar', stopAfterMatch: true),
        OutputSanitizerRule(id: 1, find: 'bar', replace: 'baz'),
      ];
      // First rule: foo→bar (matches, stopAfterMatch fires).
      // Second rule should NOT run even though 'bar' is now in the text.
      expect(sanitizeOutput('foo foo', rules), 'bar bar');
    });

    test('stopAfterMatch=true does NOT break when rule does not match', () {
      final rules = [
        OutputSanitizerRule(
          id: 0,
          find: 'zzz',
          replace: 'YYY',
          stopAfterMatch: true,
        ),
        OutputSanitizerRule(id: 1, find: 'foo', replace: 'bar'),
      ];
      // First rule doesn't match → continue. Second rule matches.
      expect(sanitizeOutput('foo', rules), 'bar');
    });

    test('stopAfterMatch=false allows all rules to run', () {
      final rules = [
        OutputSanitizerRule(id: 0, find: 'foo', replace: 'bar'),
        OutputSanitizerRule(id: 1, find: 'bar', replace: 'baz'),
      ];
      // Both rules run: foo→bar→baz.
      expect(sanitizeOutput('foo', rules), 'baz');
    });

    test('multiple stopAfterMatch rules — first matching one wins', () {
      final rules = [
        OutputSanitizerRule(id: 0, find: 'a', replace: 'b'),
        OutputSanitizerRule(id: 1, find: 'b', replace: 'c', stopAfterMatch: true),
        OutputSanitizerRule(id: 2, find: 'c', replace: 'd'),
      ];
      // Rule 1: a→b. Rule 2: b→c (stopAfterMatch, matches → break).
      // Rule 3 never runs.
      expect(sanitizeOutput('a', rules), 'c');
    });

    test('stopAfterMatch with no text change does not break early', () {
      final rules = [
        OutputSanitizerRule(
          id: 0,
          find: 'nomatch',
          replace: 'nope',
          stopAfterMatch: true,
        ),
        OutputSanitizerRule(id: 1, find: 'foo', replace: 'bar'),
      ];
      expect(sanitizeOutput('foo', rules), 'bar');
    });
  });
}
