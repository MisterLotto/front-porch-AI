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
/// negative prompt, 768x768 size, and denoise captured in the closure.
typedef PackSlotGenerator =
    Future<Uint8List?> Function({required String prompt, required int seed});

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

  /// Advisory Vision QC verdict; null = unchecked. Cleared whenever the slot
  /// regenerates so a stale verdict can't describe a new image.
  PackQcVerdict? qc;
}

/// Drives sequential per-emotion generation for an expression pack.
///
/// All slots share ONE fixed seed (so the character stays consistent across
/// emotions); only the emotion phrase appended to [ExpressionPackSession.new]'s
/// `basePrompt` varies per slot. Re-rolls draw a fresh seed for that slot only.
class ExpressionPackSession extends ChangeNotifier {
  ExpressionPackSession({
    required List<String> emotions,
    required String basePrompt,
    required PackSlotGenerator generate,
    int? seed, // fixed shared seed; default = random positive int
  }) : _basePrompt = basePrompt,
       _generate = generate,
       // Must be a fixed POSITIVE value: ComfyUI randomizes -1 client-side and
       // A1111 server-side, so sharing a seed across slots requires pinning it.
       _seed = seed ?? Random().nextInt(1 << 31),
       _slots = [for (final e in emotions) ExpressionSlot(e)];

  final String _basePrompt;
  final PackSlotGenerator _generate;
  final int _seed;
  final List<ExpressionSlot> _slots;

  bool _running = false;
  bool _cancelRequested = false;
  bool _disposed = false;

  List<ExpressionSlot> get slots => List.unmodifiable(_slots);

  /// The shared seed used by every non-rerolled slot.
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
    for (final slot in _slots) {
      // In-flight generation cannot be aborted (known service limitation), so
      // the cancel flag is only consulted between slots.
      if (_cancelRequested) break;
      if (slot.state != ExpressionSlotState.pending) continue;
      await _generateSlot(slot, _seed);
      if (_disposed) return;
    }
    _running = false;
    notifyListeners();
  }

  /// Regenerate ONE slot with a fresh random seed (the shared session seed is
  /// unchanged). Works on failed slots too — that's the retry. No-op while a
  /// run is in progress, for an out-of-range index, or if the slot is
  /// currently generating.
  ///
  /// Marks the session running for its duration: the backends are single-GPU,
  /// so every generation — full runs AND single re-rolls — must serialize
  /// through [isRunning] (which is also what disables the grid's other
  /// re-roll/resume buttons while one is in flight).
  Future<void> reroll(int index) async {
    if (_running) return;
    if (index < 0 || index >= _slots.length) return;
    final slot = _slots[index];
    if (slot.state == ExpressionSlotState.generating) return;
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
      final modifier = kExpressionModifiers[slot.emotion] ?? slot.emotion;
      result = await _generate(
        prompt: '$_basePrompt, $modifier',
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
