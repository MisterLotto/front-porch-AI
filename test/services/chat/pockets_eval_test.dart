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

// The Pockets detection pass: its prompt, its parse, and its refusal to fail a
// turn.
//
// The parse cases are not defensive padding. This eval runs against whatever
// backend the user has, including small local models, and the app's standing
// position (maintainer, recorded) is that those models are capable and must be
// met with a forgiving floor rather than a feature switched off. So the shapes
// tested here are the shapes they actually emit: the object, a bare array,
// prose wrapped around JSON, a fenced code block, and outright junk.
//
// The other half is the promise that this pass can never cost a turn. The reply
// has already been written and shown; if bookkeeping fails, the record misses
// one update and the conversation carries on.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/pockets.dart';
import 'package:front_porch_ai/services/chat/pockets_eval.dart';

PocketsEval evalReturning(String? raw) => PocketsEval(
  fire: ({required debugLabel, required tools, required buildPrompt}) async {
    // Exercise both prompt shapes on every call, so a builder that throws in
    // tools mode cannot hide behind the text path.
    buildPrompt(toolsMode: true);
    buildPrompt(toolsMode: false);
    return raw;
  },
);

void main() {
  group('the prompt', () {
    test('shows the record so the model can name items consistently', () {
      final p = Pockets(
        worn: [const PocketItem('sundress', state: 'rain-soaked')],
        carrying: [const PocketItem('car keys')],
      );
      final txt = PocketsEval.buildPrompt(
        charName: 'Alice',
        current: p,
        reply: 'She pockets the keys.',
        recentExchange: '',
        toolsMode: false,
      );
      expect(txt, contains('sundress (rain-soaked)'));
      expect(txt, contains('car keys'));
      expect(txt, contains('She pockets the keys.'));
    });

    test('an empty record says so rather than showing a blank line', () {
      final txt = PocketsEval.buildPrompt(
        charName: 'Alice',
        current: Pockets(),
        reply: 'x',
        recentExchange: '',
        toolsMode: false,
      );
      expect(txt, contains('(nothing recorded)'));
    });

    test('it tells the model that "nothing changed" is the usual answer', () {
      // Without this the model invents changes to look useful, and the record
      // fills with things that never happened — the failure that would make
      // the feature worse than not having it.
      final txt = PocketsEval.buildPrompt(
        charName: 'Alice',
        current: Pockets(),
        reply: 'x',
        recentExchange: '',
        toolsMode: false,
      );
      expect(txt, contains('empty list'));
      expect(txt, contains('not things they merely mentioned'));
    });

    test('the two transports ask for the same thing, differently framed', () {
      String p(bool tools) => PocketsEval.buildPrompt(
        charName: 'Alice',
        current: Pockets(),
        reply: 'x',
        recentExchange: '',
        toolsMode: tools,
      );
      expect(p(true), contains(PocketsEval.kPocketsTool));
      expect(p(true), isNot(contains('raw JSON only')));
      expect(p(false), contains('raw JSON only'));
      expect(p(false), isNot(contains(PocketsEval.kPocketsTool)));
    });
  });

  group('the parse meets local models where they are', () {
    test('the documented object shape', () {
      final ops = PocketsEval.parseOps(
        '{"inventory_ops":[{"op":"pickup","item":"car keys"}]}',
      );
      expect(ops.single.kind, PocketOpKind.pickup);
      expect(ops.single.item, 'car keys');
    });

    test('a bare array, which smaller models hand back', () {
      final ops = PocketsEval.parseOps('[{"op":"drop","item":"a lantern"}]');
      expect(ops.single.kind, PocketOpKind.drop);
    });

    test('JSON with prose wrapped around it', () {
      final ops = PocketsEval.parseOps(
        'Sure! Here is what changed:\n'
        '{"inventory_ops":[{"op":"wear","item":"coat"}]}\n'
        'Let me know if you need anything else.',
      );
      expect(ops.single.kind, PocketOpKind.wear);
    });

    test('a fenced code block', () {
      final ops = PocketsEval.parseOps(
        '```json\n{"inventory_ops":[{"op":"give","item":"keys","to":"Sam"}]}\n```',
      );
      expect(ops.single.to, 'Sam');
    });

    test('an empty list is a real answer, not a failure', () {
      expect(PocketsEval.parseOps('{"inventory_ops":[]}'), isEmpty);
    });

    test('junk, empty and null all yield nothing rather than throwing', () {
      for (final raw in [null, '', '   ', 'no changes', '{', '{"a":']) {
        expect(() => PocketsEval.parseOps(raw), returnsNormally, reason: '$raw');
        expect(PocketsEval.parseOps(raw), isEmpty, reason: '$raw');
      }
    });

    test('one bad op does not discard the good ones beside it', () {
      final ops = PocketsEval.parseOps(
        '{"inventory_ops":['
        '{"op":"nonsense","item":"x"},'
        '{"op":"pickup","item":""},'
        '{"op":"pickup","item":"car keys"}]}',
      );
      expect(ops.length, 1);
      expect(ops.single.item, 'car keys');
    });
  });

  group('applying what it found', () {
    test('the record changes and the receipts describe it', () async {
      final p = Pockets(carrying: [const PocketItem('candy bar')]);
      final receipts = await evalReturning(
        '{"inventory_ops":['
        '{"op":"transform","item":"candy bar","state":"sweet wrapper"},'
        '{"op":"pickup","item":"car keys"}]}',
      ).evaluateAndApply(
        charName: 'Alice',
        pockets: p,
        reply: 'She eats it.',
        recentExchange: '',
      );

      expect(receipts, ['candy bar → sweet wrapper', 'picked up: car keys']);
      expect(
        [for (final i in p.carrying) i.name],
        ['sweet wrapper', 'car keys'],
      );
    });

    test('an empty reply never spends a call', () async {
      var fired = false;
      final e = PocketsEval(
        fire: ({required debugLabel, required tools, required buildPrompt}) async {
          fired = true;
          return null;
        },
      );
      final out = await e.evaluateAndApply(
        charName: 'Alice',
        pockets: Pockets(),
        reply: '   ',
        recentExchange: '',
      );
      expect(out, isEmpty);
      expect(fired, isFalse, reason: 'this feature bills per turn — do not');
    });

    test('a thrown transport leaves the record intact and the turn alive', () async {
      // The reply has already been written and shown to the user. A failed
      // bookkeeping call must cost one missed update, never the turn.
      final p = Pockets(carrying: [const PocketItem('car keys')]);
      final e = PocketsEval(
        fire: ({required debugLabel, required tools, required buildPrompt}) async =>
            throw Exception('backend went away mid-call'),
      );
      late List<String> out;
      expect(
        () async => out = await e.evaluateAndApply(
          charName: 'Alice',
          pockets: p,
          reply: 'She looks around.',
          recentExchange: '',
        ),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);
      out = await e.evaluateAndApply(
        charName: 'Alice',
        pockets: p,
        reply: 'She looks around.',
        recentExchange: '',
      );
      expect(out, isEmpty);
      expect([for (final i in p.carrying) i.name], ['car keys']);
    });

    test('a null answer changes nothing', () async {
      final p = Pockets(worn: [const PocketItem('coat')]);
      final out = await evalReturning(
        null,
      ).evaluateAndApply(
        charName: 'Alice',
        pockets: p,
        reply: 'She waits.',
        recentExchange: '',
      );
      expect(out, isEmpty);
      expect(p.worn.single.name, 'coat');
    });
  });

  group('the tool schema', () {
    test('offers exactly the ops the applier understands', () {
      final fn = PocketsEval.tools.single['function'] as Map<String, dynamic>;
      final params = fn['parameters'] as Map<String, dynamic>;
      final props = params['properties'] as Map<String, dynamic>;
      final ops = props['inventory_ops'] as Map<String, dynamic>;
      final item = ops['items'] as Map<String, dynamic>;
      final opProp =
          (item['properties'] as Map<String, dynamic>)['op']
              as Map<String, dynamic>;

      expect(
        (opProp['enum'] as List).toSet(),
        {for (final k in PocketOpKind.values) k.name},
        reason: 'a verb the schema offers but the applier cannot parse would '
            'be silently dropped every time a model chose it',
      );
      expect((item['required'] as List).toSet(), {'op', 'item'});
    });
  });
}
