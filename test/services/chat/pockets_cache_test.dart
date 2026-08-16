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

// The group pockets cache (hostile review 2026-08-11, perf): the getter used
// to run Pockets.fromJson on EVERY read, and the sidebar reads it from build
// per streamed token per member card — JSON parsing as per-frame work.
// What this pins is not speed but the cache's CONTRACT: repeated reads hand
// back the same live object (that is the entire saving), the setter replaces
// it, and serialization still reflects what was set.
//
// Guard proven to fail before passing: with the getter's cache assignment
// removed, the identical-instance test goes red.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart'
    show GroupMemberRealism, PocketItem, Pockets;

void main() {
  test('repeated reads return the SAME live object — parse once, not per '
      'frame', () {
    final m = GroupMemberRealism.fromJson({
      'pockets': {
        'worn': ['sundress'],
        'carrying': ['car keys'],
      },
    });
    final first = m.pockets;
    expect(first, isNotNull);
    expect(
      identical(first, m.pockets),
      isTrue,
      reason: 'a fresh parse per read is the per-frame work this cache kills',
    );
    expect(first!.worn.single.name, 'sundress');
  });

  test('the setter replaces the cache and serialization follows', () {
    final m = GroupMemberRealism();
    m.pockets = Pockets(carrying: [const PocketItem('lantern')]);
    expect(identical(m.pockets, m.pockets), isTrue);
    expect(m.pockets!.carrying.single.name, 'lantern');

    m.pockets = Pockets(worn: [const PocketItem('coat')]);
    expect(m.pockets!.worn.single.name, 'coat');
    expect(m.pockets!.carrying, isEmpty);

    // The stored JSON (what a save writes) matches the last set.
    final roundTrip = GroupMemberRealism.fromJson(m.toJson());
    expect(roundTrip.pockets!.worn.single.name, 'coat');
  });

  test('clearing the record clears the cache too', () {
    final m = GroupMemberRealism();
    m.pockets = Pockets(carrying: [const PocketItem('lantern')]);
    m.pockets = null;
    expect(m.pockets, isNull);
  });
}
