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
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// ComfyUI backend client (plain HTTP — no sidecar). The novice contract:
/// ComfyUI runs on http://127.0.0.1:8188 out of the box, everything the UI
/// needs (models, LoRAs, samplers) is discovered via GET /object_info, and
/// generation submits a bundled txt2img workflow graph with the app's
/// prompt/model/LoRA/sampler slotted in — the user never sees a node graph.
/// The same graph shape covers SD1.5 and SDXL checkpoints (only the latent
/// size differs, and that comes from the configured size).
class ComfyUiService {
  ComfyUiService({required this.baseUrl});

  /// e.g. `http://127.0.0.1:8188` (trailing slash tolerated).
  final String baseUrl;

  String get _root => baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  /// Known A1111-style → ComfyUI sampler name mappings, used when the stored
  /// sampler (shared across backends) isn't already a ComfyUI-native name.
  static const Map<String, String> _samplerAliases = {
    'euler a': 'euler_ancestral',
    'euler': 'euler',
    'heun': 'heun',
    'ddim': 'ddim',
    'lcm': 'lcm',
    'uni_pc': 'uni_pc',
    'unipc': 'uni_pc',
    'dpm++ 2m': 'dpmpp_2m',
    'dpm++ 2m karras': 'dpmpp_2m',
    'dpm++ sde': 'dpmpp_sde',
    'dpm++ sde karras': 'dpmpp_sde',
    'dpm++ 2m sde': 'dpmpp_2m_sde',
    'dpm++ 2m sde karras': 'dpmpp_2m_sde',
    'dpm++ 3m sde': 'dpmpp_3m_sde',
  };

  /// Normalize a (possibly A1111-style) sampler name to one this ComfyUI
  /// server actually offers. Pure — unit-tested. Preference order: already
  /// valid → known alias → 'euler' → first available.
  static String normalizeSampler(String stored, List<String> available) {
    final s = stored.trim();
    if (available.contains(s)) return s;
    final alias = _samplerAliases[s.toLowerCase()];
    if (alias != null && (available.isEmpty || available.contains(alias))) {
      return alias;
    }
    if (available.contains('euler')) return 'euler';
    return available.isNotEmpty ? available.first : 'euler';
  }

  /// A "Karras"-flavored A1111 sampler name maps to the karras scheduler in
  /// ComfyUI (the sampler and schedule are separate knobs there). Pure.
  static String schedulerFor(String storedSampler) =>
      storedSampler.toLowerCase().contains('karras') ? 'karras' : 'normal';

  /// Build the bundled txt2img workflow (ComfyUI API format: node-id →
  /// {class_type, inputs}). When [loraName] is set, a LoraLoader is spliced
  /// between the checkpoint and the sampler/text-encoders. Pure — unit-tested.
  static Map<String, dynamic> buildTxt2ImgWorkflow({
    required String model,
    required String prompt,
    required String negativePrompt,
    required int width,
    required int height,
    required int steps,
    required double cfgScale,
    required int seed,
    required String samplerName,
    required String scheduler,
    String loraName = '',
    double loraWeight = 0.8,
  }) {
    final hasLora = loraName.isNotEmpty;
    // Model/clip source for the sampler + prompts: the checkpoint directly,
    // or the LoRA loader when one is selected.
    final modelSrc = hasLora ? ['lora', 0] : ['ckpt', 0];
    final clipSrc = hasLora ? ['lora', 1] : ['ckpt', 1];
    return {
      'ckpt': {
        'class_type': 'CheckpointLoaderSimple',
        'inputs': {'ckpt_name': model},
      },
      if (hasLora)
        'lora': {
          'class_type': 'LoraLoader',
          'inputs': {
            'lora_name': loraName,
            'strength_model': loraWeight,
            'strength_clip': loraWeight,
            'model': ['ckpt', 0],
            'clip': ['ckpt', 1],
          },
        },
      'pos': {
        'class_type': 'CLIPTextEncode',
        'inputs': {'text': prompt, 'clip': clipSrc},
      },
      'neg': {
        'class_type': 'CLIPTextEncode',
        'inputs': {'text': negativePrompt, 'clip': clipSrc},
      },
      'latent': {
        'class_type': 'EmptyLatentImage',
        'inputs': {'width': width, 'height': height, 'batch_size': 1},
      },
      'sampler': {
        'class_type': 'KSampler',
        'inputs': {
          'seed': seed,
          'steps': steps,
          'cfg': cfgScale,
          'sampler_name': samplerName,
          'scheduler': scheduler,
          'denoise': 1.0,
          'model': modelSrc,
          'positive': ['pos', 0],
          'negative': ['neg', 0],
          'latent_image': ['latent', 0],
        },
      },
      'decode': {
        'class_type': 'VAEDecode',
        'inputs': {
          'samples': ['sampler', 0],
          'vae': ['ckpt', 2],
        },
      },
      'save': {
        'class_type': 'SaveImage',
        'inputs': {
          'filename_prefix': 'FrontPorchAI',
          'images': ['decode', 0],
        },
      },
    };
  }

