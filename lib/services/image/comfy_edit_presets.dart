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

// The bundled ComfyUI edit presets — the "I just want to do a thing" list.
//
// Each is a token-placeholdered API-format graph plus the nodes/model-slots it
// needs, consumed by the ONE substituteComfyWorkflow engine (a preset and an
// uploaded workflow are the same thing). The graph SHAPES mirror ComfyUI's own
// published example workflows:
//  - Qwen-Image-Edit: https://docs.comfy.org/tutorials/image/qwen/qwen-image-edit
//  - Flux Kontext:     https://docs.comfy.org/tutorials/flux/flux-1-kontext-dev
//
// IMPORTANT: these graphs are authored from the reference workflows but are
// NOT render-verified in-house (no ComfyUI runs in CI or on the maintainer's
// box). The node-presence probe catches a missing/renamed node before a run,
// and the token engine is unit-tested; but the first live render is a ComfyUI
// user's. Anyone whose graph differs uses "upload your own workflow", which is
// the fully-general path. Adding/fixing a preset is one entry in this list.

import 'comfy_edit_workflow.dart';
import 'package:front_porch_ai/services/capability/image_reference_role.dart';

/// Qwen-Image-Edit (2509/2511). Node shapes validated live against ComfyUI's
/// `/object_info`. Three-file load (diffusion + text-encoder + VAE) → three model
/// slots. Identity rides the `TextEncodeQwenImageEditPlus` conditioning (the 2509+
/// encoder — input `image1`); the reference is also VAE-encoded to the latent so
/// the strength slider (`%DENOISE%`) is meaningful. `ModelSamplingAuraFlow` carries
/// the shift knob and `CFGNorm` the CFG normalization the model expects.
const ComfyEditPreset kQwenImageEditPreset = ComfyEditPreset(
  id: 'qwen_image_edit',
  label: 'Qwen-Image-Edit',
  kind: EditModelKind.qwenEdit,
  requiredNodes: [
    'UNETLoader',
    'CLIPLoader',
    'VAELoader',
    'LoadImage',
    'TextEncodeQwenImageEditPlus',
    'VAEEncode',
    'ModelSamplingAuraFlow',
    'CFGNorm',
    'KSampler',
    'VAEDecode',
    'SaveImage',
  ],
  modelSlots: [
    ComfyModelSlot(
      token: '%MODEL_DIFFUSION%',
      loaderClass: 'UNETLoader',
      inputName: 'unet_name',
      label: 'Diffusion model',
    ),
    ComfyModelSlot(
      token: '%MODEL_CLIP%',
      loaderClass: 'CLIPLoader',
      inputName: 'clip_name',
      label: 'Text encoder (CLIP)',
    ),
    ComfyModelSlot(
      token: '%MODEL_VAE%',
      loaderClass: 'VAELoader',
      inputName: 'vae_name',
      label: 'VAE',
    ),
  ],
  template: {
    'unet': {
      'class_type': 'UNETLoader',
      'inputs': {'unet_name': '%MODEL_DIFFUSION%', 'weight_dtype': 'default'},
    },
    'clip': {
      'class_type': 'CLIPLoader',
      'inputs': {
        'clip_name': '%MODEL_CLIP%',
        'type': 'qwen_image',
        'device': 'default',
      },
    },
    'vae': {
      'class_type': 'VAELoader',
      'inputs': {'vae_name': '%MODEL_VAE%'},
    },
    'image': {
      'class_type': 'LoadImage',
      'inputs': {'image': '%IMAGE%'},
    },
    'pos': {
      'class_type': 'TextEncodeQwenImageEditPlus',
      'inputs': {
        'clip': ['clip', 0],
        'vae': ['vae', 0],
        'image1': ['image', 0],
        'prompt': '%PROMPT%',
      },
    },
    'neg': {
      'class_type': 'TextEncodeQwenImageEditPlus',
      'inputs': {
        'clip': ['clip', 0],
        'vae': ['vae', 0],
        'image1': ['image', 0],
        'prompt': '%NEGATIVE%',
      },
    },
    'latent': {
      'class_type': 'VAEEncode',
      'inputs': {
        'pixels': ['image', 0],
        'vae': ['vae', 0],
      },
    },
    'modelsampling': {
      'class_type': 'ModelSamplingAuraFlow',
      'inputs': {
        'model': ['unet', 0],
        'shift': '%SHIFT%',
      },
    },
    'cfgnorm': {
      'class_type': 'CFGNorm',
      'inputs': {
        'model': ['modelsampling', 0],
        'strength': 1.0,
      },
    },
    'sampler': {
      'class_type': 'KSampler',
      'inputs': {
        'seed': '%SEED%',
        'steps': '%STEPS%',
        'cfg': '%CFG%',
        'sampler_name': '%SAMPLER%',
        'scheduler': '%SCHEDULER%',
        'denoise': '%DENOISE%',
        'model': ['cfgnorm', 0],
        'positive': ['pos', 0],
        'negative': ['neg', 0],
        'latent_image': ['latent', 0],
      },
    },
    'decode': {
      'class_type': 'VAEDecode',
      'inputs': {
        'samples': ['sampler', 0],
        'vae': ['vae', 0],
      },
    },
    'save': {
      'class_type': 'SaveImage',
      'inputs': {
        'filename_prefix': 'FrontPorchAI',
        'images': ['decode', 0],
      },
    },
  },
);

