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

// AN ERROR BANNER WHOSE TEXT MATCHES ITS BACKGROUND IS NOT AN ERROR BANNER
// (maintainer screenshot, 2026-08-13: Image Studio showed a solid red bar —
// "Whatever the error is it can't even be read"). A color-sweep leftover had
// the banner painting background, icon and message all AppColors.logError in
// dark mode. Pixels were "correct" per the code, so only an assertion about
// the RELATIONSHIP between the two colors catches the class.
//
// Guard proven to fail before passing: with the message color set back to
// logError (the shipped bug), the contrast assert goes red.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/image_studio/generation_panel.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

void main() {
  testWidgets('error message is legible on the banner in dark mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: GenerationPanel(
            onGenerate: null,
            isGenerating: false,
            isCrafting: false,
            error: 'Connection refused: is the image backend running?',
            promptIsSane: true,
          ),
        ),
      ),
    );

    final banner = tester.widget<Container>(
      find.ancestor(
        of: find.textContaining('Connection refused'),
        matching: find.byType(Container),
      ),
    );
    final fill = (banner.decoration as BoxDecoration?)?.color;
    final text = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    final ink = text.style?.color;

    expect(fill, isNotNull);
    expect(ink, isNotNull);
    // The exact colors are free to change with the theme; what must never
    // come back is ink ≈ fill. Compare fully-opaque values so a tinted fill
    // of the same hue still fails (logError-on-logError-tint is the bug).
    expect(
      ink!.withValues(alpha: 1),
      isNot(fill!.withValues(alpha: 1)),
      reason: 'error text painted in the banner\'s own color is invisible — '
          'the exact unreadable red bar the maintainer screenshotted',
    );
    // And the message must not be the semantic red itself, which the tinted
    // background is derived from: same hue at two alphas reads as one blob.
    expect(
      ink.withValues(alpha: 1),
      isNot(AppColors.logError.withValues(alpha: 1)),
      reason: 'the icon carries the semantic red; the MESSAGE carries ink',
    );
  });
}
