import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/llm_service.dart';

/// Available image generation modes.
enum ImageGenMode {
  customPrompt,
  visualizeScene,
  fromLastMessage,
  characterPortrait,
  chatBackground,
  userAvatar,
}

/// Metadata for an image model available via the remote API.
class ImageModelInfo {
  final String id;
  final String name;
  /// Whether this model costs extra per-prompt (true) or is included
  /// with a Nano-GPT Pro subscription (false).
  final bool isPaid;

  const ImageModelInfo({required this.id, this.name = '', this.isPaid = true});

  String get displayName => name.isNotEmpty ? name : id;
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

  bool get isGenerating => _isGenerating;
  String get statusMessage => _statusMessage;
  Uint8List? get lastGeneratedImage => _lastGeneratedImage;
  String? get lastSavedPath => _lastSavedPath;
  bool get isConfigured =>
      _storage.imageGenEnabled &&
      _storage.remoteApiKey.isNotEmpty &&
      _storage.imageGenModel.isNotEmpty;

  ImageGenService(this._storage);

  /// Build the images directory path.
  Directory get _imagesDir => Directory(
      path.join(_storage.rootPath ?? '', 'KoboldManager', 'images'));

  /// Generate an image from a prompt.
  ///
  /// Returns the image bytes on success, or null on failure.
  Future<Uint8List?> generateImage({
    required String prompt,
    String negativePrompt = '',
    String? size,
    String? model,
  }) async {
    if (_storage.remoteApiKey.isEmpty) {
      _statusMessage = 'No API key configured.';
      notifyListeners();
      return null;
    }

    final imageModel = model ?? _storage.imageGenModel;
    if (imageModel.isEmpty) {
      _statusMessage = 'No image model selected.';
      notifyListeners();
      return null;
    }

    final imageSize = size ?? _storage.imageGenSize;
    final apiUrl = _storage.remoteApiUrl;
    final apiKey = _storage.remoteApiKey;

    _isGenerating = true;
    _statusMessage = 'Generating image...';
    _lastGeneratedImage = null;
    _lastSavedPath = null;
    notifyListeners();

    try {
      Uint8List imageBytes;

      // Detect API style based on URL
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

      _lastGeneratedImage = imageBytes;
      _statusMessage = 'Image generated successfully.';
      notifyListeners();
      return imageBytes;
    } catch (e) {
      _statusMessage = 'Generation failed: $e';
      notifyListeners();
      return null;
    } finally {
      _isGenerating = false;
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

  /// Common image generation models available on popular API providers.
  /// These are always shown so the user can pick one even when the API's
  /// /models endpoint doesn't list image models separately.
  /// IDs verified from Nano-GPT pricing page (Feb 2026).
  static const _commonImageModels = <ImageModelInfo>[
    // ── Included with Nano-GPT Pro subscription ($8/mo) ──
    ImageModelInfo(id: 'hidream', name: 'HiDream', isPaid: false),
    ImageModelInfo(id: 'chroma', name: 'Chroma', isPaid: false),
    ImageModelInfo(id: 'z-image-turbo', name: 'Z Image Turbo', isPaid: false),
    ImageModelInfo(id: 'qwen-image', name: 'Qwen Image', isPaid: false),
    // ── Pay-per-prompt models ──
    ImageModelInfo(id: 'dall-e-3', name: 'DALL-E 3'),
    ImageModelInfo(id: 'flux-1-pro', name: 'FLUX.1 Pro'),
    ImageModelInfo(id: 'flux-1-dev', name: 'FLUX.1 Dev'),
    ImageModelInfo(id: 'flux-1-schnell', name: 'FLUX.1 Schnell'),
    ImageModelInfo(id: 'ideogram-v3-default', name: 'Ideogram V3'),
    ImageModelInfo(id: 'ideogram-v3-turbo', name: 'Ideogram V3 Turbo'),
    ImageModelInfo(id: 'cogview-4', name: 'CogView-4'),
    ImageModelInfo(id: 'mjv6', name: 'Flux Midjourney (MJV6)'),
    ImageModelInfo(id: 'dreamshaper-xl', name: 'Dreamshaper XL'),
    ImageModelInfo(id: 'nsfw-gen-illustrious', name: 'Animagine XL 4.0'),
    ImageModelInfo(id: 'atomix-xl', name: 'Atomix XL'),
    ImageModelInfo(id: 'background-remover', name: 'Background Remover'),
    ImageModelInfo(id: 'esrgan-4x', name: 'ESRGAN 4x Upscaler'),
  ];

  /// Fetch available image models.
  ///
  /// Returns a merged list of:
  /// 1. Models discovered from the API's /models endpoint (if it tags image models)
  /// 2. A curated list of common image models (always included as fallback)
  ///
  /// Many providers (e.g. Nano-GPT) do not expose image models via /models,
  /// so the curated list ensures the dropdown is never empty.
  Future<List<ImageModelInfo>> fetchImageModels() async {
    final apiUrl = _storage.remoteApiUrl;
    final apiKey = _storage.remoteApiKey;
    if (apiUrl.isEmpty || apiKey.isEmpty) return List.from(_commonImageModels);

    final apiModels = <ImageModelInfo>[];
    final client = http.Client();

    try {
      final uri = Uri.parse('$apiUrl/models');
      final response = await client.get(
        uri,
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] as List<dynamic>? ?? [];

        for (final m in data) {
          final id = m['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final name = m['name']?.toString() ?? id;

          // If the API provides architecture/modality metadata, use it
          final arch = m['architecture'] as Map<String, dynamic>?;
          if (arch != null) {
            final outputModalities = arch['output_modalities'] as List<dynamic>?;
            if (outputModalities != null && outputModalities.contains('image')) {
              apiModels.add(ImageModelInfo(id: id, name: name));
              continue;
            }
          }

          // Also match well-known image model IDs from the model list
          if (_isKnownImageModel(id.toLowerCase())) {
            apiModels.add(ImageModelInfo(id: id, name: name));
          }
        }
      }
    } catch (_) {
      // API call failed — we'll still return the common models
    } finally {
      client.close();
    }

    // Merge: API-discovered models first, then common models not already found
    final seenIds = apiModels.map((m) => m.id.toLowerCase()).toSet();
    final merged = <ImageModelInfo>[...apiModels];
    for (final common in _commonImageModels) {
      if (!seenIds.contains(common.id.toLowerCase())) {
        merged.add(common);
      }
    }

    merged.sort((a, b) => a.displayName.compareTo(b.displayName));
    return merged;
  }

  /// Max prompt length for image generation APIs.
  /// Most models cap at 1000-1200 chars; we target 1000 to be safe.
  static const _maxPromptLength = 1000;

  /// Truncate a string to a maximum length, breaking at a word boundary.
  static String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    final cut = text.substring(0, maxLen);
    final lastSpace = cut.lastIndexOf(' ');
    return '${lastSpace > maxLen ~/ 2 ? cut.substring(0, lastSpace) : cut}...';
  }

  /// Style suffixes appended to the final image prompt.
  static const Map<String, String> styleModifiers = {
    'photorealistic': 'Style: photorealistic, cinematic lighting, high detail, 8K',
    'anime': 'Style: anime illustration, vibrant colors, cel-shaded, manga art',
    'fantasy_art': 'Style: fantasy art, epic, painterly, detailed environment',
    'oil_painting': 'Style: oil painting, classical, rich textures, fine art',
    'digital_art': 'Style: digital art, modern, vibrant, professional illustration',
    'watercolor': 'Style: watercolor painting, soft, flowing, delicate',
  };

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
  /// Falls back to the static [buildPrompt] if [llmService] is null or unavailable.
  Future<String> generateSmartPrompt({
    required ImageGenMode mode,
    required String style,
    LLMService? llmService,
    String? customPrompt,
    String? lastMessage,
    String? characterName,
    String? characterDescription,
    String? characterPersonality,
    String? scenario,
    String? worldInfo,
    String? personaName,
    String? personaDescription,
    List<String>? recentMessages,
  }) async {
    // Custom prompt mode — no LLM needed, just append style
    if (mode == ImageGenMode.customPrompt) {
      final styleSuffix = styleModifiers[style] ?? '';
      final raw = '${customPrompt ?? ''}. $styleSuffix';
      return _truncate(raw, _maxPromptLength);
    }

    // Replace {{user}}/{{char}} macros in raw context
    String resolve(String? text) {
      if (text == null || text.isEmpty) return '';
      return text
          .replaceAll('{{user}}', personaName ?? 'User')
          .replaceAll('{{char}}', characterName ?? 'Character');
    }

    // Build raw context block for the LLM
    final contextParts = <String>[];
    if (characterName != null && characterName.isNotEmpty) {
      contextParts.add('Character: $characterName');
    }
    if (characterDescription != null && characterDescription.isNotEmpty) {
      contextParts.add('Appearance: ${resolve(characterDescription)}');
    }
    if (scenario != null && scenario.isNotEmpty) {
      contextParts.add('Scenario: ${resolve(scenario)}');
    }
    if (worldInfo != null && worldInfo.isNotEmpty) {
      contextParts.add('Setting: ${resolve(worldInfo)}');
    }
    if (recentMessages != null && recentMessages.isNotEmpty) {
      final resolved = recentMessages.map((m) => resolve(m)).join('\n');
      contextParts.add('Recent events:\n$resolved');
    }
    if (lastMessage != null && lastMessage.isNotEmpty) {
      contextParts.add('Latest message: ${resolve(lastMessage)}');
    }
    if (personaName != null && personaName.isNotEmpty) {
      contextParts.add('User character: $personaName');
    }

    final rawContext = _truncate(contextParts.join('\n'), 2000);
    final styleSuffix = styleModifiers[style] ?? '';

    // If no LLM available, fall back to static prompt builder
    if (llmService == null || !llmService.isReady) {
      debugPrint('ImageGen: LLM unavailable, falling back to static prompt');
      final fallback = buildPrompt(
        mode: mode,
        customPrompt: customPrompt,
        lastMessage: lastMessage,
        characterName: characterName,
        characterDescription: characterDescription,
        characterPersonality: characterPersonality,
        scenario: scenario,
        worldInfo: worldInfo,
        personaName: personaName,
        personaDescription: personaDescription,
        recentMessages: recentMessages,
      );
      return _truncate('$fallback. $styleSuffix', _maxPromptLength);
    }

    // Mode-specific instruction
    String modeInstruction;
    switch (mode) {
      case ImageGenMode.visualizeScene:
        modeInstruction = 'Describe the current scene as a vivid image — environment, characters present, lighting, mood.';
      case ImageGenMode.fromLastMessage:
        modeInstruction = 'Describe the scene depicted in the latest message as a vivid image.';
      case ImageGenMode.characterPortrait:
        modeInstruction = 'Describe a portrait of the character — their appearance, expression, clothing, and pose.';
      case ImageGenMode.chatBackground:
        modeInstruction = 'Describe the environment/setting as a wide panoramic landscape. Do NOT include any characters or people.';
      case ImageGenMode.userAvatar:
        modeInstruction = 'Describe a portrait of the user character — their appearance, expression, and pose.';
      default:
        modeInstruction = 'Describe the scene as a vivid image.';
    }

    // Keep the instruction SHORT — thinking models regurgitate verbose prompts
    final styleInstruction = styleSuffix.isNotEmpty ? ' Art style: $styleSuffix.' : '';
    final llmPrompt = 'Write a short image prompt (under 100 words) for an AI image generator.$styleInstruction\n'
        '$modeInstruction\n'
        'Describe ONLY visual details: appearance, scene, lighting, mood. '
        'Use physical descriptions instead of names.\n\n'
        'Context:\n$rawContext\n\n'
        'Image prompt:';

    try {
      debugPrint('ImageGen: Crafting smart prompt via LLM...');
      String accumulated = '';
      await for (final token in llmService.generateStream(GenerationParams(
        prompt: llmPrompt,
        maxLength: 200,
        temperature: 0.2,
        repeatPenalty: 1.0,
        reasoningEnabled: false,
        stopSequences: ['\n\n', '<END>', '</END>'],
      ))) {
        accumulated += token;
      }

      // ── Clean LLM output ──
      String smartPrompt = accumulated;

      // Strip <think> blocks
      smartPrompt = smartPrompt
          .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '');

      // If there's an "Image prompt:" marker, take only what follows
      final markerMatch = RegExp(r'[Ii]mage\s*prompt\s*:\s*').firstMatch(smartPrompt);
      if (markerMatch != null) {
        smartPrompt = smartPrompt.substring(markerMatch.end);
      }

      // Strip markdown: **bold**, headers, lists
      smartPrompt = smartPrompt
          .replaceAll(RegExp(r'#{1,6}\s*'), '')
          .replaceAllMapped(RegExp(r'\*{1,3}([^*]+)\*{1,3}'), (m) => m.group(1) ?? '')
          .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
          .replaceAll(RegExp(r'^\s*[-•*]\s+', multiLine: true), '')
          .replaceAll(RegExp(r'\n+'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();

      // Detect echoed instructions — if the output contains our instruction text, the model failed
      final echoMarkers = ['concise visual description', 'image generator', 'physical descriptions instead of names',
                           'Output ONLY', 'Do NOT', 'VISUALLY happening'];
      final isEcho = echoMarkers.any((marker) => smartPrompt.toLowerCase().contains(marker.toLowerCase()));

      if (smartPrompt.isEmpty || isEcho) {
        debugPrint('ImageGen: LLM echoed instructions or empty, falling back to static prompt');
        final fallback = buildPrompt(
          mode: mode,
          customPrompt: customPrompt,
          lastMessage: lastMessage,
          characterName: characterName,
          characterDescription: characterDescription,
          characterPersonality: characterPersonality,
          scenario: scenario,
          worldInfo: worldInfo,
          personaName: personaName,
          personaDescription: personaDescription,
          recentMessages: recentMessages,
        );
        return _truncate('$fallback. $styleSuffix', _maxPromptLength);
      }

      // Ensure style is present
      if (styleSuffix.isNotEmpty && !smartPrompt.toLowerCase().contains(styleSuffix.toLowerCase().substring(0, 10))) {
        smartPrompt = '$smartPrompt. $styleSuffix';
      }

      debugPrint('ImageGen: Smart prompt crafted (${smartPrompt.length} chars)');
      return _truncate(smartPrompt, _maxPromptLength);
    } catch (e) {
      debugPrint('ImageGen: Smart prompt failed ($e), falling back to static');
      final fallback = buildPrompt(
        mode: mode,
        customPrompt: customPrompt,
        lastMessage: lastMessage,
        characterName: characterName,
        characterDescription: characterDescription,
        characterPersonality: characterPersonality,
        scenario: scenario,
        worldInfo: worldInfo,
        personaName: personaName,
        personaDescription: personaDescription,
        recentMessages: recentMessages,
      );
      return _truncate('$fallback. $styleSuffix', _maxPromptLength);
    }
  }

  /// Build a prompt for the given generation mode.
  String buildPrompt({
    required ImageGenMode mode,
    String? customPrompt,
    String? lastMessage,
    String? characterName,
    String? characterDescription,
    String? characterPersonality,
    String? scenario,
    String? worldInfo,
    String? personaName,
    String? personaDescription,
    List<String>? recentMessages,
  }) {
    String raw;
    switch (mode) {
      case ImageGenMode.customPrompt:
        raw = customPrompt ?? '';

      case ImageGenMode.visualizeScene:
        final parts = <String>[];
        if (scenario != null && scenario.isNotEmpty) {
          parts.add('Scene: ${_truncate(scenario, 300)}');
        }
        if (worldInfo != null && worldInfo.isNotEmpty) {
          parts.add('Setting: ${_truncate(worldInfo, 200)}');
        }
        if (recentMessages != null && recentMessages.isNotEmpty) {
          parts.add('Recent events: ${_truncate(recentMessages.join(" "), 300)}');
        }
        parts.add('Style: cinematic, atmospheric, detailed environment.');
        raw = parts.join(' ');

      case ImageGenMode.fromLastMessage:
        if (lastMessage == null || lastMessage.isEmpty) return '';
        raw = 'Depict the following scene: ${_truncate(lastMessage, 500)}';

      case ImageGenMode.characterPortrait:
        final parts = <String>[];
        if (characterName != null && characterName.isNotEmpty) {
          parts.add('Character portrait of $characterName.');
        }
        if (characterDescription != null && characterDescription.isNotEmpty) {
          parts.add(_truncate(characterDescription, 400));
        }
        if (characterPersonality != null && characterPersonality.isNotEmpty) {
          parts.add('Personality: ${_truncate(characterPersonality, 200)}');
        }
        parts.add('Style: detailed character portrait, expressive, high quality.');
        raw = parts.join(' ');

      case ImageGenMode.chatBackground:
        final parts = <String>[];
        if (scenario != null && scenario.isNotEmpty) {
          parts.add('Environment: ${_truncate(scenario, 300)}');
        }
        if (worldInfo != null && worldInfo.isNotEmpty) {
          parts.add('Setting: ${_truncate(worldInfo, 300)}');
        }
        parts.add('Style: wide panoramic landscape, atmospheric, suitable as a wallpaper background, no characters or people.');
        raw = parts.join(' ');

      case ImageGenMode.userAvatar:
        final parts = <String>[];
        if (personaName != null && personaName.isNotEmpty) {
          parts.add('Portrait of $personaName.');
        }
        if (personaDescription != null && personaDescription.isNotEmpty) {
          parts.add(_truncate(personaDescription, 400));
        }
        parts.add('Style: detailed character portrait, expressive, high quality.');
        raw = parts.join(' ');
    }

    // Final safety cap
    return _truncate(raw, _maxPromptLength);
  }

  // ── Private helpers ────────────────────────────────────────────────

  /// Detect if URL is an OpenRouter-style API (uses chat/completions for images).
  bool _isOpenRouterStyle(String url) {
    return url.contains('openrouter.ai');
  }

  /// Check if a model ID is a well-known image generation model.
  bool _isKnownImageModel(String id) {
    const knownPrefixes = [
      'dall-e', 'flux', 'hidream', 'stable-diffusion', 'sdxl',
      'black-forest-labs', 'playground', 'midjourney', 'imagen',
      'gpt-image', 'openai/gpt-image', 'stability',
      // Nano-GPT specific
      'ideogram', 'cogview', 'dreamshaper', 'animagine', 'atomix',
      'mjv', 'esrgan', 'background-remover', 'qrbtf', 'riverflow',
      'glm-image', 'z-image', 'nsfw-gen', 'rev-animated', 'wai-',
      'cyberrealistic', '2dn-pony', 'nano-banana', 'boltning',
    ];
    for (final prefix in knownPrefixes) {
      if (id.contains(prefix)) return true;
    }
    return false;
  }

  /// Generate via OpenAI-compatible /images/generations endpoint.
  /// Works with Nano-GPT, direct OpenAI, and local A1111/SD servers.
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
      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

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
        final imgResponse =
            await client.get(Uri.parse(first['url'] as String))
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
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'modalities': ['image'],
      'max_tokens': 4096,
    };

    final client = http.Client();
    try {
      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://github.com/linux4life1/front-porch-AI',
          'X-Title': 'Front Porch AI',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

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
                  final imgResp = await client.get(Uri.parse(imageUrl))
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