/// Flux Kontext (dev). Node shapes validated live against ComfyUI's `/object_info`.
/// Uses the OFFICIAL split load (UNET + DualCLIP + VAE) rather than an all-in-one
/// checkpoint — a plain Flux checkpoint doesn't carry the dual CLIP (clip-L + T5),
/// so `CheckpointLoaderSimple` alone can't feed a working text encoder. Four model
/// slots. The reference is scaled (`FluxKontextImageScale`), VAE-encoded, and
/// injected as a `ReferenceLatent`; Flux steers with `FluxGuidance` (not CFG), so
/// the KSampler cfg is pinned to 1.0 and `%CFG%` drives the guidance. Flux has no
/// classic negative — `ConditioningZeroOut` supplies the empty one.
const ComfyEditPreset kFluxKontextPreset = ComfyEditPreset(
  id: 'flux_kontext',
  label: 'Flux Kontext',
  kind: EditModelKind.kontext,
  requiredNodes: [
    'UNETLoader',
    'DualCLIPLoader',
    'VAELoader',
    'LoadImage',
    'FluxKontextImageScale',
    'VAEEncode',
    'CLIPTextEncode',
    'ReferenceLatent',
    'FluxGuidance',
    'ConditioningZeroOut',
    'KSampler',
    'VAEDecode',
    'SaveImage',
  ],
  modelSlots: [
    ComfyModelSlot(
      token: '%MODEL_DIFFUSION%',
      loaderClass: 'UNETLoader',
      inputName: 'unet_name',
      label: 'Diffusion model',
    ),
    ComfyModelSlot(
      token: '%MODEL_CLIP1%',
      loaderClass: 'DualCLIPLoader',
      inputName: 'clip_name1',
      label: 'Text encoder 1 (CLIP-L)',
    ),
    ComfyModelSlot(
      token: '%MODEL_CLIP2%',
      loaderClass: 'DualCLIPLoader',
      inputName: 'clip_name2',
      label: 'Text encoder 2 (T5-XXL)',
    ),
    ComfyModelSlot(
      token: '%MODEL_VAE%',
      loaderClass: 'VAELoader',
      inputName: 'vae_name',
      label: 'VAE',
    ),
  ],
  template: {
    'unet': {
      'class_type': 'UNETLoader',
      'inputs': {'unet_name': '%MODEL_DIFFUSION%', 'weight_dtype': 'default'},
    },
    'clip': {
      'class_type': 'DualCLIPLoader',
      'inputs': {
        'clip_name1': '%MODEL_CLIP1%',
        'clip_name2': '%MODEL_CLIP2%',
        'type': 'flux',
        'device': 'default',
      },
    },
    'vae': {
      'class_type': 'VAELoader',
      'inputs': {'vae_name': '%MODEL_VAE%'},
    },
    'image': {
      'class_type': 'LoadImage',
      'inputs': {'image': '%IMAGE%'},
    },
    'scale': {
      'class_type': 'FluxKontextImageScale',
      'inputs': {
        'image': ['image', 0],
      },
    },
    'latent': {
      'class_type': 'VAEEncode',
      'inputs': {
        'pixels': ['scale', 0],
        'vae': ['vae', 0],
      },
    },
    'pos': {
      'class_type': 'CLIPTextEncode',
      'inputs': {'text': '%PROMPT%', 'clip': ['clip', 0]},
    },
    'reflatent': {
      'class_type': 'ReferenceLatent',
      'inputs': {
        'conditioning': ['pos', 0],
        'latent': ['latent', 0],
      },
    },
    'guidance': {
      'class_type': 'FluxGuidance',
      'inputs': {
        'conditioning': ['reflatent', 0],
        'guidance': '%CFG%',
      },
    },
    'neg': {
      'class_type': 'ConditioningZeroOut',
      'inputs': {
        'conditioning': ['pos', 0],
      },
    },
    'sampler': {
      'class_type': 'KSampler',
      'inputs': {
        'seed': '%SEED%',
        'steps': '%STEPS%',
        'cfg': 1.0,
        'sampler_name': '%SAMPLER%',
        'scheduler': '%SCHEDULER%',
        'denoise': '%DENOISE%',
        'model': ['unet', 0],
        'positive': ['guidance', 0],
        'negative': ['neg', 0],
        'latent_image': ['latent', 0],
      },
    },
    'decode': {
      'class_type': 'VAEDecode',
      'inputs': {
        'samples': ['sampler', 0],
        'vae': ['vae', 0],
      },
    },
    'save': {
      'class_type': 'SaveImage',
      'inputs': {
        'filename_prefix': 'FrontPorchAI',
        'images': ['decode', 0],
      },
    },
  },
);

/// The bundled presets, in display order. Adding a model = one entry.
const List<ComfyEditPreset> kComfyEditPresets = [
  kQwenImageEditPreset,
  kFluxKontextPreset,
];
