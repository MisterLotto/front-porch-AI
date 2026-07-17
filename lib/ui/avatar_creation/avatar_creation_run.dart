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

part of 'avatar_creation_controller.dart';

/// Run-step internals for [AvatarCreationController], split out to keep both
/// files under the 500-LOC cap (same `part of` + private-extension pattern as
/// settings_page). Direct access to the controller's private state, so
/// behavior is identical to living inline.
extension _AvatarCreationRunSteps on AvatarCreationController {
  Future<void> _runPack(Uint8List? base) async {
    if (base == null) {
      _fail('The expression pack needs a portrait to build from.');
      return;
    }
    final normalized = normalizePackBase(base);
    if (normalized == null) {
      _fail('The portrait image could not be decoded.');
      return;
    }
    final editMode = packEditModeNow;
    if (editMode) {
      // Explicit stage: the swap itself is graceful (the model rides each
      // request; DT/Comfy load-unload themselves) — the cost is load TIME.
      _setStage(AvatarRunStage.switching);
      await imageGen.nudgeComfyFree();
      if (_disposed) return;
    }
    final emotions = missingEmotions;
    if (emotions.isEmpty) return;

    final s = ExpressionPackSession(
      emotions: emotions,
      basePrompt: '${promptController.text.trim()}, $kExpressionFraming',
      negativePrompt: storage.imageGenSettings.imageGenNegativePrompt,
      denoise: kCreatorPackDenoise,
      editMode: editMode,
      generate:
          ({
            required String prompt,
            required String negativePrompt,
            required int seed,
            required double denoise,
          }) => imageGen.generateImage(
            prompt: prompt,
            negativePrompt: negativePrompt,
            size: '${normalized.width}x${normalized.height}',
            referenceImage: normalized.bytes,
            seed: seed,
            denoise: denoise,
            intent: editMode ? StudioIntent.edit : StudioIntent.create,
            editStrength: editMode ? denoise : null,
          ),
    );
    _replaceSession(s);
    _setStage(AvatarRunStage.pack);
    await s.run();
    if (_disposed) return;

    if (qcEnabled && s.doneCount > 0 && !_cancelRequested) {
      _setStage(AvatarRunStage.qc);
      _visionFire ??= await resolveVisionFire();
      if (_disposed) return;
      final fire = _visionFire;
      if (fire != null) {
        final q = ExpressionPackQc(
          slots: s.slots,
          baseImageB64: base64Encode(normalized.bytes),
          fire: fire,
        );
        _replaceQc(q);
        await q.run();
        if (_disposed) return;
        // Unattended flow: flagged images are held back from the gallery
        // (same semantics as the grid's "Uncheck flagged", applied for you).
        final slots = s.slots;
        for (var i = 0; i < slots.length; i++) {
          final verdict = slots[i].qc;
          if (verdict != null && !verdict.pass && slots[i].keep) {
            s.setKeep(i, false);
            flaggedExcluded++;
          }
        }
      }
    }

    // Cancel keeps completed images — import whatever finished.
    _setStage(AvatarRunStage.importing);
    importedCount = await ExpressionPackImporter.importPack(
      repository: repository,
      storage: storage,
      characterDbId: _card!.dbId!,
      characterName: _card!.name,
      slots: s.slots,
    );
    _existingEmotions = {
      ..._existingEmotions,
      for (final slot in s.slots)
        if (slot.state == ExpressionSlotState.done && slot.keep) slot.emotion,
    };
  }

  Future<bool> _ensureCard() async {
    if (_card?.dbId != null) {
      if (_existingEmotions.isEmpty) await _loadExistingEmotions();
      return true;
    }
    final c = await ensureCardSaved();
    if (_disposed) return false;
    if (c == null || c.dbId == null) return false;
    _card = c;
    await _loadExistingEmotions();
    if (!_disposed) _notify();
    return true;
  }

  Future<void> _loadExistingEmotions() async {
    final id = _card?.dbId;
    if (id == null) return;
    _existingEmotions = (await repository.getAvatarImages(id))
        .map((a) => (a.label ?? '').toLowerCase())
        .where((l) => l.isNotEmpty && l != AvatarImage.lookLabel)
        .toSet();
  }

  void _setStage(AvatarRunStage s) {
    stage = s;
    if (!_disposed) _notify();
  }

  void _fail(String message) {
    statusDetail = message;
    _setStage(AvatarRunStage.failed);
  }

  void _replaceSession(ExpressionPackSession s) {
    session?.removeListener(_notify);
    session?.dispose();
    session = s;
    s.addListener(_notify);
  }

  void _replaceQc(ExpressionPackQc q) {
    qc?.removeListener(_notify);
    qc?.dispose();
    qc = q;
    q.addListener(_notify);
  }
}
