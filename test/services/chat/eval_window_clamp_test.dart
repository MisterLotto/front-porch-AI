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

// THE EVAL PROMPT DIET (2026-08-10, from the maintainer's EvalTraffic
// capture): verbose models write 20k+ character replies, and every eval
// window carried its messages UNCAPPED — four ~50k-char eval prompts in one
// turn, 48k tokens and 50 seconds of LLM time to score a single exchange.
// Every turn-time eval window (the three judges, one-shot, scene-time,
// needs/climax/pockets via recentExchange, and the objective check — which
// additionally read RAW m.text, think blocks included) now flows through
// recentExchange, whose per-message clamp keeps the head and tail of a
// long message around a visible omission marker.
//
// The objective-check site is the same one-line recentExchange call the
// judges use; its conversion is covered by these function-level guards plus
// review, not by a dedicated harness.
//
// Guards proven to fail before passing:
//   * make clampEvalMessage return its input → the clamp tests AND the
//     judge/one-shot capture tests go red
//   * revert a judge window to its inline uncapped copy → that judge's
//     capture test goes red (marker absent, window at full novella length)

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

/// A 21k-char reply, the size from the maintainer's live log (textLen=21248).
final String _novella =
    'OPENING-REACTION ${'porch boards creak under the evening light and she '
            'keeps talking, unhurried, about everything at once. ' * 200}'
    'SCENE-LANDING';

RealismEvals _evals({
  required Future<String?> Function(String, {void Function(String)? onChunk})
  fire,
  required List<ChatMessage> messages,
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
  return RealismEvals(
    fireLLMEval: fire,
    fireToolEval: (p, t) async => null,
    probe: ToolTransportProbe(),
    getBackendIdentity: () => 'test-backend',
    isEvalCancelled: () => false,
    stripThinkBlocks: (t) => t,
    extractJsonInt: (t, k) => null,
    extractJsonBool: (t, k) => null,
    getActiveCharacter: () => char,
    getActiveGroup: () => null,
    getIsObserverMode: () => false,
    getUserName: () => 'User',
    getRealismEnabled: () => true,
    getMessages: () => messages,
    getPendingRealismMetadata: () => <String, dynamic>{},
    setPendingRealismMetadata: (v) {},
    captureRealismState: ({Map<String, int>? preTurn}) => <String, dynamic>{},
    getCharacterEmotion: () => '',
    setCharacterEmotion: (_) {},
    getEmotionIntensity: () => '',
    setEmotionIntensity: (_) {},
    relationshipService: rel,
    nsfwService: NsfwService(
      getGroupInt: (_, _) => 0,
      getGroupValue: (_, _) => null,
      setGroupValue: (_, _, _) {},
    ),
    timeService: time,
    getExpressionEnabled: () => false,
    getCharacterDossier: (card) => card.personality,
    getPrimaryObjective: () => null,
    getActiveObjectives: () => [],
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

List<ChatMessage> _withNovella() => [
  ChatMessage(text: 'an older turn', sender: 'User', isUser: true),
  ChatMessage(text: _novella, sender: 'Nia', isUser: false),
  ChatMessage(text: 'what happened next?', sender: 'User', isUser: true),
];

void main() {
  group('clampEvalMessage', () {
    test('text at or under the cap passes through byte-identical', () {
      final text = 'x' * kEvalMessageCharCap;
      expect(identical(clampEvalMessage(text), text), isTrue);
      expect(clampEvalMessage('short'), 'short');
    });

    test('long text keeps head and tail around a visible marker', () {
      final clamped = clampEvalMessage(_novella);
      expect(clamped, contains(kEvalClampMarker));
      expect(clamped, startsWith('OPENING-REACTION'));
      expect(
        clamped,
        endsWith('SCENE-LANDING'),
        reason:
            'the head carries the reaction the judges score; the tail '
            'carries where the scene landed for the reply-readers — losing '
            'either defeats the window',
      );
      expect(
        clamped.length,
        lessThan(kEvalMessageCharCap + kEvalClampMarker.length + 10),
      );
    });

    test('deterministic — a regen sees the identical window', () {
      expect(clampEvalMessage(_novella), clampEvalMessage(_novella));
    });
  });

  group('recentExchange applies the clamp', () {
    test('a novella-sized reply is clamped inside the window', () {
      final window = recentExchange(_withNovella());
      expect(window, contains(kEvalClampMarker));
      expect(
        window.length,
        lessThan(3 * (kEvalMessageCharCap + 200)),
        reason:
            'THE DIET. Uncapped, this window is ~21k chars for one '
            'message alone.',
      );
      expect(window, contains('User: what happened next?'));
    });

    test('short windows are byte-identical to the pre-clamp format', () {
      final msgs = [
        ChatMessage(text: 'plain words', sender: 'User', isUser: true),
        ChatMessage(text: '*She nods.*', sender: 'Nia', isUser: false),
      ];
      expect(recentExchange(msgs), 'User: plain words\nNia: *She nods.*');
    });
  });

  group('the judges and one-shot ride the clamped window', () {
    test('a judge prompt carries the clamp, not the novella', () async {
      String? captured;
      final svc = _evals(
        fire: (p, {onChunk}) async {
          captured ??= p;
          return '{"emotion":"neutral","emotion_intensity":"mild"}';
        },
        messages: _withNovella(),
      );
      await svc.evaluateEmotionalStateCall();
      expect(captured, isNotNull);
      expect(
        captured,
        contains(kEvalClampMarker),
        reason:
            'the judge window must flow through recentExchange — an inline '
            'uncapped copy re-opens the 50k-char prompt',
      );
      expect(captured!.length, lessThan(_novella.length));
    });

    test('the one-shot prompt carries the clamp identically', () async {
      String? captured;
      final svc = _evals(
        fire: (p, {onChunk}) async {
          captured ??= p;
          return '{"relationship_delta":0,"trust_delta":0,'
              '"minutes_elapsed":5,"new_day":false}';
        },
        messages: _withNovella(),
      );
      await svc.evaluateOneShotCall();
      expect(captured, isNotNull);
      expect(captured, contains(kEvalClampMarker));
      expect(captured!.length, lessThan(_novella.length));
    });
  });
}
