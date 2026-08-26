// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Alt-greeting seeds must show Needs baselines like the main Realism
// editor, and must not use SwitchListTile (that tile inside the
// Alternate Greetings section card trips Flutter's ink-invisible assert).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/ui/widgets/greeting_seed_form.dart';
import 'package:front_porch_ai/ui/widgets/slider_with_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'needs baselines show by default and the toggle is not a ListTile',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GreetingSeedForm(
                seed: GreetingRealismSeed(),
                onChanged: _noop,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('Needs Simulation'), findsOneWidget);
      expect(find.text('Hunger'), findsOneWidget);
      expect(find.text('Comfort'), findsOneWidget);
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Starting Emotion'), findsOneWidget);
      expect(find.text('Time & Day'), findsOneWidget);

      final sliders = tester
          .widgetList<SliderWithInput>(find.byType(SliderWithInput))
          .toList();
      expect(
        sliders.where((s) => s.label == 'Hunger'),
        isNotEmpty,
        reason: 'alt openings must seed needs the same way they seed bond',
      );
    },
  );
}

void _noop(GreetingRealismSeed? _) {}
