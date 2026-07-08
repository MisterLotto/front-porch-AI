// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Draw Things gRPC service — thin JSON CLI wrapper around the (untouched) Python client.py
/// Bundled via PyInstaller in release builds (Resources/dt_grpc/dt_grpc_client/...).
/// Falls back to python3 + dt_grpc_client.py for flutter run dev (requires `pip install -r tools/dt-grpc-python/requirements.txt` once).
class DrawThingsGrpcService {
  final String host;
  final int port;

  DrawThingsGrpcService({required this.host, this.port = 7859}) {
    debugPrint('DrawThingsGrpcService: host=$host port=$port (CLI sidecar)');
  }

  /// Runs one JSON request through the CLI sidecar and returns the parsed
  /// JSON response map, or null when the CLI failed / returned non-JSON.
  ///
  /// Consolidates the CLI resolution + spawn + stdin/stdout plumbing that was
  /// previously copy-pasted into testConnection/fetchModels/generateImage
  /// (three near-identical ~50-line blocks). Resolution order: the PyInstaller
  /// bundle (macOS Resources/dt_grpc/...) first, then the dev fallback of
  /// `python`/`python3 tools/dt-grpc-python/dt_grpc_client.py` found by
  /// walking up from the executable dir (mirrors the stt/kokoro pattern).
  Future<Map<String, dynamic>?> _runCli(
    Map<String, dynamic> request,
    Duration timeout,
  ) async {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    String? cliExe;
    String? pyScript;
    bool useWrapper = false;
    if (Platform.isMacOS) {
      final contents = File(Platform.resolvedExecutable).parent.parent.path;
      final bundled = p.join(
        contents,
        'Resources',
        'dt_grpc',
        'dt_grpc_client',
        'dt_grpc_client',
      );
      if (File(bundled).existsSync()) {
        cliExe = bundled;
        useWrapper = true;
      }
    }
    if (cliExe == null) {
      var dir = Directory(execDir);
      for (int i = 0; i < 12; i++) {
        final cand = File(
          p.join(dir.path, 'tools', 'dt-grpc-python', 'dt_grpc_client.py'),
        );
        if (cand.existsSync()) {
          pyScript = cand.path;
          break;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      if (pyScript == null) {
        final cwdCand = File(
          p.join(
            Directory.current.path,
            'tools',
            'dt-grpc-python',
            'dt_grpc_client.py',
          ),
        );
        if (cwdCand.existsSync()) pyScript = cwdCand.path;
      }
    }

    final process = await Process.start(
      useWrapper ? cliExe! : (Platform.isWindows ? 'python' : 'python3'),
      useWrapper ? [] : (pyScript != null ? [pyScript] : []),
      includeParentEnvironment: true,
    );
    process.stdin.writeln(jsonEncode(request));
    await process.stdin.close();

    final stdoutFut = process.stdout.transform(utf8.decoder).join();
    final stderrFut = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode.timeout(timeout);
    final stdoutStr = await stdoutFut;
    final stderrStr = await stderrFut;

    final filteredErr = stderrStr
        .split('\n')
        .where((l) => !l.contains('CERTIFICATE_VERIFY_FAILED'))
        .join('\n')
        .trim();
    if (filteredErr.isNotEmpty) {
      debugPrint('DrawThingsGrpcService: CLI stderr: $filteredErr');
    }

    // The CLI should emit exactly one clean JSON line on stdout, but if extra
    // prints leaked, fall back to the last JSON-looking line.
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(stdoutStr.trim()) as Map<String, dynamic>;
    } catch (_) {
      for (final line in stdoutStr.trim().split('\n').reversed) {
        final t = line.trim();
        if (t.startsWith('{') && t.endsWith('}')) {
          try {
            parsed = jsonDecode(t) as Map<String, dynamic>;
          } catch (_) {}
          break;
        }
      }
    }
    if (parsed == null || exitCode != 0 && parsed['success'] != true) {
      debugPrint(
        'DrawThingsGrpcService: CLI op=${request['op']} failed '
        '(exit $exitCode): $stdoutStr',
      );
    }
    return parsed;
  }

  /// Tests connection via the JSON CLI sidecar (bundled or dev fallback).
  Future<bool> testConnection() async {
    try {
      final parsed = await _runCli({
        'op': 'test',
        'host': host,
        'port': port,
      }, const Duration(seconds: 25));
      final ok = parsed?['success'] == true;
      debugPrint(
        'DrawThingsGrpcService: testConnection ${ok ? "OK" : "failed"}',
      );
      return ok;
    } catch (e) {
      debugPrint('DrawThingsGrpcService: testConnection error: $e');
      return false;
    }
  }

  /// Fetches checkpoint models via the JSON CLI sidecar (uses Draw Things Echo hack internally in CLI).
  Future<List<String>> fetchModels() async {
    try {
      final parsed = await _runCli({
        'op': 'models',
        'host': host,
        'port': port,
      }, const Duration(seconds: 25));
      if (parsed == null || parsed['success'] != true) return [];
      final raw = (parsed['models'] as List?)?.cast<String>() ?? <String>[];
      // Secondary filter on Dart side (defense in depth).
      // This mirrors the improved logic in dt_grpc_client.py.
      // We use broad category patterns so users don't have to manually
      // blacklist every VAE, upscaler (4x_ultrasharp, etc.), or preprocessor.
      final skip = [
        // Text encoders / CLIP / T5 / LLM encoders
        'clip', 't5', 'text_encoder', 'encoder', 'gemma', 'llama',
        'mistral', 'qwen', 'phi', 'chroma', 'ltx', 'vicuna', 'alpaca',

        // VAEs
        'vae',

        // Safety / NSFW filters
        'safety',

        // LoRAs
        'lora',

        // ControlNet + common preprocessors
        'controlnet', 'openpose', 'dwpose', 'pose', 'depth', 'canny',
        'normal', 'lineart', 'softedge', 'seg', 'inpaint', 'ip2p',
        'shuffle', 'mlsd', 'tile', 'blur', 'hed', 'parsenet',

        // Upscalers (catches most 4x_*, realesrgan, ultrasharp variants etc.)
        '4x_', '2x_', 'realesrgan', 'esrgan', 'ultrasharp', 'swinir',
        'hat_', 'real_esrgan', 'upscaler',

        // Video / I2V / motion models
        'i2v', 'video', 'wan_', 'svd', 'motion',
      ];
      // Trust the Python CLI's skip list primarily; include everything that is
      // not a known sidecar type so the dropdown populates even when Draw
      // Things reports bare names, .pth files, or paths.
      final models = raw.where((f) {
        final lower = f.toLowerCase();
        return !skip.any((k) => lower.contains(k));
      }).toList();

      debugPrint(
        'DrawThingsGrpcService: Fetched ${models.length} models via CLI (after filtering)',
      );
      return models;
    } catch (e) {
      debugPrint('DrawThingsGrpcService: fetchModels error: $e');
      return [];
    }
  }

  /// Fetches available LoRA files from Draw Things (op 'loras' — same
  /// Echo('models') listing the checkpoint fetch uses, filtered to LoRAs by
  /// the CLI). Returned names are passed verbatim into the generation
  /// config's `loras` list.
  Future<List<String>> fetchLoras() async {
    try {
      final parsed = await _runCli({
        'op': 'loras',
        'host': host,
        'port': port,
      }, const Duration(seconds: 25));
      if (parsed == null || parsed['success'] != true) return [];
      final loras = (parsed['loras'] as List?)?.cast<String>() ?? <String>[];
      debugPrint(
        'DrawThingsGrpcService: Fetched ${loras.length} LoRAs via CLI',
      );
      return loras;
    } catch (e) {
      debugPrint('DrawThingsGrpcService: fetchLoras error: $e');
      return [];
    }
  }

  /// Generates an image via the JSON CLI sidecar (full DT-native config passed through).
  /// referenceImageBytes: optional PNG/JPG/etc bytes for img2img (written to temp file for the Python client).
  /// loras: optional list of {'file': name, 'weight': double} maps applied natively by Draw Things.
  Future<Uint8List> generateImage({
    required String prompt,
    String negativePrompt = '',
    String model = '',
    int width = 1024,
    int height = 1024,
    int steps = 20,
    double cfgScale = 7.0,
    int seed = -1,
    double strength = 1.0,
    double shift = 3.0,
    int sampler = 16, // Sampler.DDIM_TRAILING default
    int seedMode = 2, // SeedMode.SCALE_ALIKE
    bool teaCache = false,
    double teaCacheThreshold = 0.15,
    bool cfgZeroStar = false,
    List<Map<String, dynamic>> loras = const [],
    Uint8List? referenceImageBytes,
  }) async {
    Directory? refTempDir;
    String? refImagePath;
    String? cliOutPath; // reported by CLI
    final tempRoot = await getTemporaryDirectory();

    try {
      // If reference image bytes supplied, write to a short-lived temp for the Python NNC encoder.
      // Use high-entropy name (timestamp + random) to reduce TOCTOU/predictability risk.
      if (referenceImageBytes != null && referenceImageBytes.isNotEmpty) {
        final rand =
            DateTime.now().millisecondsSinceEpoch ^
            (DateTime.now().microsecondsSinceEpoch % 100000);
        refTempDir = await Directory(
          p.join(tempRoot.path, 'dt_ref_$rand'),
        ).create(recursive: true);
        refImagePath = p.join(refTempDir.path, 'ref.png');
        await File(refImagePath).writeAsBytes(referenceImageBytes);
        debugPrint(
          'DrawThingsGrpcService: Wrote ${referenceImageBytes.length} byte reference image to temp',
        );
      }

      // Build rich config dict for the CLI (all DT-specific knobs)
      final cfg = {
        'model': model,
        'start_width': width ~/ 64,
        'start_height': height ~/ 64,
        'seed': (seed == -1 ? 0 : seed),
        'steps': steps,
        'guidance_scale': cfgScale,
        'strength': strength,
        'shift': shift,
        'sampler': sampler,
        'seed_mode': seedMode,
        'tea_cache': teaCache,
        'tea_cache_threshold': teaCacheThreshold,
        'cfg_zero_star': cfgZeroStar,
        'resolution_dependent_shift': false,
        'mask_blur': 1.5,
        'sharpness': 0.0,
        if (loras.isNotEmpty) 'loras': loras,
      };

      debugPrint(
        'DrawThingsGrpcService: generate (model=$model, '
        'loras=${loras.isEmpty ? "none" : loras.map((l) => l['file']).join(',')})',
      );
      final parsed = await _runCli({
        'op': 'generate',
        'host': host,
        'port': port,
        'prompt': prompt,
        'negative_prompt': negativePrompt,
        'config': cfg,
        'reference_image_path': ?refImagePath,
      }, const Duration(seconds: 300));

      if (parsed == null) {
        throw Exception('CLI returned no parseable response');
      }
      if (parsed['success'] != true) {
        throw Exception('Generation error from CLI: ${parsed['error']}');
      }

      cliOutPath = parsed['output_path'] as String?;
      if (cliOutPath == null || cliOutPath.isEmpty) {
        throw Exception('CLI did not return output_path');
      }

      final outFile = File(cliOutPath);
      if (!await outFile.exists()) {
        throw Exception('CLI output file missing at $cliOutPath');
      }
      final bytes = await outFile.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('CLI output file empty');
      }
      debugPrint(
        'DrawThingsGrpcService: Generated ${bytes.length} bytes via CLI (elapsed=${parsed['elapsed']})',
      );
      return bytes;
    } catch (e) {
      debugPrint('DrawThingsGrpcService: generateImage error: $e');
      rethrow;
    } finally {
      // Best-effort cleanup of any temps we created
      try {
        if (refTempDir != null && await refTempDir.exists()) {
          await refTempDir.delete(recursive: true);
        }
      } catch (_) {}
      try {
        if (cliOutPath != null) {
          final f = File(cliOutPath);
          if (await f.exists()) await f.delete();
          final parent = f.parent;
          if (await parent.exists() && (await parent.list().isEmpty)) {
            await parent.delete();
          }
        }
      } catch (_) {}
    }
  }
}
