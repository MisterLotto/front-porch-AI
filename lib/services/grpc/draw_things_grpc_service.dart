// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import 'image_service.pbgrpc.dart';
import 'draw_things_generated.dart';

class ImageGenProgress {
  final int step;
  final int totalSteps;
  final Uint8List? previewImage;

  const ImageGenProgress(this.step, this.totalSteps, {this.previewImage});
}

class DrawThingsGrpcService {
  final String host;
  final int port;
  final bool useTls;

  ClientChannel? _channel;
  ImageGenerationServiceClient? _client;

  DrawThingsGrpcService({
    required this.host,
    this.port = 7859,
    this.useTls = false,
  });

  void connect() {
    if (_channel != null) return;

    final targetHost = host.replaceAll('http://', '').replaceAll('https://', '').split(':')[0];

    // Draw Things uses self-signed TLS certs, so we need to accept untrusted certs
    final credentials = !useTls
        ? const ChannelCredentials.insecure()
        : ChannelCredentials.secure(
            onBadCertificate: allowBadCertificates,
          );

    _channel = ClientChannel(
      targetHost,
      port: port,
      options: ChannelOptions(
        credentials: credentials,
        // Some servers on Mac are picky about the authority (Host) header
        userAgent: 'FrontPorchAI/1.0',
      ),
    );
    _client = ImageGenerationServiceClient(_channel!);
  }

  Future<void> disconnect() async {
    await _channel?.shutdown();
    _channel = null;
    _client = null;
  }

  /// Tests connection by making an Hours request (no parameters required)
  Future<bool> testConnection() async {
    final targetHost = host.replaceAll('http://', '').replaceAll('https://', '').split(':')[0];
    try {
      debugPrint('DrawThingsGrpcService: Initializing channel to $targetHost:$port');
      connect();
      
      debugPrint('DrawThingsGrpcService: Sending Hours request (timeout 30s)...');
      final request = HoursRequest();
      final response = await _client!.hours(request, options: CallOptions(timeout: const Duration(seconds: 30)));

      debugPrint('DrawThingsGrpcService: Hours response received. hasThresholds=${response.hasThresholds()}');
      return true;
    } catch (e) {
      debugPrint('DrawThingsGrpcService: Hours request failed: $e');
      
      // Try Echo as a second attempt
      try {
        debugPrint('DrawThingsGrpcService: Sending Echo request as fallback (timeout 30s)...');
        final echoRequest = EchoRequest(name: 'FrontPorchAI', sharedSecret: '');
        final echoResponse = await _client!.echo(echoRequest, options: CallOptions(timeout: const Duration(seconds: 30)));
        debugPrint('DrawThingsGrpcService: Echo response received. message=${echoResponse.message}');
        return true;
      } catch (e2) {
        debugPrint('DrawThingsGrpcService: Echo fallback failed: $e2');
      }

      // If we failed with localhost, try 127.0.0.1 explicitly as a last resort
      if (targetHost == 'localhost') {
        try {
          debugPrint('DrawThingsGrpcService: Retrying EVERYTHING with 127.0.0.1...');
          await disconnect();

          final retryCredentials = !useTls
              ? const ChannelCredentials.insecure()
              : ChannelCredentials.secure(
                  onBadCertificate: allowBadCertificates,
                );

          _channel = ClientChannel(
            '127.0.0.1',
            port: port,
            options: ChannelOptions(
              credentials: retryCredentials,
              userAgent: 'FrontPorchAI/1.0',
            ),
          );
          _client = ImageGenerationServiceClient(_channel!);
          
          final request = HoursRequest();
          await _client!.hours(request, options: CallOptions(timeout: const Duration(seconds: 30)));
          return true;
        } catch (e2) {
          debugPrint('DrawThingsGrpcService: Final fallback to 127.0.0.1 failed: $e2');
        }
      }
      return false;
    }
  }

