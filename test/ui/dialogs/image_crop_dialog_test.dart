// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// The blank-slate ImageCropDialog (2026-08-14): real gesture → real saved
// bytes. The Discord report's exact failure — the preview showing one thing
// and the save producing another — is only catchable end-to-end, so these
// drive the dialog with pointer drags and decode what pops out.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:front_porch_ai/ui/dialogs/dialogs.dart';
import 'package:front_porch_ai/utils/utils.dart';

Uint8List _png(int w, int h) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(200, 10, 10));
  return img.encodePng(im);
}

void main() {
  // Simpler harness: open, interact via callback, then resolve.
  Future<Uint8List?> run(
    WidgetTester tester,
    Uint8List bytes,
    Future<void> Function() interact,
  ) async {
    Uint8List? result;
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ImageCropDialog.show(context, imageBytes: bytes);
              popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Bounded wait for the real-async image decode (the spinner animates,
    // so pumpAndSettle would spin forever if it caught the loading state).
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.text('Crop Your Image').evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    expect(find.text('Crop Your Image'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'the image must finish decoding');

    await interact();

    for (var i = 0; i < 60 && !popped; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(popped, isTrue, reason: 'the dialog must resolve');
    return result;
  }

  testWidgets('save with the default full-image box returns the image '
      'unchanged in size', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = await run(tester, _png(64, 64), () async {
      await tester.tap(find.text('Crop & Save'));
    });
    final decoded = img.decodePng(out!)!;
    expect(decoded.width, 64);
    expect(decoded.height, 64);
  });

  testWidgets('dragging the top-left corner inward crops smaller — the saved '
      'bytes match what the box showed', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = await run(tester, _png(64, 64), () async {
      final stage = find.byKey(const ValueKey('crop_stage'));
      final rect = tester.getRect(stage);
      // The image is contain-fit and centered; its top-left corner in the
      // stage is where the crop box's top-left handle sits. Compute it the
      // same way the dialog does.
      final inset = 0.15 * rect.size.shortestSide;
      final imageVp = containFitRect(
        const Size(64, 64),
        (Offset.zero & rect.size).deflate(inset),
      );
      final start = rect.topLeft + imageVp.topLeft;
      // Drag the corner inward by a quarter of the displayed image.
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(Offset(imageVp.width / 4, imageVp.height / 4));
      await gesture.up();
      await tester.pump();
      await tester.tap(find.text('Crop & Save'));
    });
    final decoded = img.decodePng(out!)!;
    expect(decoded.width, closeTo(48, 2));
    expect(decoded.height, closeTo(48, 2));
  });

  testWidgets('dragging a corner PAST the image edge saves a larger canvas '
      'with the fill color — the pad-canvas replacement', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = await run(tester, _png(64, 64), () async {
      final stage = find.byKey(const ValueKey('crop_stage'));
      final rect = tester.getRect(stage);
      final inset = 0.15 * rect.size.shortestSide;
      final imageVp = containFitRect(
        const Size(64, 64),
        (Offset.zero & rect.size).deflate(inset),
      );
      final start = rect.topLeft + imageVp.topLeft;
      // Drag the top-left corner OUT into the fill margin by half the inset.
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(Offset(-inset / 2, -inset / 2));
      await gesture.up();
      await tester.pump();
      await tester.tap(find.text('Crop & Save'));
    });
    final decoded = img.decodePng(out!)!;
    expect(decoded.width, greaterThan(64));
    expect(decoded.height, greaterThan(64));
    // The overhang corner is the fill color; the image is still intact at
    // the opposite corner.
    final corner = decoded.getPixel(0, 0);
    expect([corner.r, corner.g, corner.b], [cropFillR, cropFillG, cropFillB]);
    final bottomRight = decoded.getPixel(decoded.width - 1, decoded.height - 1);
    expect([bottomRight.r, bottomRight.g, bottomRight.b], [200, 10, 10]);
  });

  testWidgets('Cancel pops null', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = await run(tester, _png(32, 32), () async {
      await tester.tap(find.text('Cancel'));
    });
    expect(out, isNull);
  });
}
