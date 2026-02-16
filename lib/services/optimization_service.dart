import 'dart:io';
import 'package:kobold_character_card_manager/services/hardware_service.dart';

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
  static OptimizationResult calculateSettings(HardwareInfo hardware, {int modelSizeMb = 0}) {
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

    // Basic heuristic: if VRAM is generous, offload everything
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
