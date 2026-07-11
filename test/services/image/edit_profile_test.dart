// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Unit tests for the backend-neutral EditProfile recipe — pins the maintainer's
// field-tested Qwen config, lightning-LoRA detection + non-lightning fallback,
// the distinct Kontext recipe, user-LoRA merging, and that no backend-specific
// encoding (sampler ints, seedMode) leaks into the neutral type.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/capability/image_reference_role.dart';
import 'package:front_porch_ai/services/image/edit_profile.dart';

void main() {
  const ownerLightning4 = 'qwen_image_1.0_lightning_4_step_v2.0_lora_f16.ckpt';
  const lightning8 = 'qwen_image_lightning_8_step_v1.ckpt';

  group('Qwen edit — lightning present', () {
    test('4-step LoRA → strength 0.8, 4 steps, guidance 1.0, canonical sampler',
        () {
      final p = resolveEditProfile(
        editKind: EditModelKind.qwenEdit,
        availableLoras: const ['some_style.ckpt', ownerLightning4],
      );
      expect(p.strength, kQwenEditStrength); // 0.8
      expect(p.steps, 4);
      expect(p.guidance, 1.0);
      expect(p.shift, 3.0);
      expect(p.samplerName, kEditSamplerUnipc); // 'unipc' — never a backend int
      expect(p.usedLightning, isTrue);
      expect(p.loras.single['file'], ownerLightning4);
      expect(p.loras.single['weight'], 1.0);
    });

    test('8-step LoRA → 8 steps', () {
      final p = resolveEditProfile(
        editKind: EditModelKind.qwenEdit,
        availableLoras: const [lightning8],
      );
      expect(p.usedLightning, isTrue);
      expect(p.steps, 8);
      expect(p.strength, 0.8);
    });

    test('a user LoRA SUPPRESSES the auto lightning LoRA (no stacking — DT '
        'hard-fails when the lightning LoRA is stacked on a user LoRA)', () {
      final p = resolveEditProfile(
        editKind: EditModelKind.qwenEdit,
        availableLoras: const [ownerLightning4],
        userLoraName: 'my_style_lora.ckpt',
        userLoraWeight: 0.6,
      );
      // Only the user's LoRA; the lightning speed hack is dropped, so the
      // non-lightning recipe (more steps, real guidance) applies.
      expect(p.loras.length, 1);
      expect(p.loras.single['file'], 'my_style_lora.ckpt');
      expect(p.loras.single['weight'], 0.6);
      expect(p.usedLightning, isFalse);
      expect(p.steps, 20);
      expect(p.guidance, 3.5);
    });

    test('a user LoRA that IS the lightning LoRA → used as the user LoRA at '
        'their weight (non-lightning path)', () {
      final p = resolveEditProfile(
        editKind: EditModelKind.qwenEdit,
        availableLoras: const [ownerLightning4],
        userLoraName: ownerLightning4,
        userLoraWeight: 0.5,
      );
      expect(p.loras.length, 1);
      expect(p.loras.single['file'], ownerLightning4);
      expect(p.loras.single['weight'], 0.5);
      expect(p.usedLightning, isFalse);
    });
  });

  group('Qwen edit — no lightning LoRA (fallback)', () {
    test('strength stays 0.8, more steps, real guidance, no lightning', () {
      final p = resolveEditProfile(
        editKind: EditModelKind.qwenEdit,
        availableLoras: const ['unrelated_style.ckpt'],
      );
      expect(p.strength, kQwenEditStrength); // still 0.8 — NOT 1.0, NOT denoise
      expect(p.usedLightning, isFalse);
      expect(p.steps, 20);
      expect(p.guidance, 3.5);
      expect(p.loras, isEmpty);
    });

    test('empty LoRA list → fallback (works on any backend install)', () {
      final p = resolveEditProfile(
        editKind: EditModelKind.qwenEdit,
        availableLoras: const [],
      );
      expect(p.usedLightning, isFalse);
      expect(p.strength, 0.8);
      expect(p.samplerName, kEditSamplerUnipc);
    });

    test('user LoRA still merged in the fallback', () {
      final p = resolveEditProfile(
        editKind: EditModelKind.qwenEdit,
        availableLoras: const [],
        userLoraName: 'my_style.ckpt',
      );
      expect(p.loras.single['file'], 'my_style.ckpt');
    });
  });

  group('Kontext — distinct recipe (never the Qwen lightning one)', () {
    test('Kontext ignores lightning LoRAs and uses its own defaults', () {
      final p = resolveEditProfile(
        editKind: EditModelKind.kontext,
        availableLoras: const [ownerLightning4], // present but irrelevant
      );
      expect(p.usedLightning, isFalse);
      expect(p.strength, 1.0);
      expect(p.guidance, 2.5);
      expect(p.loras, isEmpty);
    });
  });
}
