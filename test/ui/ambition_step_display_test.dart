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

// Does the ambition↔objective link actually REACH THE SCREEN?
//
// ambition_steps_test.dart proves the merge picks the right quest, but a
// correct map that no widget renders is worth nothing to the user — and that
// is not hypothetical here: served_ambition has been computed, stored and read
// by the completion judge since schema v46 while being displayed absolutely
// nowhere. A pure-function guard would have stayed green through all of that.
//
// So these two pin the pixels-side contract instead: given a step, the row
// shows it; given a tag, the chip shows it; given neither, neither appears
// (a situational quest must not sprout an empty chip, and an ambition nobody
// is working on must not grow a dangling arrow).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/character_state/ambitions_row.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/story_tools/objective_task_row.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_card_sections.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 320, child: child)),
);

void main() {
  group('AmbitionsRow — the active step (v46)', () {
    testWidgets('shows the open quest under the ambition it climbs', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AmbitionsRow(
            ambitions: [(text: 'open her own bakery', progress: 40)],
            steps: {'open her own bakery': 'sign the lease'},
          ),
        ),
      );

      expect(find.text('open her own bakery'), findsOneWidget);
      expect(find.text('↳ sign the lease'), findsOneWidget);
    });

    testWidgets('an ambition with no open quest shows no step line', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AmbitionsRow(
            ambitions: [(text: 'open her own bakery', progress: 40)],
          ),
        ),
      );

      expect(find.text('open her own bakery'), findsOneWidget);
      expect(find.textContaining('↳'), findsNothing);
    });

    testWidgets('only the ambition being worked on gets a step', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AmbitionsRow(
            ambitions: [
              (text: 'open her own bakery', progress: 40),
              (text: 'mend things at home', progress: 10),
            ],
            steps: {'open her own bakery': 'sign the lease'},
          ),
        ),
      );

      expect(find.text('↳ sign the lease'), findsOneWidget);
      expect(find.textContaining('↳'), findsOneWidget);
    });
  });

  group('AmbitionServedChip — which mountain a quest climbs', () {
    testWidgets('renders the tagged ambition', (tester) async {
      await tester.pumpWidget(
        host(const AmbitionServedChip(servedAmbition: 'open her own bakery')),
      );
      expect(find.text('open her own bakery'), findsOneWidget);
    });

    testWidgets('an untagged quest renders nothing at all', (tester) async {
      // The common case, and the one that would look like clutter if it
      // rendered an empty pill: situational quests are legal by design, and
      // every objective created before v46 has a NULL tag.
      await tester.pumpWidget(
        host(const AmbitionServedChip(servedAmbition: null)),
      );
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a blank tag is treated as untagged, not as an empty chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AmbitionServedChip(servedAmbition: '   ')),
      );
      expect(find.byType(Text), findsNothing);
    });
  });

  // The Stoop section reads a card uploaded by a STRANGER, so its parse is the
  // one place here that faces hostile input. Flagged in review by Grok: the
  // first draft used `re['ambitions'] as List?`, which throws on a present-but-
  // wrong-typed value and would take the whole card-detail panel down rather
  // than just omitting one section.
  group('stoopAmbitionsSection — untrusted card JSON', () {
    testWidgets('renders the authored ambitions', (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (c) => stoopAmbitionsSection(c, const {
              'ambitions': ['open her own bakery', 'mend things at home'],
            }),
          ),
        ),
      );
      // Counted in the header so the reader knows what is inside before
      // opening it — the panel is an index of default-collapsed sections.
      expect(find.textContaining('Ambitions (2)'), findsOneWidget);

      await tester.tap(find.textContaining('Ambitions (2)'));
      await tester.pumpAndSettle();
      expect(find.text('open her own bakery'), findsOneWidget);
      expect(find.text('mend things at home'), findsOneWidget);
    });

    testWidgets('shown even when the realism engine is off on the card', (
      tester,
    ) async {
      // Ambitions are identity — they travel with the card and steer quests
      // whenever Objectives is on, independent of the Realism Engine. Copying
      // the sibling sections' `enabled` guard would hide real authored content.
      await tester.pumpWidget(
        host(
          Builder(
            builder: (c) => stoopAmbitionsSection(c, const {
              'enabled': false,
              'ambitions': ['open her own bakery'],
            }),
          ),
        ),
      );
      expect(find.textContaining('Ambitions (1)'), findsOneWidget);

      await tester.tap(find.textContaining('Ambitions (1)'));
      await tester.pumpAndSettle();
      expect(find.text('open her own bakery'), findsOneWidget);
    });

    testWidgets('a malformed ambitions value renders nothing, never throws', (
      tester,
    ) async {
      for (final junk in <Object>[
        'open her own bakery', // a bare string, not a list
        42,
        {'a': 1}, // an object
      ]) {
        await tester.pumpWidget(
          host(
            Builder(
              builder: (c) => stoopAmbitionsSection(c, {'ambitions': junk}),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('absent, empty and blank-only all render nothing', (
      tester,
    ) async {
      for (final re in <Map<String, dynamic>>[
        const {},
        const {'ambitions': []},
        const {
          'ambitions': ['', '   '],
        },
        const {
          'ambitions': [1, null],
        },
      ]) {
        await tester.pumpWidget(
          host(Builder(builder: (c) => stoopAmbitionsSection(c, re))),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Ambitions'), findsNothing);
      }
    });
  });
}
