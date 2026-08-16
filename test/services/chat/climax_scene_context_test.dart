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

// The climax check must see the EXCHANGE, not only the character's reply.
//
// THE REGRESSION THIS PINS. Afterglow's climax detection used to ride the
// needs-impact eval, whose prompt carries two things:
//
//     RESPONSE (the scene that just happened):
//     <the character's reply>
//     Recent exchange for context:
//     <the last three messages>
//
// Extracting it into its own pass kept the first and silently dropped the
// second, which narrowed what the detector could see without anything saying
// so. Unit tests stayed green — every one of them was about the criteria text,
// the transport, or WHERE the pass runs, and none about what scene it is shown.
// The E2E caught it, on all three platforms, because its fixture is exactly the
// case that breaks: the USER narrates the climax ("the wave crests over us
// both") and the character answers with aftermath ("Closer now, and closer
// still."). Shown only that reply, the model answers false, no refractory
// starts, and Afterglow does nothing — the very symptom the decoupling work
// existed to fix.
//
// That shape is not a quirk of the fixture. It is how a great deal of intimate
// roleplay is written, and it is why the context is in the prompt at all.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/climax_eval.dart';

void main() {
  String prompt({String reply = 'Closer now, and closer still.', String recent = ''}) =>
      ClimaxEval.buildPrompt(
        charName: 'Jennifer',
        reply: reply,
        recentExchange: recent,
        toolsMode: false,
      );

  group('the exchange reaches the model', () {
    test('a climax the USER narrated is visible to the check', () {
      final p = prompt(recent: 'You: the wave crests over us both\nJennifer: Closer now.');

      expect(
        p,
        contains('the wave crests'),
        reason: 'the character rarely narrates her own release in so many '
            'words; if only her reply reaches the model, the answer is false '
            'and the refractory never starts',
      );
    });

    test('it is labelled as context, not as a second thing to score', () {
      // The verdict is still about the CHARACTER and still judged on a reply
      // that already exists. The exchange is there to read that reply against.
      final p = prompt(recent: 'You: something\nJennifer: something else');

      expect(p, contains('Recent exchange for context:'));
      expect(
        p.indexOf('The scene:'),
        lessThan(p.indexOf('Recent exchange for context:')),
        reason: 'the reply under judgement comes first; the exchange follows '
            'it as background',
      );
    });

    test('the reply itself is still the subject', () {
      final p = prompt(reply: 'she shuddered and went limp');

      expect(p, contains('she shuddered and went limp'));
      expect(p, contains('CLIMAX DETECTION'));
    });
  });

  group('an empty exchange changes nothing', () {
    test('no context means no empty section header', () {
      // The very first turn of a chat has nothing behind it. A bare
      // "Recent exchange for context:" with nothing under it reads to a model
      // as "the exchange was empty", which is a different claim from silence.
      final p = prompt(recent: '');

      expect(p, isNot(contains('Recent exchange for context:')));
      expect(p, contains('CLIMAX DETECTION'));
    });

    test('whitespace-only context is treated as none', () {
      expect(prompt(recent: '   \n  '), isNot(contains('Recent exchange')));
    });
  });

  test('the parameter is REQUIRED, so it cannot be dropped again silently', () {
    // Not a behaviour check — a design one, and the reason this bug cannot
    // recur the same way. `recentExchange` is a required named parameter on
    // buildPrompt, so a future caller that forgets it fails to compile instead
    // of quietly narrowing what the detector sees. The compiler enforces this;
    // this test exists to say WHY, next to the assertions it protects.
    expect(
      () => ClimaxEval.buildPrompt(
        charName: 'Jennifer',
        reply: 'x',
        recentExchange: '',
        toolsMode: false,
      ),
      returnsNormally,
    );
  });
}
