// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Zip codec for `.fpchat` packages (chat.json + optional images/).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'fpchat_format.dart';

const String kFpchatChatJsonName = 'chat.json';
const String kFpchatImagesDir = 'images/';

/// Build a `.fpchat` zip from [chatJson] and optional [images] (relative
/// path under images/ → bytes).
Uint8List encodeFpchatZip({
  required Map<String, dynamic> chatJson,
  Map<String, List<int>> images = const {},
}) {
  final archive = Archive();
  final jsonBytes = utf8.encode(jsonEncode(chatJson));
  archive.addFile(
    ArchiveFile(kFpchatChatJsonName, jsonBytes.length, jsonBytes),
  );
  for (final e in images.entries) {
    final name = e.key.startsWith(kFpchatImagesDir)
        ? e.key
        : '$kFpchatImagesDir${e.key}';
    archive.addFile(ArchiveFile(name, e.value.length, e.value));
  }
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

/// Decode a `.fpchat` zip (or raw JSON bytes of chat.json for convenience).
({Map<String, dynamic> chatJson, Map<String, List<int>> images})
    decodeFpchatBytes(Uint8List bytes) {
  // Raw JSON / ST JSONL (transcript-only) — not a zip.
  if (bytes.isNotEmpty && (bytes[0] == 0x7B /* { */ || bytes[0] == 0x5B)) {
    final text = utf8.decode(bytes);
    final jsonl = tryParseSillyTavernJsonl(text);
    if (jsonl != null) return (chatJson: jsonl, images: const {});
    final root = decodeChatJson(text);
    return (chatJson: root, images: const {});
  }

  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  Map<String, dynamic>? chatJson;
  final images = <String, List<int>>{};

  for (final file in archive.files) {
    if (!file.isFile) continue;
    final name = file.name.replaceAll('\\', '/');
    final data = file.content as List<int>;
    if (name == kFpchatChatJsonName || name.endsWith('/$kFpchatChatJsonName')) {
      chatJson = decodeChatJson(utf8.decode(data));
    } else if (name.startsWith(kFpchatImagesDir) ||
        name.contains('/$kFpchatImagesDir')) {
      final rel = name.contains(kFpchatImagesDir)
          ? name.substring(name.indexOf(kFpchatImagesDir) + kFpchatImagesDir.length)
          : name;
      if (rel.isNotEmpty) images[rel] = data;
    }
  }

  if (chatJson == null) {
    throw FormatException(
      'Invalid .$kFpchatExtension package: missing $kFpchatChatJsonName',
    );
  }
  return (chatJson: chatJson, images: images);
}
