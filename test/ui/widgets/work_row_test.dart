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
    String hours = '',
    ValueChanged<String>? onHoursChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkRow(
            occupation: occupation,
            hours: hours,
            onOccupationChanged: (_) {},
            onHoursChanged: onHoursChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('Hours is two chips, not a text field', (tester) async {
    await pump(tester, hours: '9am–5pm');

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('e.g. 9–5'), findsNothing);
    expect(find.byKey(const ValueKey('work-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-end')), findsOneWidget);
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('5:00 PM'), findsOneWidget);
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
}
