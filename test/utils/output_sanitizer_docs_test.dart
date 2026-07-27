// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Pins every worked example in docs/output-sanitizer-syntax.md to real
// compiler behaviour. That doc is written for non-technical users, so a
// wrong example costs them a rule that silently misbehaves (or refuses to
// save) with no way to tell why.
//
// Two examples shipped wrong in PR #170 and are now regression-guarded:
//   * `(\(\w+)\)` was documented as the way to capture inside literal
//     parens — it is REJECTED outright (`\)` outside a group is not a
//     valid escape). The working form is a bare `)`: `(\(\w+))`.
//   * the doc claimed the `\a` / `\l` / `\p` wildcards work inside a
//     capture group. They do not — group content is raw regex, so the
//     engine reads them as the literal letters a / l / p, silently.
//
// If you edit the doc, edit this file in the same change.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/output_sanitizer_rule.dart';
import 'package:front_porch_ai/utils/output_sanitizer_regex.dart';

String _apply(String find, String replace, String text) => sanitizeOutput(
  text,
  [OutputSanitizerRule(id: 1, find: find, replace: replace)],
);

void main() {
  group('docs/output-sanitizer-syntax.md — worked examples', () {
    test('capture groups and backreferences', () {
      expect(_apply(r'\(\d+)', r'[\1]', 'abc 123 def'), 'abc [123] def');
      expect(_apply(r'\(\w+)', r'\1 and \1', 'abc'), 'abc and abc');
      expect(_apply(r'\(\w+) \(\d+)', r'\2 \1', 'hello 42'), '42 hello');
      expect(_apply(r'\(\d+)', 'NUMBER', 'order 456 shipped'),
          'order NUMBER shipped');
    });

    test('literal parens: the bare-) form is the one that works', () {
      // Documented recipe — captures the word, consumes the parens.
      expect(_apply(r'(\(\w+))', r'[\1]', '(hello)'), '[hello]');
      // The form the doc now explicitly warns against.
      expect(isValidFindPattern(r'(\(\w+)\)'), isFalse);
      // Escaping inside the group captures the parens too.
      expect(_apply(r'\(\(\w+\))', r'[\1]', '(hello)'), '[(hello)]');
      // A literal ) inside the group does not close it.
      expect(_apply(r'\(\w+\))', r'[\1]', 'hello)'), '[hello)]');
    });

    test('inside a group, app wildcards degrade to literal letters', () {
      // These are the silent-failure cases the doc now calls out.
      expect(_apply(r'\(\a+)', r'<\1>', 'banana'), 'b<a>n<a>n<a>');
      expect(_apply(r'\(\l+)', r'<\1>', 'hello'), 'he<ll>o');
      expect(_apply(r'\(\p+)', r'<\1>', 'apple'), 'a<pp>le');
      // …while the recommended standard classes behave as documented.
      expect(_apply(r'\([a-zA-Z]+)', r'<\1>', 'hello'), '<hello>');
      expect(_apply(r'\([0-9]+)', r'<\1>', 'abc 123'), 'abc <123>');
      // \d and \w keep working; \w picks up `_` inside a group.
      expect(_apply(r'\(\d+)', r'<\1>', 'abc 123'), 'abc <123>');
      expect(_apply(r'\(\w+)', r'<\1>', 'ab_cd'), '<ab_cd>');
    });

    test('replace-field escapes', () {
      expect(_apply('x', r'$$100', 'x'), r'$100');
      expect(_apply('x', r'\\path', 'x'), r'\path');
      // The documented caveat: $$ before a digit collides with \1 in a
      // rule that has capture groups; the space workaround is what the
      // doc tells users to reach for.
      expect(_apply(r'\(\w+)', r'$$100', 'abc'), 'abc00');
      expect(_apply(r'\(\w+)', r'$$ 100', 'abc'), r'$ 100');
    });

    test('quantifiers, including the * added in PR #170', () {
      expect(_apply(r'\l+', 'X', 'hi there'), 'X X');
      expect(_apply(r'\d*', '', 'abc 12 def'), 'abc  def');
      expect(_apply(r'\( )+', ' ', 'a  b   c    d'), 'a b c d');
      expect(_apply('—', ' - ', 'she said—hello'), 'she said - hello');
    });

    test('Stop after match skips later rules only on a real change', () {
      List<OutputSanitizerRule> rules(String replace) => [
        OutputSanitizerRule(
          id: 1,
          find: 'cat',
          replace: replace,
          stopAfterMatch: true,
        ),
        OutputSanitizerRule(id: 2, find: 'sky', replace: 'sea'),
      ];
      expect(sanitizeOutput('cat sky', rules('dog')), 'dog sky');
      expect(sanitizeOutput('bird sky', rules('dog')), 'bird sea');
      // Matched, but replacement identical → nothing changed → chain runs on.
      expect(sanitizeOutput('cat sky', rules('cat')), 'cat sea');
    });
  });
}
