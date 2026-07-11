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

import 'package:front_porch_ai/services/capability/image_reference_role.dart';

/// A backend-NEUTRAL edit recipe for instruction-edit models. Every edit-capable
/// backend consumes the same profile and maps the subset it supports to its own
/// call — no backend owns its own recipe, so Draw Things gets no special
/// treatment over ComfyUI/remote. This is a RECIPE (a handful of tuned values),
/// deliberately NOT a universal generation config: wire-only knobs (seed, size,
/// seedMode, refiner, teaCache, …) stay out so it can't drift into "everything
/// one backend can send".
///
/// Mapping per backend (values expressed once, here):
///  - Draw Things: samplerName → its int (e.g. 'unipc' → 17), denoise=strength,
///    seed-mode fixed to scale-alike at the apply site (DT-only, not in here).
///  - ComfyUI (Phase 5): reuses the SAME profile via `normalizeSampler` +
///    KSampler denoise/steps/cfg; a shift node when the graph has one.
///  - Remote (Phase 5): takes the thin subset its API exposes (usually just the
///    reference + prompt); ignores the rest.
///  - A1111: never edits, never calls this.
///
/// Pure and deterministic (no I/O; the caller supplies the LoRA list). Qwen
/// values mirror the maintainer's field-tested `qwen_image_edit_config`
/// (`tools/dt-grpc-python/client.py`).

/// Field-tested Qwen-Image-Edit reference strength (NOT 1.0, NOT img2img denoise).
const double kQwenEditStrength = 0.8;

/// Canonical sampler id every backend maps from (DT → 17 / UniPC-trailing,
/// ComfyUI → 'uni_pc' via its normalizer). Never a backend enum/int here.
const String kEditSamplerUnipc = 'unipc';

/// A resolved, backend-neutral edit recipe.
class EditProfile {
  /// Reference/denoise strength (Qwen-Edit: 0.8).
  final double strength;
  final int steps;

  /// CFG / guidance scale (1.0 with a lightning LoRA, higher without).
  final double guidance;

  /// Canonical sampler id (see [kEditSamplerUnipc]) — a backend maps it natively.
  final String samplerName;

  /// Model-family shift (e.g. 3.0). Backends without a shift knob ignore it.
  final double shift;

  /// The merged LoRA list — the lightning LoRA (when found) plus any user LoRA.
  /// Each entry is `{'file': name, 'weight': w}`. Remote typically ignores this.
  final List<Map<String, dynamic>> loras;

  /// True when a lightning LoRA was found and applied (for status/logging).
  final bool usedLightning;

  const EditProfile({
    required this.strength,
    required this.steps,
    required this.guidance,
    required this.samplerName,
    required this.shift,
    required this.loras,
    required this.usedLightning,
  });
}

/// Resolve the backend-neutral edit recipe.
///
/// Provides the two things the edit model NEEDS but a user's txt2img settings
/// usually get wrong: the sampler (UniPC — qwen-image-edit produces no image on
/// some samplers) and a moderate guidance. The caller supplies the STEP count
/// (the user's — they control it) and the strength (the "how much should change"
/// slider). Any user-selected LoRA rides along AS-IS — the app never auto-injects
/// a LoRA the user didn't pick (no "lightning" auto-detection).
EditProfile resolveEditProfile({
  required EditModelKind editKind,
  String? userLoraName,
  double? userLoraWeight,
}) {
  final userLora = (userLoraName != null && userLoraName.isNotEmpty)
      ? <Map<String, dynamic>>[
          {'file': userLoraName, 'weight': userLoraWeight ?? 1.0},
        ]
      : const <Map<String, dynamic>>[];

  if (editKind == EditModelKind.kontext) {
    // Flux Kontext: conservative starting points (field-tested on Qwen, not
    // Kontext — tune when Kontext is run).
    return EditProfile(
      strength: 1.0,
      steps: 20,
      guidance: 2.5,
      samplerName: kEditSamplerUnipc,
      shift: 3.0,
      loras: userLora,
      usedLightning: false,
    );
  }

  // Qwen-Image-Edit: the sampler + guidance the model needs; the user's LoRA
  // as-is. `steps` here is only a fallback default — the edit path uses the
  // user's step count.
  return EditProfile(
    strength: kQwenEditStrength,
    steps: 20,
    guidance: 3.5,
    samplerName: kEditSamplerUnipc,
    shift: 3.0,
    loras: userLora,
    usedLightning: false,
  );
}
