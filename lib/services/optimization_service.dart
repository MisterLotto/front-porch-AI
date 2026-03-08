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
      // Estimate KV cache VRAM cost: ~0.5 MB per 1K context (rough FP16 estimate)
      // Actual varies by model architecture, but this is conservative
      final contextVramMb = (requestedContextSize / 1024 * 0.5).round();
      final availableForLayers = vram - contextVramMb - 200; // 200MB safety margin

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
