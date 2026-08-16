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

/// Common image generation models available on Nano-GPT and similar providers.
/// These are always shown so the user can pick one even when the API's
/// /models endpoint doesn't list image models separately (Nano-GPT's /models
/// endpoint only returns text models; image models have no discovery endpoint).
///
/// Model IDs sourced from https://nano-gpt.com/models/image (May 2026).
const _commonImageModels = <ImageModelInfo>[
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

/// Cluster C — remote model catalog. fetchImageModels() itself (fake-pinned)
/// stays a shell instance member; this extension holds only the OpenRouter
/// HTTP helper it delegates to.
extension _ImageGenCatalog on ImageGenService {
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
}
