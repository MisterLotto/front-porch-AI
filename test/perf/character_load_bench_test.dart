// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Benchmark, not an assertion suite: measures the per-character work
// CharacterRepository.loadCharacters() performs for every row in the library.
// That loop sits between "the window appeared" and "the home grid is usable",
// and it was never measured — this prints the cost so a change to it can be
// judged against a number instead of a hunch.
//
// Tagged `perf` so the normal suite skips it (it needs a seeded library that
// only the perf harness creates). Run with:
//   FP_BENCH_DIR=~/Documents/FrontPorchAI flutter test --tags perf \
//     test/perf/character_load_bench_test.dart

@Tags(['perf'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:front_porch_ai/services/v2_card_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final root = Platform.environment['FP_BENCH_DIR'];

  test('per-character PNG parse cost (the loadCharacters inner loop)', () async {
    if (root == null) {
      markTestSkipped('set FP_BENCH_DIR to a seeded library root');
      return;
    }
    final dir = Directory(p.join(root, 'characters'));
    if (!dir.existsSync()) {
      markTestSkipped('no characters dir at ${dir.path}');
      return;
    }
    final pngs = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList();
    expect(pngs, isNotEmpty, reason: 'seed the library first');

    // Exactly what the loop does per character: a fresh V2CardService and a
    // full readCard() of the card PNG.
    final sw = Stopwatch()..start();
    var parsed = 0;
    for (final f in pngs) {
      final card = await V2CardService().readCard(f.path);
      if (card != null) parsed++;
    }
    sw.stop();

    final each = sw.elapsedMilliseconds / pngs.length;
    // ignore: avoid_print
    print(
      '[bench] readCard x${pngs.length}: ${sw.elapsedMilliseconds}ms total, '
      '${each.toStringAsFixed(2)}ms each ($parsed parsed)  '
      '-> projected ${(each * 500).round()}ms for a 500-character library',
    );

    final totalBytes = pngs.fold<int>(0, (a, f) => a + f.lengthSync());
    // ignore: avoid_print
    print(
      '[bench] whole-file reads: ${(totalBytes / 1e6).toStringAsFixed(1)}MB '
      'pulled off disk to reach a metadata chunk in the first few KB',
    );

    // The proposed fix: the 'chara' tEXt chunk sits in the PNG header region,
    // so a bounded prefix read finds it without pulling the multi-MB IDAT.
    // Measured here so the win is a number, not a claim.
    const prefix = 64 * 1024;
    final sw2 = Stopwatch()..start();
    var hits = 0;
    for (final f in pngs) {
      final handle = await f.open();
      try {
        final head = await handle.read(prefix);
        if (_hasCharaChunk(head)) hits++;
      } finally {
        await handle.close();
      }
    }
    sw2.stop();
    // ignore: avoid_print
    print(
      '[bench] 64KB prefix read x${pngs.length}: ${sw2.elapsedMilliseconds}ms '
      '($hits/${pngs.length} found the chunk in the prefix) '
      '-> ${(sw.elapsedMilliseconds / (sw2.elapsedMilliseconds == 0 ? 1 : sw2.elapsedMilliseconds)).toStringAsFixed(1)}x faster',
    );
  });
}

/// Cheap presence check for a `chara` tEXt chunk inside a PNG prefix.
bool _hasCharaChunk(List<int> bytes) {
  const needle = [0x63, 0x68, 0x61, 0x72, 0x61, 0x00]; // "chara\0"
  outer:
  for (var i = 0; i + needle.length <= bytes.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
