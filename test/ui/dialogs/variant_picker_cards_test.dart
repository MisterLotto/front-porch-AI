// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/ui/dialogs/dialogs.dart';

void main() {
  testWidgets('HTML comments do not appear; prose does', (tester) async {
    final variants = buildVariantOptions(
      [
        '<!-- [Context: {{user}} and {{char}} have been living together '
            'for two weeks.] -->\n'
            'Elara curtsies deeply at the door and smiles.',
      ],
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

    expect(find.textContaining('<!--'), findsNothing);
    expect(find.textContaining('Context:'), findsNothing);
    expect(find.textContaining('Elara curtsies deeply'), findsWidgets);
    expect(find.textContaining('#1'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.textContaining('characters'), findsWidgets);
  });

  testWidgets('jump Go commits the 1-based index', (tester) async {
    int? picked;
    final variants = buildVariantOptions(
      [
        'First greet says hello to you at the door',
        'Second greet is at the window instead',
        'Third greet is a wave from the porch',
      ],
      0,
      kind: VariantKind.greet,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showVariantPickerDialog(
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

    await tester.enterText(find.byKey(const Key('variant-jump-field')), '2');
    await tester.tap(find.byKey(const Key('variant-jump-go')));
    await tester.pumpAndSettle();

    expect(picked, 1);
    expect(find.text('Select greet'), findsNothing);
  });

  testWidgets('expand does not commit a selection', (tester) async {
    int? picked;
    final variants = buildVariantOptions([
      'First greet says hello to you at the door',
      'Second greet is at the window instead',
    ], 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showVariantPickerDialog(
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

    await tester.tap(find.byKey(const Key('variant-expand-0')));
    await tester.pumpAndSettle();

    expect(picked, isNull);
    expect(find.text('Select greet'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });
}
