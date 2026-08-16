// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Enhance Review must offer keep-or-accept for Porch Life, and an empty
// proposal must default Use this OFF so a mute model cannot wipe a wardrobe.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chargen/chat_grounding.dart';
import 'package:front_porch_ai/ui/pages/home/enhance/enhance_review_body.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('Porch Life proposal shows Before vs After with Use this on', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        EnhanceReviewBody(
          original: CharacterCard(
            name: 'Nina',
            frontPorchExtensions: FrontPorchExtensions(
              ambitions: const ['old goal'],
              inventory: const {
                'worn': ['old coat'],
              },
            ),
          ),
          enhanced: CharacterCard(
            name: 'Nina',
            frontPorchExtensions: FrontPorchExtensions(
              ambitions: const ['stay fed'],
              inventory: const {
                'worn': ['flour-dusted apron'],
              },
            ),
          ),
          selection: const EnhanceSelection(
            description: false,
            personality: false,
            exampleDialogue: false,
            porchLife: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Porch Life (wardrobe, ambitions, likes)'),
      findsOneWidget,
    );
    expect(find.textContaining('old goal'), findsOneWidget);
    expect(find.text('stay fed'), findsOneWidget);
    final useSwitch = tester.widget<Switch>(find.byType(Switch).first);
    expect(useSwitch.value, isTrue);
  });

  testWidgets('empty Porch Life proposal defaults Use this off', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        EnhanceReviewBody(
          original: CharacterCard(
            name: 'Nina',
            frontPorchExtensions: FrontPorchExtensions(
              ambitions: const ['old goal'],
            ),
          ),
          enhanced: CharacterCard(name: 'Nina'),
          selection: const EnhanceSelection(
            description: false,
            personality: false,
            exampleDialogue: false,
            porchLife: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final useSwitch = tester.widget<Switch>(find.byType(Switch).first);
    expect(useSwitch.value, isFalse);
  });
}
