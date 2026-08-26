// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// After the Porch Life split, wardrobe / likes / time / chaos must stay
// editable with the Realism Engine switch OFF. They used to live inside
// `if (enabled)` in RealismFormSection, so the manual (and AI) creator
// hid the whole Porch Life authoring surface behind that toggle.
//
// ChipListEditor renders labels in uppercase (`WEARING`), so assertions
// match that surface — `find.text('Wearing')` is a false red.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/ui/widgets/realism_form_section.dart';

Widget _form({required bool enabled}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: RealismFormSection(
        enabled: enabled,
        onEnabledChanged: (_) {},
        timeOfDay: 'morning',
        onTimeOfDayChanged: (_) {},
        dayCount: 1,
        onDayCountChanged: (_) {},
        shortTermBond: 0,
        onShortTermBondChanged: (_) {},
        longTermBond: 0,
        onLongTermBondChanged: (_) {},
        trustLevel: 0,
        onTrustLevelChanged: (_) {},
        emotion: '',
        onEmotionChanged: (_) {},
        emotionIntensity: 'mild',
        onEmotionIntensityChanged: (_) {},
        nsfwCooldownEnabled: false,
        onNsfwCooldownChanged: (_) {},
        chaosModeEnabled: false,
        onChaosModeChanged: (_) {},
        ambitions: const [],
        onAmbitionsChanged: (_) {},
        likes: const [],
        onLikesChanged: (_) {},
        dislikes: const [],
        onDislikesChanged: (_) {},
        worn: const [],
        onWornChanged: (_) {},
        carrying: const [],
        onCarryingChanged: (_) {},
        realismVerificationEnabled: false,
        onRealismVerificationChanged: (_) {},
      ),
    ),
  ),
);

void main() {
  testWidgets('Porch Life chips stay up with the Realism Engine off', (
    tester,
  ) async {
    await tester.pumpWidget(_form(enabled: false));
    await tester.pumpAndSettle();

    expect(find.text('Pockets & Wardrobe'), findsOneWidget);
    expect(find.text('WEARING'), findsOneWidget);
    expect(find.text('CARRYING'), findsOneWidget);
    expect(find.text('Ambitions'), findsOneWidget);
    expect(find.text('Likes & Dislikes'), findsOneWidget);
    expect(find.text('Time of Day'), findsOneWidget);
    expect(find.text('Chaos Mode (Chance Time)'), findsOneWidget);
    expect(find.text('Short-Term Bond'), findsNothing);
    expect(find.text('Starting Emotion'), findsNothing);
    expect(find.text('Afterglow (intimacy pacing)'), findsNothing);
    expect(
      find.text('Realism Verification (Director/Verifier)'),
      findsNothing,
    );
  });

  testWidgets('engine-only seeds appear only when the switch is on', (
    tester,
  ) async {
    await tester.pumpWidget(_form(enabled: true));
    await tester.pumpAndSettle();

    expect(find.text('Short-Term Bond'), findsOneWidget);
    expect(find.text('Starting Emotion'), findsOneWidget);
    expect(find.text('Afterglow (intimacy pacing)'), findsOneWidget);
    expect(find.text('Pockets & Wardrobe'), findsOneWidget);
    expect(find.text('Chaos Mode (Chance Time)'), findsOneWidget);
  });
}
