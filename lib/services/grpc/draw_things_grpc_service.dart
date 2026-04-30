// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Progress update from image generation
class ImageGenProgress {
  final int step;
  final int totalSteps;
  final String message;

  const ImageGenProgress(this.step, this.totalSteps, {this.message = ''});
}

/// Draw Things gRPC service - uses Python client as bridge
class DrawThingsGrpcService {
  final String host;
  final int port;
  final String pythonPath;
  final String pythonClientDir;

  DrawThingsGrpcService({
    required this.host,
    this.port = 7859,
    this.pythonPath = 'python3',
    this.pythonClientDir = '/tmp/dt-grpc-python',
  });

  /// Tests connection to Draw Things via Python client
  Future<bool> testConnection() async {
    try {
      var script = '''
import sys
sys.path.insert(0, 'PYTHON_CLIENT_DIR')
from client import DrawThingsClient
client = DrawThingsClient('HOST', PORT)
try:
    result = client.echo('test')
    print('OK')
    sys.exit(0)
except Exception as e:
    print(str(e))
    sys.exit(1)
finally:
    client.close()
''';
      script = script.replaceAll('PYTHON_CLIENT_DIR', pythonClientDir);
      script = script.replaceAll('HOST', host);
      script = script.replaceAll('PORT', port.toString());

      final scriptFile = await _writePythonScript(script);
      debugPrint('DrawThingsGrpcService: Script:\n$script');
      
      final result = await _runWithTimeout(
        pythonPath,
        [scriptFile.path],
        const Duration(seconds: 30),
      );
      debugPrint('DrawThingsGrpcService: Exit code: ${result.exitCode}');
      debugPrint('DrawThingsGrpcService: Stdout: ${result.stdout}');
      debugPrint('DrawThingsGrpcService: Stderr: ${result.stderr}');
      await scriptFile.delete();

      if (result.exitCode == 0 && result.stdout.toString().trim() == 'OK') {
        debugPrint('DrawThingsGrpcService: Connection test passed');
        return true;
      } else {
        debugPrint('DrawThingsGrpcService: Connection test failed: ${result.stdout}');
        return false;
      }
    } catch (e) {
      debugPrint('DrawThingsGrpcService: Connection test error: $e');
      return false;
    }
  }

  /// Fetches available checkpoint models from Draw Things
  Future<List<String>> fetchModels() async {
    try {
      var script = '''
import sys, json
sys.path.insert(0, 'PYTHON_CLIENT_DIR')
from client import DrawThingsClient
import imageService_pb2 as pb2

client = DrawThingsClient('HOST', PORT)
try:
    client._connect()
    response = client._stub.Echo(pb2.EchoRequest(name='models'))
    files = []
    for f in response.files:
        lower = f.lower()
        if any(x in lower for x in ['lora', 'controlnet', 'clip', 't5', 'encoder', 'gemma', 'llama', 'mistral', 'qwen', 'phi', 'chroma', 'ltx', 'vicuna', 'alpaca']):
            continue
        if f.endswith('.ckpt'):
            files.append(f)
    print(json.dumps(files))
except Exception as e:
    print('[]')
finally:
    client.close()
''';
      script = script.replaceAll('PYTHON_CLIENT_DIR', pythonClientDir);
      script = script.replaceAll('HOST', host);
      script = script.replaceAll('PORT', port.toString());

      final scriptFile = await _writePythonScript(script);

      final result = await _runWithTimeout(
        pythonPath,
        [scriptFile.path],
        const Duration(seconds: 30),
      );
      await scriptFile.delete();

      if (result.exitCode == 0) {
        final files = jsonDecode(result.stdout.toString()) as List;
        final checkpoints = files.cast<String>();
        debugPrint('DrawThingsGrpcService: Fetched ${checkpoints.length} models');
        return checkpoints;
      } else {
        debugPrint('DrawThingsGrpcService: fetchModels failed: ${result.stdout}');
        return [];
      }
    } catch (e) {
      debugPrint('DrawThingsGrpcService: fetchModels error: $e');
      return [];
    }
  }

