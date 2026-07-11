// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Unit tests for the backend-neutral EditProfile recipe: the edit model's
// required sampler (UniPC) + moderate guidance + strength, the user's LoRA
// passed through AS-IS (the app never auto-injects a LoRA the user didn't pick),
// the distinct Kontext recipe, and that no backend-specific encoding (sampler
// ints, seedMode) leaks into the neutral type. The STEP count is NOT owned here
// — the edit path uses the user's chosen steps.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/capability/image_reference_role.dart';
import 'package:front_porch_ai/services/image/edit_profile.dart';

void main() {
  group('Qwen-Image-Edit recipe', () {
    test('sampler UniPC + moderate guidance + strength 0.8, no LoRA', () {
      final p = resolveEditProfile(editKind: EditModelKind.qwenEdit);
      expect(p.strength, kQwenEditStrength); // 0.8 — NOT 1.0, NOT img2img denoise
      expect(p.guidance, 3.5);
      expect(p.shift, 3.0);
      expect(p.samplerName, kEditSamplerUnipc); // 'unipc' — never a backend int
      expect(p.usedLightning, isFalse); // no auto lightning LoRA, ever
      expect(p.loras, isEmpty);
    });

    test('the user LoRA is passed through as-is (never stacked with anything)', () {
      final p = resolveEditProfile(
        editKind: EditModelKind.qwenEdit,
        userLoraName: 'my_nsfw_lora.ckpt',
        userLoraWeight: 0.6,
      );
      expect(p.loras.length, 1);
      expect(p.loras.single['file'], 'my_nsfw_lora.ckpt');
      expect(p.loras.single['weight'], 0.6);
      expect(p.usedLightning, isFalse);
    });

    test('a LoRA whose name contains "lightning" is treated like any user LoRA', () {
      final p = resolveEditProfile(
        editKind: EditModelKind.qwenEdit,
        userLoraName: 'qwen_lightning_4step.ckpt',
        userLoraWeight: 1.0,
      );
      // No special-casing — it's just the user's LoRA at their weight.
      expect(p.loras.single['file'], 'qwen_lightning_4step.ckpt');
      expect(p.usedLightning, isFalse);
    });
  });

  group('Kontext — distinct recipe', () {
    test('its own defaults (strength 1.0, guidance 2.5), user LoRA as-is', () {
      final p = resolveEditProfile(editKind: EditModelKind.kontext);
      expect(p.usedLightning, isFalse);
      expect(p.strength, 1.0);
      expect(p.guidance, 2.5);
      expect(p.samplerName, kEditSamplerUnipc);
      expect(p.loras, isEmpty);
    });
  });
}
