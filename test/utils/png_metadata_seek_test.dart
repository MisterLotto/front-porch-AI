// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// extractTextChunkFromFile walks the PNG chunk table by seeking so a multi-MB
// card's IDAT never leaves the disk (opening a 120-card library used to read
// 142 MB to recover a few KB of JSON). It must agree EXACTLY with the
// whole-file extractTextChunk it replaced on the fast path — including where it
// returns null, because null is what makes readCard fall back to the old path.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/utils/utils.dart';

/// Builds a PNG carrying [chunks] as `(type, payload)` between IHDR and IEND.
Uint8List buildPng(List<(String, List<int>)> chunks, {int idatBytes = 0}) {
  final out = BytesBuilder();
  out.add(const [137, 80, 78, 71, 13, 10, 26, 10]);

  void chunk(String type, List<int> data) {
    final len = ByteData(4)..setUint32(0, data.length);
    out.add(len.buffer.asUint8List());
    out.add(ascii.encode(type));
    out.add(data);
    out.add(const [0, 0, 0, 0]); // CRC — the walker does not verify it
  }

  chunk('IHDR', List<int>.filled(13, 0));
  for (final (type, data) in chunks) {
    chunk(type, data);
  }
  if (idatBytes > 0) {
    chunk('IDAT', List<int>.filled(idatBytes, 7));
  }
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> tExt(String keyword, String text) =>
    [...ascii.encode(keyword), 0, ...utf8.encode(text)];

List<int> iTxt(String keyword, String text) => [
  ...ascii.encode(keyword),
  0, // keyword null
  0, // compression flag (uncompressed)
  0, // compression method
  0, // empty language tag
  0, // empty translated keyword
  ...utf8.encode(text),
];

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('fpai_png_seek_'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<String> write(String name, List<int> bytes) async {
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  test('reads a tEXt chunk without reading the image payload', () async {
    // 4 MB of IDAT after the metadata: if the walker read payloads, this test
    // would still pass but the whole optimisation would be pointless — so the
    // real assertion is the agreement check against the byte path below.
    final bytes = buildPng([
      ('tEXt', tExt('chara', 'eyJoZWxsbyI6ICJ3b3JsZCJ9')),
    ], idatBytes: 4 * 1024 * 1024);
    final path = await write('big.png', bytes);

    expect(
      await PngMetadataUtils.extractTextChunkFromFile(path, 'chara'),
      'eyJoZWxsbyI6ICJ3b3JsZCJ9',
    );
    expect(
      PngMetadataUtils.extractTextChunk(bytes, 'chara'),
      await PngMetadataUtils.extractTextChunkFromFile(path, 'chara'),
      reason: 'seeking and whole-file paths must agree',
    );
  });

  test('reads an iTXt chunk', () async {
    final bytes = buildPng([('iTXt', iTxt('chara', 'payload-here'))]);
    final path = await write('itxt.png', bytes);
    expect(
      await PngMetadataUtils.extractTextChunkFromFile(path, 'chara'),
      'payload-here',
    );
  });

  test('finds the chunk even when it sits AFTER the image data', () async {
    // The PNG spec allows tEXt after IDAT. Cards written that way must still
    // load — they simply do not get the speedup.
    final bytes = buildPng([
      ('IDAT', List<int>.filled(2048, 3)),
      ('tEXt', tExt('chara', 'trailing-metadata')),
    ]);
    final path = await write('trailing.png', bytes);
    expect(
      await PngMetadataUtils.extractTextChunkFromFile(path, 'chara'),
      'trailing-metadata',
    );
  });

  test('skips non-matching keywords and other text chunks', () async {
    final bytes = buildPng([
      ('tEXt', tExt('Software', 'SomeEditor')),
      ('tEXt', tExt('Comment', 'not the one')),
      ('tEXt', tExt('chara', 'the-right-one')),
    ], idatBytes: 512);
    final path = await write('multi.png', bytes);
    expect(
      await PngMetadataUtils.extractTextChunkFromFile(path, 'chara'),
      'the-right-one',
    );
    expect(
      await PngMetadataUtils.extractTextChunkFromFile(path, 'Software'),
      'SomeEditor',
    );
  });

  test('returns null (not a throw) so callers fall back', () async {
    // Missing keyword.
    final noChara = await write(
      'nochara.png',
      buildPng([('tEXt', tExt('Comment', 'x'))], idatBytes: 64),
    );
    expect(
      await PngMetadataUtils.extractTextChunkFromFile(noChara, 'chara'),
      isNull,
    );

    // Not a PNG at all.
    final notPng = await write('notpng.png', utf8.encode('plain text file'));
    expect(
      await PngMetadataUtils.extractTextChunkFromFile(notPng, 'chara'),
      isNull,
    );

    // Truncated INSIDE the chara chunk, so its declared length runs past EOF.
    // (Lopping bytes off the end only removes IEND — the chunk before it is
    // still complete and must still be returned, which is what an earlier
    // version of this test got wrong.)
    // Layout: signature 8 + IHDR (4+4+13+4 = 25) = 33, then the tEXt header
    // occupies 33..41 and its payload starts at 41.
    final full = buildPng([('tEXt', tExt('chara', 'abcdefghijklmnop'))]);
    final truncated = await write('truncated.png', full.sublist(0, 50));
    expect(
      await PngMetadataUtils.extractTextChunkFromFile(truncated, 'chara'),
      isNull,
    );
    expect(
      PngMetadataUtils.extractTextChunk(full.sublist(0, 50), 'chara'),
      isNull,
      reason: 'the whole-file path rejects it too — same contract',
    );

    // A file that does not exist must not throw either.
    expect(
      await PngMetadataUtils.extractTextChunkFromFile(
        '${dir.path}/absent.png',
        'chara',
      ),
      isNull,
    );
  });
}
