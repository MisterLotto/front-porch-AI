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

import 'dart:io';
import 'package:front_porch_ai/services/hardware_service.dart';

class OptimizationResult {
  final int gpuLayers;
  final int contextSize;
  final bool useVulkan;
  final String reasoning;

  OptimizationResult({
    required this.gpuLayers,
    required this.contextSize,
    required this.useVulkan,
    required this.reasoning,
  });
}

class OptimizationService {
  /// Calculate optimal settings for KoboldCpp based on hardware.
  ///
  /// If [requestedContextSize] is provided, the context size is respected
  /// and GPU layers are adjusted to accommodate it. If null, context is
  /// auto-determined from VRAM tiers.
  static OptimizationResult calculateSettings(
    HardwareInfo hardware, {
    int modelSizeMb = 0,
    int? requestedContextSize,
    int? kvBytesPerToken,
    int kvQuantizationLevel = 0,
  }) {
    int vram = hardware.vramMb;
    
    // For shared memory GPUs (Intel ARC, AMD APU), be conservative —
    // the OS and other apps also need system RAM, so only use ~60%
    if (hardware.isSharedMemory) {
      vram = (vram * 0.6).round();
    }
    
    // Default to Vulkan for non-Nvidia, non-Mac (Mac uses Metal)
    bool useVulkan = hardware.vendor != 'Nvidia' && !Platform.isMacOS;
    bool useMetal = Platform.isMacOS;

    // Build the backend suffix for reasoning messages
    String backendNote = useMetal ? ' Using Metal.' : useVulkan ? ' Using Vulkan.' : '';
    String sharedNote = hardware.isSharedMemory ? ' (Shared memory GPU — using conservative estimate)' : '';

    // If user specified a context size, respect it and adjust GPU layers
    if (requestedContextSize != null && requestedContextSize > 0) {
      // Use exact KV cost if known, otherwise fall back to ~100 MB per 1K heuristic
      double contextVramMb = kvBytesPerToken != null
          ? (requestedContextSize * kvBytesPerToken / (1024 * 1024))
          : (requestedContextSize / 1024 * 100.0);
          
      // Apply KV Cache Quantization multiplier
      if (kvQuantizationLevel == 1) {
        contextVramMb *= 0.5; // Q8 is ~50% the size of f16
      } else if (kvQuantizationLevel == 2) {
        contextVramMb *= 0.25; // Q4 is ~25% the size of f16
      }
          
      final availableForLayers = vram - contextVramMb.round() - 200; // 200MB safety margin

      int gpuLayers;
      String reasoning;

      if (availableForLayers > modelSizeMb + 500) {
        gpuLayers = 99; // Enough VRAM for all layers + requested context
        reasoning = 'Full GPU offload with ${requestedContextSize} context.$backendNote$sharedNote';
      } else if (availableForLayers > modelSizeMb * 0.5) {
        // Can offload a good portion
        final ratio = availableForLayers / (modelSizeMb > 0 ? modelSizeMb : 5000);
        gpuLayers = (ratio * 40).round().clamp(1, 99); // rough layer estimate
        reasoning = 'Partial GPU offload ($gpuLayers layers) to fit ${requestedContextSize} context.$backendNote$sharedNote';
      } else if (availableForLayers > 1000) {
        gpuLayers = (availableForLayers / 200).round().clamp(1, 20);
        reasoning = 'Limited GPU offload ($gpuLayers layers) — large context uses most VRAM.$backendNote$sharedNote';
      } else {
        gpuLayers = 0;
        reasoning = 'CPU-only mode — ${requestedContextSize} context requires too much VRAM for GPU layers.$sharedNote';
      }

      return OptimizationResult(
        gpuLayers: gpuLayers,
        contextSize: requestedContextSize,
        useVulkan: useVulkan,
        reasoning: reasoning,
      );
    }

    // No user-specified context — auto-determine from VRAM tiers
    if (vram > modelSizeMb + 1000) {
      return OptimizationResult(
        gpuLayers: 99, // Offload all
        contextSize: 8192,
        useVulkan: useVulkan,
        reasoning: 'High VRAM detected. Offloading all layers to GPU.$backendNote$sharedNote',
      );
    } else if (vram > 4000) {
       return OptimizationResult(
        gpuLayers: 20,
        contextSize: 4096,
        useVulkan: useVulkan,
        reasoning: 'Moderate VRAM. Offloading some layers.$backendNote$sharedNote',
      );
    } else {
      return OptimizationResult(
        gpuLayers: 0,
        contextSize: 2048,
        useVulkan: useVulkan,
        reasoning: 'Low VRAM. Running primarily on CPU.$sharedNote',
      );
    }
  }
}
