// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Work identity card: Ambitions chrome + What the job is bound to
// occupationBrief. Empty brief is allowed (today). No second key.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/identity_chip_lists.dart';
import 'package:front_porch_ai/ui/widgets/work_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCard(
    WidgetTester tester, {
    String occupation = 'librarian',
    String occupationBrief = '',
    String hours = '',
    ValueChanged<String>? onBrief,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IdentityChipLists(
              occupation: occupation,
              occupationBrief: occupationBrief,
              hours: hours,
              onOccupationChanged: (_) {},
              onOccupationBriefChanged: onBrief ?? (_) {},
              onHoursChanged: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Work uses Ambitions chrome, not a grey WORK stub', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('WORK'), findsNothing);
    expect(find.byIcon(Icons.work_outline), findsOneWidget);
    expect(find.byType(WorkRow), findsOneWidget);

    final title = tester.widget<Text>(find.text('Work'));
    expect(title.style?.color, AppColors.taskAccent);
    expect(title.style?.fontSize, 15);
    expect(title.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('What the job is binds occupationBrief', (tester) async {
    String? written;
    await pumpCard(
      tester,
      occupationBrief: 'shelves returns',
      onBrief: (v) => written = v,
    );

    expect(find.text('What the job is'), findsOneWidget);
    expect(find.byKey(const ValueKey('work-brief')), findsOneWidget);
    expect(find.text('shelves returns'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('work-brief')),
      'Keeps the lamp and logs the ships',
    );
    expect(written, 'Keeps the lamp and logs the ships');
  });

  testWidgets('Work card keeps title, brief, and hours together', (
    tester,
  ) async {
    await pumpCard(
      tester,
      occupation: 'lighthouse keeper',
      occupationBrief: 'Keeps the lamp and logs the ships',
      hours: '9am–5pm',
    );

    expect(find.text('Occupation'), findsOneWidget);
    expect(find.text('lighthouse keeper'), findsOneWidget);
    expect(find.text('What the job is'), findsOneWidget);
    expect(find.text('Keeps the lamp and logs the ships'), findsOneWidget);
    expect(find.byKey(const ValueKey('work-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-end')), findsOneWidget);
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('5:00 PM'), findsOneWidget);
  });

  testWidgets('Work is omitted without the brief callback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IdentityChipLists(
            occupation: 'librarian',
            hours: '9am–5pm',
            onOccupationChanged: _ignore,
            onHoursChanged: _ignore,
          ),
        ),
      ),
    );

    expect(find.text('Work'), findsNothing);
    expect(find.byType(WorkRow), findsNothing);
  });
}

void _ignore(String _) {}
