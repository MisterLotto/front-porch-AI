// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

// "Current Task / Quest" is retired from character authoring; Ambitions took
// its place (approved Porch Life sketch §4).
//
// The two boxes sat next to each other and asked for the same kind of sentence,
// which is why authors typed a per-chat errand ("find the missing artifact")
// into a field baked permanently into the card. A quest belongs to a chat and
// lives in the sidebar's Objectives panel; an ambition belongs to the character
// and spans every chat they are ever in. Only one of those is a card property.
//
// This pins the swap where a user can see it: the editor offers ambitions and
// no longer offers the task box. The card FIELD survives untouched — see
// authored_task_import_test.dart for the half that keeps old cards whole.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/widgets/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps the shared realism form the way the character editors mount it,
  /// with the engine on so every optional section is rendered.
  Future<void> pumpForm(
    WidgetTester tester, {
    List<String>? ambitions = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RealismFormSection(
              enabled: true,
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
              ambitions: ambitions,
              onAmbitionsChanged: ambitions == null ? null : (_) {},
              realismVerificationEnabled: false,
              onRealismVerificationChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the character editor no longer offers a Current Task box', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(
      find.textContaining('Current task', findRichText: true),
      findsNothing,
      reason: 'the authoring surface is retired — a label left behind would '
          'still invite authors to bake a per-chat errand into the card',
    );
    // The box carried three pieces of copy. Any one of them surviving means it
    // is still on screen under a different heading.
    expect(find.text('Current Task / Quest'), findsNothing);
    expect(
      find.textContaining('Find the missing artifact'),
      findsNothing,
      reason: 'the placeholder taught the wrong lesson: it offered a per-chat '
          'errand as an example of a permanent card property',
    );
    expect(
      find.textContaining('initial quest or objective when a new conversation'),
      findsNothing,
    );
  });

  testWidgets('Ambitions is what stands in its place', (tester) async {
    await pumpForm(tester, ambitions: const ['open her own bakery']);

    expect(find.text('Ambitions'), findsOneWidget);
    expect(find.text('open her own bakery'), findsOneWidget);
    expect(
      find.byType(ChipListEditor),
      findsOneWidget,
      reason: 'chips, not a newline-encoded textarea — the whole point of the '
          'replacement',
    );
  });

  testWidgets('surfaces with no ambitions state render neither box', (
    tester,
  ) async {
    // The group-member card passes null: it has no ambitions state to edit.
    // It must not fall back to showing the retired task box.
    await pumpForm(tester, ambitions: null);

    expect(find.byType(ChipListEditor), findsNothing);
    expect(find.textContaining('Current task'), findsNothing);
  });
}
