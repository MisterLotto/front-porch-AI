// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// Starting Emotion and Day Number used to build a TextEditingController inside
// build(), with the caret forced to the end of the text. Every caller of
// RealismFormSection rebuilds on each keystroke (create_character_page,
// edit_character_page, the AI creator's realism step, group_member_realism_
// editor), so the field was handed a brand-new controller every frame: put the
// caret in the middle of "curius" to fix the typo and the next character landed
// at the end instead, and an IME's multi-keystroke composition was destroyed
// each frame. Same class of bug as the user-reported Image Studio prompt box.
//
// Two guards: the shared field keeps the caret where the user put it across a
// parent rebuild, and the form's two fields hold ONE controller across rebuilds
// (an in-build controller hands out a different instance every time).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/widgets/synced_text_field.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SyncedTextField keeps the caret through a parent rebuild', (
    tester,
  ) async {
    var value = 'curius';
    var rebuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuilds++;
              // Exactly what the real callers do: store, then notify, which
              // rebuilds the whole section on every keystroke.
              return SyncedTextField(
                value: value,
                onChanged: (v) => setState(() => value = v),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    // The platform reports an insert with the caret mid-word ("cur|ius" +
    // 'o'), which is what a real mid-text keystroke looks like.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'curoius',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pump();

    expect(value, 'curoius');
    expect(rebuilds, greaterThan(1), reason: 'the parent must have rebuilt');

    final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
    expect(
      controller.selection.baseOffset,
      4,
      reason: 'the rebuild must not drag the caret to the end of the text — '
          'that is what made mid-word editing impossible',
    );
    expect(controller.text, 'curoius');
  });

  testWidgets('the realism form owns its Emotion and Day Number controllers', (
    tester,
  ) async {
    Widget form(String emotion, int dayCount) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RealismFormSection(
            enabled: true,
            onEnabledChanged: (_) {},
            timeOfDay: 'morning',
            onTimeOfDayChanged: (_) {},
            dayCount: dayCount,
            onDayCountChanged: (_) {},
            shortTermBond: 0,
            onShortTermBondChanged: (_) {},
            longTermBond: 0,
            onLongTermBondChanged: (_) {},
            trustLevel: 0,
            onTrustLevelChanged: (_) {},
            emotion: emotion,
            onEmotionChanged: (_) {},
            emotionIntensity: 'mild',
            onEmotionIntensityChanged: (_) {},
            nsfwCooldownEnabled: false,
            onNsfwCooldownChanged: (_) {},
            chaosModeEnabled: false,
            onChaosModeChanged: (_) {},
            ambitions: const [],
            onAmbitionsChanged: (_) {},
            realismVerificationEnabled: false,
            onRealismVerificationChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(form('curious', 1));
    await tester.pumpAndSettle();

    List<TextEditingController?> controllers() => tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.controller)
        .toList();

    final before = controllers();
    expect(
      before.length,
      greaterThanOrEqualTo(2),
      reason: 'Emotion and Day Number are both text fields',
    );

    // A rebuild with unchanged values — one keystroke elsewhere in the form
    // does this, and it must not swap the controllers out.
    await tester.pumpWidget(form('curious', 1));
    await tester.pumpAndSettle();

    final after = controllers();
    expect(after.length, before.length);
    for (var i = 0; i < before.length; i++) {
      expect(
        identical(before[i], after[i]),
        isTrue,
        reason: 'field $i was handed a fresh controller by build(), which '
            'discards the caret and any IME composing region',
      );
    }
  });
}
