// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Thumbnail generation (decode → resize → re-encode) is synchronous CPU work in
// package:image, and the web server shares the Flutter UI isolate — running it
// inline froze the desktop app for ~100ms+ per tile while a phone loaded the
// library grid. It now runs in a worker isolate, serialized by a single gate so
// a cold grid of N tiles cannot hold N fully-decoded cards in memory at once.
//
// Two properties that only that shape can break, and that the existing
// image_thumbnails_test.dart (single sequential calls) cannot see:
//  1. A FAILED generation must still release the gate, or one bad request
//     wedges every later thumbnail for the rest of the session.
//  2. Concurrent requests must each come back with their own correct bytes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:front_porch_ai/services/web/util/image_thumbnails.dart';

void main() {
  late Directory cacheDir;
  late Directory srcDir;
  late ThumbnailCache cache;

  setUp(() {
    cacheDir = Directory.systemTemp.createTempSync('fpa_thumb_gate_cache_');
    srcDir = Directory.systemTemp.createTempSync('fpa_thumb_gate_src_');
    cache = ThumbnailCache(cacheDir);
  });

  tearDown(() {
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
    if (srcDir.existsSync()) srcDir.deleteSync(recursive: true);
  });

  File writePng(String name, int w, int h) {
    final im = img.Image(width: w, height: h);
    img.fill(im, color: img.ColorRgb8(200, 140, 60));
    final f = File('${srcDir.path}${Platform.pathSeparator}$name');
    f.writeAsBytesSync(img.encodePng(im));
    return f;
  }

  test('a failed generation releases the gate for the next request', () async {
    final missing = File('${srcDir.path}${Platform.pathSeparator}gone.png');
    await expectLater(cache.bytesFor(missing, 128, 0), throwsA(anything));

    final ok = writePng('after.png', 400, 400);
    final thumb = await cache
        .bytesFor(ok, 128)
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw StateError(
            'the gate was never released — every later thumbnail request is '
            'wedged for the rest of the session',
          ),
        );
    expect(img.decodeImage(thumb.bytes)!.width, 128);
  });

  test('concurrent requests each get their own correct thumbnail', () async {
    final sources = [
      writePng('a.png', 600, 600),
      writePng('b.png', 800, 400),
      writePng('c.png', 500, 1000),
      writePng('d.png', 640, 480),
    ];

    final thumbs = await Future.wait([
      for (var i = 0; i < sources.length; i++)
        cache.bytesFor(sources[i], 64 + i * 32),
    ]);

    for (var i = 0; i < sources.length; i++) {
      final decoded = img.decodeImage(thumbs[i].bytes);
      expect(decoded, isNotNull, reason: 'source $i produced garbage bytes');
      expect(decoded!.width, 64 + i * 32);
    }
  });
}
