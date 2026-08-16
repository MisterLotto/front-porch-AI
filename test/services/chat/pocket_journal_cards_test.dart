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

// The item-memory feed, pure layer (2026-08-11 maintainer design): the
// applier's event emission (canonical names, applied-changes-only), the
// editorial mapper (which events are diary-worthy), and the keyword re-warm
// matcher. Deterministic end to end — the whole point is that NO model
// writes these cards, so nothing here mocks an LLM.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/chat/journal_physics.dart';
import 'package:front_porch_ai/services/chat/pocket_journal_cards.dart';
import 'package:front_porch_ai/services/chat/pockets.dart';

PocketOpReport op(
  PocketOpKind kind,
  String item, {
  String to = '',
  String where = '',
}) => PocketOpReport(kind: kind, item: item, to: to, where: where);

void main() {
  group('the applier emits events with canonical names', () {
    test('an applied setdown carries the RECORD\'s spelling, not the model\'s',
        () {
      final p = Pockets(carrying: [const PocketItem('canvas bag')]);
      final events = <PocketEvent>[];
      applyPocketOps(
        p,
        [op(PocketOpKind.setdown, 'the bag', where: 'by the door')],
        events: events,
      );
      expect(events.single.kind, PocketOpKind.setdown);
      expect(
        events.single.item,
        'canvas bag',
        reason: 'cards must name what the record holds, not what was typed',
      );
      expect(events.single.where, 'by the door');
    });

    test('a no-op emits nothing', () {
      final events = <PocketEvent>[];
      applyPocketOps(
        Pockets(),
        [op(PocketOpKind.setdown, 'a lantern'), op(PocketOpKind.drop, 'keys')],
        events: events,
      );
      expect(events, isEmpty);
    });

    test('a bulk undress marks every event bulk', () {
      final p = Pockets(
        worn: [const PocketItem('sundress')],
        carrying: [const PocketItem('phone')],
      );
      final events = <PocketEvent>[];
      applyPocketOps(p, [op(PocketOpKind.remove, 'her clothes')],
          events: events);
      expect(events, hasLength(2));
      expect(events.every((e) => e.bulk), isTrue);
      expect(events.first.clothing, isTrue, reason: 'the sundress');
      expect(events.last.clothing, isFalse, reason: 'the phone');
    });
  });

  group('the editorial desk (itemCardsFrom)', () {
    test('setdown, give, and drop each earn a diary line', () {
      final drafts = itemCardsFrom(const [
        PocketEvent(
          kind: PocketOpKind.setdown,
          item: 'car keys',
          where: 'on the hallway table',
        ),
        PocketEvent(kind: PocketOpKind.give, item: 'letter', to: 'Sam'),
        PocketEvent(kind: PocketOpKind.drop, item: 'candy wrapper'),
      ]);
      expect(drafts.map((d) => d.content), [
        'I set my car keys down — on the hallway table.',
        'I gave my letter to Sam.',
        'I parted with my candy wrapper.',
      ]);
      expect(drafts.map((d) => d.item), ['car keys', 'letter', 'candy wrapper']);
    });

    test('a give with no resolvable recipient still reads honestly', () {
      final drafts = itemCardsFrom(const [
        PocketEvent(kind: PocketOpKind.give, item: 'coin'),
      ]);
      expect(drafts.single.content, 'I handed my coin over.');
    });

    test('undressing alone is SILENT — bedtime is not diary material', () {
      expect(
        itemCardsFrom(const [
          PocketEvent(
            kind: PocketOpKind.remove,
            item: 'sundress',
            clothing: true,
            bulk: true,
          ),
          PocketEvent(kind: PocketOpKind.remove, item: 'boots', clothing: true),
        ]),
        isEmpty,
      );
    });

    test('dressing alone is silent too', () {
      expect(
        itemCardsFrom(const [
          PocketEvent(kind: PocketOpKind.wear, item: 'jeans', clothing: true),
        ]),
        isEmpty,
      );
    });

    test('a change of clothes earns ONE combined card', () {
      final drafts = itemCardsFrom(const [
        PocketEvent(
          kind: PocketOpKind.remove,
          item: 'white blouse',
          clothing: true,
        ),
        PocketEvent(
          kind: PocketOpKind.wear,
          item: 'green flannel shirt',
          clothing: true,
        ),
      ]);
      expect(
        drafts.single.content,
        'I changed into green flannel shirt (out of white blouse).',
      );
      expect(drafts.single.item, 'green flannel shirt');
    });
  });

  group('the keyword re-warm matcher', () {
    JournalMemoryData card({String? kind, String? item, String category = 'item'})
        => JournalMemoryData(
          id: 'x',
          sessionId: 's1',
          characterId: 'mara',
          content: 'I set my car keys down — on the hallway table.',
          category: category,
          heat: 0.1,
          accessCount: 0,
          pinned: false,
          dimensions: 0,
          metadata: kind == null
              ? null
              : '{"kind":"$kind"${item == null ? '' : ',"item":"$item"'}}',
          createdAt: DateTime(2026),
          lastAccessedAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('naming the item resurfaces its card — no embeddings anywhere', () {
      final tokens = itemNameTokens('Where did I leave my keys?');
      expect(
        JournalPhysics.itemCardMentioned(
          card(kind: 'item', item: 'car keys'),
          tokens,
        ),
        isTrue,
        reason: '"keys" intersects {car, keys} — the no-RAG floor',
      );
    });

    test('emotional cards never ride the keyword path', () {
      final tokens = itemNameTokens('remember the keys?');
      expect(
        JournalPhysics.itemCardMentioned(card(kind: null), tokens),
        isFalse,
        reason: 'feelings have no trigger words — that is what cosine is for',
      );
    });

    test('an unrelated turn matches nothing', () {
      expect(
        JournalPhysics.itemCardMentioned(
          card(kind: 'item', item: 'car keys'),
          itemNameTokens('the porch light hums in the dusk'),
        ),
        isFalse,
      );
    });

    test('filler and short noise never count as a mention', () {
      // "my", "the", "of" are filler; "it" is under the length floor — a
      // greedy tokenizer here would make every turn mention everything.
      expect(itemNameTokens('my the of it an'), isEmpty);
    });
  });
}
