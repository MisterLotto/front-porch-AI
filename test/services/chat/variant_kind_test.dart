// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  group('usesGreetingPicker', () {
    test('opening message with alt greets and no regen swipes is a greet', () {
      expect(
        usesGreetingPicker(
          messageIndex: 0,
          isUser: false,
          greetCount: 3,
          swipeCount: 1,
        ),
        isTrue,
      );
    });

    test('pre-existing regen swipes on the opening message are not greets', () {
      expect(
        usesGreetingPicker(
          messageIndex: 0,
          isUser: false,
          greetCount: 3,
          swipeCount: 4,
        ),
        isFalse,
      );
    });

    test('later messages are never greets', () {
      expect(
        usesGreetingPicker(
          messageIndex: 2,
          isUser: false,
          greetCount: 3,
          swipeCount: 1,
        ),
        isFalse,
      );
    });

    test('a user reply ends the greet picker', () {
      expect(
        usesGreetingPicker(
          messageIndex: 0,
          isUser: false,
          greetCount: 3,
          swipeCount: 1,
          userHasReplied: true,
        ),
        isFalse,
      );
    });
  });

  group('buildVariantOptions kind', () {
    test('greet rows carry kind greet', () {
      final rows = buildVariantOptions(
        ['Hi there', 'Hey you'],
        0,
        kind: VariantKind.greet,
      );
      expect(rows.every((r) => r.kind == VariantKind.greet), isTrue);
      expect(rows.first.toJson()['kind'], 'greet');
      expect(variantKindLabel(rows.first.kind), 'Greet');
    });

    test('regen rows carry kind regen', () {
      final rows = buildVariantOptions(
        ['First swipe', 'Second swipe'],
        1,
        kind: VariantKind.regen,
      );
      expect(rows.every((r) => r.kind == VariantKind.regen), isTrue);
      expect(rows.last.toJson()['kind'], 'regen');
      expect(variantKindLabel(rows.last.kind), 'Regen');
    });
  });
}
