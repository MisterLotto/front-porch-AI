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

part of 'image_gen_service.dart';

/// Cluster B (disk persistence) + Cluster F (backend generator
/// implementations). Neither saveImageToDisk/saveAvatarToDisk nor any
/// `_generateVia*`/helper below is overridden by a test fake, so all of it
/// moves here as ordinary extension members under their original names.
/// This extension's name is PUBLIC (not `_`-prefixed): saveImageToDisk and
/// saveAvatarToDisk are called from other libraries (chat_service parts, the
/// image studio, chat_page, the web image facade) — a private extension name
/// would make those calls resolve to `undefined_method`, because extension
/// applicability for a caller outside the declaring library requires the
/// extension itself to be public, independent of whether the individual
/// member name is public. (The private `_generateVia*`/helper members below
/// stay uncallable externally either way, by ordinary identifier privacy.)
/// The one edit versus the original file: `_generateViaA1111`'s internal
/// `buildA1111Payload(...)` call gains the `ImageGenService.` qualifier,
/// because that member is a true class static (kept on the shell for its
/// test-pinned qualified name) and statics are not in an extension's lexical
/// scope. Also: `notifyListeners()` calls become `_notify()` (the shell's
/// forwarder) — a direct call from here trips
/// `invalid_use_of_protected_member`.
extension ImageGenBackends on ImageGenService {
  /// Save the last generated image to disk.
  ///
  /// Returns the saved file path, or null on failure.
  ///
  /// [preferredFileName] — optional basename (e.g. package import). Sanitized
  /// and uniquified if a file already exists so back-to-back writes never
  /// collide on the same millisecond (review 03d46d9a finding 1).
  /// When omitted, uses `img_<ms>.png` with the same collision guard.
  Future<String?> saveImageToDisk([
    Uint8List? imageBytes,
    String? preferredFileName,
  ]) async {
    final bytes = imageBytes ?? _lastGeneratedImage;
    if (bytes == null) return null;

    try {
      final dir = _imagesDir;
      await dir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      var base = (preferredFileName != null && preferredFileName.trim().isNotEmpty)
          ? path.basename(preferredFileName.trim())
          : 'img_$timestamp.png';
      // Strip path traversal; force a png-ish name if empty after sanitize.
      base = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      if (base.isEmpty || base == '.' || base == '..') {
        base = 'img_$timestamp.png';
      }
      var file = File(path.join(dir.path, base));
      if (await file.exists()) {
        final stem = path.basenameWithoutExtension(base);
        final ext = path.extension(base).isEmpty ? '.png' : path.extension(base);
        var n = 1;
        do {
          file = File(path.join(dir.path, '${stem}_$n$ext'));
          n++;
        } while (await file.exists());
      }
      await file.writeAsBytes(bytes);

      // Import/package paths pass preferredFileName — do not clobber Image
      // Studio "last saved" or fire a notify storm (one per imported image).
      if (preferredFileName == null || preferredFileName.trim().isEmpty) {
        _lastSavedPath = file.path;
        _notify();
      }
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
      _notify();
      return file.path;
    } catch (e) {
      debugPrint('Failed to save avatar: $e');
      return null;
    }
  }

