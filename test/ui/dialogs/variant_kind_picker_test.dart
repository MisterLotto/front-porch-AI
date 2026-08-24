// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/ui/dialogs/dialogs.dart';

void main() {
  testWidgets('regen swipes are labeled Regen, not Greet', (tester) async {
    final variants = buildVariantOptions(
      ['Original reply about the porch', 'Regenerated reply about the garden'],
      0,
      kind: VariantKind.regen,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showVariantPickerDialog(
                context,
                title: 'Select variant',
                variants: variants,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Regen ·'), findsWidgets);
    expect(find.textContaining('Greet ·'), findsNothing);
  });

  testWidgets('card greets are labeled Greet', (tester) async {
    final variants = buildVariantOptions(
      ['First greet says hello at the door', 'Second greet is at the window'],
      0,
      kind: VariantKind.greet,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showVariantPickerDialog(
                context,
                title: 'Select greet',
                variants: variants,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Greet ·'), findsWidgets);
    expect(find.textContaining('Regen ·'), findsNothing);
  });
}
