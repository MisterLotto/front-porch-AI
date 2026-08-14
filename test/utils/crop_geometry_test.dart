// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// The blank-slate crop's pure math (2026-08-14, replaced crop_your_image).
// What these pin, in order of what the Discord report actually hit:
//  - the compositor crops EXACTLY the requested source rect (no hidden zoom
//    level can exist — the rect IS the output), including rects that extend
//    beyond the image, where the overhang must be the crop fill color;
//  - drag math cannot invert the box, shrink it below the minimum, or
//    escape the visible world;
//  - hit-testing prefers corners over edges over move.
//
// Red-proven: with applyCropDrag's left-edge clamp loosened to ignore
// minSize, 'resize cannot invert or shrink below minSize' fails.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:front_porch_ai/utils/utils.dart';

void main() {
  group('containFitRect', () {
    test('portrait image in landscape viewport: contained, centered, '
        'aspect preserved', () {
      const image = Size(90, 160);
      final vp = const Offset(10, 20) & const Size(400, 200);
      final r = containFitRect(image, vp);
      expect(r.height, closeTo(200, 0.001));
      expect(r.width, closeTo(200 * 90 / 160, 0.001));
      expect(r.center.dx, closeTo(vp.center.dx, 0.001));
      expect(r.center.dy, closeTo(vp.center.dy, 0.001));
      // Numeric bounds — Rect.contains excludes the far edges, and the
      // fitted rect legitimately touches them.
      expect(r.left, greaterThanOrEqualTo(vp.left - 0.001));
      expect(r.top, greaterThanOrEqualTo(vp.top - 0.001));
      expect(r.right, lessThanOrEqualTo(vp.right + 0.001));
      expect(r.bottom, lessThanOrEqualTo(vp.bottom + 0.001));
    });

    test('small image scales UP to fit', () {
      final r = containFitRect(
        const Size(10, 10),
        Offset.zero & const Size(100, 80),
      );
      expect(r.width, closeTo(80, 0.001));
      expect(r.height, closeTo(80, 0.001));
    });
  });

  group('hitTestCropHandle', () {
    final crop = const Offset(100, 100) & const Size(200, 100);

    test('corners beat edges beat move; outside is null', () {
      expect(
        hitTestCropHandle(const Offset(102, 98), crop, 14),
        CropHandle.topLeft,
      );
      expect(
        hitTestCropHandle(const Offset(200, 102), crop, 14),
        CropHandle.top,
      );
      expect(
        hitTestCropHandle(const Offset(298, 150), crop, 14),
        CropHandle.right,
      );
      expect(
        hitTestCropHandle(const Offset(200, 150), crop, 14),
        CropHandle.move,
      );
      expect(hitTestCropHandle(const Offset(50, 50), crop, 14), isNull);
    });
  });

  group('applyCropDrag', () {
    final world = const Offset(-50, -50) & const Size(300, 300);
    final rect = const Offset(0, 0) & const Size(100, 100);

    test('move translates and clamps to the world', () {
      final moved = applyCropDrag(
        rect,
        CropHandle.move,
        const Offset(20, -10),
        world: world,
        minSize: 16,
      );
      expect(moved, const Offset(20, -10) & const Size(100, 100));

      final slammed = applyCropDrag(
        rect,
        CropHandle.move,
        const Offset(-500, -500),
        world: world,
        minSize: 16,
      );
      expect(slammed.topLeft, const Offset(-50, -50));
      expect(slammed.size, rect.size);
    });

    test('corner resize moves exactly its two edges', () {
      final r = applyCropDrag(
        rect,
        CropHandle.bottomRight,
        const Offset(30, 40),
        world: world,
        minSize: 16,
      );
      expect(r, Rect.fromLTRB(0, 0, 130, 140));
    });

    test('resize cannot invert or shrink below minSize', () {
      final r = applyCropDrag(
        rect,
        CropHandle.left,
        const Offset(500, 0), // drag the left edge way past the right edge
        world: world,
        minSize: 16,
      );
      expect(r.width, 16);
      expect(r.right, 100, reason: 'the right edge must not move');
    });

    test('a tiny image (world smaller than minSize) cannot crash the drag '
        'math — pixel-art avatars are real', () {
      // An 8×8 image scaled up ~50× to fit the stage: the world is ~10
      // source px across while the dialog's minSize floor is 16. Before the
      // 2026-08-14 guard, the clamp bounds inverted (hi < lo) and
      // num.clamp THREW mid-drag.
      final tinyWorld = const Rect.fromLTRB(-1.2, -1.0, 9.2, 9.0);
      final tinyRect = const Offset(0, 0) & const Size(8, 8);
      final r = applyCropDrag(
        tinyRect,
        CropHandle.left,
        const Offset(5, 0),
        world: tinyWorld,
        minSize: 16,
      );
      expect(r.width, greaterThan(0));
      expect(r.left, lessThan(r.right));

      // Rect hugging the world edge with an unreachable minSize: the edge
      // freezes instead of throwing.
      final hugging = const Offset(-1.2, -1.0) & const Size(4, 4);
      final r2 = applyCropDrag(
        hugging,
        CropHandle.right,
        const Offset(-500, 0),
        world: tinyWorld,
        minSize: 16,
      );
      expect(r2.left, lessThan(r2.right));
    });

    test('resize clamps to the world bounds', () {
      final r = applyCropDrag(
        rect,
        CropHandle.topLeft,
        const Offset(-500, -500),
        world: world,
        minSize: 16,
      );
      expect(r.topLeft, const Offset(-50, -50));
    });
  });

  group('aspect-locked drag', () {
    final world = const Offset(-100, -100) & const Size(400, 400);
    final rect = const Offset(0, 0) & const Size(100, 100);

    test('corner drag preserves the ratio exactly (dominant axis drives)', () {
      final r = applyCropDrag(
        rect,
        CropHandle.bottomRight,
        const Offset(60, 10),
        world: world,
        minSize: 16,
        aspect: 2.0, // twice as wide as tall
      );
      expect(r.topLeft, Offset.zero, reason: 'the anchor corner is fixed');
      expect(r.width / r.height, closeTo(2.0, 1e-9));
      expect(r.width, closeTo(160, 1e-9), reason: 'the x-delta dominates');
    });

    test('aspect drag clamps to the world without breaking the ratio', () {
      final r = applyCropDrag(
        rect,
        CropHandle.bottomRight,
        const Offset(5000, 5000),
        world: world,
        minSize: 16,
        aspect: 1.0,
      );
      expect(r.width / r.height, closeTo(1.0, 1e-9));
      expect(r.right, lessThanOrEqualTo(world.right + 1e-9));
      expect(r.bottom, lessThanOrEqualTo(world.bottom + 1e-9));
    });

    test('edge handles freeze under a locked aspect', () {
      final r = applyCropDrag(
        rect,
        CropHandle.right,
        const Offset(50, 0),
        world: world,
        minSize: 16,
        aspect: 1.0,
      );
      expect(r, rect);
    });
  });

  group('aspectFitRect', () {
    final world = const Offset(-100, -100) & const Size(400, 400);

    test('keeps the center, hits the ratio, stays in the world', () {
      final r = aspectFitRect(
        const Offset(10, 10) & const Size(120, 30),
        1.0,
        world: world,
        minSize: 16,
      );
      expect(r.width / r.height, closeTo(1.0, 1e-9));
      expect(r.center.dx, closeTo(70, 1e-6));
      expect(r.center.dy, closeTo(25, 1e-6));
      expect(world.left <= r.left && r.right <= world.right, isTrue);
    });

    test('a rect hugging the world edge shifts inside instead of leaking', () {
      final r = aspectFitRect(
        const Offset(-100, -100) & const Size(20, 200),
        1.0,
        world: world,
        minSize: 16,
      );
      expect(r.left, greaterThanOrEqualTo(world.left - 1e-9));
      expect(r.top, greaterThanOrEqualTo(world.top - 1e-9));
    });
  });

  group('cropWorldRect', () {
    test('triples a normal image and stays centered on it', () {
      final w = cropWorldRect(const Size(1000, 500));
      expect(w.width, 3000);
      expect(w.height, 1500);
      expect(w.center, const Offset(500, 250));
    });

    test('caps the world so the output cannot become a memory bomb', () {
      final w = cropWorldRect(const Size(6000, 6000));
      expect(w.width, kMaxCropOutputSide);
      expect(w.height, kMaxCropOutputSide);
    });
  });

  group('cropCompositeSync', () {
    Uint8List redSquarePng(int size) {
      final im = img.Image(width: size, height: size);
      img.fill(im, color: img.ColorRgb8(200, 10, 10));
      return img.encodePng(im);
    }

    test('an inside crop returns exactly those pixels', () {
      final out = img.decodePng(
        cropCompositeSync(<Object>[redSquarePng(8), 2, 2, 4, 4, 26, 26, 46, 255]),
      )!;
      expect(out.width, 4);
      expect(out.height, 4);
      final p = out.getPixel(0, 0);
      expect([p.r, p.g, p.b], [200, 10, 10]);
    });

    test('a crop extending beyond the image fills the overhang with the '
        'crop fill color and keeps the image where it belongs', () {
      // Crop from (-4,-4) to (12,12) over an 8×8 red image: a 16×16 output
      // whose corner is fill and whose center 8×8 is the red image.
      final out = img.decodePng(
        cropCompositeSync(<Object>[redSquarePng(8), -4, -4, 16, 16, 26, 26, 46, 255]),
      )!;
      expect(out.width, 16);
      expect(out.height, 16);
      final corner = out.getPixel(0, 0);
      expect(
        [corner.r, corner.g, corner.b],
        [cropFillR, cropFillG, cropFillB],
        reason: 'the overhang is the fill color',
      );
      final center = out.getPixel(8, 8);
      expect(
        [center.r, center.g, center.b],
        [200, 10, 10],
        reason: 'the image lands offset by the overhang',
      );
      final lastImagePx = out.getPixel(11, 11);
      expect([lastImagePx.r, lastImagePx.g, lastImagePx.b], [200, 10, 10]);
      final pastImage = out.getPixel(12, 12);
      expect(
        [pastImage.r, pastImage.g, pastImage.b],
        [cropFillR, cropFillG, cropFillB],
      );
    });

    test('white and transparent fills land in the saved pixels', () {
      final white = img.decodePng(
        cropCompositeSync(
          <Object>[redSquarePng(8), -4, -4, 16, 16, 255, 255, 255, 255],
        ),
      )!;
      final wc = white.getPixel(0, 0);
      expect([wc.r, wc.g, wc.b, wc.a], [255, 255, 255, 255]);

      final clear = img.decodePng(
        cropCompositeSync(
          <Object>[redSquarePng(8), -4, -4, 16, 16, 0, 0, 0, 0],
        ),
      )!;
      final cc = clear.getPixel(0, 0);
      expect(cc.a, 0, reason: 'the overhang is fully transparent');
      final center = clear.getPixel(8, 8);
      expect([center.r, center.g, center.b, center.a], [200, 10, 10, 255],
          reason: 'the image itself stays opaque');
    });

    test('undecodable bytes throw a FormatException, empty rect too', () {
      expect(
        () => cropCompositeSync(<Object>[Uint8List.fromList([1, 2, 3]), 0, 0, 4, 4, 26, 26, 46, 255]),
        throwsFormatException,
      );
      expect(
        () => cropCompositeSync(<Object>[redSquarePng(4), 0, 0, 0, 4, 26, 26, 46, 255]),
        throwsFormatException,
      );
    });
  });
}
