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

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:front_porch_ai/services/model_fetch.dart';
import 'package:front_porch_ai/services/tts/piper_voice_import.dart';
import 'package:front_porch_ai/services/tts/sherpa_piper_engine.dart';

/// IO half of custom Piper voice import (the pure converters live in
/// piper_voice_import.dart): materializes the sherpa bundle layout from a
/// raw `.onnx` + `.onnx.json` pair and registers the voice. Extracted from
/// VoiceManager to keep that file under the 500-line cap.

/// Import a CUSTOM raw Piper voice — a self-trained or community
/// `.onnx` + sibling `.onnx.json` pair with no sherpa re-export. Converts
/// it on the fly into the exact bundle layout [SherpaPiperEngine] expects
/// (metadata-embedded model + tokens.txt + shared espeak-ng-data; see
/// piper_voice_import.dart for the contract and sources) and registers it
/// in the installed list. Returns the voice key. Throws [FormatException]
/// with a user-displayable message when the files are not a standard
/// espeak-based Piper voice. deleteVoice() already cleans these up like
/// any other voice.
Future<String> installCustomPiperVoice({
required String onnxPath,
required String root,
required Set<String> catalogKeys,
required Future<bool> Function(String key) isVoiceInstalled,
required String voicesDirPath,
}) async {
  final onnxFile = File(onnxPath);
  if (!await onnxFile.exists()) {
    throw FormatException('File not found: $onnxPath');
  }
  final configFile = File('$onnxPath.json');
  if (!await configFile.exists()) {
    throw FormatException(
      'No matching config found — expected "${p.basename(onnxPath)}.json" '
      'next to the model. Piper voices always ship as a .onnx + '
      '.onnx.json pair.',
    );
  }
  final Map<String, dynamic> config;
  try {
    config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    throw const FormatException('The .onnx.json file is not valid JSON.');
  }
  final invalid = validatePiperConfig(config);
  if (invalid != null) throw FormatException(invalid);

  // Voice key = file name, sanitized; suffixed on a catalog collision so
  // the sherpa bundle dir can never clash with an official voice's.
  var key = p
      .basenameWithoutExtension(onnxPath)
      .replaceAll(RegExp(r'[^A-Za-z0-9_+.\-]'), '-')
      // Dots pass the filter above, so strip leading ones — a file named
      // "...onnx" would otherwise key as ".." and escape the bundle dir
      // (and deleteVoice('..') would wipe the whole models tree). Trailing
      // dots go too: Windows rejects/strips them in file names.
      .replaceFirst(RegExp(r'^\.+'), '')
      .replaceFirst(RegExp(r'\.+$'), '');
  if (key.isEmpty || key == '.' || key == '..') key = 'custom-voice';
  // Never occupy an official voice's bundle path: suffix on a catalog
  // match, and (for the offline/no-catalog case) on an orphan bundle dir
  // — but NOT when the key is an installed voice, which must fall through
  // to the duplicate refusal below rather than silently multiplying as
  // key-custom, key-custom-custom, … on every re-import.
  if (catalogKeys.contains(key) ||
      (!await isVoiceInstalled(key) &&
          Directory(SherpaPiperEngine.modelDir(root, key)).existsSync())) {
    key = '$key-custom';
  }
  if (await isVoiceInstalled(key)) {
    throw FormatException(
      'A voice named "$key" is already installed. Rename the file to '
      'import it under a different name.',
    );
  }
  final bundleDir = Directory(SherpaPiperEngine.modelDir(root, key));
  await bundleDir.create(recursive: true);
  try {
    final sink = File(p.join(bundleDir.path, '$key.onnx')).openWrite();
    try {
      sink.add(await onnxFile.readAsBytes());
      sink.add(encodeOnnxMetadataProps(piperMetadataFor(config)));
    } finally {
      // Close BEFORE any cleanup: deleting a dir with an open sink leaves
      // locked partial files on Windows.
      await sink.close();
    }

    await File(
      p.join(bundleDir.path, 'tokens.txt'),
    ).writeAsString(tokensFromPiperConfig(config));

    await _ensureEspeakData(bundleDir.path, root);

    // Register LAST, so a failed import never lists a broken voice.
    await configFile.copy(p.join(voicesDirPath, '$key.onnx.json'));
  } catch (_) {
    // Leave nothing half-installed.
    if (await bundleDir.exists()) await bundleDir.delete(recursive: true);
    rethrow;
  }
  return key;
}

/// Provision `espeak-ng-data/` for a custom bundle: copied from any
/// already-installed sherpa bundle (free, and byte-identical — one tree
/// serves every Piper voice), else downloaded once from sherpa's
/// standalone release artifact.
Future<void> _ensureEspeakData(String bundlePath, String root) async {
  final dst = Directory(p.join(bundlePath, 'espeak-ng-data'));
  if (await dst.exists()) return;
  final sherpaRoot = Directory(
    p.join(root, 'system', 'piper_models', 'sherpa'),
  );
  if (await sherpaRoot.exists()) {
    await for (final d in sherpaRoot.list()) {
      if (d is! Directory) continue;
      final src = Directory(p.join(d.path, 'espeak-ng-data'));
      // phontab is espeak-ng's core table — its presence separates a real
      // data tree from the empty/partial dir a broken download leaves.
      if (await src.exists() &&
          File(p.join(src.path, 'phontab')).existsSync()) {
        await _copyDir(src, dst);
        return;
      }
    }
  }
  await ModelFetch.fetchAndExtractTarBz2(
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
    'tts-models/espeak-ng-data.tar.bz2',
    dst.path,
  );
}

Future<void> _copyDir(Directory src, Directory dst) async {
  await dst.create(recursive: true);
  await for (final entity in src.list(recursive: true)) {
    final rel = p.relative(entity.path, from: src.path);
    if (entity is Directory) {
      await Directory(p.join(dst.path, rel)).create(recursive: true);
    } else if (entity is File) {
      await entity.copy(p.join(dst.path, rel));
    }
  }
}
