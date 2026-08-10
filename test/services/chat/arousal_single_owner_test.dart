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

// ONE AROUSAL OWNER PER TURN (eval review item 7, 2026-08-10).
//
// The eval whose prompt REQUESTS arousal_delta is the only one allowed to
// apply it: the emotional-state eval in multi-call mode, the fused call in
// one-shot mode. The relationship path used to parse the field "best-effort"
// even though its prompt never asks for it — so a chatty model that
// volunteered `"arousal_delta"` in the relationship reply got it applied
// TWICE in one turn (once by the relationship parse, once by the emotional
// eval), Lust moved by the sum, and the chip showed only the second value.
// Regens made it worse: whether the double fired depended on whether the
// model felt like volunteering the field that roll.
//
// Guards proven to fail before passing:
//   * restore the old unconditional arousal parse in
//     _parseAndApplyRelationshipDeltas (drop the applyArousal gate) → the
//     "relationship path never applies arousal" and "whole turn applies it
//     once" tests go red
//   * flip the one-shot call site to applyArousal:false → the one-shot test
//     goes red (arousal stops moving entirely in one-shot mode)
//
// Factory modeled on createTestRealismEvals in realism_evals_test.dart
// (dedicated suites redefine their factories by precedent), trimmed to the
// callbacks these paths touch.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart' show Objective;
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

