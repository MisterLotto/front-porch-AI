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
      test('\\(...\\) creates a capture group', () {
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

  group('sanitizeOutputWithRegex()', () {
    test('single rule application', () {
      final result = sanitizeOutputWithRegex(
        'she said \u2014 hello',
        [(find: '\u2014', replace: ' - ')],
      );
      expect(result, 'she said  -  hello');
    });

    test('multiple rules applied in order', () {
      final result = sanitizeOutputWithRegex(
        'hello world',
        [
          (find: 'hello', replace: 'goodbye'),
          (find: 'world', replace: 'earth'),
        ],
      );
      expect(result, 'goodbye earth');
    });

    test('empty find string skips rule', () {
      final result = sanitizeOutputWithRegex(
        'text',
        [(find: '', replace: 'x')],
      );
      expect(result, 'text');
    });

    test('invalid find string skips rule silently', () {
      final result = sanitizeOutputWithRegex(
        'text',
        [(find: r'\x', replace: 'x')],
      );
      expect(result, 'text');
    });

    test('no matches leaves text unchanged', () {
      final result = sanitizeOutputWithRegex(
        'hello',
        [(find: 'xyz', replace: 'abc')],
      );
      expect(result, 'hello');
    });

    test('empty rules list returns text unchanged', () {
      expect(sanitizeOutputWithRegex('hello', []), 'hello');
    });

    test('multiple matches in same text', () {
      final result = sanitizeOutputWithRegex(
        'aaa bbb aaa',
        [(find: 'aaa', replace: 'xxx')],
      );
      expect(result, 'xxx bbb xxx');
    });

    test('backreference expands capture group content', () {
      // \\( in find creates a capture group, \\1 in replace references it.
      final result = sanitizeOutputWithRegex(
        'abc 123 def',
        [(find: r'\(\d+)', replace: r'[\1]')],
      );
      expect(result, 'abc [123] def');
    });

    test('multiple capture groups with backreferences', () {
      // Two separate \\( groups: group 1 = \\w+, group 2 = \\d+.
      final result = sanitizeOutputWithRegex(
        'hello 42',
        [(find: r'\(\w+) \(\d+)', replace: r'\2 \1')],
      );
      expect(result, '42 hello');
    });

    test('capture group without backreference works fine', () {
      // The group captures but replace doesn't reference it — no error.
      final result = sanitizeOutputWithRegex(
        'abc 123 def',
        [(find: r'\(\d+)', replace: 'NUMBER')],
      );
      expect(result, 'abc NUMBER def');
    });

    test('empty replace string deletes matches', () {
      final result = sanitizeOutputWithRegex(
        'hello 123 world',
        [(find: r'\d+', replace: '')],
      );
      expect(result, 'hello  world');
    });

    test('literal backslash in find matches backslash in text', () {
      final result = sanitizeOutputWithRegex(
        r'path\to\file',
        [(find: r'\\', replace: '/')],
      );
      expect(result, 'path/to/file');
    });

    test('brackets in find are treated as literals', () {
      final result = sanitizeOutputWithRegex(
        '[bold] text [/bold]',
        [(find: '[bold]', replace: '**')],
      );
      expect(result, '** text [/bold]');
    });

    test('large text with many rules does not blow up', () {
      final bigText = 'word ' * 2000; // 10k chars
      final rules = List.generate(
        50,
        (i) => (find: 'word', replace: 'w$i'),
      );
      final result = sanitizeOutputWithRegex(bigText, rules);
      // First rule replaces all "word" → "w0", subsequent rules find nothing.
      expect(result, startsWith('w0 '));
    });
  });

  // ─── OutputSanitizerRule model — stopAfterMatch ─────────────────────

  group('OutputSanitizerRule', () {
    test('stopAfterMatch defaults to false', () {
      final rule = OutputSanitizerRule(find: 'a', replace: 'b');
      expect(rule.stopAfterMatch, isFalse);
    });

    test('stopAfterMatch round-trips through JSON', () {
      final rule = OutputSanitizerRule(
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
      final rule = OutputSanitizerRule(find: 'a', replace: 'b');
      final json = rule.toJson();
      expect(json.containsKey('stop_after_match'), isFalse);
    });

    test('fromJson missing stop_after_match defaults to false', () {
      final rule = OutputSanitizerRule.fromJson({'find': 'x', 'replace': 'y'});
      expect(rule.stopAfterMatch, isFalse);
    });

    test('equality includes stopAfterMatch', () {
      final a = OutputSanitizerRule(find: 'x', replace: 'y');
      final b = OutputSanitizerRule(find: 'x', replace: 'y', stopAfterMatch: true);
      final c = OutputSanitizerRule(find: 'x', replace: 'y');

      expect(a, equals(c));
      expect(a == b, isFalse);
    });
  });

  // ─── stopAfterMatch behaviour in sanitizeOutput ─────────────────────

  group('sanitizeOutput with stopAfterMatch', () {
    /// Mirrors ChatServiceGeneration.sanitizeOutput logic for testing
    /// without importing the full chat service.
    String sanitize(
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

    test('stopAfterMatch=true breaks after first matching rule', () {
      final rules = [
        OutputSanitizerRule(find: 'foo', replace: 'bar', stopAfterMatch: true),
        OutputSanitizerRule(find: 'bar', replace: 'baz'),
      ];
      // First rule: foo→bar (matches, stopAfterMatch fires).
      // Second rule should NOT run even though 'bar' is now in the text.
      expect(sanitize('foo foo', rules), 'bar bar');
    });

    test('stopAfterMatch=true does NOT break when rule does not match', () {
      final rules = [
        OutputSanitizerRule(
          find: 'zzz',
          replace: 'YYY',
          stopAfterMatch: true,
        ),
        OutputSanitizerRule(find: 'foo', replace: 'bar'),
      ];
      // First rule doesn't match → continue. Second rule matches.
      expect(sanitize('foo', rules), 'bar');
    });

    test('stopAfterMatch=false allows all rules to run', () {
      final rules = [
        OutputSanitizerRule(find: 'foo', replace: 'bar'),
        OutputSanitizerRule(find: 'bar', replace: 'baz'),
      ];
      // Both rules run: foo→bar→baz.
      expect(sanitize('foo', rules), 'baz');
    });

    test('multiple stopAfterMatch rules — first matching one wins', () {
      final rules = [
        OutputSanitizerRule(find: 'a', replace: 'b'),
        OutputSanitizerRule(find: 'b', replace: 'c', stopAfterMatch: true),
        OutputSanitizerRule(find: 'c', replace: 'd'),
      ];
      // Rule 1: a→b. Rule 2: b→c (stopAfterMatch, matches → break).
      // Rule 3 never runs.
      expect(sanitize('a', rules), 'c');
    });

    test('stopAfterMatch with no text change does not break early', () {
      final rules = [
        OutputSanitizerRule(
          find: 'nomatch',
          replace: 'nope',
          stopAfterMatch: true,
        ),
        OutputSanitizerRule(find: 'foo', replace: 'bar'),
      ];
      expect(sanitize('foo', rules), 'bar');
    });
  });
}
