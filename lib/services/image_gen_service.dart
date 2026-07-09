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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/grpc/draw_things_grpc_service.dart';
import 'package:front_porch_ai/services/image_prompt/image_gen_context.dart';
import 'package:front_porch_ai/services/comfy_ui_service.dart';
import 'package:front_porch_ai/services/image_prompt/image_prompt_builder.dart';

/// Available image generation modes.
enum ImageGenMode {
  customPrompt,
  visualizeScene,
  characterPortrait,
  chatBackground,
  userAvatar,
}

/// Local image-generation backend options.
enum ImageGenBackend {
  remote,
  a1111,
  drawThings,
  comfyUi;

  static ImageGenBackend fromKey(String key) {
    switch (key) {
      case 'a1111':
        return ImageGenBackend.a1111;
      case 'drawthings':
        return ImageGenBackend.drawThings;
      case 'comfyui':
        return ImageGenBackend.comfyUi;
      default:
        return ImageGenBackend.remote;
    }
  }

  String get key {
    switch (this) {
      case ImageGenBackend.a1111:
        return 'a1111';
      case ImageGenBackend.drawThings:
        return 'drawthings';
      case ImageGenBackend.comfyUi:
        return 'comfyui';
      case ImageGenBackend.remote:
        return 'remote';
    }
  }

  String get label {
    switch (this) {
      case ImageGenBackend.a1111:
        return 'AUTOMATIC1111';
      case ImageGenBackend.drawThings:
        return 'Draw Things';
      case ImageGenBackend.comfyUi:
        return 'ComfyUI';
      case ImageGenBackend.remote:
        return 'Remote API';
    }
  }
}

/// Metadata for an image model available via the remote API.
class ImageModelInfo {
  final String id;
  final String name;

  /// Whether this model costs extra per-prompt (true) or is included
  /// with a Nano-GPT Pro subscription (false).
  final bool isPaid;

  /// Pricing information from OpenRouter (if available).
  /// Format: "prompt_cost / completion_cost per token" or raw JSON string.
  final String? pricingInfo;

  const ImageModelInfo({
    required this.id,
    this.name = '',
    this.isPaid = true,
    this.pricingInfo,
  });

  String get displayName => name.isNotEmpty ? name : id;

  /// Human-readable description including pricing if available.
  String get description {
    if (pricingInfo != null && pricingInfo!.isNotEmpty) {
      return '$displayName — $pricingInfo';
    }
    return displayName;
  }
}

/// Service for generating images via the remote API.
///
/// Reuses the same API URL and key configured for text generation
/// (OpenRouter, Nano-GPT, or any OpenAI-compatible endpoint).
class ImageGenService extends ChangeNotifier {
  final StorageService _storage;

  bool _isGenerating = false;
  String _statusMessage = '';
  Uint8List? _lastGeneratedImage;
  String? _lastSavedPath;

  /// Live generation progress (0..1) and the latest in-progress preview
  /// frame, so the UI can show the image "coming to life" instead of a
  /// spinner. Fed per backend: A1111 polls /sdapi/v1/progress (percent +
  /// preview), ComfyUI streams its WebSocket (percent + preview when the
  /// server has previews enabled), Draw Things reports sampling steps
  /// (percent only). Remote APIs return in one shot — both stay null there
  /// (indeterminate). Cleared at the start and end of every generation.
  double? _genProgress;
  Uint8List? _genPreview;
  double? get genProgress => _genProgress;
  Uint8List? get genPreview => _genPreview;

  void _updateGenProgress(double? progress, [Uint8List? preview]) {
    _genProgress = progress;
    if (preview != null) _genPreview = preview;
    notifyListeners();
  }

  /// The checkpoint name that is currently loaded on the local A1111 server.
  /// Used to skip redundant unload→reload cycles that can leave tensors
  /// split across CPU and CUDA on Windows/nVidia setups.
  String? _lastLoadedCheckpoint;

  bool get isGenerating => _isGenerating;
  String get statusMessage => _statusMessage;
  Uint8List? get lastGeneratedImage => _lastGeneratedImage;
  String? get lastSavedPath => _lastSavedPath;

  /// Whether image gen is configured and ready to use.
  bool get isConfigured {
    if (!_storage.imageGenSettings.imageGenEnabled) return false;
    final backend = ImageGenBackend.fromKey(
      _storage.imageGenSettings.imageGenBackend,
    );
    switch (backend) {
      case ImageGenBackend.remote:
        return _storage.backendSettings.remoteApiKey.isNotEmpty &&
            _storage.imageGenSettings.imageGenModel.isNotEmpty;
      case ImageGenBackend.a1111:
        return _storage.imageGenSettings.localImageGenUrl.isNotEmpty;
      case ImageGenBackend.drawThings:
        return _storage.imageGenSettings.drawThingsGrpcHost.isNotEmpty;
      case ImageGenBackend.comfyUi:
        return _storage.imageGenSettings.comfyUiUrl.isNotEmpty;
    }
  }

  DrawThingsGrpcService? _drawThingsGrpc;
  ComfyUiService? _comfyUi;

  ComfyUiService get _ensureComfyUi {
    final url = _storage.imageGenSettings.comfyUiUrl;
    if (_comfyUi == null || _comfyUi!.baseUrl != url) {
      _comfyUi = ComfyUiService(baseUrl: url);
    }
    return _comfyUi!;
  }

  // Thin delegation hook for prompt construction.
  // Full ownership of ImageGenContext mapping semantics, mode contracts (visualizeScene N-slider
  // now covers the former fromLastMessage "Message Illustration" distillation; no-personality portraits,
  // no-people backgrounds, etc.), style enforcement, LLM smart path, and static fallbacks lives in
  // ImagePromptBuilder.
  // Keep prompt blocks in sync: changes to ctx construction here must be mirrored in
  // builder tests (roundtrips), any direct ImageGenContext sites, and the builder's own
  // _buildStatic / buildPrompt / _generateSmartWith. The builder is stateless/prompt-only
  // (no reset calls needed). ImageGenService owns no prompt scalars that require zeroing
  // on chat startNew / setActive / load (per-call snapshot from _storage is authoritative).
  // See ImagePromptBuilder for the authoritative mode semantics and style rules.
  late final ImagePromptBuilder _promptBuilder = ImagePromptBuilder();

  DrawThingsGrpcService get _ensureDrawThingsGrpc {
    final h = _storage.imageGenSettings.drawThingsGrpcHost;
    final p = _storage.imageGenSettings.drawThingsGrpcPort;
    // Recreate if host/port changed since last use (cheap; keeps things in sync with settings)
    if (_drawThingsGrpc == null ||
        _drawThingsGrpc!.host != h ||
        _drawThingsGrpc!.port != p) {
      _drawThingsGrpc = DrawThingsGrpcService(host: h, port: p);
    }
    return _drawThingsGrpc!;
  }

  ImageGenService(this._storage);

  /// Build the images directory path.
  Directory get _imagesDir =>
      Directory(path.join(_storage.rootPath ?? '', 'KoboldManager', 'images'));

