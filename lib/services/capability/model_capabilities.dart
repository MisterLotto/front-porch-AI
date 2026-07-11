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

import 'package:front_porch_ai/utils/gguf_vision.dart';

/// Where a vision verdict came from. Higher-quality signals (metadata, embedded
/// GGUF projector) are preferred over the runtime probe of last resort.
enum VisionSource {
  /// The local GGUF file carries the vision projector itself.
  ggufEmbedded,

  /// The local GGUF is multimodal and a matching mmproj file is configured.
  ggufWithMmproj,

  /// A remote provider's `/models` metadata declared image support.
  apiMetadata,

  /// A runtime probe (sent a tiny test image and it was accepted).
  probe,

  /// No vision support detected.
  none,
}

/// A single cached verdict on whether a backend+model can accept images.
class VisionSupport {
  final bool supported;
  final VisionSource source;

  const VisionSupport(this.supported, this.source);

  /// The universal "no vision" verdict.
  static const VisionSupport none = VisionSupport(false, VisionSource.none);

  /// Pure verdict for a local GGUF, given its parsed [GgufVisionInfo] and
  /// whether a usable mmproj file is currently configured for it.
  ///
  /// - Embedded projector       → supported ([VisionSource.ggufEmbedded]).
  /// - An mmproj is configured  → supported ([VisionSource.ggufWithMmproj]),
  ///   regardless of what the arch heuristic thinks (see below).
  /// - Otherwise                → not supported.
  ///
  /// An explicitly-configured mmproj is AUTHORITATIVE and is trusted even when
  /// [GgufVisionInfo.isMultimodal] is false. The arch check
  /// ([GgufVisionParser.alwaysMultimodalArches]) is deliberately conservative
  /// and misses plenty of real vision models — finetunes that rename the arch
  /// ("…-heretic"), quant variants, and any model whose vision config lives
  /// entirely in the companion mmproj rather than the main file. A user who
  /// picked an mmproj file for this model knows it does vision; KoboldCpp loads
  /// it via `--mmproj` and it works. Gating on the heuristic here is exactly
  /// what left users unable to enable vision on models we failed to recognize.
  factory VisionSupport.fromGguf(
    GgufVisionInfo? info, {
    required bool mmprojConfigured,
  }) {
    if (info == null) return VisionSupport.none;
    if (info.hasEmbeddedProjector) {
      return const VisionSupport(true, VisionSource.ggufEmbedded);
    }
    if (mmprojConfigured) {
      return const VisionSupport(true, VisionSource.ggufWithMmproj);
    }
    return VisionSupport.none;
  }

  /// Pure verdict from a remote provider's parsed capabilities.
  factory VisionSupport.fromApi(ModelApiCapabilities? caps) {
    if (caps != null && caps.vision) {
      return const VisionSupport(true, VisionSource.apiMetadata);
    }
    return VisionSupport.none;
  }

  @override
  String toString() => 'VisionSupport(supported: $supported, source: $source)';
}

/// Capabilities distilled from a provider `/models` entry.
///
/// Only [vision] is consumed today. [toolCalling] is parsed from the very same
/// metadata (OpenRouter's `supported_parameters`, Nano-GPT's
/// `capabilities.tool_calling`) so a later phase can adopt native tool calling
/// without another round-trip — the seam is intentionally left obvious here.
class ModelApiCapabilities {
  final bool vision;
  final bool toolCalling;

  const ModelApiCapabilities({this.vision = false, this.toolCalling = false});

  /// Parse an OpenRouter `/models` entry.
  ///
  /// Vision: `architecture.input_modalities` contains `"image"`.
  /// Tools:  `supported_parameters` contains `"tools"`.
  factory ModelApiCapabilities.fromOpenRouterEntry(Map<dynamic, dynamic> entry) {
    bool vision = false;
    final arch = entry['architecture'];
    if (arch is Map) {
      final modalities = arch['input_modalities'];
      if (modalities is List) {
        vision = modalities
            .map((e) => e.toString().toLowerCase())
            .contains('image');
      }
    }

    bool tools = false;
    final params = entry['supported_parameters'];
    if (params is List) {
      tools = params.map((e) => e.toString().toLowerCase()).contains('tools');
    }

    return ModelApiCapabilities(vision: vision, toolCalling: tools);
  }

  /// Parse a Nano-GPT `/models?detailed=true` entry, whose `capabilities`
  /// object exposes `vision` and `tool_calling` booleans (absent on the basic,
  /// non-detailed list — which is why the detailed request is required).
  factory ModelApiCapabilities.fromNanoGptEntry(Map<dynamic, dynamic> entry) {
    final caps = entry['capabilities'];
    if (caps is Map) {
      return ModelApiCapabilities(
        vision: caps['vision'] == true,
        toolCalling: caps['tool_calling'] == true,
      );
    }
    return const ModelApiCapabilities();
  }
}

/// True for Nano-GPT hosts, whose `/models` needs `?detailed=true` to surface
/// the per-model `capabilities` block.
bool isNanoGptUrl(String apiUrl) => apiUrl.toLowerCase().contains('nano-gpt');

/// True when [apiUrl] points at a provider whose `/models` metadata describes
/// per-model capabilities (vision, tool calling): OpenRouter or Nano-GPT.
/// Everything else — generic OpenAI-compatible servers, oMLX at localhost —
/// has no capability metadata and stays on the runtime probes.
bool isCapabilityMetadataProviderUrl(String apiUrl) =>
    apiUrl.toLowerCase().contains('openrouter.ai') || isNanoGptUrl(apiUrl);
