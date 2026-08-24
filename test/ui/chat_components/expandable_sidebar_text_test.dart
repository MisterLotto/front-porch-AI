// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/expandable_sidebar_text.dart';

void main() {
  testWidgets('long text clamps then expands on tap', (tester) async {
    const long =
        'This is a long journal memory that should wrap onto several '
        'lines in a narrow sidebar so the clamp has something to hide '
        'until the user taps it. Extra words keep it overflowing the '
        'four-line budget easily for the test font.';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: ExpandableSidebarText(text: long, maxLines: 4),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final clamped = tester.widget<Text>(find.byType(Text));
    expect(clamped.maxLines, 4);
    expect(clamped.overflow, TextOverflow.ellipsis);

    await tester.tap(find.byType(ExpandableSidebarText));
    await tester.pumpAndSettle();

    final expanded = tester.widget<Text>(find.byType(Text));
    expect(expanded.maxLines, isNull);
  });

  testWidgets('short text is not tappable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ExpandableSidebarText(text: 'Short.', maxLines: 4),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GestureDetector), findsNothing);
    expect(tester.widget<Text>(find.byType(Text)).maxLines, 4);
  });
}
