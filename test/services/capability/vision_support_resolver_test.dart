// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Proof tests for resolveForActiveLlm's local-backend branch — specifically
// the .kcpps fix: when a preset owns the model (lastUsedModelPath empty), the
// resolver must interrogate the PRESET's GGUF and honor the preset's own
// `mmproj` key, instead of returning a false-negative "none" (which used to
// suppress the chat photo attachment for every preset user). Uses the same
// synthetic-GGUF builder as gguf_vision_test.dart and a real StorageService
// over mock SharedPreferences (same harness as storage_service_test.dart).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/services/capability/model_capabilities.dart';
import 'package:front_porch_ai/services/capability/vision_support_resolver.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/services/storage_service.dart';

/// Build a minimal GGUF v3 file (string KVs + optional tensor names) — the
/// same shape gguf_vision_test.dart proves the parser against.
Uint8List _buildGguf({
  required Map<String, String> kv,
  List<String> tensorNames = const [],
}) {
  final builder = BytesBuilder();
  builder.add(utf8.encode('GGUF'));
  builder.add(_u32(3));
  builder.add(_u64(tensorNames.length));
  builder.add(_u64(kv.length));
  for (final entry in kv.entries) {
    final keyBytes = utf8.encode(entry.key);
    builder.add(_u64(keyBytes.length));
    builder.add(keyBytes);
    builder.add(_u32(8)); // string type
    final valBytes = utf8.encode(entry.value);
    builder.add(_u64(valBytes.length));
    builder.add(valBytes);
  }
  for (final name in tensorNames) {
    final nameBytes = utf8.encode(name);
    builder.add(_u64(nameBytes.length));
    builder.add(nameBytes);
    builder.add(_u32(1)); // n_dims
    builder.add(_u64(1)); // dim 0
    builder.add(_u32(0)); // ggml type
    builder.add(_u64(0)); // data offset
  }
  return Uint8List.fromList(builder.takeBytes());
}

Uint8List _u32(int v) => Uint8List(4)..buffer.asUint32List()[0] = v;
Uint8List _u64(int v) => Uint8List(8)..buffer.asUint64List()[0] = v;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // path_provider mock so StorageService._init() resolves a docs dir.
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_vsr_docs_').path;
        }
        return null;
      });

  Future<StorageService> createStorageService() async {
    SharedPreferences.setMockInitialValues({});
    final service = StorageService();
    await service.initialized;
    return service;
  }

  late Directory dir;

  setUp(() {
    VisionSupportResolver.instance.clear();
    dir = Directory.systemTemp.createTempSync('fpai_vsr_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File writeGguf(String name, Uint8List bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(bytes);

  File writeKcpps(Map<String, dynamic> json) =>
      File('${dir.path}/preset.kcpps')..writeAsStringSync(jsonEncode(json));

  group('resolveForActiveLlm — .kcpps preset (local backends)', () {
    test('preset-owned multimodal model + preset mmproj → supported', () async {
      final model = writeGguf(
        'qwen2vl.gguf',
        _buildGguf(kv: {'general.architecture': 'qwen2vl'}),
      );
      final mmproj = writeGguf('mmproj.gguf', Uint8List.fromList([1, 2, 3]));
      final kcpps = writeKcpps({
        'model_param': model.path,
        'mmproj': mmproj.path,
      });
      final storage = await createStorageService();
      await storage.setActiveKcppsPath(kcpps.path);

      final support = await VisionSupportResolver.instance.resolveForActiveLlm(
        backend: BackendType.kobold,
        storage: storage,
      );
      expect(support.supported, isTrue);
      expect(support.source, VisionSource.ggufWithMmproj);
    });

    test('preset-owned multimodal model, no mmproj anywhere → none', () async {
      final model = writeGguf(
        'qwen2vl.gguf',
        _buildGguf(kv: {'general.architecture': 'qwen2vl'}),
      );
      final kcpps = writeKcpps({'model_param': model.path});
      final storage = await createStorageService();
      await storage.setActiveKcppsPath(kcpps.path);

      final support = await VisionSupportResolver.instance.resolveForActiveLlm(
        backend: BackendType.kobold,
        storage: storage,
      );
      expect(support.supported, isFalse);
    });

    test('preset-owned model with embedded projector → supported '
        'without any mmproj', () async {
      final model = writeGguf(
        'gemma-vision.gguf',
        _buildGguf(
          kv: {'general.architecture': 'gemma3'},
          tensorNames: ['v.blk.0.attn_q.weight'],
        ),
      );
      final kcpps = writeKcpps({'model': model.path});
      final storage = await createStorageService();
      await storage.setActiveKcppsPath(kcpps.path);

      final support = await VisionSupportResolver.instance.resolveForActiveLlm(
        backend: BackendType.pseudoRemote,
        storage: storage,
      );
      expect(support.supported, isTrue);
      expect(support.source, VisionSource.ggufEmbedded);
    });

    test('preset model file missing on disk → falls back to '
        'lastUsedModelPath', () async {
      final pickerModel = writeGguf(
        'picker-vision.gguf',
        _buildGguf(
          kv: {'general.architecture': 'llama'},
          tensorNames: ['mm.model.fc.weight'],
        ),
      );
      final kcpps = writeKcpps({
        'model_param': '${dir.path}/deleted-model.gguf',
      });
      final storage = await createStorageService();
      await storage.setActiveKcppsPath(kcpps.path);
      await storage.setLastUsedModelPath(pickerModel.path);

      final support = await VisionSupportResolver.instance.resolveForActiveLlm(
        backend: BackendType.kobold,
        storage: storage,
      );
      expect(support.supported, isTrue);
      expect(support.source, VisionSource.ggufEmbedded);
    });

    test('no preset, no picker model → none', () async {
      final storage = await createStorageService();
      final support = await VisionSupportResolver.instance.resolveForActiveLlm(
        backend: BackendType.kobold,
        storage: storage,
      );
      expect(support, VisionSupport.none);
    });

    test('no preset: picker model + app-mapped mmproj still resolves '
        '(pre-fix behavior preserved)', () async {
      final model = writeGguf(
        'llava.gguf',
        _buildGguf(kv: {'general.architecture': 'llava'}),
      );
      final mmproj = writeGguf(
        'llava-mmproj.gguf',
        Uint8List.fromList([1, 2, 3]),
      );
      final storage = await createStorageService();
      await storage.setLastUsedModelPath(model.path);
      await storage.setModelMmproj(model.path, mmproj.path);

      final support = await VisionSupportResolver.instance.resolveForActiveLlm(
        backend: BackendType.kobold,
        storage: storage,
      );
      expect(support.supported, isTrue);
      expect(support.source, VisionSource.ggufWithMmproj);
    });
  });
}