RealismEvals _evals({
  required NsfwService nsfw,
  required Future<String?> Function(String, {void Function(String)? onChunk})
  fire,
}) {
  final rel = RelationshipService(
    onNotify: () {},
    onSaveChat: () async {},
    getIsGroupActive: () => false,
    getObserverMode: () => false,
    getGroupCharacterCount: () => 0,
    getShouldTrackInterCharacterRelationships: () => false,
    getCurrentSpeakerIdForRealism: () => '',
    getCurrentGroupMemberIds: () => {},
    getOtherGroupMemberIds: (_) => [],
    getOtherGroupMemberIdToLowerName: (_) => {},
    getRecentExchangeLowerText: () => '',
    getMessageCount: () => 0,
    getIsGroupRealismActive: () => false,
    getGroupAffectionScore: (id, {defaultValue = 0}) => defaultValue,
    setGroupAffectionScore: (_, _) {},
    getGroupLongTermScore: (id, {defaultValue = 0}) => defaultValue,
    setGroupLongTermScore: (_, _) {},
    getGroupTrustLevel: (id, {defaultValue = 0}) => defaultValue,
    setGroupTrustLevel: (_, _) {},
    getGroupFixation: (id, {defaultValue = ''}) => defaultValue,
    setGroupFixation: (_, _) {},
    getGroupFixationLifespan: (id, {defaultValue = 0}) => defaultValue,
    setGroupFixationLifespan: (_, _) {},
    getGroupRelationshipTier: (id, {defaultValue = 0}) => defaultValue,
    setGroupRelationshipTier: (_, _) {},
    getGroupLongTermTier: (id, {defaultValue = 0}) => defaultValue,
    setGroupLongTermTier: (_, _) {},
    getGroupSpatialStance: (id, {defaultValue = ''}) => defaultValue,
    setGroupSpatialStance: (_, _) {},
    getGroupInterCharacterRelationships: (_) => <String, int>{},
    setGroupInterCharacterRelationships: (_, _) {},
  );
  final time = TimeService(
    onNotify: () {},
    onSaveChat: () async {},
    onSetPendingRealismMetadata: (k, v) {},
    onPatchLastMessageRealismState: (tod, dc, iso) {},
  );
  final char = CharacterCard(name: 'TestChar', personality: 'test');
  int? extractInt(String text, String key) {
    final m = RegExp(
      '"' + RegExp.escape(key) + r'"\s*:\s*(-?\d+)',
    ).firstMatch(text);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  bool? extractBool(String text, String key) {
    final m = RegExp(
      '"' + RegExp.escape(key) + r'"\s*:\s*(true|false)',
    ).firstMatch(text);
    return m != null ? (m.group(1) == 'true') : null;
  }

  return RealismEvals(
    fireLLMEval: fire,
    fireToolEval: (p, t) async => null,
    probe: ToolTransportProbe(),
    getBackendIdentity: () => 'test-backend',
    isEvalCancelled: () => false,
    stripThinkBlocks: (t) => t,
    extractJsonInt: extractInt,
    extractJsonBool: extractBool,
    getActiveCharacter: () => char,
    getActiveGroup: () => null,
    getIsObserverMode: () => false,
    getUserName: () => 'User',
    getRealismEnabled: () => true,
    getMessages: () => <ChatMessage>[
      ChatMessage(text: 'hey there', sender: 'User', isUser: true),
    ],
    getPendingRealismMetadata: () => <String, dynamic>{},
    setPendingRealismMetadata: (v) {},
    captureRealismState: ({Map<String, int>? preTurn}) => <String, dynamic>{},
    getCharacterEmotion: () => '',
    setCharacterEmotion: (_) {},
    getEmotionIntensity: () => '',
    setEmotionIntensity: (_) {},
    relationshipService: rel,
    nsfwService: nsfw,
    timeService: time,
    getExpressionEnabled: () => false,
    getCharacterDossier: (card) => card.personality,
    getPrimaryObjective: () => null,
    getActiveObjectives: () => <Objective>[],
    setObjective:
        (
          text, {
          isPrimary = false,
          autoGenerateTasks = false,
          servedAmbition,
        }) async {},
    verifyRealismOutput: null,
  );
}

NsfwService _nsfw() => NsfwService(
  getGroupInt: (_, _) => 0,
  getGroupValue: (_, _) => null,
  setGroupValue: (_, _, _) {},
)..setNsfwCooldownEnabled(true);

/// A relationship reply from a chatty model that VOLUNTEERS arousal_delta —
/// the field its prompt never asked for. This is the exact input that used
/// to double-apply. (20 sits inside the ±25 arousal clamp so the expected
/// level equals the delta and a double-apply reads as exactly 40.)
const _relationshipReply =
    '{"relationship_delta": 2, "bond_reason": "warm words", '
    '"trust_delta": 1, "trust_reason": "kept a promise", '
    '"arousal_delta": 20}';

const _emotionalReply =
    '{"emotion": "flustered", "emotion_intensity": "moderate", '
    '"arousal_delta": 20}';

void main() {
  group('arousal has exactly one owner per turn', () {
    test(
      'the relationship path never applies a volunteered arousal_delta',
      () async {
        final nsfw = _nsfw();
        final svc = _evals(
          nsfw: nsfw,
          fire: (p, {onChunk}) async {
            return _relationshipReply;
          },
        );
        await svc.evaluateRelationshipCall();
        expect(
          nsfw.arousalLevel,
          0,
          reason:
              'THE BUG. The relationship prompt does not request arousal_delta; '
              'a model that volunteers it anyway must not move Lust — that is '
              'the emotional eval\'s field, and applying here means applying '
              'twice per turn.',
        );
      },
    );

    test('the emotional-state eval is the multi-call owner', () async {
      final nsfw = _nsfw();
      final svc = _evals(
        nsfw: nsfw,
        fire: (p, {onChunk}) async {
          return _emotionalReply;
        },
      );
      await svc.evaluateEmotionalStateCall();
      expect(nsfw.arousalLevel, 20);
    });

    test('a full multi-call turn applies arousal exactly once', () async {
      final nsfw = _nsfw();
      // One merged reply for BOTH judges — every call sees an arousal_delta,
      // so the total can only stay 20 if exactly one call owns the field.
      final svc = _evals(
        nsfw: nsfw,
        fire: (p, {onChunk}) async {
          return '{"relationship_delta": 2, "bond_reason": "warm words", '
              '"trust_delta": 1, "trust_reason": "kept a promise", '
              '"emotion": "flustered", "emotion_intensity": "moderate", '
              '"arousal_delta": 20}';
        },
      );
      await svc.evaluateRelationshipCall();
      await svc.evaluateEmotionalStateCall();
      expect(
        nsfw.arousalLevel,
        20,
        reason: 'one turn, one application — 40 means the double-apply is back',
      );
    });

    test('one-shot still applies arousal (single owner there is the fused '
        'call itself)', () async {
      final nsfw = _nsfw();
      final svc = _evals(
        nsfw: nsfw,
        fire: (p, {onChunk}) async {
          return '{"relationship_delta": 2, "bond_reason": "warm words", '
              '"trust_delta": 1, "trust_reason": "kept a promise", '
              '"arousal_delta": 20, "emotion": "flustered", '
              '"emotion_intensity": "moderate", "minutes_elapsed": 5, '
              '"new_day": false, "proposed_objective": "none", '
              '"fixation_topic": "none", "reason": "none"}';
        },
      );
      await svc.evaluateOneShotCall();
      expect(
        nsfw.arousalLevel,
        20,
        reason:
            'flipping the ownership flag off on the one-shot call site would '
            'silence arousal entirely in one-shot mode — a strict-parity '
            'violation in the other direction',
      );
    });
  });
}
