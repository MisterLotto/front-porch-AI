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

// Handing things between characters.
//
// `give` shipped as half a transfer: the item left the giver and reached
// nobody, so Alice handing Bob the keys left Bob's record untouched. The reason
// was sound and is worth restating, because it is what shapes every test here:
// resolving a free-text name the model picked, and putting the keys in the
// WRONG character's pocket, is a worse failure than not moving them — it is
// invisible AND wrong, where the old behaviour was merely incomplete.
//
// So the fix is not a cleverer guess. It is a resolver that refuses anything it
// is not certain of, and a caller that falls back to the old floor when it
// refuses. Most of this file is about what must NOT resolve.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/pockets.dart';
import 'package:front_porch_ai/services/chat/pockets_eval.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const roster = ['Alice', 'Bob Vance', 'Samantha'];

  group('the resolver refuses to guess', () {
    test('an exact name matches, whatever the casing', () {
      expect(resolveRecipient('Alice', roster), 'Alice');
      expect(resolveRecipient('alice', roster), 'Alice');
      expect(resolveRecipient('  ALICE  ', roster), 'Alice');
    });

    test('a unique first name matches the full name', () {
      expect(resolveRecipient('Bob', roster), 'Bob Vance');
    });

    test('an ambiguous first name matches NOBODY', () {
      const twoBobs = ['Bob Vance', 'Bob Kelso'];

      expect(
        resolveRecipient('Bob', twoBobs),
        isNull,
        reason: 'picking either one is a coin flip that puts an item in a real '
            "person's pocket — the whole failure this feature avoids",
      );
      expect(resolveRecipient('Bob Kelso', twoBobs), 'Bob Kelso');
    });

    test('it never matches on a substring', () {
      expect(
        resolveRecipient('Sam', roster),
        isNull,
        reason: '"Sam" is not Samantha. A prefix rule would hand Sam\'s coat '
            'to Samantha and nobody would ever see it happen',
      );
      expect(
        resolveRecipient('Ann', ['Joanne']),
        isNull,
        reason: 'and a contains-rule would find Ann inside Joanne',
      );
    });

    test('pronouns, roles and strangers resolve to nobody', () {
      for (final raw in const ['him', 'her', 'them', 'the barkeep', 'you', '']) {
        expect(
          resolveRecipient(raw, roster),
          isNull,
          reason: '"$raw" names no member; the item leaves the giver and goes '
              'nowhere, which is exactly what every build before this did',
        );
      }
    });

    test('an empty roster resolves nothing at all', () {
      expect(
        resolveRecipient('Alice', const []),
        isNull,
        reason: 'a 1:1 chat has no other record to put anything into',
      );
    });
  });

  group('the giver always loses the item, resolvable or not', () {
    Pockets alice() => Pockets(
      worn: [const PocketItem('sundress')],
      carrying: [const PocketItem('car keys', state: 'muddy')],
    );

    test('a resolvable hand-off reports the item and its condition', () {
      final p = alice();
      final handed = <String, PocketItem>{};

      final receipts = applyPocketOps(
        p,
        [const PocketOpReport(kind: PocketOpKind.give, item: 'car keys', to: 'Bob')],
        onTransfer: (to, item) {
          final match = resolveRecipient(to, roster);
          if (match != null) handed[match] = item;
        },
      );

      expect(p.carrying, isEmpty, reason: 'she is not still holding them');
      expect(handed.keys, ['Bob Vance']);
      expect(
        handed['Bob Vance']!.state,
        'muddy',
        reason: 'the item travels as it was — a rain-soaked coat arrives '
            'rain-soaked, or the record quietly launders things',
      );
      expect(receipts.single, contains('gave car keys to Bob'));
    });

    test('an UNRESOLVABLE recipient still empties the giver', () {
      final p = alice();
      final handed = <String, PocketItem>{};

      applyPocketOps(
        p,
        [
          const PocketOpReport(
            kind: PocketOpKind.give,
            item: 'car keys',
            to: 'the barkeep',
          ),
        ],
        onTransfer: (to, item) {
          final match = resolveRecipient(to, roster);
          if (match != null) handed[match] = item;
        },
      );

      expect(
        p.carrying,
        isEmpty,
        reason: 'she handed them over; that much is true whether or not the '
            'app can work out who took them',
      );
      expect(
        handed,
        isEmpty,
        reason: 'and nobody on the roster receives an item they were never '
            'named for',
      );
    });

    test('a worn item can be handed over too', () {
      final p = alice();
      final handed = <String, PocketItem>{};

      applyPocketOps(
        p,
        [
          const PocketOpReport(
            kind: PocketOpKind.give,
            item: 'sundress',
            to: 'Alice',
          ),
        ],
        onTransfer: (to, item) {
          final m = resolveRecipient(to, roster);
          if (m != null) handed[m] = item;
        },
      );

      expect(p.worn, isEmpty);
      expect(handed['Alice']?.name, 'sundress');
    });

    test('drop never transfers, even with a name attached', () {
      final p = alice();
      var fired = false;

      applyPocketOps(
        p,
        [const PocketOpReport(kind: PocketOpKind.drop, item: 'car keys', to: 'Bob')],
        onTransfer: (_, _) => fired = true,
      );

      expect(p.carrying, isEmpty);
      expect(
        fired,
        isFalse,
        reason: 'dropping a thing in front of someone is not handing it to them',
      );
    });

    test('giving something she does not have transfers nothing', () {
      final p = alice();
      var fired = false;

      applyPocketOps(
        p,
        [const PocketOpReport(kind: PocketOpKind.give, item: 'a horse', to: 'Alice')],
        onTransfer: (_, _) => fired = true,
      );

      expect(
        fired,
        isFalse,
        reason: 'the model imagining a hand-off must not conjure an item into '
            "the recipient's pocket",
      );
    });
  });

  group('the model is only asked for a name it can actually use', () {
    test('with a roster, it is told the exact spellings', () {
      final p = PocketsEval.buildPrompt(
        charName: 'Alice',
        current: Pockets(),
        reply: 'she handed him the keys',
        recentExchange: '',
        toolsMode: false,
        others: const ['Bob Vance', 'Samantha'],
      );

      expect(p, contains('Bob Vance, Samantha'));
      expect(
        p,
        contains('leave "to" empty rather than guessing'),
        reason: 'without this the model picks the nearest name on the list for '
            'a hand-off to the user or a passer-by',
      );
    });

    test('without one, it is never invited to name anybody', () {
      final p = PocketsEval.buildPrompt(
        charName: 'Alice',
        current: Pockets(),
        reply: 'she handed him the keys',
        recentExchange: '',
        toolsMode: false,
      );

      expect(
        p,
        isNot(contains('Put their name in "to"')),
        reason: 'a 1:1 chat, or transfers switched off — a "to" nobody can '
            'resolve is a "to" that does nothing, so asking for it is waste',
      );
    });
  });
}
