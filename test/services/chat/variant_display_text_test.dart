// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  group('variantDisplayText', () {
    test('strips HTML comment context so the preview is the prose', () {
      const raw =
          '<!-- [Context: {{user}} and {{char}} have been living together '
          'for two weeks. {{char}} is already waiting.] -->\n'
          '*Elara curtsies deeply — which causes her to look up.*';
      final display = variantDisplayText(raw);
      expect(display, contains('Elara curtsies deeply'));
      expect(display, isNot(contains('<!--')));
      expect(display, isNot(contains('Context:')));
      expect(variantSnippet(raw), contains('Elara curtsies'));
    });

    test('keeps think-strip behaviour after comment removal', () {
      expect(
        variantDisplayText('<think>plan</think>\nHello   there'),
        'Hello there',
      );
    });
  });

  group('variantApproxTokens', () {
    test('uses the chars/4 floor', () {
      expect(variantApproxTokens(0), 0);
      expect(variantApproxTokens(4), 1);
      expect(variantApproxTokens(5), 2);
    });
  });

  group('buildVariantOptions preview', () {
    test('rows carry cleaned text and token counts', () {
      final rows = buildVariantOptions([
        '<!-- skip me -->\nHello there friend',
      ], 0);
      expect(rows.single.text, 'Hello there friend');
      expect(rows.single.snippet, 'Hello there friend');
      expect(
        rows.single.tokenCount,
        variantApproxTokens(rows.single.charCount),
      );
      expect(rows.single.toJson()['text'], 'Hello there friend');
    });
  });
}
