// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Audit P3: SettingsMenuItem was hard-coded Colors.white / white70, so the
// Main Settings popup (AppColors.surfaceContainerOf paper in light mode) showed
// near-invisible white-on-warm-paper labels. Guard both brightnesses.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/chat_components/widgets/settings_menu_item.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

void main() {
  Future<BuildContext> pumpItem(WidgetTester t, Brightness b) async {
    late BuildContext captured;
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: b),
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              captured = ctx;
              return const SettingsMenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit Character',
              );
            },
          ),
        ),
      ),
    );
    return captured;
  }

  testWidgets('light mode uses dark ink (not white-on-paper)', (t) async {
    final ctx = await pumpItem(t, Brightness.light);
    final icon = t.widget<Icon>(find.byIcon(Icons.edit_outlined));
    final text = t.widget<Text>(find.text('Edit Character'));
    expect(icon.color, AppColors.iconSecondary(ctx));
    expect(text.style?.color, AppColors.textPrimary(ctx));
    // The regression: pure white was invisible on lightSurface paper.
    expect(icon.color, isNot(Colors.white70));
    expect(text.style?.color, isNot(Colors.white));
  });

  testWidgets('dark mode keeps light ink', (t) async {
    final ctx = await pumpItem(t, Brightness.dark);
    final icon = t.widget<Icon>(find.byIcon(Icons.edit_outlined));
    final text = t.widget<Text>(find.text('Edit Character'));
    expect(icon.color, AppColors.iconSecondary(ctx));
    expect(text.style?.color, AppColors.textPrimary(ctx));
    expect(icon.color, Colors.white70);
    expect(text.style?.color, Colors.white);
  });
}
