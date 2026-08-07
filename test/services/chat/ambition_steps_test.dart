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

// The READER for ambition-driven objectives (schema v46).
//
// Since v46 the proposal eval is shown the character's ambitions, picks the
// next step up one of them, and reports which — stored in
// `objectives.served_ambition`. ambition_steering_test.dart guards the numbering
// contract on the way OUT and back IN. This file guards the last hop: turning
// those stored tags into "what is this character working on right now", which
// is what the sidebar Ambitions row, the group member card and the web facade
// all display.
//
// The failure mode worth guarding is the same one the steering tests worry
// about, one layer down and just as silent: nothing throws when the merge picks
// the wrong quest. The user simply reads "↳ deliver the letter" under the wrong
// mountain, or sees a finished quest presented as still in progress. So the
// cases below pin exactly which objective wins and which are ignored.
//
// AmbitionService.activeStepsFrom is pure and static, so this needs no DB, no
// LLM and no ChatService — which is the point of having put the merge there
// rather than in either widget.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/database/database.dart' show Objective;
import 'package:front_porch_ai/services/chat/ambition_service.dart';

/// A minimal objective row. Only the four fields the merge reads matter;
/// the rest carry values the merge must not consult.
Objective obj(
  String objective, {
  String? served,
  bool active = true,
  bool isPrimary = false,
}) => Objective(
  id: 'obj-$objective',
  characterId: 'char-1',
  chatId: 'chat-1',
  objective: objective,
  tasks: '[]',
  isPrimary: isPrimary,
  active: active,
  checkFrequency: 5,
  injectionDepth: 0,
  createdAt: DateTime(2026, 8, 7),
  servedAmbition: served,
);

void main() {
  group('AmbitionService.activeStepsFrom', () {
    test('an ambition with an open quest gets that quest as its step', () {
      final steps = AmbitionService.activeStepsFrom([
        obj('rent the empty shopfront', served: 'open her own bakery'),
      ]);
      expect(steps, {'open her own bakery': 'rent the empty shopfront'});
    });

    test('a quest serving no ambition contributes nothing', () {
      // Situational quests are legal by design — "life happens; not every
      // quest serves the arc" — so they must not attach themselves to a
      // mountain they were never tagged with.
      final steps = AmbitionService.activeStepsFrom([
        obj('find the missing cat'),
        obj('help at the fair', served: ''),
        obj('walk the dog', served: '   '),
      ]);
      expect(steps, isEmpty);
    });

    test('a completed or cleared quest is not an active step', () {
      // The tag survives completion — that is how the progress judge credits
      // the right ambition afterwards — so filtering on `active` is the only
      // thing stopping a finished quest from being shown as current forever.
      final steps = AmbitionService.activeStepsFrom([
        obj('buy the flour', served: 'open her own bakery', active: false),
      ]);
      expect(steps, isEmpty);
    });

    test('the primary quest wins when two serve the same ambition', () {
      // Order-independent: only one objective can be primary, and it is the
      // one the character is actually working.
      const mountain = 'open her own bakery';
      final secondaryFirst = AmbitionService.activeStepsFrom([
        obj('price the ovens', served: mountain),
        obj('sign the lease', served: mountain, isPrimary: true),
      ]);
      final primaryFirst = AmbitionService.activeStepsFrom([
        obj('sign the lease', served: mountain, isPrimary: true),
        obj('price the ovens', served: mountain),
      ]);
      expect(secondaryFirst, {mountain: 'sign the lease'});
      expect(primaryFirst, {mountain: 'sign the lease'});
    });

    test('two side quests on one ambition keep the first, not the last', () {
      const mountain = 'open her own bakery';
      final steps = AmbitionService.activeStepsFrom([
        obj('price the ovens', served: mountain),
        obj('taste-test the sourdough', served: mountain),
      ]);
      expect(steps, {mountain: 'price the ovens'});
    });

    test('separate ambitions keep separate steps', () {
      final steps = AmbitionService.activeStepsFrom([
        obj('sign the lease', served: 'open her own bakery'),
        obj('write to her sister', served: 'mend things at home'),
      ]);
      expect(steps, {
        'open her own bakery': 'sign the lease',
        'mend things at home': 'write to her sister',
      });
    });

    test('a tag is matched on its trimmed text', () {
      // resolveServedAmbition returns the roster string verbatim, but a local
      // model round-trip can leave whitespace on it. The display key must
      // still line up with the ambition text the card carries.
      final steps = AmbitionService.activeStepsFrom([
        obj('sign the lease', served: '  open her own bakery  '),
      ]);
      expect(steps, {'open her own bakery': 'sign the lease'});
    });

    test('no objectives at all is an empty map, not a throw', () {
      expect(AmbitionService.activeStepsFrom(const []), isEmpty);
    });
  });
}
