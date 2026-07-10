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

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/services/expression_pack_service.dart';

/// Fires one multimodal eval and returns the raw reply text, or null on
/// failure. Production wires this to vision_eval.dart's fireVisionEval with
/// the active LLM captured in the closure; tests substitute a fake.
typedef VisionEvalFn =
    Future<String?> Function({
      required String prompt,
      required List<String> imagesB64,
    });

/// Runs advisory Vision QC over a finished expression pack: for each done
/// slot the vision model compares the generated image against the base
/// portrait ("same person? expression reads? visual flaws?") and the parsed
/// verdict is stamped on the slot for the grid to badge. Verdicts never
/// block anything — keeping or discarding a flagged image stays the user's
/// call. Mirrors [ExpressionPackSession]'s sequential run/cancel/dispose
/// idioms.
class ExpressionPackQc extends ChangeNotifier {
  ExpressionPackQc({
    required List<ExpressionSlot> slots,
    required String baseImageB64,
    required VisionEvalFn fire,
  }) : _slots = slots,
       _baseImageB64 = baseImageB64,
       _fire = fire;

  final List<ExpressionSlot> _slots;
  final String _baseImageB64;
  final VisionEvalFn _fire;

  bool _running = false;
  bool _cancelRequested = false;
  bool _disposed = false;
  int _checkedCount = 0;
  int _totalToCheck = 0;
  int _unparsedCount = 0;

  bool get isRunning => _running;

  /// Slots whose QC finished during this run (parsed or not).
  int get checkedCount => _checkedCount;

  /// Done slots that were eligible for QC when [run] started.
  int get totalToCheck => _totalToCheck;

  /// Slots currently carrying a failing verdict.
  int get flaggedCount =>
      _slots.where((s) => s.qc != null && !s.qc!.pass).length;

  /// Replies this run that couldn't be parsed (their slots keep qc == null).
  int get unparsedCount => _unparsedCount;

  /// Sequentially QC every done slot; no-op if already running. Each check
  /// sends the base portrait first and the slot image second. An in-flight
  /// eval can't be aborted from here, so — like the pack session — the
  /// cancel flag is only consulted between slots.
  Future<void> run() async {
    if (_running) return;
    final targets = _slots
        .where((s) => s.state == ExpressionSlotState.done && s.bytes != null)
        .toList();
    _running = true;
    _cancelRequested = false;
    _checkedCount = 0;
    _unparsedCount = 0;
    _totalToCheck = targets.length;
    notifyListeners();
    for (final slot in targets) {
      if (_cancelRequested) break;
      final checkedBytes = slot.bytes!;
      final reply = await _fire(
        prompt: _qcPrompt(slot.emotion),
        imagesB64: [_baseImageB64, base64Encode(checkedBytes)],
      );
      if (_disposed) return;
      // A re-roll may have replaced the image while this check was in
      // flight (the session doesn't lock during QC) — never stamp a verdict
      // for bytes the slot no longer holds.
      if (identical(slot.bytes, checkedBytes)) {
        final verdict = reply == null ? null : _parseVerdict(reply);
        if (verdict != null) {
          slot.qc = verdict;
        } else {
          _unparsedCount++;
        }
      }
      _checkedCount++;
      notifyListeners();
    }
    _running = false;
    notifyListeners();
  }

  /// Finish the in-flight slot's eval, then stop; the rest stay unchecked.
  void cancel() {
    _cancelRequested = true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String _qcPrompt(String emotion) =>
    'Image 1 is the reference portrait of a character. Image 2 should be the '
    'SAME character showing a clearly readable «$emotion» facial expression. '
    'Reply with ONLY this JSON: {"same_person": true/false, '
    '"expression_matches": true/false, "flaw": "none" or a very short '
    'description of any visual defect (warped face, extra limbs, artifacts)}';

/// Regex-fishes the two verdict booleans (and the optional flaw string) out
/// of the reply — the same brittle-JSON posture as LlmEvalEngine's
/// extractors, because vision models wrap the JSON in prose more often than
/// not. Both booleans present → a verdict; anything else → null (unparsed).
PackQcVerdict? _parseVerdict(String reply) {
  bool? readBool(String key) {
    final m = RegExp(
      r'"' + RegExp.escape(key) + r'"\s*:\s*(true|false)',
    ).firstMatch(reply);
    return m != null ? (m.group(1) == 'true') : null;
  }

  final samePerson = readBool('same_person');
  final expressionMatches = readBool('expression_matches');
  if (samePerson == null || expressionMatches == null) return null;

  final flaw =
      RegExp(r'"flaw"\s*:\s*"([^"]*)"').firstMatch(reply)?.group(1)?.trim() ??
      '';
  return PackQcVerdict(
    samePerson: samePerson,
    expressionMatches: expressionMatches,
    // A reported flaw is tooltip context only — it never flips pass, which
    // stays the two booleans; advisory nuance is the UI's call.
    note: flaw.toLowerCase() == 'none' ? '' : flaw,
  );
}

/// Vision describe of the base portrait for prompt grounding: asks the model
/// for comma-separated physical-appearance tags (hair, eyes, skin, notable
/// features, clothing — no names, no emotion words). Returns the trimmed
/// tags, truncated at a tag boundary when the model rambles past ~600 chars,
/// or null when the reply is empty or the eval failed.
Future<String?> describePortrait({
  required String imageB64,
  required VisionEvalFn fire,
}) async {
  const prompt =
      'Describe the physical appearance of the character in this image as a '
      'comma-separated list of short visual tags: hair color and style, eye '
      'color, skin tone, notable features, clothing. No names, no emotion '
      'words, no sentences — reply with ONLY the comma-separated tags.';
  final reply = await fire(prompt: prompt, imagesB64: [imageB64]);
  var text = reply?.trim() ?? '';
  if (text.length > 600) {
    final cut = text.lastIndexOf(',', 600);
    text = text.substring(0, cut > 0 ? cut : 600).trim();
  }
  return text.isEmpty ? null : text;
}