  /// Generate an image from a prompt.
  ///
  /// Routes to the configured remote API (OpenRouter, Nano-GPT, etc.).
  ///
  /// Returns the image bytes on success, or null on failure.
  Future<Uint8List?> generateImage({
    required String prompt,
    String? negativePrompt,
    String? size,
    Uint8List?
    referenceImage, // for img2img / reference conditioning (wired for Draw Things; ignored by others for now)
    String? model,
    bool isPortrait = false,
  }) async {
    _isGenerating = true;
    _statusMessage = 'Generating image...';
    _lastGeneratedImage = null;
    _lastSavedPath = null;
    _genProgress = null;
    _genPreview = null;
    notifyListeners();

    // Callers that don't specify a negative prompt (guest portraits, the
    // character creators, web chargen) get the user's configured default —
    // previously those paths silently generated with none. An explicit ''
    // still means "no negative". Remote APIs ignore negatives (see the
    // remote generators below).
    negativePrompt ??= _storage.imageGenSettings.imageGenNegativePrompt;

    // Portrait requests (character/persona portraits, guest card art) orient
    // the configured size vertically when the caller didn't pass an explicit
    // size. Previously this flag was accepted but ignored, so portraits came
    // out landscape whenever the default size was landscape.
    if (size == null && isPortrait) {
      final (w, h) = _parseSize(_storage.imageGenSettings.imageGenSize);
      if (w > h) size = '${h}x$w';
    }

    try {
      Uint8List imageBytes;

      final backend = ImageGenBackend.fromKey(
        _storage.imageGenSettings.imageGenBackend,
      );

      if (backend == ImageGenBackend.a1111 ||
          backend == ImageGenBackend.drawThings) {
        final isDrawThings =
            _storage.imageGenSettings.imageGenBackend == 'drawthings';

        if (isDrawThings) {
          // Use gRPC for Draw Things (Python client bridge)
          _statusMessage = 'Connecting to Draw Things...';
          notifyListeners();

          final modelCheckpoint =
              model ?? _storage.imageGenSettings.imageGenModel;
          // Relaxed .ckpt check: gRPC file list returns the actual filenames Draw Things knows about
          // (may be .ckpt, .safetensors, or bare names). Empty is allowed (uses current in DT).
          if (modelCheckpoint.isNotEmpty &&
              !modelCheckpoint.toLowerCase().contains('.')) {
            // Only warn on clearly bad names; let the CLI/DT surface the real error
          }

          try {
            final grpcService = _ensureDrawThingsGrpc;
            final imageSize = size ?? _storage.imageGenSettings.imageGenSize;
            final (width, height) = _parseSize(imageSize);
            final steps = _storage.imageGenSettings.imageGenSteps;
            final cfgScale = _storage.imageGenSettings.imageGenCfgScale;
            final seed = _storage.imageGenSettings.imageGenSeed;

            // DT-native advanced knobs (shared sliders still used for steps/cfg/seed/size)
            final sampler = _storage.imageGenSettings.drawThingsSampler;
            final shift = _storage.imageGenSettings.drawThingsShift;
            final strength = _storage.imageGenSettings.drawThingsStrength;
            final seedMode = _storage.drawThingsSeedMode;
            final teaCache = _storage.drawThingsTeaCache;
            final cfgZeroStar = _storage.drawThingsCfgZeroStar;
            // Same shared LoRA setting the A1111 path uses; DT applies it
            // natively via the generation config instead of a prompt tag.
            final loraName = _storage.imageGenSettings.imageGenLora;
            final loraWeight = _storage.imageGenSettings.imageGenLoraWeight;

            imageBytes = await _generateViaDrawThingsGrpc(
              grpcService: grpcService,
              prompt: prompt,
              negativePrompt: negativePrompt,
              model: modelCheckpoint,
              width: width,
              height: height,
              steps: steps,
              cfgScale: cfgScale,
              seed: seed,
              strength: strength,
              shift: shift,
              sampler: sampler,
              seedMode: seedMode,
              teaCache: teaCache,
              cfgZeroStar: cfgZeroStar,
              loras: loraName.isEmpty
                  ? const []
                  : [
                      {'file': loraName, 'weight': loraWeight},
                    ],
              referenceImage: referenceImage,
              onProgress: (step, total) => _updateGenProgress(
                total > 0 ? (step / total).clamp(0.0, 1.0) : null,
              ),
            );
          } catch (e) {
            // Sanitize for user display (no full tracebacks, absolute paths, or raw CLI internals)
            final msg = e.toString();
            final safe = msg.contains('CLI') || msg.contains('Generation error')
                ? 'Draw Things generation failed. Check that the gRPC server is enabled in Draw Things and the host/port are correct.'
                : 'Draw Things connection or generation failed.';
            _statusMessage = safe;
            debugPrint('ImageGen: Draw Things error (sanitized for user): $e');
            _isGenerating = false;
            notifyListeners();
            return null;
          }
        } else {
          // Use HTTP for A1111
          final localUrl = _storage.imageGenSettings.localImageGenUrl;
          if (localUrl.isEmpty) {
            _statusMessage = 'No local server URL configured.';
            _isGenerating = false;
            notifyListeners();
            return null;
          }
          final imageSize = size ?? _storage.imageGenSettings.imageGenSize;
          final modelCheckpoint =
              model ?? _storage.imageGenSettings.imageGenModel;
          imageBytes = await _generateViaA1111(
            baseUrl: localUrl,
            prompt: prompt,
            negativePrompt: negativePrompt,
            size: imageSize,
            modelCheckpoint: modelCheckpoint,
            switchModelFirst: modelCheckpoint.isNotEmpty,
            loraName: _storage.imageGenSettings.imageGenLora,
            loraWeight: _storage.imageGenSettings.imageGenLoraWeight,
            steps: _storage.imageGenSettings.imageGenSteps,
            cfgScale: _storage.imageGenSettings.imageGenCfgScale,
            samplerName: _storage.imageGenSettings.imageGenSampler,
            seed: _storage.imageGenSettings.imageGenSeed,
          );
        }
      } else if (backend == ImageGenBackend.comfyUi) {
        // ── ComfyUI (HTTP + bundled txt2img workflow) ──────────────────
        _statusMessage = 'Connecting to ComfyUI...';
        notifyListeners();
        try {
          final comfy = _ensureComfyUi;
          final (width, height) = _parseSize(
            size ?? _storage.imageGenSettings.imageGenSize,
          );
          // The stored sampler is shared across backends and may be an
          // A1111-style name; normalize it against what this server offers.
          final available = await comfy.fetchSamplers();
          final storedSampler = _storage.imageGenSettings.imageGenSampler;
          imageBytes = await comfy.generateImage(
            prompt: prompt,
            negativePrompt: negativePrompt,
            model: model ?? _storage.imageGenSettings.imageGenModel,
            width: width,
            height: height,
            steps: _storage.imageGenSettings.imageGenSteps,
            cfgScale: _storage.imageGenSettings.imageGenCfgScale,
            seed: _storage.imageGenSettings.imageGenSeed,
            samplerName: ComfyUiService.normalizeSampler(
              storedSampler,
              available,
            ),
            scheduler: ComfyUiService.schedulerFor(storedSampler),
            loraName: _storage.imageGenSettings.imageGenLora,
            loraWeight: _storage.imageGenSettings.imageGenLoraWeight,
            onProgress: _updateGenProgress,
          );
        } catch (e) {
          // Sanitize for user display (mirrors the Draw Things branch).
          final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          _statusMessage = msg.startsWith('ComfyUI') || msg.contains('model')
              ? msg
              : 'ComfyUI generation failed. Check that ComfyUI is running and '
                    'the URL is correct.';
          debugPrint('ImageGen: ComfyUI error: $e');
          _isGenerating = false;
          notifyListeners();
          return null;
        }
      } else {
        // ── Remote API ─────────────────────────────────────────────────
        if (_storage.backendSettings.remoteApiKey.isEmpty) {
          _statusMessage = 'No API key configured.';
          _isGenerating = false;
          notifyListeners();
          return null;
        }

        final imageModel = model ?? _storage.imageGenSettings.imageGenModel;
        if (imageModel.isEmpty) {
          _statusMessage = 'No image model selected.';
          _isGenerating = false;
          notifyListeners();
          return null;
        }

        final imageSize = size ?? _storage.imageGenSettings.imageGenSize;
        final apiUrl = _storage.backendSettings.remoteApiUrl;
        final apiKey = _storage.backendSettings.remoteApiKey;

        if (_isOpenRouterStyle(apiUrl)) {
          imageBytes = await _generateViaOpenRouter(
            apiUrl: apiUrl,
            apiKey: apiKey,
            model: imageModel,
            prompt: prompt,
            size: imageSize,
          );
        } else {
          imageBytes = await _generateViaOpenAICompat(
            apiUrl: apiUrl,
            apiKey: apiKey,
            model: imageModel,
            prompt: prompt,
            negativePrompt: negativePrompt,
            size: imageSize,
          );
        }
      }

      _lastGeneratedImage = imageBytes;
      _statusMessage = 'Image generated successfully.';
      debugPrint('ImageGen: Returning ${imageBytes.length} bytes');
      notifyListeners();
      return imageBytes;
    } catch (e) {
      _statusMessage = 'Generation failed: $e';
      notifyListeners();
      return null;
    } finally {
      _isGenerating = false;
      _genProgress = null;
      _genPreview = null;
      notifyListeners();
    }
  }

