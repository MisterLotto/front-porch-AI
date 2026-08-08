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

// The authoring half of Pockets & Wardrobe: chip text <-> the card's
// `frontPorchExtensions.inventory` map.
//
// Everything else about this feature already shipped — the eval, the injection,
// the sidebar row, the receipts, the settings switch. The only way to give a
// character something to START a chat with was to hand-edit the card JSON, so
// the release note's "characters you download can arrive already holding
// things, if their author set that up" described something no author could
// actually do.
//
// THE DESIGN DECISION UNDER TEST. Items carry a free-text condition
// ("rain-soaked", "half-eaten") but a chip editor holds plain strings. Rather
// than grow a second field per item, the chip text IS the item as it reads —
// `sundress (rain-soaked)` — which is already the string the sidebar, the
// receipts and the prompt all show. `PocketItem.parseDisplay` is the inverse.
//
// That split is not information-preserving in the naive sense and is not meant
// to be: "pepper spray (small)" re-splits as name + state. What it preserves is
// the DISPLAY STRING, and display is what gets injected and shown — so the
// re-split is invisible from every direction a user or a model can look. The
// first group below is that claim, stated as a property.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart'
    show PocketItem, Pockets, kMaxWorn;

void main() {
  group('display round-trips exactly — the property the design rests on', () {
    // If any of these ever fails, the editor is silently rewriting what the
    // author typed, which is the one thing it must never do.
    const cases = [
      'car keys',
      'sundress (rain-soaked)',
      'iron sword (notched, needs sharpening)',
      'pepper spray (small)', // brackets that are arguably part of the name
      'a candy bar (half-eaten)',
      '(nothing)', // no name half
      'keys ()', // no state half
      'a (b) c', // brackets, but not trailing
    ];

    for (final text in cases) {
      test('"$text"', () {
        expect(
          PocketItem.parseDisplay(text).display,
          text,
          reason: 'the author typed this and must get this back',
        );
      });
    }
  });

  group('the split itself', () {
    test('a trailing bracket becomes the condition', () {
      final i = PocketItem.parseDisplay('sundress (rain-soaked)');
      expect(i.name, 'sundress');
      expect(i.state, 'rain-soaked');
    });

    test('no brackets means no condition', () {
      final i = PocketItem.parseDisplay('car keys');
      expect(i.name, 'car keys');
      expect(i.state, isEmpty);
    });

    test('an empty half on either side is part of the name', () {
      // "(nothing)" has no name; "keys ()" has no condition. Splitting either
      // would produce an item that renders differently from what was typed.
      expect(PocketItem.parseDisplay('(nothing)').name, '(nothing)');
      expect(PocketItem.parseDisplay('(nothing)').state, isEmpty);
      expect(PocketItem.parseDisplay('keys ()').name, 'keys ()');
      expect(PocketItem.parseDisplay('keys ()').state, isEmpty);
    });

    test('only the LAST bracket group is considered', () {
      final i = PocketItem.parseDisplay('flask (dented) (empty)');
      expect(i.name, 'flask (dented)');
      expect(i.state, 'empty');
      expect(i.display, 'flask (dented) (empty)');
    });

    test('whitespace is collapsed, as everywhere else items are cleaned', () {
      // Not cosmetic: these strings land inside a prompt, so a newline would
      // let an item name open what looks like a new section.
      expect(PocketItem.parseDisplay('  car   keys \n').name, 'car keys');
    });
  });

  group('cardJsonFrom is the ONE normalization for all three editors', () {
    test('builds the card map both editors and the runtime read', () {
      final json = Pockets.cardJsonFrom(
        worn: ['flour-dusted apron (well-worn)'],
        carrying: ['shop keys'],
      );

      final back = Pockets.fromJson(json);
      expect(back.worn.single.name, 'flour-dusted apron');
      expect(back.worn.single.state, 'well-worn');
      expect(back.carrying.single.name, 'shop keys');
    });

    test('blank and whitespace-only chips are dropped', () {
      final json = Pockets.cardJsonFrom(
        worn: ['', '   ', 'apron'],
        carrying: const [],
      );
      expect((json['worn'] as List), hasLength(1));
    });

    test('over-long text is capped rather than rejected', () {
      final json = Pockets.cardJsonFrom(
        worn: ['${'x' * 200} (${'y' * 200})'],
        carrying: const [],
      );
      final i = Pockets.fromJson(json).worn.single;
      expect(i.name.length, lessThanOrEqualTo(60));
      expect(i.state.length, lessThanOrEqualTo(60));
    });

    test('more items than the cap keeps the cap, not the extras', () {
      final json = Pockets.cardJsonFrom(
        worn: [for (var i = 0; i < kMaxWorn + 5; i++) 'thing $i'],
        carrying: const [],
      );
      expect((json['worn'] as List), hasLength(kMaxWorn));
    });

    test('a full editor round trip is stable', () {
      // Type it, save it, reopen the editor, save again — the second save must
      // produce the same card as the first or the field creeps on every edit.
      const worn = ['sundress (rain-soaked)'];
      const carrying = ['car keys', 'a candy bar (half-eaten)'];

      final first = Pockets.cardJsonFrom(worn: worn, carrying: carrying);
      final reopened = Pockets.fromJson(first);
      final second = Pockets.cardJsonFrom(
        worn: reopened.wornDisplay,
        carrying: reopened.carryingDisplay,
      );

      expect(second, first);
      expect(reopened.wornDisplay, worn);
      expect(reopened.carryingDisplay, carrying);
    });
  });

  group('an empty wardrobe must stay ABSENT from the card', () {
    // Load-bearing beyond tidiness. CharacterCard.toJson emits the key only
    // when the map is non-empty, and two PROTECTED goldens
    // (test/golden/_goldens/card/v25_full.golden.json and
    // creator/saved_card.golden.json) pin serialized cards that contain no
    // `inventory` key. If an editor with empty chip lists started writing
    // `{"worn": [], "carrying": []}`, every card written by every surface would
    // gain a key, both goldens would change, and test-integrity.yml blocks a PR
    // that modifies a golden without a maintainer's label.
    test('no chips at all produces an empty map', () {
      expect(Pockets.cardJsonFrom(worn: const [], carrying: const []), isEmpty);
    });

    test('only blank chips also produces an empty map', () {
      expect(
        Pockets.cardJsonFrom(worn: const ['', '  '], carrying: const ['']),
        isEmpty,
      );
    });

    test('one real item is enough to produce a map', () {
      expect(
        Pockets.cardJsonFrom(worn: const ['apron'], carrying: const []),
        isNotEmpty,
      );
    });
  });

  group('seeding the editor from a card', () {
    test('reads the rich shape an app-authored card stores', () {
      final p = Pockets.fromJson({
        'worn': [
          {'name': 'sundress', 'state': 'rain-soaked'},
        ],
        'carrying': [
          {'name': 'car keys'},
        ],
      });
      expect(p.wornDisplay, ['sundress (rain-soaked)']);
      expect(p.carryingDisplay, ['car keys']);
    });

    test('reads the plain-string shape a hand-written card may use', () {
      final p = Pockets.fromJson({
        'worn': ['sundress'],
        'carrying': ['car keys'],
      });
      expect(p.wornDisplay, ['sundress']);
    });

    test('a card with no inventory seeds empty chip lists', () {
      final p = Pockets.fromJson(null);
      expect(p.wornDisplay, isEmpty);
      expect(p.carryingDisplay, isEmpty);
    });

    test('a downloaded card with junk in the field does not break the editor', () {
      for (final junk in <Object?>['apron', 7, <String>[], null]) {
        expect(() => Pockets.fromJson(junk).wornDisplay, returnsNormally);
      }
    });
  });
}
