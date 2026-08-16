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

// The Stoop card panel's Pockets & Wardrobe section.
//
// The reason this section needs its own reader — and its own tests — is a shape
// break its two neighbours do not have. Ambitions and Likes & Dislikes are flat
// lists of strings, so `stoopPhrases` reads them. `inventory` is a MAP of two
// lists whose entries may each be a bare string OR a `{name, state}` object.
// Handing that to `stoopPhrases` returns empty for every card ever uploaded,
// and does it SILENTLY: a section that renders nothing is exactly what a card
// with no wardrobe looks like, so the feature would have appeared to work while
// showing nothing, forever.
//
// Like its neighbours, this parses a stranger's upload, so the hostile-input
// cases are the point rather than padding.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/pages/repository/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

  /// Pumps the section and OPENS it. StoopCollapsible starts closed, so the
  /// rows do not exist in the tree until the header is tapped — a test that
  /// skipped this would pass on an empty section and prove nothing.
  Future<void> pump(
    WidgetTester t,
    Map<String, dynamic> re, {
    bool expand = true,
  }) async {
    await t.pumpWidget(host(Builder(builder: (c) => stoopWardrobeSection(c, re))));
    if (expand && t.any(find.byType(StoopCollapsible))) {
      await t.tap(find.byType(StoopCollapsible));
      await t.pumpAndSettle();
    }
  }

  group('what a downloader sees', () {
    testWidgets('renders both lists with a total count', (t) async {
      await pump(t, const {
        'inventory': {
          'worn': ['flour-dusted apron'],
          'carrying': ['shop keys', 'a notebook'],
        },
      });

      expect(find.text('Pockets & Wardrobe (3)'), findsOneWidget);
      expect(find.text('WEARING'), findsOneWidget);
      expect(find.text('CARRYING'), findsOneWidget);
      expect(find.text('flour-dusted apron'), findsOneWidget);
      expect(find.text('shop keys'), findsOneWidget);
    });

    testWidgets('condition is shown, not silently dropped', (t) async {
      // The whole reason a bare stoopPhrases reader would have been wrong: an
      // item's condition lives in an object, and a reader that only understands
      // strings shows "sundress" for something the card says is rain-soaked.
      await pump(t, const {
        'inventory': {
          'worn': [
            {'name': 'sundress', 'state': 'rain-soaked'},
          ],
        },
      });

      expect(find.text('sundress (rain-soaked)'), findsOneWidget);
    });

    testWidgets('a half-empty wardrobe shows only the half it has', (t) async {
      await pump(t, const {
        'inventory': {
          'carrying': ['car keys'],
        },
      });

      expect(find.text('Pockets & Wardrobe (1)'), findsOneWidget);
      expect(find.text('WEARING'), findsNothing);
      expect(find.text('CARRYING'), findsOneWidget);
    });

    testWidgets('the section is ABSENT when the author wrote none', (t) async {
      await pump(t, const {});
      expect(find.byType(StoopCollapsible), findsNothing);
    });

    testWidgets('an empty record is the same as no record', (t) async {
      await pump(t, const {
        'inventory': {'worn': [], 'carrying': []},
      });
      expect(find.byType(StoopCollapsible), findsNothing);
    });
  });

  group('a stranger uploaded this, so nothing here may throw', () {
    testWidgets('junk in the inventory slot omits the section', (t) async {
      for (final junk in <Object>[
        'apron', // a string where the map belongs
        7,
        <String>['apron'], // a LIST — the shape the phrase reader expects
        {'worn': 'apron'}, // right map, wrong inner type
        {'worn': 7},
      ]) {
        await pump(t, {'inventory': junk});
        expect(
          find.byType(StoopCollapsible),
          findsNothing,
          reason: 'junk: $junk must cost this section, never the whole panel',
        );
      }
    });

    testWidgets('malformed entries are dropped, valid ones survive', (t) async {
      await pump(t, const {
        'inventory': {
          'worn': [
            42,
            null,
            {'state': 'torn'}, // a condition with nothing to attach it to
            'apron',
          ],
        },
      });

      expect(find.text('Pockets & Wardrobe (1)'), findsOneWidget);
      expect(find.text('apron'), findsOneWidget);
    });

    testWidgets('a huge list cannot freeze the panel', (t) async {
      // The same concern _maxStoopPhrases exists for on the neighbouring
      // sections. Here the bound comes from Pockets.fromJson's take(8) on the
      // RAW list, which is also the number the app would actually honour — so
      // the Stoop never advertises more than a download would give you.
      await pump(t, {
        'inventory': {
          'worn': [for (var i = 0; i < 5000; i++) 'thing $i'],
        },
      });

      expect(find.text('Pockets & Wardrobe (8)'), findsOneWidget);
    });
  });

  group('long phrases render as text, not as Dart source', () {
    // A pre-existing bug in stoopPhrases, fixed while adding this section: the
    // truncation branch was written '\${s.substring(...)}…' inside a NON-raw
    // string, so the $ was escaped and no interpolation happened. Any phrase
    // over 160 characters rendered on the Stoop panel as the literal text
    // '${s.substring(0, _maxStoopPhraseChars).trimRight()}…'. It survived
    // because every card anyone looked at was under the limit.
    testWidgets('a 200-character ambition truncates to its own text', (t) async {
      final long = 'a' * 200;
      await t.pumpWidget(
        host(Builder(builder: (c) => stoopAmbitionsSection(c, {
          'ambitions': [long],
        }))),
      );
      await t.tap(find.byType(StoopCollapsible));
      await t.pumpAndSettle();

      expect(
        find.textContaining(r'$'),
        findsNothing,
        reason: 'a dollar sign on screen means the escape came back',
      );
      expect(find.textContaining('substring'), findsNothing);
      expect(find.textContaining('aaaa'), findsOneWidget);
    });
  });
}