  /// Extract the option list for one node input from a GET /object_info
  /// payload, e.g. node 'CheckpointLoaderSimple' input 'ckpt_name'. ComfyUI
  /// encodes enum inputs as `[ [options...], {meta} ]`. Pure — unit-tested.
  static List<String> optionsFromObjectInfo(
    Map<String, dynamic> objectInfo,
    String nodeType,
    String inputName,
  ) {
    final node = objectInfo[nodeType];
    if (node is! Map) return const [];
    final input = node['input'];
    if (input is! Map) return const [];
    for (final section in ['required', 'optional']) {
      final sec = input[section];
      if (sec is! Map) continue;
      final spec = sec[inputName];
      if (spec is List && spec.isNotEmpty && spec.first is List) {
        return (spec.first as List).map((e) => e.toString()).toList();
      }
    }
    return const [];
  }

  /// True when the server answers GET /system_stats.
  Future<bool> testConnection() async {
    try {
      final r = await http
          .get(Uri.parse('$_root/system_stats'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (e) {
      debugPrint('ComfyUI: testConnection failed: $e');
      return false;
    }
  }

  /// One /object_info fetch shared by the model/LoRA/sampler listings.
  Future<Map<String, dynamic>?> _objectInfo() async {
    try {
      final r = await http
          .get(Uri.parse('$_root/object_info'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('ComfyUI: object_info failed: $e');
      return null;
    }
  }

  Future<List<String>> fetchModels() async {
    final info = await _objectInfo();
    if (info == null) return const [];
    return optionsFromObjectInfo(info, 'CheckpointLoaderSimple', 'ckpt_name');
  }

  Future<List<String>> fetchLoras() async {
    final info = await _objectInfo();
    if (info == null) return const [];
    return optionsFromObjectInfo(info, 'LoraLoader', 'lora_name');
  }

  Future<List<String>> fetchSamplers() async {
    final info = await _objectInfo();
    if (info == null) return const [];
    return optionsFromObjectInfo(info, 'KSampler', 'sampler_name');
  }

  /// Generate one image: submit the workflow, poll /history until the prompt
  /// finishes, then download the first output image via /view. Throws with a
  /// readable message on failure (the ImageGenService dispatcher sanitizes).
  Future<Uint8List> generateImage({
    required String prompt,
    String negativePrompt = '',
    String model = '',
    int width = 1024,
    int height = 1024,
    int steps = 20,
    double cfgScale = 7.0,
    int seed = -1,
    String samplerName = 'euler',
    String scheduler = 'normal',
    String loraName = '',
    double loraWeight = 0.8,
  }) async {
    if (model.isEmpty) {
      // ComfyUI has no "current model" concept like A1111 — the graph must
      // name a checkpoint. Surface that instead of a cryptic node error.
      throw Exception('Select a checkpoint model for ComfyUI first.');
    }
    final workflow = buildTxt2ImgWorkflow(
      model: model,
      prompt: prompt,
      negativePrompt: negativePrompt,
      width: width,
      height: height,
      steps: steps,
      cfgScale: cfgScale,
      seed: seed == -1 ? Random().nextInt(1 << 31) : seed,
      samplerName: samplerName,
      scheduler: scheduler,
      loraName: loraName,
      loraWeight: loraWeight,
    );

    final clientId =
        'frontporch-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final submit = await http
        .post(
          Uri.parse('$_root/prompt'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'prompt': workflow, 'client_id': clientId}),
        )
        .timeout(const Duration(seconds: 30));
    if (submit.statusCode != 200) {
      String detail = 'HTTP ${submit.statusCode}';
      try {
        final err = jsonDecode(submit.body);
        detail = err['error']?['message']?.toString() ?? detail;
      } catch (_) {}
      throw Exception('ComfyUI rejected the workflow: $detail');
    }
    final promptId =
        (jsonDecode(submit.body) as Map<String, dynamic>)['prompt_id']
            ?.toString();
    if (promptId == null || promptId.isEmpty) {
      throw Exception('ComfyUI did not return a prompt_id');
    }

    // Poll history until this prompt completes (generation can be slow on
    // first model load; 10 min cap mirrors the other local backends).
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    Map<String, dynamic>? outputs;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        final h = await http
            .get(Uri.parse('$_root/history/$promptId'))
            .timeout(const Duration(seconds: 10));
        if (h.statusCode != 200) continue;
        final hist = jsonDecode(h.body) as Map<String, dynamic>;
        final entry = hist[promptId];
        if (entry is! Map) continue;
        final status = entry['status'];
        if (status is Map && status['status_str'] == 'error') {
          throw Exception(
            'ComfyUI reported an error — check the model name and its server '
            'console.',
          );
        }
        final out = entry['outputs'];
        if (out is Map && out.isNotEmpty) {
          outputs = Map<String, dynamic>.from(out);
          break;
        }
      } on TimeoutException {
        // transient — keep polling until the deadline
      }
    }
    if (outputs == null) {
      throw Exception('ComfyUI generation timed out');
    }

    // First image from any output node (ours is 'save').
    for (final nodeOut in outputs.values) {
      final images = (nodeOut is Map) ? nodeOut['images'] : null;
      if (images is List && images.isNotEmpty && images.first is Map) {
        final img = images.first as Map;
        final uri = Uri.parse('$_root/view').replace(
          queryParameters: {
            'filename': img['filename']?.toString() ?? '',
            'subfolder': img['subfolder']?.toString() ?? '',
            'type': img['type']?.toString() ?? 'output',
          },
        );
        final r = await http.get(uri).timeout(const Duration(seconds: 60));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
          return r.bodyBytes;
        }
        throw Exception(
          'ComfyUI produced an image but /view failed to serve it',
        );
      }
    }
    throw Exception('ComfyUI finished without producing an image');
  }
}