  /// Fetches available checkpoint models from the server
  Future<List<String>> fetchModels() async {
    try {
      connect();
      final request = EchoRequest(name: 'FrontPorchAI');
      final response = await _client!.echo(request, options: CallOptions(timeout: const Duration(seconds: 30)));

      List<String> checkpoints;

      // Try parsing the categorized override.models field first (proper SD checkpoints only)
      if (response.hasOverride() && response.override.models.isNotEmpty) {
        try {
          final modelJson = utf8.decode(response.override.models);
          final parsed = jsonDecode(modelJson);
          if (parsed is List) {
            checkpoints = parsed
                .whereType<Map<String, dynamic>>()
                .map((m) => m['name']?.toString() ?? m['title']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
            debugPrint('DrawThingsGrpcService: Parsed ${checkpoints.length} checkpoints from override.models');
            return checkpoints;
          }
        } catch (e) {
          debugPrint('DrawThingsGrpcService: Failed to parse override.models: $e');
        }
      }

      // Fallback: filter files list by excluding known non-checkpoint types
      checkpoints = response.files.where((file) {
        final lower = file.toLowerCase();
        // Exclude LoRAs, ControlNets, embeddings, upscalers
        if (lower.contains('lora') ||
            lower.contains('controlnet') ||
            lower.contains('control_net') ||
            lower.contains('embedding') ||
            lower.contains('upscaler') ||
            lower.contains('hypernetwork')) {
          return false;
        }
        // Exclude text encoders and LLMs
        if (lower.contains('clip') ||
            lower.contains('t5') ||
            lower.contains('encoder') ||
            lower.contains('gemma') ||
            lower.contains('llama') ||
            lower.contains('mistral') ||
            lower.contains('qwen') ||
            lower.contains('phi') ||
            lower.contains('chroma') ||
            lower.contains('ltx') ||
            lower.contains('vicuna') ||
            lower.contains('alpaca')) {
          return false;
        }
        return true;
      }).toList();

      debugPrint('DrawThingsGrpcService: Fetched ${checkpoints.length} checkpoints (filtered from ${response.files.length} total)');
      return checkpoints;
    } catch (e) {
      debugPrint('DrawThingsGrpcService fetchModels failed: $e');
      return [];
    }
  }

  /// Generates an image and yields progress updates, ending with the final image bytes
  Stream<dynamic> generateImage({
    required String prompt,
    String negativePrompt = '',
    String model = '',
    int width = 1024,
    int height = 1024,
    int steps = 20,
    double cfgScale = 7.0,
    String samplerName = 'Euler a',
    int seed = -1,
  }) async* {
    connect();

    // Map sampler name to FlatBuffer enum
    SamplerType samplerType = SamplerType.EulerA;
    if (samplerName.toLowerCase().contains('dpm++ 2m karras')) {
      samplerType = SamplerType.DPMPP2MKarras;
    } else if (samplerName.toLowerCase().contains('unipc')) {
      samplerType = SamplerType.UniPC;
    } else if (samplerName.toLowerCase().contains('lcm')) {
      samplerType = SamplerType.LCM;
    } else if (samplerName.toLowerCase().contains('tcd')) {
      samplerType = SamplerType.TCD;
    }

    // Build FlatBuffer config — matching Python client's full config
    final builder = fb.Builder(initialSize: 1024);
    final modelOffset = model.isNotEmpty ? builder.writeString(model) : null;

    final configBuilder = GenerationConfigurationBuilder(builder)
      ..begin()
      ..addStartWidth(width ~/ 64)
      ..addStartHeight(height ~/ 64)
      ..addSeed(seed == -1 ? DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF : seed)
      ..addSteps(steps)
      ..addGuidanceScale(cfgScale)
      ..addStrength(1.0)
      ..addBatchCount(1)
      ..addBatchSize(1)
      ..addSeedMode(SeedMode.Legacy)
      ..addRefinerStart(0.7)
      ..addPreserveOriginalAfterInpaint(true)
      ..addResolutionDependentShift(false)
      ..addMaskBlur(0.0)
      ..addSharpness(0.0)
      ..addSampler(samplerType);

    if (modelOffset != null) {
      configBuilder.addModelOffset(modelOffset);
    }

    final configOffset = configBuilder.finish();
    builder.finish(configOffset);

    final configBytes = builder.buffer;
    debugPrint('DrawThingsGrpcService: FlatBuffer size=${configBytes.length} bytes, model="$model", latent=${width ~/ 64}x${height ~/ 64}');

    // Build the gRPC request — matching Python client (no chunked/device overrides)
    final request = ImageGenerationRequest(
      prompt: prompt,
      negativePrompt: negativePrompt,
      configuration: configBytes,
      scaleFactor: 1,
      user: 'FrontPorchAI',
    );

    int currentStep = 0;

    try {
      final stream = _client!.generateImage(request);
      await for (final response in stream) {
        if (response.hasCurrentSignpost()) {
          final signpost = response.currentSignpost;
          if (signpost.hasSampling()) {
            currentStep = signpost.sampling.step;
            Uint8List? preview;
            if (response.hasPreviewImage()) {
              preview = Uint8List.fromList(response.previewImage);
            }
            yield ImageGenProgress(currentStep, steps, previewImage: preview);
          }
        }

        if (response.generatedImages.isNotEmpty) {
          yield Uint8List.fromList(response.generatedImages.first);
        }
      }
    } catch (e) {
      debugPrint('DrawThingsGrpcService generation failed: $e');
      throw Exception('Generation failed: $e');
    }
  }
}