  /// Generate via AUTOMATIC1111 / Draw Things local server.
  ///
  /// Endpoint: POST {baseUrl}/sdapi/v1/txt2img — or /sdapi/v1/img2img when a
  /// [referenceImage] is supplied (init image at [denoise] denoising strength).
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
    String scheduler = 'Automatic',
    int seed = -1,
    Uint8List? referenceImage,
    double denoise = 0.5,
  }) async {
    // Switch model only if a different checkpoint was requested.
    // Skipping redundant switches prevents the unload→reload cycle that
    // can leave tensors split across CPU & CUDA on Windows/nVidia setups.
    if (switchModelFirst &&
        modelCheckpoint.isNotEmpty &&
        modelCheckpoint != _lastLoadedCheckpoint) {
      _statusMessage = 'Loading model: $modelCheckpoint…';
      _notify();
      await switchLocalModel(baseUrl, modelCheckpoint);
    }

    final (width, height) = _parseSize(size);
    // img2img when a reference image is supplied; else txt2img (unchanged path).
    final isImg2Img = referenceImage != null && referenceImage.isNotEmpty;
    final endpoint = isImg2Img ? 'img2img' : 'txt2img';
    final uri = Uri.parse(
      '${ComfyUiService.ensureHttpScheme(baseUrl)}/sdapi/v1/$endpoint',
    );

    // Inject LoRA into the prompt: <lora:name:weight>
    final effectivePrompt = (loraName.isNotEmpty)
        ? '$prompt <lora:$loraName:${loraWeight.toStringAsFixed(2)}>'
        : prompt;

    debugPrint(
      'ImageGen: POST $uri (model=${modelCheckpoint.isNotEmpty ? modelCheckpoint : "current"}, lora=${loraName.isNotEmpty ? loraName : "none"})',
    );

    final payload = ImageGenService.buildA1111Payload(
      prompt: effectivePrompt,
      negativePrompt: negativePrompt,
      width: width,
      height: height,
      steps: steps,
      cfgScale: cfgScale,
      samplerName: samplerName,
      scheduler: scheduler,
      seed: seed,
      referenceImageB64: isImg2Img ? base64Encode(referenceImage) : null,
      denoise: denoise,
    );

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
    // When set, this is an EDIT: POST the reference (as a base64 data URI) +
    // instruction to the OpenAI-compatible /images/edits endpoint instead of
    // /images/generations. Verified against Nano-GPT (JSON imageDataUrl variant).
    Uint8List? editImage,
  }) async {
    final isEdit = editImage != null;
    final imageEndpoint = isEdit
        ? '$apiUrl/images/edits'
        : '$apiUrl/images/generations';
    debugPrint('ImageGen: POST $imageEndpoint (model=$model, edit=$isEdit)');
    final uri = Uri.parse(imageEndpoint);
    final payload = isEdit
        ? <String, dynamic>{
            'model': model,
            'prompt': prompt,
            'imageDataUrl':
                'data:image/png;base64,${base64Encode(editImage)}',
          }
        : <String, dynamic>{
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
          // Handle both OpenAI format {"error":{"message":"..."}} and Nano-GPT
          // format {"error":"Insufficient balance","message":"Available X,
          // required Y","code":"insufficient_balance"} — prefer the detailed
          // top-level message so e.g. a low-balance edit says exactly how much.
          if (error is Map<String, dynamic>) {
            errorMsg = error['message'] as String? ?? errorMsg;
          } else if (error is String) {
            final detail = errBody['message'];
            errorMsg = (detail is String && detail.isNotEmpty) ? detail : error;
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
  ///
  /// When [editImage] is set this is an EDIT: the reference rides as an
  /// `image_url` content part (base64 data URI) alongside the instruction — the
  /// only image-edit shape OpenRouter exposes (it has no /images/edits). Wired
  /// from OpenRouter's documented multimodal image support but NOT verified
  /// in-house (only Nano-GPT's /images/edits was); community-verified.
  Future<Uint8List> _generateViaOpenRouter({
    required String apiUrl,
    required String apiKey,
    required String model,
    required String prompt,
    String size = '1024x1024',
    Uint8List? editImage,
  }) async {
    final uri = Uri.parse('$apiUrl/chat/completions');
    final content = editImage == null
        ? prompt
        : [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/png;base64,${base64Encode(editImage)}',
              },
            },
          ];
    final payload = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'user', 'content': content},
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

      // OpenRouter returns the generated/edited image in message.images:
      // [{type:'image_url', image_url:{url:'data:...'|'https://...'}}] — VERIFIED
      // live against a real edit (2026-07). This is where the image actually is;
      // the `content` shapes below are legacy/other-provider fallbacks.
      final images = message['images'];
      if (images is List) {
        for (final im in images) {
          if (im is! Map<String, dynamic>) continue;
          final iu = im['image_url'];
          final url = iu is Map<String, dynamic> ? iu['url'] as String? : null;
          if (url != null) return _imageBytesFromUrl(client, url);
        }
      }

      final content = message['content'];
      // Fallback: content as a list with image_url parts.
      if (content is List) {
        for (final part in content) {
          if (part is! Map<String, dynamic> || part['type'] != 'image_url') {
            continue;
          }
          final iu = part['image_url'];
          final url = iu is Map<String, dynamic> ? iu['url'] as String? : null;
          if (url != null) return _imageBytesFromUrl(client, url);
        }
      }

      // Fallback: a bare base64 string in content.
      if (content is String && content.isNotEmpty) {
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

  /// Decode an image reference from a chat image part — a `data:` base64 URI, or
  /// an https URL to download. Shared by the OpenRouter images/content parsing.
  Future<Uint8List> _imageBytesFromUrl(http.Client client, String url) async {
    if (url.startsWith('data:')) return base64Decode(url.split(',').last);
    final r = await client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    return r.bodyBytes;
  }
}