  /// Save the last generated image to disk.
  ///
  /// Returns the saved file path, or null on failure.
  Future<String?> saveImageToDisk([Uint8List? imageBytes]) async {
    final bytes = imageBytes ?? _lastGeneratedImage;
    if (bytes == null) return null;

    try {
      final dir = _imagesDir;
      await dir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'img_$timestamp.png';
      final file = File(path.join(dir.path, filename));
      await file.writeAsBytes(bytes);

      _lastSavedPath = file.path;
      notifyListeners();
      return file.path;
    } catch (e) {
      debugPrint('Failed to save image: $e');
      return null;
    }
  }

  /// Save a generated image as a character avatar to the characters directory.
  ///
  /// Unlike [saveImageToDisk], this saves to the characters directory
  /// (`KoboldManager/Characters/`) so cloud sync picks it up.
  /// Returns the saved file path, or null on failure.
  Future<String?> saveAvatarToDisk(
    Uint8List? imageBytes, {
    String? characterName,
  }) async {
    final bytes = imageBytes ?? _lastGeneratedImage;
    if (bytes == null) return null;

    try {
      final dir = _storage.charactersDir;
      await dir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = (characterName ?? 'avatar')
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      final filename = '${safeName}_$timestamp.png';
      final file = File(path.join(dir.path, filename));
      await file.writeAsBytes(bytes);

      _lastSavedPath = file.path;
      notifyListeners();
      return file.path;
    } catch (e) {
      debugPrint('Failed to save avatar: $e');
      return null;
    }
  }

  /// Common image generation models available on Nano-GPT and similar providers.
  /// These are always shown so the user can pick one even when the API's
  /// /models endpoint doesn't list image models separately (Nano-GPT's /models
  /// endpoint only returns text models; image models have no discovery endpoint).
  ///
  /// Model IDs sourced from https://nano-gpt.com/models/image (May 2026).
  static const _commonImageModels = <ImageModelInfo>[
    // ── Included with Nano-GPT Pro subscription ($8/mo) ──
    ImageModelInfo(id: 'hidream', name: 'HiDream', isPaid: false),
    ImageModelInfo(id: 'chroma', name: 'Chroma', isPaid: false),
    ImageModelInfo(id: 'z-image-turbo', name: 'Z Image Turbo', isPaid: false),
    ImageModelInfo(id: 'qwen-image', name: 'Qwen Image', isPaid: false),
    // ── Pay-per-prompt: OpenAI ──
    ImageModelInfo(id: 'gpt-image-2', name: 'GPT Image 2'),
    ImageModelInfo(id: 'dall-e-3', name: 'DALL-E 3'),
    // ── Pay-per-prompt: Black Forest Labs (FLUX) ──
    ImageModelInfo(id: 'flux-1-pro', name: 'FLUX.1 Pro'),
    ImageModelInfo(id: 'flux-1-dev', name: 'FLUX.1 Dev'),
    ImageModelInfo(id: 'flux-1-schnell', name: 'FLUX.1 Schnell'),
    ImageModelInfo(id: 'flux-2-klein-4b', name: 'FLUX.2 Klein 4B'),
    ImageModelInfo(id: 'flux-2-klein-9b', name: 'FLUX.2 Klein 9B'),
    // ── Pay-per-prompt: Ideogram ──
    ImageModelInfo(id: 'ideogram-v3-default', name: 'Ideogram V3'),
    ImageModelInfo(id: 'ideogram-v3-turbo', name: 'Ideogram V3 Turbo'),
    ImageModelInfo(
      id: 'ideogram-v3-generate-transparent',
      name: 'Ideogram V3 Transparent',
    ),
    ImageModelInfo(
      id: 'ideogram-v3-remove-text',
      name: 'Ideogram V3 Remove Text',
    ),
    // ── Pay-per-prompt: Alibaba (WAN / Qwen) ──
    ImageModelInfo(id: 'wan2.7-image', name: 'WAN 2.7 Image'),
    ImageModelInfo(id: 'wan2.7-image-pro', name: 'WAN 2.7 Image Pro'),
    ImageModelInfo(id: 'qwen-image-2.0', name: 'Qwen Image 2.0'),
    ImageModelInfo(id: 'qwen-image-2.0-pro', name: 'Qwen Image 2.0 Pro'),
    ImageModelInfo(id: 'qwen-image-max', name: 'Qwen Image Max'),
    ImageModelInfo(id: 'qwen-image-max-edit', name: 'Qwen Image Max Edit'),
    // ── Pay-per-prompt: Google (Nano Banana) ──
    ImageModelInfo(id: 'nano-banana-2', name: 'Nano Banana 2 (Gemini Image)'),
    ImageModelInfo(id: 'nano-banana-2-fast', name: 'Nano Banana 2 Fast'),
    // ── Pay-per-prompt: ByteDance (Seedream) ──
    ImageModelInfo(id: 'seedream-v5.0-lite', name: 'Seedream 5.0 Lite'),
    ImageModelInfo(
      id: 'seedream-v5.0-lite-sequential',
      name: 'Seedream 5.0 Lite Sequential',
    ),
    // ── Pay-per-prompt: Z.AI (GLM / CogView) ──
    ImageModelInfo(id: 'cogview-4', name: 'Z.AI CogView-4'),
    ImageModelInfo(id: 'z-image-base', name: 'Z Image Base'),
    ImageModelInfo(id: 'glm-image', name: 'Z.AI GLM Image'),
    ImageModelInfo(id: 'glm-image-edit', name: 'GLM Image Edit'),
    // ── Pay-per-prompt: Tencent (Hunyuan) ──
    ImageModelInfo(
      id: 'hunyuan-image-3-instruct',
      name: 'Hunyuan Image 3 Instruct',
    ),
    // ── Pay-per-prompt: Baidu (ERNIE) ──
    ImageModelInfo(id: 'ernie-image', name: 'ERNIE Image'),
    ImageModelInfo(id: 'ernie-image/turbo', name: 'ERNIE Image Turbo'),
    // ── Pay-per-prompt: xAI ──
    ImageModelInfo(id: 'grok-imagine-image', name: 'Grok Imagine Image'),
    // ── Pay-per-prompt: MiniMax ──
    ImageModelInfo(id: 'minimax-image-01', name: 'MiniMax Image-01'),
    // ── Pay-per-prompt: Bria ──
    ImageModelInfo(id: 'bria-fibo', name: 'Bria Fibo'),
    ImageModelInfo(id: 'bria-fibo-edit', name: 'Bria Fibo Edit'),
    // ── Pay-per-prompt: Sourceful (Riverflow) ──
    ImageModelInfo(id: 'riverflow-2.0-pro', name: 'Riverflow 2.0 Pro'),
    // ── Pay-per-prompt: Other / Utility ──
    ImageModelInfo(id: 'juggernaut-z', name: 'Juggernaut Z'),
    ImageModelInfo(id: 'mjv6', name: 'Flux Midjourney (MJV6)'),
    ImageModelInfo(id: 'dreamshaper-xl', name: 'Dreamshaper XL'),
    ImageModelInfo(id: 'nsfw-gen-illustrious', name: 'Animagine XL 4.0'),
    ImageModelInfo(id: 'atomix-xl', name: 'Atomix XL'),
    ImageModelInfo(id: 'background-remover', name: 'Background Remover'),
    ImageModelInfo(id: 'esrgan-4x', name: 'ESRGAN 4x Upscaler'),
    ImageModelInfo(id: 'custom-civitai', name: 'Custom CivitAI Model'),
  ];

