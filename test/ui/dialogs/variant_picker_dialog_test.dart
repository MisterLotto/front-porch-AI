// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/ui/dialogs/dialogs.dart';

void main() {
  testWidgets('tapping a row commits that index and closes', (tester) async {
    int? picked;
    final variants = buildVariantOptions([
      'First greet says hello to you at the door',
      'Second greet is at the window instead',
      'Third greet is a wave from the porch',
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

    expect(find.text('Select greet'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.textContaining('characters'), findsWidgets);

    await tester.tap(find.textContaining('Second greet'));
    await tester.pumpAndSettle();

    expect(picked, 1);
    expect(find.text('Select greet'), findsNothing);
  });
}
