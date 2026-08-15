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

// NO MEMORY EVER CROSSES CHATS — INCLUDING THE RECAP.
//
// JournalReview.apply() checked the session ONCE, before its awaits, then
// wrote the recap and the pass cursor. The card writes it makes in between
// are session-addressed and safe, but setRecap/setCursor are ChatService's
// LIVE scalars and onSaveChat stamps them onto whichever chat is open when
// the writes finish. Applying a review with several cards to vector (one
// embedder round trip per card) and then switching chats therefore wrote
// chat A's "Where we are" into chat B's session row, and A's cursor target
// with it — another chat's story injected into every prompt.
//
// Red-proved: removing the post-await session re-check in apply() makes the
// first test fail with B's recap set to 'Chat A: we made up on the porch.'.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  late AppDatabase db;
  late JournalStore store;
  late String session;
  final recaps = <String>[];
  final cursors = <int>[];
  var saves = 0;

  setUp(() async {
    db = AppDatabase.forTesting(sameIsolate: true);
    session = 's1';
    recaps.clear();
    cursors.clear();
    saves = 0;
    await db.insertSession(SessionsCompanion.insert(id: 's1'));
    await db.insertSession(SessionsCompanion.insert(id: 's2'));
  });

  tearDown(() async {
    await db.close();
  });

  JournalReview build({void Function()? duringEmbed}) {
    store = JournalStore(
      getDb: () => db,
      embedText: (t) async {
        duringEmbed?.call();
        return List<double>.filled(4, 0.1);
      },
    );
    return JournalReview(
      store: store,
      getSessionId: () => session,
      setRecap: recaps.add,
      setCursor: cursors.add,
      onSaveChat: () async => saves++,
      onNotify: () {},
      getMaxCards: () => 200,
    );
  }

  JournalReviewBatch batch() => JournalReviewBatch(
    sessionId: 's1',
    cursorTarget: 12,
    owners: [
      JournalOwnerProposals(
        ownerId: 'mira',
        ownerName: 'Mira',
        ops: [
          JournalProposedOp(
            action: JournalOpAction.add,
            text: 'We sat out past midnight.',
          ),
        ],
      ),
    ],
    recap: 'Chat A: we made up on the porch.',
  );

  test('a chat switch mid-apply leaves the other chat\'s recap alone', () async {
    // The switch happens while the accepted card is being vectored — exactly
    // the multi-second window the embedder opens.
    final review = build(duringEmbed: () => session = 's2');
    review.park(batch());
    await review.apply();

    expect(
      recaps,
      isEmpty,
      reason: 'chat A\'s recap must never be written into chat B',
    );
    expect(
      cursors,
      isEmpty,
      reason: 'and A\'s pass cursor must not become B\'s',
    );
    expect(saves, 0);
    expect(review.pending, isNull);
    // The card itself is session-addressed, so it still landed in chat A.
    expect((await store.cardsFor('s1', 'mira')).single.content,
        'We sat out past midnight.');
    expect(await store.cardsFor('s2', 'mira'), isEmpty);
  });

  test('the ordinary apply still writes the recap and moves the cursor', () async {
    final review = build();
    review.park(batch());
    await review.apply();

    expect(recaps, ['Chat A: we made up on the porch.']);
    expect(cursors, [12]);
    expect(saves, 1);
    expect(review.pending, isNull);
  });
}