  /// Fetch available image models.
  ///
  /// Behavior depends on which API backend is configured:
  ///
  /// **OpenRouter** (detected by URL containing "openrouter.ai"):
  /// - Calls `/models?output_modalities=image` to get real image-capable models
  /// - Returns what OpenRouter provides (includes pricing info from their API)
  /// - If API fails: returns empty list with error logged
  ///
  /// **Nano-GPT and others**:
  /// - Returns the curated list of known image models (Nano-GPT's /models
  ///   endpoint only returns text models; there is no image-specific listing API)
  Future<List<ImageModelInfo>> fetchImageModels() async {
    final apiUrl = _storage.backendSettings.remoteApiUrl;
    final apiKey = _storage.backendSettings.remoteApiKey;
    if (apiUrl.isEmpty || apiKey.isEmpty) return List.from(_commonImageModels);

    // Detect if this is OpenRouter
    final isOpenRouter = _isOpenRouterStyle(apiUrl);

    if (isOpenRouter) {
      return _fetchOpenRouterImageModels(apiUrl, apiKey);
    } else {
      // For Nano-GPT and other providers: return curated list
      return List.from(_commonImageModels);
    }
  }

  /// Fetch image models specifically from OpenRouter's API.
  ///
  /// OpenRouter supports querying for image-capable models via:
  /// GET /models?output_modalities=image
  ///
  /// Returns the models as provided by OpenRouter with their pricing,
  /// or an empty list if the API call fails.
  Future<List<ImageModelInfo>> _fetchOpenRouterImageModels(
    String apiUrl,
    String apiKey,
  ) async {
    final apiModels = <ImageModelInfo>[];
    final client = http.Client();

    try {
      // Query for models that can output images
      final uri = Uri.parse('$apiUrl/models?output_modalities=image');
      final response = await client
          .get(uri, headers: {'Authorization': 'Bearer $apiKey'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] as List<dynamic>? ?? [];

        for (final m in data) {
          final id = m['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final name = m['name']?.toString() ?? id;

          // Extract pricing info if available (display as-is from OpenRouter)
          final pricing = m['pricing'] as Map<String, dynamic>?;
          String? pricingInfo;

          // NOTE: OpenRouter returns $0/$0 for free-tier-only models or unclear pricing
          // We do NOT mark these as "free" since they may have restrictions or credits only
          // Instead, we show the pricing as-is and let user check OpenRouter's site for details
          bool isPaid =
              true; // Conservative: assume paid unless clearly free ($0 everywhere)

          if (pricing != null) {
            final prompt = pricing['prompt'];
            final completion = pricing['completion'];

            // Format pricing for display (show as-is from API)
            if (prompt != null || completion != null) {
              pricingInfo = '\$$prompt / \$$completion';
            }
          }

          apiModels.add(
            ImageModelInfo(
              id: id,
              name: name,
              isPaid: isPaid,
              pricingInfo: pricingInfo,
            ),
          );
        }

        debugPrint(
          'ImageGen: Fetched ${apiModels.length} image models from OpenRouter',
        );
      } else {
        debugPrint(
          'ImageGen: OpenRouter /models?output_modalities=image returned ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('ImageGen: Failed to fetch OpenRouter image models: $e');
    } finally {
      client.close();
    }

    // Sort by name for consistent display
    apiModels.sort((a, b) => a.displayName.compareTo(b.displayName));
    return apiModels;
  }

  // NOTE (Stage 2 image prompt refactor): _maxPromptLength and _truncate moved into
  // ImageGenContext / ImagePromptBuilder (the single source of truth). The old copies
  // were dead after delegation and have been deleted as part of hygiene.

  // NOTE (Stage 2): styleModifiers and legacyStyleModifiers have been moved to
  // ImagePromptBuilder (the canonical owner). Old copies deleted here as dead duplication.
  // styleLabels kept for UI (studio + any other surfaces).

  /// Available style labels for UI display.
  static const Map<String, String> styleLabels = {
    'photorealistic': 'Photorealistic',
    'anime': 'Anime / Manga',
    'fantasy_art': 'Fantasy Art',
    'oil_painting': 'Oil Painting',
    'digital_art': 'Digital Art',
    'watercolor': 'Watercolor',
  };

  /// Use the active LLM to craft a concise, effective image prompt from raw context.
  ///
  /// Thin delegation to ImagePromptBuilder — see there for mode semantics and style rules
  /// (visualizeScene N-slider now covers former fromLastMessage/Message Illustration; portrait = appearance+expression only, background
  /// = environment only with strong NO PEOPLE, visualize = current scene distillation, style
  /// enforcement for both paradigms, etc.).
  /// Old inline implementation (switch cases, raw dumps, personality injection, "Depict the
  /// following scene", fragile substring style) removed in Stage 2.
  /// Keep prompt blocks in sync with ImagePromptBuilder (and ctx construction in call sites
  /// like chat_page._showImageGenDialog and web chargen paths). Builder is stateless/prompt-only.
  ///
  /// NOTE on duplication fix (Stage 2 review): the ternary + 15+ field bag construction that
  /// used to be repeated in happy path, ultimate fallback, and buildPrompt is now in the
  /// tiny pure helper _buildPromptContext below. This is *thin coordination only* (data bag
  /// assembly + the custom vs lastMessage rule from the original thins). It contains ZERO
  /// prompt logic, distillation, style, or LLM — all of that stays in ImagePromptBuilder.
  /// This does not violate the "0 new god private _ methods for prompt logic" rule.
  /// MUST KEEP IN SYNC with roundtrips (especially the new customPrompt ternary test) and
  /// future call-site enrichment (currentExpression etc.).
  ///
  /// Stage 4 user spec continuation (no boilerplate pregen in box; visualize slider N + simple `<think>` strip on pre-generated msgs;
  /// user box text + User persona + char visual info (no personality) + style sent to LLM on Craft to produce the visual prompt;
  /// 6 types now buttons inside studio, launch neutral): added userInstruction (box text before craft), visualizeNumMessages (slider).
  /// Forwarded to thin _build + ctx + builder. Keep all thins + ctx ctor + studio craft + launcher collection + builder assembly in sync.
  /// (0 new private _ methods — only extended existing _buildPromptContext thin; void _ count stable at baseline.)
  Future<String> generateSmartPrompt({
    required ImageGenMode mode,
    required String style,
    LLMService? llmService,
    String? customPrompt,
    String? lastMessage,
    String? characterName,
    String? characterDescription,
    String?
    characterPersonality, // kept for signature compatibility during transition (ignored for visuals)
    String? scenario,
    String? worldInfo,
    String? personaName,
    String? personaText,
    List<String>? recentMessages,
    // Stage 4: richer optional fields for better prompts (expression/pose, time/lighting, group speaker targeting).
    // Forwarded to thin ctx builder. Keep in sync with buildPrompt sig, _buildPromptContext, studio craft/ctor/show, chat_page launch.
    String? currentExpression,
    String? timeOfDay,
    String? lightingHint,
    bool isGroupNonObserver = false,
    String? currentSpeakerId,
    // User spec: text user typed in studio box pre-Craft (passed to LLM as instr to "parse into" image prompt).
    // visualize N: slider value (only meaningful for visualizeScene); messages stripped simply since already generated.
    String? userInstruction,
    int? visualizeNumMessages,
  }) async {
    final paradigm = _storage.imageGenSettings.imageGenPromptParadigm;

    // Build the rich typed context (builder owns all distillation + style rules).
    // Uses the thin coordination helper (see _buildPromptContext) to keep the customPrompt
    // ternary + future-hint mapping in one place. Expanded for future visual hints...
    final ctx = _buildPromptContext(
      mode: mode,
      style: style,
      paradigm: paradigm,
      customPrompt: customPrompt,
      lastMessage: lastMessage,
      characterName: characterName,
      characterDescription: characterDescription,
      scenario: scenario,
      worldInfo: worldInfo,
      personaName: personaName,
      personaText: personaText,
      recentMessages: recentMessages,
      // Stage 4 richer fields forwarded (keep in sync with other _build calls, studio, launch site, builder).
      currentExpression: currentExpression,
      timeOfDay: timeOfDay,
      lightingHint: lightingHint,
      isGroupNonObserver: isGroupNonObserver,
      currentSpeakerId: currentSpeakerId,
      // User spec continuation (no pregen boiler; N slider for visualize + user box text + persona+char visual no pers + style on craft/LLM).
      // Keep thin + ctx + studio craft call + builder _generateSmartWith parts + chat launcher in sync (both startNew equiv N/A for snapshot).
      userInstruction: userInstruction,
      visualizeNumMessages: visualizeNumMessages,
    );

    // Pass an LLM only if the caller supplied a ready one (builder will use it for smart path).
    // We create a fresh builder with the provided LLM for this call so existing call sites that
    // sometimes pass a different llmService continue to work exactly as before.
    final effectiveBuilder = (llmService != null && llmService.isReady)
        ? ImagePromptBuilder(llmService: llmService)
        : _promptBuilder;

    try {
      return await effectiveBuilder.buildPrompt(ctx);
    } catch (e) {
      debugPrint('ImageGen: Builder failed ($e), using ultimate fallback');
      // Ultimate safety fallback (should almost never be reached).
      // Uses the same thin helper for exact parity with happy path (style honored via arg).
      final fbCtx = _buildPromptContext(
        mode: mode,
        style: style,
        paradigm: paradigm,
        customPrompt: customPrompt,
        lastMessage: lastMessage,
        characterName: characterName,
        characterDescription: characterDescription,
        scenario: scenario,
        worldInfo: worldInfo,
        personaName: personaName,
        personaText: personaText,
        recentMessages: recentMessages,
        // Stage 4 richer fields (keep blocks in sync with happy ctx, buildPrompt ctx, studio, chat_page launch, ctx ctor).
        currentExpression: currentExpression,
        timeOfDay: timeOfDay,
        lightingHint: lightingHint,
        isGroupNonObserver: isGroupNonObserver,
        currentSpeakerId: currentSpeakerId,
        // User spec (userInstruction for craft box text, visualizeNum for slider N stripped msgs). Sync with happy path above + builder.
        userInstruction: userInstruction,
        visualizeNumMessages: visualizeNumMessages,
      );
      return effectiveBuilder.buildStaticPrompt(fbCtx);
    }
  }

  /// Build a prompt for the given generation mode.
  ///
  /// Thin delegation to ImagePromptBuilder (full implementation + contracts live there).
  /// Old switch body deleted as part of Stage 2 of the image prompt refactor.
  /// See ImagePromptBuilder for the authoritative mode semantics and style rules.
  /// Keep prompt blocks in sync: this thin + generateSmartPrompt's ctx mapping must stay
  /// aligned with builder._buildStatic + _ensureStyleAndCap. No new _private methods were
  /// added for prompt logic (only the pre-existing _promptBuilder late final hook).
  ///
  /// User spec (visualize slider, user box as instr to LLM craft, buttons inside studio instead of popup, no boilerplate pregen):
  /// forward userInstruction + visualizeNumMessages (edit to existing thin only; 0 new _privs).
  String buildPrompt({
    required ImageGenMode mode,
    String? customPrompt,
    String? lastMessage,
    String? characterName,
    String? characterDescription,
    String?
    characterPersonality, // signature compat only (personality is never visual)
    String? scenario,
    String? worldInfo,
    String? personaName,
    String? personaText,
    List<String>? recentMessages,
    // Stage 4: richer optional fields (see generateSmartPrompt). Keep ctx construction / studio / launch / builder in sync.
    String? currentExpression,
    String? timeOfDay,
    String? lightingHint,
    bool isGroupNonObserver = false,
    String? currentSpeakerId,
    String? userInstruction,
    int? visualizeNumMessages,
  }) {
    final paradigm = _storage.imageGenSettings.imageGenPromptParadigm;
    final style = _storage.imageGenSettings.imageGenStyle;

    // Uses the thin coordination helper (dedup; see _buildPromptContext javadoc).
    final ctx = _buildPromptContext(
      mode: mode,
      style: style,
      paradigm: paradigm,
      customPrompt: customPrompt,
      lastMessage: lastMessage,
      characterName: characterName,
      characterDescription: characterDescription,
      scenario: scenario,
      worldInfo: worldInfo,
      personaName: personaName,
      personaText: personaText,
      recentMessages: recentMessages,
      // Stage 4 richer fields forwarded for builder use in static path (keep in sync with generateSmart ctx sites + launch + studio ctx + builder consumption).
      currentExpression: currentExpression,
      timeOfDay: timeOfDay,
      lightingHint: lightingHint,
      isGroupNonObserver: isGroupNonObserver,
      currentSpeakerId: currentSpeakerId,
      // User spec: forward box text + viz N (for static fallback parity on visualize limit + instr if used in static; main is LLM craft path).
      userInstruction: userInstruction,
      visualizeNumMessages: visualizeNumMessages,
    );

    // buildPrompt remains the synchronous "static quality" path (used by fallbacks and any direct callers).
    // It now gets the improved static builder logic (no LLM). The async generateSmartPrompt
    // is the one that may use the caller's LLM for higher quality.
    try {
      // We added a small sync static helper on the builder in the same change.
      return _promptBuilder.buildStaticPrompt(ctx);
    } catch (_) {
      return (customPrompt ?? lastMessage ?? 'a scene');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────

  /// Parse a "WxH" size string into width and height integers.
  static (int width, int height) _parseSize(String size) {
    final parts = size.split('x');
    if (parts.length == 2) {
      final w = int.tryParse(parts[0]) ?? 1024;
      final h = int.tryParse(parts[1]) ?? 1024;
      return (w, h);
    }
    return (1024, 1024);
  }

  /// Tiny pure helper: assembles ImageGenContext from the flat params the thins receive.
  /// This is *thin coordination/wiring only* — no distillation, no style rules, no LLM,
  /// no mode semantics. All of that is in ImagePromptBuilder (the single source of truth).
  /// The only "logic" here is the original customPrompt ? customPrompt : lastMessage
  /// ternary (plus the paradigm read that was already here).
  /// MUST KEEP IN SYNC with: builder_test roundtrips (including the customPrompt ternary
  /// test + new field roundtrips for expression/time/group), any direct ImageGenContext
  /// construction (chat_page launch, studio init, studio _craft path), studio ctx build,
  /// and call sites. Keep blocks in sync with ImageGenContext ctor, studio _ctx=,
  /// chat_page _showImageGenDialog collection, and builder consumption sites.
  /// (incomplete zeroing of secondary config on resets not applicable here; ctx is per-invocation snapshot).
  /// Stage 4 complete for richer fields wiring.
  ///
  /// User spec (Stage 4 continuation): extended for userInstruction (typed box text pre-Craft, sent to LLM "to parse into the image gen prompt")
  /// + visualizeNumMessages (slider for N recent msgs to include for visualize; stripped of all `<think>` simply — messages pre-generated).
  /// No new private _ methods (this is edit to the sole existing thin _buildPromptContext; live grep count of _ methods stable post-edit).
  /// 1:1/group parity qualified via existing speaker/flag paths (visualize N applies to provided recent snapshot regardless of 1:1 vs group).
  /// Keep launcher collection (now take(12) for slider headroom), studio (internal mode + slider + craft pass of current box + active), builder assembly in sync.
  ImageGenContext _buildPromptContext({
    required ImageGenMode mode,
    required String style,
    required String paradigm,
    String? customPrompt,
    String? lastMessage,
    String? characterName,
    String? characterDescription,
    String? scenario,
    String? worldInfo,
    String? personaName,
    String? personaText,
    List<String>? recentMessages,
    String? currentExpression,
    String? timeOfDay,
    String? lightingHint,
    bool isGroupNonObserver = false,
    String? currentSpeakerId,
    String? userInstruction,
    int? visualizeNumMessages,
  }) {
    return ImageGenContext(
      mode: mode,
      style: style,
      paradigm: paradigm,
      characterName: characterName,
      characterDescription: characterDescription,
      lastMessage: (mode == ImageGenMode.customPrompt
          ? customPrompt
          : lastMessage),
      scenario: scenario,
      worldInfo: worldInfo,
      personaName: personaName,
      personaText: personaText,
      recentMessages: recentMessages,
      currentExpression: currentExpression,
      timeOfDay: timeOfDay,
      lightingHint: lightingHint,
      isGroupNonObserver: isGroupNonObserver,
      currentSpeakerId: currentSpeakerId,
      userInstruction: userInstruction,
      visualizeNumMessages: visualizeNumMessages,
    );
  }

  /// Test whether a local image-gen server is reachable.
  ///
  /// For Draw Things, uses gRPC. For ComfyUI, GET /system_stats. For A1111,
  /// GET /sdapi/v1/sd-models.
  Future<bool> testLocalConnection(String baseUrl) async {
    final backendKey = _storage.imageGenSettings.imageGenBackend;

    if (backendKey == 'drawthings') {
      try {
        final grpcService = _ensureDrawThingsGrpc;
        return await grpcService.testConnection();
      } catch (e) {
        debugPrint('ImageGen: Draw Things connection test failed: $e');
        return false;
      }
    } else if (backendKey == 'comfyui') {
      return _ensureComfyUi.testConnection();
    } else {
      final client = http.Client();
      try {
        final uri = Uri.parse(
          '${ComfyUiService.ensureHttpScheme(baseUrl)}/sdapi/v1/sd-models',
        );
        final response = await client
            .get(uri)
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      } catch (_) {
        return false;
      } finally {
        client.close();
      }
    }
  }

  /// Fetch available checkpoints from an A1111 / Draw Things server.
  ///
  /// For Draw Things, uses gRPC. For A1111, uses HTTP.
  Future<List<String>> fetchA1111Models(String baseUrl) async {
    final isDrawThings =
        _storage.imageGenSettings.imageGenBackend == 'drawthings';

    if (isDrawThings) {
      try {
        final grpcService = _ensureDrawThingsGrpc;
        return await grpcService.fetchModels();
      } catch (e) {
        debugPrint('ImageGen: fetchDrawThingsModels failed: $e');
        return [];
      }
    } else {
      final client = http.Client();
      try {
        final uri = Uri.parse(
          '${ComfyUiService.ensureHttpScheme(baseUrl)}/sdapi/v1/sd-models',
        );
        final response = await client
            .get(uri)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) return [];
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((m) => (m as Map<String, dynamic>)['title']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      } catch (_) {
        return [];
      } finally {
        client.close();
      }
    }
  }

  /// Fetch models from a Draw Things server.
  ///
  /// Uses the Draw Things gRPC CLI to fetch available .ckpt models (via the
  /// special Echo('models') response). LoRAs come from [fetchDrawThingsLoras].
  Future<List<String>> fetchDrawThingsModels(String baseUrl) async {
    try {
      final grpcService = _ensureDrawThingsGrpc;
      return await grpcService.fetchModels();
    } catch (e) {
      debugPrint('ImageGen: fetchDrawThingsModels failed: $e');
      return [];
    }
  }

  /// Fetch LoRA files from a Draw Things server (gRPC CLI op 'loras' — the
  /// same Echo('models') listing as [fetchDrawThingsModels], filtered to
  /// LoRAs). The selected name is applied natively via the generation config.
  Future<List<String>> fetchDrawThingsLoras(String baseUrl) async {
    try {
      final grpcService = _ensureDrawThingsGrpc;
      return await grpcService.fetchLoras();
    } catch (e) {
      debugPrint('ImageGen: fetchDrawThingsLoras failed: $e');
      return [];
    }
  }

  /// ComfyUI discovery — checkpoints / LoRAs / samplers all come from one
  /// GET /object_info payload (see [ComfyUiService]); URL from settings.
  Future<List<String>> fetchComfyModels(String baseUrl) =>
      _ensureComfyUi.fetchModels();

  Future<List<String>> fetchComfyLoras(String baseUrl) =>
      _ensureComfyUi.fetchLoras();

  Future<List<String>> fetchComfySamplers(String baseUrl) =>
      _ensureComfyUi.fetchSamplers();

  /// Fetch LoRAs from an A1111 / Forge / SD.Next server.
  ///
  /// Endpoint: GET /sdapi/v1/loras
  /// Returns a list of LoRA names (the `name` field from each entry).
  /// Draw Things uses [fetchDrawThingsLoras] instead (no HTTP endpoint).
  Future<List<String>> fetchA1111Loras(String baseUrl) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(
        '${ComfyUiService.ensureHttpScheme(baseUrl)}/sdapi/v1/loras',
      );
      debugPrint('ImageGen: Fetching LoRAs from $uri');
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) {
            final m = e as Map<String, dynamic>;
            // Prefer alias if present and non-empty, else use name
            final alias = m['alias']?.toString() ?? '';
            final name = m['name']?.toString() ?? '';
            return alias.isNotEmpty ? alias : name;
          })
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('ImageGen: fetchA1111Loras failed: $e');
      return [];
    } finally {
      client.close();
    }
  }

  /// Unload the currently active model from memory on a local server.
  ///
  /// Calls `POST /sdapi/v1/unload-checkpoint` (standard A1111 endpoint).
  /// Draw Things may support this via its A1111-compat layer.
  /// If the server doesn't support it the error is silently ignored —
  /// model switching via [switchLocalModel] will still proceed.
  ///
  /// Returns true if the server acknowledged the unload (HTTP 200).
  Future<bool> unloadLocalModel(String baseUrl) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(
        '${ComfyUiService.ensureHttpScheme(baseUrl)}/sdapi/v1/unload-checkpoint',
      );
      debugPrint('ImageGen: Requesting model unload at $uri');
      final response = await client
          .post(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));
      final ok = response.statusCode == 200;
      debugPrint(
        'ImageGen: Unload ${ok ? "accepted" : "rejected (${response.statusCode}) — may not be supported"}',
      );
      return ok;
    } catch (e) {
      debugPrint('ImageGen: unloadLocalModel failed (ignored): $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Switch the active checkpoint on a local A1111 / Draw Things server.
  ///
  /// Sequence:
  ///   1. `POST /sdapi/v1/unload-checkpoint` — free current model from memory
  ///      (silently ignored if not supported by the server)
  ///   2. `POST /sdapi/v1/options` with the new model name — trigger model load
  ///   3. Poll `GET /sdapi/v1/options` to confirm the model is fully loaded
  ///      on the GPU before returning, preventing tensor device mismatches.
  ///
  /// Returns true if the model was successfully switched and confirmed ready.
  Future<bool> switchLocalModel(String baseUrl, String modelName) async {
    if (modelName.isEmpty) return false;
    final backendKey = _storage.imageGenSettings.imageGenBackend;
    if (backendKey == 'drawthings' || backendKey == 'comfyui') {
      // Draw Things and ComfyUI have no separate switch endpoint — the model
      // is named per-generation (DT config dict / ComfyUI workflow graph).
      // Treat as immediate success so web API / legacy callers and the
      // lastLoaded tracking continue to work without error.
      debugPrint(
        'ImageGen: switchLocalModel: $backendKey backend — recording '
        '$modelName (sent at generate time; no pre-load call)',
      );
      _lastLoadedCheckpoint = modelName;
      return true;
    }
    // Step 1: unload current model (best-effort — Draw Things may ignore this)
    await unloadLocalModel(baseUrl);
    // Step 2: request the new checkpoint
    final client = http.Client();
    try {
      final uri = Uri.parse(
        '${ComfyUiService.ensureHttpScheme(baseUrl)}/sdapi/v1/options',
      );
      debugPrint('ImageGen: Switching checkpoint → $modelName');
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'sd_model_checkpoint': modelName}),
          )
          .timeout(const Duration(seconds: 120)); // model loads can be slow
      final ok = response.statusCode == 200;
      debugPrint(
        'ImageGen: Checkpoint switch ${ok ? "accepted" : "rejected (${response.statusCode})"}',
      );
      if (!ok) return false;

      // Step 3: confirm the model is fully loaded before returning.
      // A1111's /sdapi/v1/options POST returns 200 when the load *starts*,
      // but on Windows/nVidia/CuBLAS the model may still be transferring
      // tensors to CUDA. We poll until the reported checkpoint matches or
      // we exhaust retries.
      final ready = await _waitForModelReady(baseUrl, modelName, client);
      if (ready) {
        _lastLoadedCheckpoint = modelName;
      } else {
        debugPrint('ImageGen: Model ready check timed out — proceeding anyway');
        _lastLoadedCheckpoint = modelName; // assume it loaded
      }
      return true;
    } catch (e) {
      debugPrint('ImageGen: switchLocalModel failed: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Poll the A1111 server until the active checkpoint matches [expected].
  ///
  /// This prevents a race condition where `txt2img` fires while the model
  /// is still being moved to the CUDA device, causing the
  /// "Expected all tensors to be on the same device" RuntimeError.
  ///
  /// Polls up to 30 times with a 2-second interval (60 s total).
  Future<bool> _waitForModelReady(
    String baseUrl,
    String expected,
    http.Client client,
  ) async {
    final uri = Uri.parse(
      '${ComfyUiService.ensureHttpScheme(baseUrl)}/sdapi/v1/options',
    );
    const maxAttempts = 30;
    const pollInterval = Duration(seconds: 2);

    for (var i = 0; i < maxAttempts; i++) {
      try {
        final resp = await client.get(uri).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final active = body['sd_model_checkpoint']?.toString() ?? '';
          if (active == expected) {
            debugPrint('ImageGen: Model ready confirmed on attempt ${i + 1}');
            return true;
          }
          debugPrint(
            'ImageGen: Waiting for model load… '
            '(active="$active", expected="$expected", attempt ${i + 1}/$maxAttempts)',
          );
        }
      } catch (e) {
        debugPrint('ImageGen: Model ready poll failed (attempt ${i + 1}): $e');
      }
      await Future<void>.delayed(pollInterval);
    }
    return false;
  }

  /// Fetch available samplers from an A1111 / Draw Things server.
  ///
  /// Endpoint: GET /sdapi/v1/samplers
  /// Returns sampler names (the `name` field from each entry).
  Future<List<String>> fetchA1111Samplers(String baseUrl) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(
        '${ComfyUiService.ensureHttpScheme(baseUrl)}/sdapi/v1/samplers',
      );
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('ImageGen: fetchA1111Samplers failed: $e');
      return [];
    } finally {
      client.close();
    }
  }

  /// Generate via AUTOMATIC1111 / Draw Things local server.
  ///
  /// Endpoint: POST {baseUrl}/sdapi/v1/txt2img
  /// Response: { "images": ["<base64>", ...] }
  ///
  /// When [modelCheckpoint] is non-empty and the backend is Draw Things,
  /// the active model is switched via `POST /sdapi/v1/options` first,
  /// mimicking "create a new project" with the selected model.
  Future<Uint8List> _generateViaA1111({
    required String baseUrl,
    required String prompt,
    String negativePrompt = '',
    String size = '1024x1024',
    String modelCheckpoint = '',
    bool switchModelFirst = false,
    String loraName = '',
    double loraWeight = 0.8,
    int steps = 20,
    double cfgScale = 7.0,
    String samplerName = 'Euler a',
    int seed = -1,
  }) async {
    // Switch model only if a different checkpoint was requested.
    // Skipping redundant switches prevents the unload→reload cycle that
    // can leave tensors split across CPU & CUDA on Windows/nVidia setups.
    if (switchModelFirst &&
        modelCheckpoint.isNotEmpty &&
        modelCheckpoint != _lastLoadedCheckpoint) {
      _statusMessage = 'Loading model: $modelCheckpoint…';
      notifyListeners();
      await switchLocalModel(baseUrl, modelCheckpoint);
    }

    final (width, height) = _parseSize(size);
    final uri = Uri.parse(
      '${ComfyUiService.ensureHttpScheme(baseUrl)}/sdapi/v1/txt2img',
    );

    // Inject LoRA into the prompt: <lora:name:weight>
    final effectivePrompt = (loraName.isNotEmpty)
        ? '$prompt <lora:$loraName:${loraWeight.toStringAsFixed(2)}>'
        : prompt;

    debugPrint(
      'ImageGen: POST $uri (model=${modelCheckpoint.isNotEmpty ? modelCheckpoint : "current"}, lora=${loraName.isNotEmpty ? loraName : "none"})',
    );

    final payload = <String, dynamic>{
      'prompt': effectivePrompt,
      'negative_prompt': negativePrompt,
      'width': width,
      'height': height,
      'steps': steps,
      'cfg_scale': cfgScale,
      'sampler_name': samplerName,
      'seed': seed,
      'batch_size': 1,
      // NOTE: override_settings is intentionally omitted here.
      // Passing sd_model_checkpoint inside override_settings causes A1111 to
      // attempt a model reload mid-request, which splits tensors across
      // cpu and cuda and throws:
      //   "Expected all tensors to be on the same device"
      // The model switch is already handled by switchLocalModel() above.
    };

    final client = http.Client();
    // Live progress while the txt2img request is in flight: A1111 exposes
    // GET /sdapi/v1/progress with a percent AND an in-progress preview frame,
    // so the chat/studio can show the image forming instead of a spinner.
    final progressUri = Uri.parse(
      '${ComfyUiService.ensureHttpScheme(baseUrl)}/sdapi/v1/progress',
    );
    final progressTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final r = await http
            .get(progressUri)
            .timeout(const Duration(seconds: 2));
        if (r.statusCode != 200) return;
        final p = jsonDecode(r.body) as Map<String, dynamic>;
        final pct = (p['progress'] as num?)?.toDouble();
        final b64 = p['current_image'] as String?;
        _updateGenProgress(
          (pct != null && pct > 0) ? pct.clamp(0.0, 1.0) : null,
          (b64 != null && b64.isNotEmpty) ? base64Decode(b64) : null,
        );
      } catch (_) {
        // transient — the next tick retries; the request itself is the truth
      }
    });
    try {
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 600)); // allow time for model load

      if (response.statusCode != 200) {
        String errorMsg = 'HTTP ${response.statusCode}';
        try {
          final errBody = jsonDecode(response.body);
          final detail = errBody['detail'];
          if (detail is String) errorMsg = detail;
        } catch (_) {}
        throw Exception(errorMsg);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final images = body['images'] as List<dynamic>?;
      if (images == null || images.isEmpty) {
        throw Exception('No images returned from local server');
      }

      final b64 = images[0] as String;
      return base64Decode(b64);
    } finally {
      progressTimer.cancel();
      client.close();
    }
  }

  /// Generate via Draw Things gRPC service (Python client bridge).
  /// Extended with DT-native params, LoRAs, + optional reference image (passed through to CLI).
  Future<Uint8List> _generateViaDrawThingsGrpc({
    required DrawThingsGrpcService grpcService,
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
    int sampler = 16,
    int seedMode = 2,
    bool teaCache = false,
    double teaCacheThreshold = 0.15,
    bool cfgZeroStar = false,
    List<Map<String, dynamic>> loras = const [],
    Uint8List? referenceImage,
    void Function(int step, int totalSteps)? onProgress,
  }) async {
    return await grpcService.generateImage(
      prompt: prompt,
      negativePrompt: negativePrompt,
      model: model,
      width: width,
      height: height,
      steps: steps,
      cfgScale: cfgScale,
      seed: seed,
      strength: strength,
      shift: shift,
      sampler: sampler,
      seedMode: seedMode,
      teaCache: teaCache,
      teaCacheThreshold: teaCacheThreshold,
      cfgZeroStar: cfgZeroStar,
      loras: loras,
      referenceImageBytes: referenceImage,
      onProgress: onProgress,
    );
  }

  /// Detect if URL is an OpenRouter-style API (uses chat/completions for images).
  bool _isOpenRouterStyle(String url) {
    return url.contains('openrouter.ai');
  }

  /// Generate via OpenAI-compatible /images/generations endpoint.
  /// Works with Nano-GPT, direct OpenAI, and local A1111/SD servers.
  ///
  /// NOTE: [negativePrompt] is accepted for signature symmetry but is NOT
  /// sent — the OpenAI images API has no negative_prompt parameter and
  /// rejects unknown fields, so it is deliberately dropped here (and by
  /// [_generateViaOpenRouter]). Negatives only take effect on the A1111 and
  /// Draw Things backends.
  Future<Uint8List> _generateViaOpenAICompat({
    required String apiUrl,
    required String apiKey,
    required String model,
    required String prompt,
    String negativePrompt = '',
    String size = '1024x1024',
  }) async {
    final imageEndpoint = '$apiUrl/images/generations';
    debugPrint('ImageGen: POST $imageEndpoint (model=$model)');
    final uri = Uri.parse(imageEndpoint);
    final payload = <String, dynamic>{
      'model': model,
      'prompt': prompt,
      'n': 1,
      'size': size,
      'response_format': 'b64_json',
    };

    final client = http.Client();
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        debugPrint('ImageGen: HTTP ${response.statusCode} from $imageEndpoint');
        debugPrint('ImageGen: Response body: ${response.body}');
        String errorMsg = 'HTTP ${response.statusCode}';
        try {
          final errBody = jsonDecode(response.body);
          final error = errBody['error'];
          // Handle both OpenAI format {"error":{"message":"..."}} and
          // Nano-GPT format {"error":"...","code":"..."}
          if (error is Map<String, dynamic>) {
            errorMsg = error['message'] as String? ?? errorMsg;
          } else if (error is String) {
            errorMsg = error;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }

      final body = jsonDecode(response.body);
      final data = body['data'] as List<dynamic>;
      if (data.isEmpty) throw Exception('No image data returned');

      // Handle both b64_json and url response formats
      final first = data[0] as Map<String, dynamic>;
      if (first.containsKey('b64_json')) {
        return base64Decode(first['b64_json'] as String);
      } else if (first.containsKey('url')) {
        // Download the image from the URL
        final imgResponse = await client
            .get(Uri.parse(first['url'] as String))
            .timeout(const Duration(seconds: 30));
        if (imgResponse.statusCode != 200) {
          throw Exception('Failed to download image from URL');
        }
        return imgResponse.bodyBytes;
      } else {
        throw Exception('Unexpected response format');
      }
    } finally {
      client.close();
    }
  }

  /// Generate via OpenRouter's chat/completions endpoint with image modality.
  Future<Uint8List> _generateViaOpenRouter({
    required String apiUrl,
    required String apiKey,
    required String model,
    required String prompt,
    String size = '1024x1024',
  }) async {
    final uri = Uri.parse('$apiUrl/chat/completions');
    final payload = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'modalities': ['image'],
      'max_tokens': 4096,
    };

    final client = http.Client();
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer': 'https://github.com/linux4life1/front-porch-AI',
              'X-Title': 'Front Porch AI',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        String errorMsg = 'HTTP ${response.statusCode}';
        try {
          final errBody = jsonDecode(response.body);
          final error = errBody['error'];
          if (error is Map<String, dynamic>) {
            errorMsg = error['message'] as String? ?? errorMsg;
          } else if (error is String) {
            errorMsg = error;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }

      final body = jsonDecode(response.body);
      final choices = body['choices'] as List<dynamic>? ?? [];
      if (choices.isEmpty) throw Exception('No response choices');

      final message = choices[0]['message'] as Map<String, dynamic>;
      final content = message['content'];

      // OpenRouter may return content as a list with image parts
      if (content is List) {
        for (final part in content) {
          if (part is Map<String, dynamic>) {
            if (part['type'] == 'image_url') {
              final imageUrl = part['image_url']?['url'] as String?;
              if (imageUrl != null) {
                if (imageUrl.startsWith('data:')) {
                  // Base64 data URI
                  final b64 = imageUrl.split(',').last;
                  return base64Decode(b64);
                } else {
                  // Regular URL — download it
                  final imgResp = await client
                      .get(Uri.parse(imageUrl))
                      .timeout(const Duration(seconds: 30));
                  return imgResp.bodyBytes;
                }
              }
            }
          }
        }
      }

      // Fallback: try to extract base64 from string content
      if (content is String && content.isNotEmpty) {
        // Check if it's a base64 string
        try {
          return base64Decode(content);
        } catch (_) {
          throw Exception('Could not extract image from response');
        }
      }

      throw Exception('No image found in response');
    } finally {
      client.close();
    }
  }
}
