// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Hours is the story-time dial, twice. There is no free-text Hours field
// and period words never appear on the chips.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/widgets/work_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester, {
    String occupation = 'librarian',
    String occupationBrief = '',
    String hours = '',
    ValueChanged<String>? onOccupationChanged,
    ValueChanged<String>? onOccupationBriefChanged,
    ValueChanged<String>? onHoursChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkRow(
            occupation: occupation,
            occupationBrief: occupationBrief,
            hours: hours,
            onOccupationChanged: onOccupationChanged ?? (_) {},
            onOccupationBriefChanged: onOccupationBriefChanged ?? (_) {},
            onHoursChanged: onHoursChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('Occupation title binds the real WorkRow field', (tester) async {
    String? written;
    await pump(
      tester,
      occupation: 'librarian',
      onOccupationChanged: (v) => written = v,
    );

    expect(find.text('Occupation'), findsOneWidget);
    expect(find.byKey(const ValueKey('work-occupation')), findsOneWidget);
    expect(find.text('librarian'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('work-occupation')),
      'lighthouse keeper',
    );
    expect(written, 'lighthouse keeper');
  });

  testWidgets('What the job is binds occupationBrief on WorkRow', (
    tester,
  ) async {
    String? written;
    await pump(
      tester,
      occupationBrief: 'shelves returns',
      onOccupationBriefChanged: (v) => written = v,
    );

    expect(find.text('What the job is'), findsOneWidget);
    expect(find.byKey(const ValueKey('work-brief')), findsOneWidget);
    expect(find.text('shelves returns'), findsOneWidget);
    expect(
      find.text('Grounds at-work narration. Not a lorebook. Empty is today.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('work-brief')),
      'Keeps the lamp and logs the ships',
    );
    expect(written, 'Keeps the lamp and logs the ships');
  });

  testWidgets('empty brief still shows the field, not a dropped box', (
    tester,
  ) async {
    await pump(tester, occupationBrief: '');

    expect(find.byKey(const ValueKey('work-brief')), findsOneWidget);
    expect(find.text('What the job is'), findsOneWidget);
    expect(find.text('shelves returns'), findsNothing);
  });

  testWidgets('Hours is two chips, not a text field', (tester) async {
    await pump(tester, hours: '9am–5pm');

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('e.g. 9–5'), findsNothing);
    expect(find.byKey(const ValueKey('work-occupation')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-brief')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-end')), findsOneWidget);
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('5:00 PM'), findsOneWidget);
    expect(find.text('What the job is'), findsOneWidget);
  });

  testWidgets('mornings is not shown; unset chips say Set', (tester) async {
    await pump(tester, hours: 'mornings');

    expect(find.text('mornings'), findsNothing);
    expect(find.text('Set'), findsNWidgets(2));
    expect(find.text('9:00 AM'), findsNothing);
  });

  testWidgets('Start chip opens the story-time dial', (tester) async {
    String? written;
    await pump(tester, hours: '9am–5pm', onHoursChanged: (v) => written = v);

    await tester.tap(find.byKey(const ValueKey('work-start')));
    await tester.pumpAndSettle();

    expect(find.text('Shift starts at…'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(written, '9am–5pm');
  });

  testWidgets('confirming an unset row writes a clock range', (tester) async {
    String? written;
    await pump(tester, hours: 'mornings', onHoursChanged: (v) => written = v);

    await tester.tap(find.byKey(const ValueKey('work-end')));
    await tester.pumpAndSettle();
    expect(find.text('Shift ends at…'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(written, '9am–5pm');
  });

  testWidgets('confirming a time replaces Set on the chips', (tester) async {
    await pump(tester, hours: '');

    expect(find.text('Set'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('work-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Set'), findsNothing);
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('5:00 PM'), findsOneWidget);
  });
}
