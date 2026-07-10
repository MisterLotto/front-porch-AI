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

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/image_prompt/expression_prompts.dart';

/// Generates one image per emotion for an expression pack. The generator
/// closure is injected so this class stays pure and unit-testable; the UI
/// wires it to ImageGenService.generateImage with the fixed base image,
/// size, and denoise captured in the closure. The negative prompt is passed
/// per call because each emotion appends its own counter-cues (see
/// kExpressionNegatives — a no-op on CFG-1 models, real steering on classic
/// CFG backends).
typedef PackSlotGenerator =
    Future<Uint8List?> Function({
      required String prompt,
      required String negativePrompt,
      required int seed,
    });

/// Lifecycle of one emotion slot in an expression pack grid.
enum ExpressionSlotState { pending, generating, done, failed }

/// Advisory Vision QC verdict for one generated slot ("same person?
/// expression reads?"), stamped by ExpressionPackQc and rendered as a badge
/// on the grid.
class PackQcVerdict {
  const PackQcVerdict({
    required this.samePerson,
    required this.expressionMatches,
    this.note = '',
  });

  final bool samePerson;
  final bool expressionMatches;

  /// Short flaw description from the vision model, or '' when none was
  /// reported. Tooltip context only — it never affects [pass].
  final String note;

  bool get pass => samePerson && expressionMatches;
}

/// One emotion's slot in an expression pack: its generation state, the
/// resulting image bytes, and whether the user wants to import it.
class ExpressionSlot {
  ExpressionSlot(this.emotion);

  /// Lowercase EmotionLabels.all value (stored verbatim as the avatar label).
  final String emotion;

  ExpressionSlotState state = ExpressionSlotState.pending;
  Uint8List? bytes;

  /// Import checkbox; defaults to keeping every generated image.
  bool keep = true;

  String? error;

  /// Times this slot has been re-rolled. The grid unlocks manual prompt
  /// editing only after the first re-roll — the app gets its automatic
  /// attempt before the user is offered the steering wheel.
  int rerollCount = 0;

  /// User-edited prompt for this slot (set via edit-and-re-roll). When set it
  /// REPLACES the modifier+base composition for every later generation of
  /// this slot, so the user isn't re-rolling blind forever.
  String? customPrompt;

  /// Advisory Vision QC verdict; null = unchecked. Cleared whenever the slot
  /// regenerates so a stale verdict can't describe a new image.
  PackQcVerdict? qc;
}

/// Drives sequential per-emotion generation for an expression pack.
///
/// Identity consistency comes from the img2img BASE image, not the seed —
/// each slot derives its own seed from the session seed (+ its index), which
/// is what lets the expression actually differ per emotion. (The original
/// shared-seed design produced 28 near-identical images: same base + same
/// noise + a short prompt tail that low-CFG turbo models barely weigh.) The
/// emotion phrase leads the prompt for the same reason: front tokens carry
/// the most conditioning weight. Re-rolls draw a fresh random seed.
class ExpressionPackSession extends ChangeNotifier {
  ExpressionPackSession({
    required List<String> emotions,
    required String basePrompt,
    required String negativePrompt,
    required PackSlotGenerator generate,
    int? seed, // fixed shared seed; default = random positive int
  }) : _basePrompt = basePrompt,
       _negativePrompt = negativePrompt,
       _generate = generate,
       // Must be a fixed POSITIVE value: ComfyUI randomizes -1 client-side and
       // A1111 server-side, so sharing a seed across slots requires pinning it.
       _seed = seed ?? Random().nextInt(1 << 31),
       _slots = [for (final e in emotions) ExpressionSlot(e)];

  final String _basePrompt;
  final String _negativePrompt;
  final PackSlotGenerator _generate;
  final int _seed;
  final List<ExpressionSlot> _slots;

  bool _running = false;
  bool _cancelRequested = false;
  bool _disposed = false;

  List<ExpressionSlot> get slots => List.unmodifiable(_slots);

  /// The session seed; slot N generates with `(seed + N) & 0x7fffffff`.
  int get seed => _seed;

  bool get isRunning => _running;
  int get doneCount =>
      _slots.where((s) => s.state == ExpressionSlotState.done).length;
  int get keptCount => _slots
      .where((s) => s.state == ExpressionSlotState.done && s.keep)
      .length;
  int get pendingCount =>
      _slots.where((s) => s.state == ExpressionSlotState.pending).length;

