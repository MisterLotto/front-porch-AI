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

// THE JUDGE PROMPTS SHARE A BYTE-IDENTICAL PREFIX, AND NO EVAL CHANGED PHASE.
//
// Two contracts from the same maintainer ruling (2026-08-10), pinned together
// because one enabled the other:
//
//   1. PREFIX. Relationship, emotional and narrative fire back-to-back every
//      turn, and each used to open with a different first sentence — so
//      KoboldCpp's fast-forward was defeated from token one and every call
//      re-prefilled its own copy of the same dossier/standing/frame. They now
//      open with the byte-identical `judgePrefix`, and the dispatch order
//      keeps them consecutive (scene-time, which is deliberately lean and
//      shares nothing, fires last) so the first call's prefill serves all
//      three. Firing ORDER was declared free to change.
//   2. PHASE. Eval PLACEMENT was declared frozen: "no evals can change from
//      pre to post" — the four judges stay pre-generation (they score the
//      user's message; a reroll must not reroll her feelings), and the
//      reply-readers (needs impact, climax, pockets, posture) stay
//      post-generation (they read words that do not exist before the reply).
//      The phase group below is the durable form of that sentence.
//
// Proven-to-fail note (the mandatory negative check, run 2026-08-10 before
// this file was allowed to land): appending one character to the prefix used
// by the relationship builder alone turned the byte-identity group red;
// swapping narrative and scene-time back in the dispatch list turned the
// order guard red. Both were restored and the suite went green again.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  const ambitions = [(text: 'open her own bakery', progress: 30)];

  String prefix() => RealismPromptBuilder.judgePrefix(
    charName: 'Vera',
    userName: 'Sam',
    dossier: 'DOSSIER\n',
    standing: 'STANDING\n',
    preferences: 'PREFS\n',
    ambitions: ambitions,
  );

  group('byte-identical prefix across every judge', () {
    test('relationship, emotional, narrative and one-shot all open with it', () {
      final p = prefix();
      expect(p.length, greaterThan(400), reason: 'a trivial prefix shares nothing');

      final rel = RealismPromptBuilder.relationshipEvalPrompt(
        charName: 'Vera',
        userName: 'Sam',
        dossier: 'DOSSIER\n',
        standing: 'STANDING\n',
        recent: 'Sam: hey',
        preferences: 'PREFS\n',
        ambitions: ambitions,
      );
      final emo = RealismPromptBuilder.emotionalEvalPrompt(
        charName: 'Vera',
        userName: 'Sam',
        dossier: 'DOSSIER\n',
        standing: 'STANDING\n',
        recent: 'Sam: hey',
        arousalEnabled: true,
        arousalLevel: 10,
        preferences: 'PREFS\n',
        ambitions: ambitions,
      );
      final narr = RealismPromptBuilder.narrativeEvalPrompt(
        charName: 'Vera',
        userName: 'Sam',
        dossier: 'DOSSIER\n',
        standing: 'STANDING\n',
        recent: 'Sam: hey',
        preferences: 'PREFS\n',
        ambitions: ambitions,
      );
      final oneShot = RealismPromptBuilder.oneShotEvalPrompt(
        charName: 'Vera',
        userName: 'Sam',
        dossier: 'DOSSIER\n',
        standing: 'STANDING\n',
        recent: 'Sam: hey',
        arousalEnabled: true,
        arousalLevel: 10,
        preferences: 'PREFS\n',
        ambitions: ambitions,
      );

      for (final judge in [rel, emo, narr, oneShot]) {
        expect(
          judge.startsWith(p),
          isTrue,
          reason: 'one drifted first byte means that judge re-prefills its '
              'whole context every turn — the exact cost the shared prefix '
              'exists to remove. Compose from judgePrefix; never re-inline.',
        );
      }

      // And the tails still differ where they must: each judge asks its own
      // question after the shared prefix.
      expect(rel.substring(p.length), contains('"relationship_delta"'));
      expect(emo.substring(p.length), contains('"emotion_intensity"'));
      expect(narr.substring(p.length), contains('"fixation_topic"'));
      expect(narr.substring(p.length), contains('not generic story beats'));
    });

    test('the rubrics come before the recent window in every judge', () {
      // The parity-slice contract (realism_prompt_builder_test extracts the
      // rubric as everything before '\nRecent conversation:') and the format
      // ask staying last both depend on this ordering.
      final rel = RealismPromptBuilder.relationshipEvalPrompt(
        charName: 'Vera',
        userName: 'Sam',
        dossier: '',
        standing: '',
        recent: 'Sam: hey',
      );
      expect(
        rel.indexOf('- "relationship_delta"'),
        lessThan(rel.indexOf('\nRecent conversation:')),
      );
    });
  });

  group('dispatch keeps the prefix-sharers consecutive', () {
    test('scene-time fires after the three shared-prefix judges', () {
      final src = File(
        'lib/services/chat/chat_service_realism_evals.dart',
      ).readAsStringSync();
      final body = src.substring(src.indexOf('_fireStaggeredRealismEvals'));
      final rel = body.indexOf('_evaluateRelationshipCall');
      final emo = body.indexOf('_evaluateEmotionalStateCall');
      final narr = body.indexOf('_evaluateNarrativeCall');
      final phys = body.indexOf('_evaluatePhysicalStateCall');
      expect(rel, greaterThan(-1));
      expect(emo, greaterThan(rel));
      expect(narr, greaterThan(emo));
      expect(
        phys,
        greaterThan(narr),
        reason: 'scene-time shares no prefix; dispatched between two judges '
            'it evicts the shared prefill on a single-slot backend and the '
            'optimization silently dies',
      );
    });
  });

  group('no eval changed phase (maintainer constraint, 2026-08-10)', () {
    // "No evals can change from pre to post" — the judges score the USER's
    // message and must run before generation; the reply-readers read the
    // reply and must run after. Order within a phase is free; the boundary
    // is not.
    final preGen = File(
      'lib/services/chat/chat_service_realism_dance.dart',
    ).readAsStringSync();
    final postGen = File(
      'lib/services/chat/chat_service_generation_postgen.dart',
    ).readAsStringSync();

    test('the four judges fire from the pre-generation dance', () {
      expect(preGen, contains('_fireStaggeredRealismEvals'));
      for (final replyReader in const [
        '_runClimaxPass(',
        '_runPocketsPass(',
        '_runPostGenNeedsChecks(',
        '_prefetchReplyFacts(',
      ]) {
        expect(
          preGen,
          isNot(contains(replyReader)),
          reason: '$replyReader reads the reply, which does not exist before '
              'generation — firing it from the dance judges words never '
              'written',
        );
      }
    });

    test('the reply-readers fire from the post-generation phase', () {
      for (final replyReader in const [
        '_runClimaxPass(finalResponse)',
        '_runPocketsPass(finalResponse)',
        '_runPostGenNeedsChecks(finalResponse)',
        '_prefetchReplyFacts(finalResponse)',
      ]) {
        expect(postGen, contains(replyReader));
      }
      for (final judge in const [
        '_fireStaggeredRealismEvals',
        'evaluateOneShotCall',
        '_evaluateRelationshipCall',
        '_evaluateEmotionalStateCall',
        '_evaluateNarrativeCall',
      ]) {
        expect(
          postGen,
          isNot(contains(judge)),
          reason: '$judge scores the user\'s message and runs at temperature '
              '0.1 so a regen reproduces its deltas — moved after the reply '
              'it would score the character\'s own words, and rerolling a '
              'line would reroll her feelings (the settled 2026-08-02 rule)',
        );
      }
    });
  });
}
