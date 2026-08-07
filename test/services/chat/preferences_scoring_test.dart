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

// Likes & Dislikes — the SCORING half, and its parity contract.
//
// CLAUDE.md's one-shot rule is strict: `_evaluateOneShotCall` must produce 1:1
// equivalent Bond/Trust/Emotion/Arousal output to the multi-call path, because
// one-shot exists purely to save tokens and must never change observable
// behaviour. A preferences block that reached the relationship prompt but not
// the fused one-shot prompt would break exactly that, and it would break it
// QUIETLY — the same user, the same card, the same message, scored differently
// depending on a token-optimisation toggle they set weeks ago.
//
// The mitigation is structural: all three prompts compose the SAME
// _subjectivityFrame, so the block cannot be added to one and forgotten in
// another. These tests pin that structure, following the precedent
// ambition_steering_test set with its byte-identical steering-text check.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/preference_phrases.dart';
import 'package:front_porch_ai/services/chat/realism_prompt_builder.dart';

String block({
  List<String> likes = const [],
  List<String> dislikes = const [],
  List<String> into = const [],
  List<String> notInto = const [],
}) => RealismPromptBuilder.preferencesBlock(
  charName: 'Alice',
  likes: likes,
  dislikes: dislikes,
  intimateInto: into,
  intimateNotInto: notInto,
);

/// The three judge prompts that carry the subjectivity frame, built with
/// identical inputs so only the preferences block can differ between them.
({String relationship, String emotional, String oneShot}) prompts(String prefs) {
  const common = (
    charName: 'Alice',
    userName: 'Sam',
    dossier: 'Who Alice is …\n\n',
    standing: 'Where things stand …\n\n',
    recent: 'Sam: hello\nAlice: hi',
  );
  return (
    relationship: RealismPromptBuilder.relationshipEvalPrompt(
      charName: common.charName,
      userName: common.userName,
      dossier: common.dossier,
      standing: common.standing,
      recent: common.recent,
      preferences: prefs,
    ),
    emotional: RealismPromptBuilder.emotionalEvalPrompt(
      charName: common.charName,
      userName: common.userName,
      dossier: common.dossier,
      standing: common.standing,
      recent: common.recent,
      arousalEnabled: false,
      arousalLevel: 0,
      preferences: prefs,
    ),
    oneShot: RealismPromptBuilder.oneShotEvalPrompt(
      charName: common.charName,
      userName: common.userName,
      dossier: common.dossier,
      standing: common.standing,
      recent: common.recent,
      arousalEnabled: false,
      arousalLevel: 0,
      preferences: prefs,
    ),
  );
}

void main() {
  group('the block itself', () {
    test('names both everyday sides and tells the judge to weigh them', () {
      final txt = block(
        likes: ['being read to', 'thunderstorms'],
        dislikes: ['being interrupted'],
      );
      expect(txt, contains('drawn to being read to, thunderstorms'));
      expect(txt, contains('put off by being interrupted'));
      expect(txt, contains('lands harder'));
      // The judge must not extrapolate a personality it was not given.
      expect(txt, contains('Do not invent preferences beyond these'));
    });

    test('the intimate pair renders when the caller passes it', () {
      final txt = block(into: ['slow mornings'], notInto: ['an audience']);
      expect(txt, contains('warms to slow mornings'));
      expect(txt, contains('not interested in an audience'));
    });

    test('a character with no preferences costs nothing at all', () {
      // The same contract the ambition roster keeps: absent means the block is
      // not in the prompt, not that an empty header is.
      expect(block(), isEmpty);
      expect(block(likes: const ['', '   ']), isEmpty);
    });

    test('the cap bounds the prompt, not the card', () {
      final many = [for (var i = 0; i < 12; i++) 'thing$i'];
      final txt = block(likes: many);
      expect(txt, contains('thing0'));
      expect(
        txt,
        contains('thing${kMaxPreferencePhrases - 1}'),
      );
      expect(
        txt,
        isNot(contains('thing$kMaxPreferencePhrases')),
      );
    });
  });

  group('one-shot vs multi-call parity (CLAUDE.md, strict)', () {
    final prefs = block(likes: ['thunderstorms'], dislikes: ['crowds']);

    test('all three judge prompts carry the SAME block, byte for byte', () {
      final p = prompts(prefs);
      expect(p.relationship, contains(prefs));
      expect(p.emotional, contains(prefs));
      expect(p.oneShot, contains(prefs));
    });

    test('and all three omit it entirely when there is nothing to say', () {
      final p = prompts('');
      for (final text in [p.relationship, p.emotional, p.oneShot]) {
        expect(text, isNot(contains('Specifically, Alice is')));
        expect(text, isNot(contains('Do not invent preferences')));
      }
    });

    test('the block sits inside the shared subjectivity frame in each', () {
      // Position matters as much as presence: the frame ends by telling the
      // judge that what reaches someone is what THEY value, and the block is
      // the answer to that sentence. Split apart, it reads as an unrelated
      // instruction.
      final p = prompts(prefs);
      for (final text in [p.relationship, p.emotional, p.oneShot]) {
        final anchor = text.indexOf('What genuinely reaches someone');
        final blockAt = text.indexOf('Specifically, Alice is');
        expect(anchor, greaterThan(-1));
        expect(blockAt, greaterThan(anchor));
        expect(blockAt - anchor, lessThan(400), reason: 'must follow directly');
      }
    });
  });

  group('regen determinism', () {
    test('the same card produces the same block every time', () {
      // Evals run at temperature 0.1 and a regen MUST reproduce the same
      // deltas (CLAUDE.md: two regens disagreeing is a rewind bug). A block
      // that shuffled, sampled, or timestamped would make the prompt differ
      // between a turn and its own regen.
      final a = block(likes: ['a', 'b', 'c'], dislikes: ['d']);
      final b = block(likes: ['a', 'b', 'c'], dislikes: ['d']);
      expect(a, b);
    });
  });
}