  /// Generates an image via Python client bridge
  Future<Uint8List> generateImage({
    required String prompt,
    String negativePrompt = '',
    String model = '',
    int width = 1024,
    int height = 1024,
    int steps = 20,
    double cfgScale = 7.0,
    int seed = -1,
    Function(ImageGenProgress)? onProgress,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('dt_gen_');
    final outputPath = '${tempDir.path}/output.png';

    var script = '''
import sys, json, os
sys.path.insert(0, 'PYTHON_CLIENT_DIR')
from client import DrawThingsClient, GenerationConfig, Sampler, SeedMode

client = DrawThingsClient('HOST', PORT)
try:
    config = GenerationConfig(
        model='MODEL',
        start_width=WIDTH_DIV64,
        start_height=HEIGHT_DIV64,
        seed=SEED,
        steps=STEPS,
        guidance_scale=CFG_SCALE,
        strength=1.0,
        shift=3.0,
        sampler=Sampler.DDIM_TRAILING,
        seed_mode=SeedMode.SCALE_ALIKE,
        refiner_start=0.1,
        resolution_dependent_shift=False,
        mask_blur=1.5,
        sharpness=0.0,
    )
    
    result = client.generate(
        config=config,
        prompt='PROMPT',
        negative_prompt='NEGATIVE_PROMPT',
        verbose=True,
    )
    
    if result.images:
        img_data = result.images[0]
        with open('OUTPUT_PATH', 'wb') as f:
            f.write(img_data)
            f.flush()
            os.fsync(f.fileno())
        print('SUCCESS')
    else:
        print('NO_IMAGE')
except Exception as e:
    print('ERROR: ' + str(e))
finally:
    client.close()
''';

    script = script.replaceAll('PYTHON_CLIENT_DIR', pythonClientDir);
    script = script.replaceAll('HOST', host);
    script = script.replaceAll('PORT', port.toString());
    script = script.replaceAll('MODEL', model);
    script = script.replaceAll('WIDTH_DIV64', (width ~/ 64).toString());
    script = script.replaceAll('HEIGHT_DIV64', (height ~/ 64).toString());
    script = script.replaceAll('SEED', (seed == -1 ? 0 : seed).toString());
    script = script.replaceAll('STEPS', steps.toString());
    script = script.replaceAll('CFG_SCALE', cfgScale.toString());
    script = script.replaceAll('PROMPT', prompt.replaceAll("'", "\\'"));
    script = script.replaceAll('NEGATIVE_PROMPT', negativePrompt.replaceAll("'", "\\'"));
    script = script.replaceAll('OUTPUT_PATH', outputPath);

    debugPrint('DrawThingsGrpcService: Generated Python script:\n$script');

    final scriptFile = await _writePythonScript(script);

    try {
      final result = await _runWithTimeout(
        pythonPath,
        [scriptFile.path],
        const Duration(seconds: 300),
      );

      debugPrint('DrawThingsGrpcService: Python exit code: ${result.exitCode}');
      debugPrint('DrawThingsGrpcService: Python stdout: ${result.stdout}');
      if (result.stderr.isNotEmpty) {
        debugPrint('DrawThingsGrpcService: Python stderr: ${result.stderr}');
      }

      await scriptFile.delete();

      if (result.exitCode != 0 || !result.stdout.toString().contains('SUCCESS')) {
        throw Exception('Generation failed: ${result.stdout}');
      }

      final file = File(outputPath);
      if (!await file.exists()) {
        throw Exception('Output file not created');
      }

      final fileSize = await file.length();
      debugPrint('DrawThingsGrpcService: Output file size: $fileSize bytes');
      final bytes = await file.readAsBytes();
      debugPrint('DrawThingsGrpcService: Read ${bytes.length} bytes');
      return bytes;
    } finally {
      // Clean up temp directory
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<File> _writePythonScript(String content) async {
    final tempDir = await Directory.systemTemp.createTemp('dt_script_');
    final scriptFile = File('${tempDir.path}/script.py');
    await scriptFile.writeAsString(content);
    return scriptFile;
  }

  Future<ProcessResult> _runWithTimeout(
    String executable,
    List<String> arguments,
    Duration timeout,
  ) async {
    final process = await Process.start(executable, arguments);
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode.timeout(timeout);
    return ProcessResult(process.pid, exitCode, await stdout, stderr);
  }
}
