// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Regression guard for the theme-preset dead-buttons bug: a CustomPaint whose
// background painter leaves hitTest at the CustomPainter default (null) is
// hit-test OPAQUE over its whole rect. The theme border overlay is drawn
// Positioned.fill over the message bubble, so with any of the 10 preset
// themes active it swallowed every tap underneath — edit, fork, delete, TTS,
// thought chips, greeting arrows. The fix is two-layered (IgnorePointer on
// the overlay + hitTest false on the shared painter base); this test pins the
// painter layer so a new painter can't silently reintroduce the bug.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/chat_components/bubbles/border_painters.dart';

void main() {
  test('every theme border painter refuses pointer hits', () {
    expect(borderPainterFactories, isNotEmpty);
    for (final entry in borderPainterFactories.entries) {
      final painter = entry.value(const Color(0xFFF5A623));
      // Probe corners and center — false everywhere, never null (the opaque
      // default) or true.
      for (final p in const [
        Offset.zero,
        Offset(100, 40),
        Offset(1, 1),
      ]) {
        expect(
          painter.hitTest(p),
          isFalse,
          reason:
              "'${entry.key}' painter must not intercept taps — a null/true "
              'hitTest makes the bubble border overlay eat every button under '
              'it when that theme preset is active',
        );
      }
    }
  });

  testWidgets('a button under a Positioned.fill border overlay stays tappable',
      (tester) async {
    var taps = 0;
    // Mirror the message bubble's exact stacking: content first, decorative
    // border overlay LAST (hit-tested first).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => taps++,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: borderPainterFactories['vine']!(
                        const Color(0xFFF5A623),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(taps, 1);
  });
}
