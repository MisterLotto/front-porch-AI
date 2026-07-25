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

// Custom Piper voice import: the pure converters (tokens.txt derivation +
// ONNX metadata_props wire encoding) and the VoiceManager end-to-end flow
// that materializes the sherpa bundle layout from a raw .onnx/.onnx.json
// pair — all offline (espeak-ng-data is copied from a pre-seeded sibling
// bundle, never downloaded, so no network in tests).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/tts/piper_voice_import.dart';
import 'package:front_porch_ai/services/voice_manager.dart';

/// StorageService with a deterministic root: the real one's async self-init
/// appends /FrontPorchAI to the (mocked) documents dir on its own schedule,
/// which races the importer's root resolution and defeats the offline
/// espeak-ng-data seeding below.
class _TestStorage extends StorageService {
  final String root;
  _TestStorage(this.root);
  @override
  String? get rootPath => root;
}

Map<String, dynamic> _validConfig() => {
      'audio': {'sample_rate': 22050},
      'espeak': {'voice': 'en-us'},
      'language': {'name_english': 'English', 'code': 'en_US'},
      'num_speakers': 1,
      'phoneme_type': 'espeak',
      'phoneme_id_map': {
        '_': [0],
        '^': [1],
        ' ': [3],
        'a': [4],
        'ɐ': [5],
      },
    };