  /// Sequentially generate every pending slot; no-op if already running.
  ///
  /// Failed slots are left for [reroll] (the retry path); calling [run] again
  /// after a [cancel] resumes the slots that stayed pending.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    _cancelRequested = false;
    notifyListeners();
    for (var i = 0; i < _slots.length; i++) {
      final slot = _slots[i];
      // In-flight generation cannot be aborted (known service limitation), so
      // the cancel flag is only consulted between slots.
      if (_cancelRequested) break;
      if (slot.state != ExpressionSlotState.pending) continue;
      await _generateSlot(slot, (_seed + i) & 0x7fffffff);
      if (_disposed) return;
    }
    _running = false;
    notifyListeners();
  }

  /// The positive prompt slot [index] generates with right now: the user's
  /// custom prompt when one was set via edit-and-re-roll, else the emotion
  /// modifier + base composition. The grid uses this to prefill the editor.
  String effectivePromptFor(int index) => _promptFor(_slots[index]);

  String _promptFor(ExpressionSlot slot) {
    final custom = slot.customPrompt;
    if (custom != null && custom.isNotEmpty) return custom;
    final modifier = kExpressionModifiers[slot.emotion] ?? slot.emotion;
    // Emotion first: front tokens get the most conditioning weight, and at
    // turbo-model CFG (~1) a tail phrase was too weak to change the face.
    return '$modifier, $_basePrompt';
  }

  /// Regenerate ONE slot with a fresh random seed (the shared session seed is
  /// unchanged). Works on failed slots too — that's the retry. No-op while a
  /// run is in progress, for an out-of-range index, or if the slot is
  /// currently generating. A non-empty [promptOverride] is remembered as the
  /// slot's custom prompt and used for this and every later generation.
  ///
  /// Marks the session running for its duration: the backends are single-GPU,
  /// so every generation — full runs AND single re-rolls — must serialize
  /// through [isRunning] (which is also what disables the grid's other
  /// re-roll/resume buttons while one is in flight).
  Future<void> reroll(int index, {String? promptOverride}) async {
    if (_running) return;
    if (index < 0 || index >= _slots.length) return;
    final slot = _slots[index];
    if (slot.state == ExpressionSlotState.generating) return;
    if (promptOverride != null && promptOverride.trim().isNotEmpty) {
      slot.customPrompt = promptOverride.trim();
    }
    slot.rerollCount++;
    _running = true;
    notifyListeners();
    await _generateSlot(slot, Random().nextInt(1 << 31));
    if (_disposed) return;
    _running = false;
    notifyListeners();
  }

  /// Finish the in-flight slot, then stop; remaining slots stay pending
  /// (a later [run] resumes them).
  void cancel() {
    _cancelRequested = true;
  }

  void setKeep(int index, bool value) {
    if (index < 0 || index >= _slots.length) return;
    _slots[index].keep = value;
    notifyListeners();
  }

  /// Shared per-slot generation used by [run] and [reroll]: drives the slot
  /// through generating → done/failed, bailing out silently if the session
  /// was disposed (dialog closed) while the generation was in flight.
  Future<void> _generateSlot(ExpressionSlot slot, int slotSeed) async {
    slot.state = ExpressionSlotState.generating;
    slot.error = null;
    // A regenerated image invalidates any prior Vision QC verdict.
    slot.qc = null;
    notifyListeners();
    Uint8List? result;
    String? error;
    try {
      final counterCues = kExpressionNegatives[slot.emotion] ?? '';
      result = await _generate(
        prompt: _promptFor(slot),
        negativePrompt: counterCues.isEmpty
            ? _negativePrompt
            : (_negativePrompt.trim().isEmpty
                  ? counterCues
                  : '$_negativePrompt, $counterCues'),
        seed: slotSeed,
      );
      if (result == null) error = 'Generation returned no image.';
    } catch (e) {
      error = e.toString();
    }
    if (_disposed) return;
    if (result != null) {
      slot.bytes = result;
      slot.state = ExpressionSlotState.done;
    } else {
      slot.state = ExpressionSlotState.failed;
      slot.error = error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Imports the kept slots of a finished pack as labeled expression avatars.
class ExpressionPackImporter {
  ExpressionPackImporter._();

  /// Imports every done+kept slot as a labeled expression avatar via
  /// CharacterRepository.addAvatar (the canonical path — same as the ZIP
  /// sprite-pack importer). Returns the number imported. When > 0, flips the
  /// global expressions toggle on. Caller handles card refresh + UI notify.
  static Future<int> importPack({
    required CharacterRepository repository,
    required StorageService storage,
    required String characterDbId,
    required String characterName,
    required List<ExpressionSlot> slots,
    bool replaceSameLabel = true,
  }) async {
    final kept = slots
        .where(
          (s) =>
              s.state == ExpressionSlotState.done && s.keep && s.bytes != null,
        )
        .toList();
    if (kept.isEmpty) return 0;

    if (replaceSameLabel) {
      final existing = await repository.getAvatarImages(characterDbId);
      final labels = kept.map((s) => s.emotion.toLowerCase()).toSet();
      for (final avatar in existing) {
        if (labels.contains(avatar.label?.toLowerCase())) {
          await repository.removeAvatar(characterDbId, avatar.id);
        }
      }
      // No prime-index adjustment here on purpose: CharacterRepository's
      // removeAvatar performs none, and the avatars dialog only clamps its
      // local UI copy after a removal without persisting it — we match that
      // existing behavior exactly.
    }

    var imported = 0;
    for (final slot in kept) {
      // Strictly sequential awaits: addAvatar filenames are
      // millisecond-stamped, so parallel adds could collide.
      await repository.addAvatar(
        characterDbId,
        characterName,
        slot.bytes!,
        slot.emotion,
      );
      imported++;
    }

    if (imported > 0 && !storage.expressionEnabled) {
      await storage.setExpressionEnabled(true);
    }
    return imported;
  }
}
