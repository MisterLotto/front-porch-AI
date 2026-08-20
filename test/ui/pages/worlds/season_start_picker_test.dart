// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Season start is a month+day on a 365-day year. The stacked Jan/Feb
// dropdowns overflowed the climate dialog; this pins the existing
// showDatePicker (same calendar Story begins uses) instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/pages/worlds/worlds.dart';

void main() {
  testWidgets(
    'season start opens the calendar picker, not month/day dropdowns',
    (tester) async {
      var month = 3;
      var day = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeasonStartRow(
              month: month,
              day: day,
              onStart: (m, d) {
                month = m;
                day = d;
              },
            ),
          ),
        ),
      );

      expect(find.byType(DropdownButton<int>), findsNothing);
      expect(find.text('Mar 1'), findsOneWidget);

      await tester.tap(find.text('Mar 1'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(month, 3);
      expect(day, 15);
    },
  );
}
