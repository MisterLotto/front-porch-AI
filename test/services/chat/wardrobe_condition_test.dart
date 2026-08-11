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

// A red sundress that goes out into the rain becomes a rain-soaked red
// sundress. Chain mail after a battle becomes dented chain mail.
//
// The APPLIER could always do this — `update` searches worn and carrying alike
// and rewrites the item in place. What could not happen was the model being in
// a position to ASK for it, in the exact case that matters most:
//
//   You:      you step out into the downpour
//   Jennifer: "Wait for me!"
//
// The pass was handed only Jennifer's reply. Nothing in "Wait for me!" says
// anything about rain, so the dress stayed recorded bone-dry and the feature
// looked broken while working exactly as written. Afterglow's climax check had
// the identical hole — same cause, same shape — and went red on three platforms
// for it, which is how this one got found.
//
// So these tests come in two halves: the applier does the right thing when
// asked (it always did), and the prompt now carries enough for the model to
// know to ask.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  PocketOpReport op(PocketOpKind kind, String item, {String state = ''}) =>
      PocketOpReport(kind: kind, item: item, state: state);

  group('the maintainer\'s two cases, end to end through the applier', () {
    test('a red sundress caught in the rain', () {
      final p = Pockets(worn: [const PocketItem('red sundress')]);

      final receipts = applyPocketOps(p, [
        op(PocketOpKind.update, 'red sundress', state: 'rain-soaked'),
      ]);

      expect(p.worn.single.display, 'red sundress (rain-soaked)');
      expect(receipts, ['red sundress: rain-soaked']);
    });

    test('chain mail armour after a battle', () {
      final p = Pockets(worn: [const PocketItem('chain mail armour')]);

      applyPocketOps(p, [
        op(PocketOpKind.update, 'chain mail armour', state: 'dented'),
      ]);

      expect(p.worn.single.display, 'chain mail armour (dented)');
    });

    test('a condition can be revised again later', () {
      // Wet, then dry by the fire. A one-shot field that could only be set once
      // would leave her permanently damp.
      final p = Pockets(worn: [const PocketItem('red sundress')]);

      applyPocketOps(p, [op(PocketOpKind.update, 'red sundress', state: 'rain-soaked')]);
      applyPocketOps(p, [op(PocketOpKind.update, 'red sundress', state: 'drying by the fire')]);

      expect(p.worn.single.state, 'drying by the fire');
    });

    test('worn and carried are both reachable', () {
      // `update` scans both lists. A version that only searched `carrying`
      // would pass every food test and silently never touch clothing.
      final p = Pockets(
        worn: [const PocketItem('boots')],
        carrying: [const PocketItem('lantern')],
      );

      applyPocketOps(p, [
        op(PocketOpKind.update, 'boots', state: 'mud-caked'),
        op(PocketOpKind.update, 'lantern', state: 'lit'),
      ]);

      expect(p.worn.single.display, 'boots (mud-caked)');
      expect(p.carrying.single.display, 'lantern (lit)');
    });

    test('the condition rides along when the item moves', () {
      // AMENDED 2026-08-11. This used to pin remove -> carrying ("taking off
      // a soaked dress must not launder it") — but remove now deletes the
      // garment outright (maintainer ruling: people do not re-wear
      // yesterday's outfit, so removed clothes leave the record). The
      // property itself — a move must never launder the condition — still
      // holds on the move that remains: putting on something she was
      // carrying.
      final p = Pockets(
        carrying: [const PocketItem('red sundress', state: 'rain-soaked')],
      );

      applyPocketOps(p, [op(PocketOpKind.wear, 'red sundress')]);

      expect(p.worn.single.display, 'red sundress (rain-soaked)');
    });
  });

  group('the model can now SEE the change it should report', () {
    String prompt({required String reply, required String recent}) =>
        PocketsEval.buildPrompt(
          charName: 'Jennifer',
          current: Pockets(worn: [const PocketItem('red sundress')]),
          reply: reply,
          recentExchange: recent,
          toolsMode: false,
        );

    test('rain the USER narrated reaches the prompt', () {
      final p = prompt(
        reply: '"Wait for me!"',
        recent: 'You: you step out into the downpour\nJennifer: "Wait for me!"',
      );

      expect(
        p,
        contains('downpour'),
        reason: 'this is the whole bug — the reply alone says nothing about '
            'weather, so without the exchange the dress stays dry forever',
      );
    });

    test('the wardrobe it might change is listed above the scene', () {
      final p = prompt(reply: 'x', recent: 'You: y');

      expect(p, contains('Currently wearing: red sundress'));
      expect(
        p.indexOf('Currently wearing'),
        lessThan(p.indexOf('The reply:')),
        reason: 'it has to know what she has before it can say what changed',
      );
    });

    test('the examples cover weather and damage, not only food', () {
      // A small local model leans hard on the examples. When every one was
      // about eating, weather and wear went unreported.
      final p = prompt(reply: 'x', recent: 'y');

      expect(p, contains('rain-soaked'));
      expect(p, contains('dented'));
      expect(p, contains('mud-caked'));
      expect(p, contains('half-eaten'), reason: 'the food case still works');
    });

    test('no exchange yet means no empty header', () {
      expect(
        prompt(reply: 'x', recent: ''),
        isNot(contains('Recent exchange for context:')),
      );
    });
  });
}
