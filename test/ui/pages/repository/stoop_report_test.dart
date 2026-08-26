// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/backporch/backporch.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_report.dart';

BackporchUser _user({required bool verified}) => BackporchUser(
  id: 'u1',
  email: 'a@b.c',
  displayName: 'Tester',
  role: 'USER',
  ageVerified: true,
  emailVerified: verified,
  nsfwEnabled: false,
  acceptedPolicyVersion: '1.0',
  twoFactorEnabled: false,
);

void main() {
  testWidgets('unverified users never get the Report button', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoopReportControl(
            user: _user(verified: false),
            onReport: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.text('Report Character'), findsNothing);
    expect(find.text('Confirm email to report'), findsOneWidget);
    await tester.tap(find.text('Confirm email to report'));
    await tester.pump();
    expect(opened, isFalse);
    expect(find.textContaining('Confirm your email to report'), findsOneWidget);
  });

  testWidgets('verified users get Report Character', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoopReportControl(
            user: _user(verified: true),
            onReport: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.text('Report Character'), findsOneWidget);
    await tester.tap(find.text('Report Character'));
    expect(opened, isTrue);
  });

  testWidgets('empty reason keeps the dialog open', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StoopReportDialog())),
    );
    await tester.tap(find.text('Submit report'));
    await tester.pump();
    expect(find.text('Please add a reason.'), findsOneWidget);
    expect(find.text('Report this card'), findsOneWidget);
  });
}