/// Minimal protobuf reader for the appended metadata_props bytes: parses
/// repeated field-14 StringStringEntryProto{key=1,value=2} messages.
Map<String, String> _decodeMetadataProps(Uint8List bytes) {
  final out = <String, String>{};
  var i = 0;
  int readVarint() {
    var shift = 0, value = 0;
    while (true) {
      final b = bytes[i++];
      value |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return value;
      shift += 7;
    }
  }

  while (i < bytes.length) {
    expect(bytes[i++], 0x72, reason: 'expected field 14 tag');
    final len = readVarint();
    final end = i + len;
    String? key, value;
    while (i < end) {
      final tag = bytes[i++];
      final flen = readVarint();
      final s = utf8.decode(bytes.sublist(i, i + flen));
      i += flen;
      if (tag == 0x0A) key = s;
      if (tag == 0x12) value = s;
    }
    out[key!] = value!;
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('validatePiperConfig', () {
    test('standard espeak config passes', () {
      expect(validatePiperConfig(_validConfig()), isNull);
    });

    test('non-espeak phonemizer is rejected with a clear reason', () {
      final c = _validConfig()..['phoneme_type'] = 'text';
      expect(validatePiperConfig(c), contains('Unsupported phonemizer'));
    });

    test('missing pieces each produce a specific reason', () {
      expect(validatePiperConfig(_validConfig()..remove('phoneme_id_map')),
          contains('phoneme_id_map'));
      expect(validatePiperConfig(_validConfig()..['audio'] = {}),
          contains('sample_rate'));
      expect(validatePiperConfig(_validConfig()..['espeak'] = {}),
          contains('espeak.voice'));
    });
  });

  group('tokensFromPiperConfig', () {
    test('one "phoneme id" line per entry, order preserved, first id wins',
        () {
      final tokens = tokensFromPiperConfig(_validConfig());
      expect(tokens, '_ 0\n^ 1\n  3\na 4\nɐ 5\n');
    });
  });

  group('ONNX metadata append', () {
    test('all seven sherpa keys round-trip through the wire encoding', () {
      final meta = piperMetadataFor(_validConfig());
      final decoded = _decodeMetadataProps(encodeOnnxMetadataProps(meta));
      expect(decoded, {
        'model_type': 'vits',
        'comment': 'piper',
        'language': 'English',
        'voice': 'en-us',
        'has_espeak': '1',
        'n_speakers': '1',
        'sample_rate': '22050',
      });
    });

    test('language falls back to code, speakers default to one', () {
      final c = _validConfig()
        ..['language'] = {'code': 'de_DE'}
        ..remove('num_speakers');
      final meta = piperMetadataFor(c);
      expect(meta['language'], 'de_DE');
      expect(meta['n_speakers'], '1');
    });
  });

  group('VoiceManager.importCustomPiperVoice (end-to-end, offline)', () {
    late Directory tempRoot;
    late Directory srcDir;
    late VoiceManager vm;

    setUp(() async {
      tempRoot = Directory.systemTemp.createTempSync('fpai_piper_root_');
      srcDir = Directory.systemTemp.createTempSync('fpai_piper_src_');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempRoot.path;
        }
        return null;
      });
      SharedPreferences.setMockInitialValues({});
      vm = VoiceManager(_TestStorage(tempRoot.path));

      // Pre-seed a sibling installed bundle so espeak-ng-data is COPIED,
      // never downloaded (tests stay offline).
      final seeded = Directory(
        '${tempRoot.path}/system/piper_models/sherpa/seed-voice/espeak-ng-data',
      )..createSync(recursive: true);
      File('${seeded.path}/phontab').writeAsStringSync('seed');
    });

    tearDown(() {
      tempRoot.deleteSync(recursive: true);
      srcDir.deleteSync(recursive: true);
    });

    Future<String> writeVoiceFiles(String baseName) async {
      final onnx = File('${srcDir.path}/$baseName.onnx');
      await onnx.writeAsBytes([1, 2, 3, 4]);
      await File('${srcDir.path}/$baseName.onnx.json')
          .writeAsString(jsonEncode(_validConfig()));
      return onnx.path;
    }

    test('materializes the full sherpa bundle and registers the voice',
        () async {
      final key = await vm.importCustomPiperVoice(
        await writeVoiceFiles('My Voice v2'),
      );
      expect(key, 'My-Voice-v2', reason: 'spaces sanitized');

      final bundle =
          '${tempRoot.path}/system/piper_models/sherpa/$key';
      final model = File('$bundle/$key.onnx').readAsBytesSync();
      expect(model.length, greaterThan(4));
      expect(model.sublist(0, 4), [1, 2, 3, 4],
          reason: 'original model bytes are a strict prefix');
      expect(_decodeMetadataProps(Uint8List.fromList(model.sublist(4)))
              ['comment'],
          'piper');

      expect(File('$bundle/tokens.txt').readAsStringSync(),
          tokensFromPiperConfig(_validConfig()));
      expect(File('$bundle/espeak-ng-data/phontab').readAsStringSync(),
          'seed', reason: 'espeak data copied from the seeded bundle');
      expect(await vm.isVoiceInstalled(key), isTrue);
    });

    test('re-import of the same name is refused, nothing half-installed',
        () async {
      final path = await writeVoiceFiles('dupe');
      await vm.importCustomPiperVoice(path);
      await expectLater(
        vm.importCustomPiperVoice(path),
        throwsA(isA<FormatException>()),
      );
    });

    test('dot-only filenames cannot escape the bundle dir', () async {
      final key = await vm.importCustomPiperVoice(
        await writeVoiceFiles('..'),
      );
      expect(key, 'custom-voice',
          reason: 'a "...onnx" file must not key as ".." — that path would '
              'escape sherpa/ and a later delete would wipe the models tree');
      expect(
        Directory('${tempRoot.path}/system/piper_models/sherpa/custom-voice')
            .existsSync(),
        isTrue,
      );
    });

    test('missing .onnx.json is a clear FormatException', () async {
      final onnx = File('${srcDir.path}/lonely.onnx');
      await onnx.writeAsBytes([1]);
      await expectLater(
        vm.importCustomPiperVoice(onnx.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('invalid config aborts with nothing left behind', () async {
      final onnx = File('${srcDir.path}/bad.onnx');
      await onnx.writeAsBytes([1]);
      await File('${srcDir.path}/bad.onnx.json')
          .writeAsString(jsonEncode({'not': 'piper'}));
      await expectLater(
        vm.importCustomPiperVoice(onnx.path),
        throwsA(isA<FormatException>()),
      );
      expect(await vm.isVoiceInstalled('bad'), isFalse);
      expect(
        Directory('${tempRoot.path}/system/piper_models/sherpa/bad')
            .existsSync(),
        isFalse,
      );
    });
  });
}
