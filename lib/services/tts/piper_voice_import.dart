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

/// Pure transforms that turn a RAW Piper voice (`.onnx` + `.onnx.json`, as
/// published on rhasspy/piper-voices or produced by piper training) into the
/// exact artifacts sherpa-onnx's vits loader requires — the same contract as
/// sherpa's own `vits-piper-*` re-export bundles, produced on the fly:
///
///  * `tokens.txt` derived from the config's `phoneme_id_map`
///    (`{phoneme} {id}` per line — byte-for-byte what sherpa's official
///    conversion script writes; the id is the FIRST element of the map's
///    list value).
///  * The required ONNX metadata (`sample_rate`, `n_speakers`, `language`,
///    `comment` containing "piper" — which also selects the piper inference
///    path — plus `voice`, `model_type`, `has_espeak`), embedded by
///    APPENDING protobuf `metadata_props` entries (ModelProto field 14) to
///    the model bytes. Appending repeated fields is valid protobuf, so no
///    ONNX/protobuf dependency is needed. Raw piper exports carry none of
///    these keys, so appends cannot conflict.
///
/// References: sherpa's piper conversion docs (k2-fsa.github.io/sherpa/onnx/
/// tts/piper.html) and offline-tts-vits-model.cc's Init() metadata reads.
/// Verified independently by two reviewers 2026-07-25.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Returns a human-readable reason the config cannot be imported, or null
/// when it looks like a standard espeak-phonemized Piper voice.
String? validatePiperConfig(Map<String, dynamic> config) {
  final phonemeType = config['phoneme_type'];
  if (phonemeType != null && phonemeType != 'espeak') {
    return 'Unsupported phonemizer "$phonemeType" — only standard '
        'espeak-based Piper voices can be imported.';
  }
  final idMap = config['phoneme_id_map'];
  if (idMap is! Map || idMap.isEmpty) {
    return 'The .onnx.json has no phoneme_id_map — not a Piper voice config.';
  }
  for (final v in idMap.values) {
    if (v is! List || v.isEmpty || v.first is! num) {
      return 'phoneme_id_map has an unexpected shape — not a standard '
          'Piper voice config.';
    }
  }
  final sampleRate = (config['audio'] as Map?)?['sample_rate'];
  if (sampleRate is! num || sampleRate <= 0) {
    return 'The .onnx.json has no audio.sample_rate.';
  }
  final espeakVoice = (config['espeak'] as Map?)?['voice'];
  if (espeakVoice is! String || espeakVoice.isEmpty) {
    return 'The .onnx.json has no espeak.voice (needed for pronunciation).';
  }
  return null;
}

/// `tokens.txt` content from a validated Piper config: one `{phoneme} {id}`
/// line per phoneme_id_map entry, insertion order preserved, trailing
/// newline — identical to sherpa's official conversion output.
String tokensFromPiperConfig(Map<String, dynamic> config) {
  final idMap = config['phoneme_id_map'] as Map;
  final buf = StringBuffer();
  for (final entry in idMap.entries) {
    final id = (entry.value as List).first as num;
    buf.write('${entry.key} ${id.toInt()}\n');
  }
  return buf.toString();
}

/// The ONNX metadata entries sherpa's vits loader needs, keyed from the
/// Piper config. All values are strings (ONNX metadata_props are
/// string→string, matching sherpa's own conversion).
Map<String, String> piperMetadataFor(Map<String, dynamic> config) {
  final language = (config['language'] as Map?)?['name_english'] as String? ??
      (config['language'] as Map?)?['code'] as String? ??
      'unknown';
  return {
    'model_type': 'vits',
    'comment': 'piper', // must contain "piper" — selects the piper path
    'language': language,
    'voice': (config['espeak'] as Map)['voice'] as String,
    'has_espeak': '1',
    'n_speakers': ((config['num_speakers'] as num?) ?? 1).toInt().toString(),
    'sample_rate':
        ((config['audio'] as Map)['sample_rate'] as num).toInt().toString(),
  };
}

/// Encodes [metadata] as ModelProto `metadata_props` wire bytes (repeated
/// field 14 of StringStringEntryProto{key=1, value=2}) — appending these to
/// an .onnx file's bytes adds the entries to the model.
Uint8List encodeOnnxMetadataProps(Map<String, String> metadata) {
  final out = BytesBuilder();
  for (final e in metadata.entries) {
    final key = utf8.encode(e.key);
    final value = utf8.encode(e.value);
    final inner = BytesBuilder()
      ..addByte(0x0A) // field 1 (key), length-delimited
      ..add(_varint(key.length))
      ..add(key)
      ..addByte(0x12) // field 2 (value), length-delimited
      ..add(_varint(value.length))
      ..add(value);
    final innerBytes = inner.toBytes();
    out
      ..addByte(0x72) // field 14 (metadata_props), length-delimited
      ..add(_varint(innerBytes.length))
      ..add(innerBytes);
  }
  return out.toBytes();
}

List<int> _varint(int n) {
  final out = <int>[];
  var v = n;
  while (v > 0x7F) {
    out.add((v & 0x7F) | 0x80);
    v >>= 7;
  }
  out.add(v);
  return out;
}
