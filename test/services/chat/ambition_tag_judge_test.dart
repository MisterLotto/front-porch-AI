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

// The other end of `objectives.served_ambition` (v46): when a quest completes,
// the tag its proposal left behind answers "which ambition?" so the judge only
// has to rule on "how big a step?".
//
// This is the half that makes the column earn its keep. Without it the tag is
// written and never read, and the completion judge keeps re-guessing which
// mountain a finished quest belonged to — from the finished text alone, having
// lost the context that produced the quest in the first place. That is not a
// cheaper question, it is a worse one.
//
// The interesting cases are all about NOT trusting the tag blindly: the author
// can edit the ambitions list at any time, so a tag can name a goal that has
// since been achieved or deleted. Both must fall back to the original
// question, which is also the path every user-typed and pre-v46 objective
// takes.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/chat/ambition_service.dart';
import 'package:front_porch_ai/services/chat/growth_store.dart';
import 'package:front_porch_ai/services/chat/journal_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late JournalStore journal;
  late GrowthStore growth;
  const sid = 's1';
  const cid = 'c1';
  const bakery = 'open my own bakery';
  const sister = 'reconcile with my sister';

  setUp(() {
    db = AppDatabase.forTesting();
    journal = JournalStore(getDb: () => db);
    growth = GrowthStore(getDb: () => db);
  });
  tearDown(() async => db.close());

  /// Captures the prompt the judge was actually handed, which is the whole
  /// point: the tagged and untagged paths must ASK different questions.
  late List<String> prompts;

  AmbitionService svc(String? verdict) {
    prompts = [];
    return AmbitionService(
      journalStore: journal,
      growthStore: growth,
      fireEval: (p) async {
        prompts.add(p);
        return verdict;
      },
      getMaxCards: () => 30,
    );
  }

  Future<Map<String, dynamic>> ambitionMeta({String? named}) async {
    for (final card in await journal.cardsFor(sid, cid)) {
      final meta = jsonDecode(card.metadata ?? '{}') as Map<String, dynamic>;
      if (meta['kind'] != 'ambition') continue;
      if (named == null || meta['ambition'] == named) return meta;
    }
    return const {};
  }

  group('a tagged quest skips the "which one?" question', () {
    test('the judge is asked only about the tagged ambition', () async {
      await svc('1 solid').onQuestAchieved(
        sessionId: sid,
        characterId: cid,
        characterName: 'Alice',
        objectiveText: 'saved enough for the oven',
        ambitions: const [bakery, sister],
        servedAmbition: bakery,
      );

      expect(prompts, hasLength(1));
      expect(
        prompts.single,
        contains('That quest was taken up in service of this ambition'),
        reason: 'the tag already answered which; re-asking throws away the '
            'context that produced the quest',
      );
      expect(
        prompts.single,
        isNot(contains(sister)),
        reason: 'offering the other ambition invites the judge to reassign the '
            'quest to a goal it was never taken up for',
      );
      expect(await ambitionMeta(named: bakery), containsPair('progress', 20));
    });

    test('a tagged quest can still be judged to have advanced nothing', () async {
      await svc('NONE').onQuestAchieved(
        sessionId: sid,
        characterId: cid,
        characterName: 'Alice',
        objectiveText: 'bought a nice apron',
        ambitions: const [bakery],
        servedAmbition: bakery,
      );

      expect(
        await ambitionMeta(),
        isEmpty,
        reason: 'being proposed FOR an ambition is not the same as having '
            'advanced it — the judge keeps its veto',
      );
    });

    test('the tag never advances a different ambition than it names', () async {
      // "1" in the tagged prompt is the tagged ambition, whatever its position
      // in the character's full list. sister is second on the card.
      await svc('1 major').onQuestAchieved(
        sessionId: sid,
        characterId: cid,
        characterName: 'Alice',
        objectiveText: 'wrote her the letter',
        ambitions: const [bakery, sister],
        servedAmbition: sister,
      );

      expect(await ambitionMeta(named: sister), containsPair('progress', 35));
      expect(
        await ambitionMeta(named: bakery),
        isEmpty,
        reason: 'a roster of one is numbered 1; resolving that against the '
            'full list would have ticked the bakery instead',
      );
    });
  });

  group('a tag that no longer makes sense falls back to the old question', () {
    test('an untagged quest asks which, as it always did', () async {
      await svc('2 solid').onQuestAchieved(
        sessionId: sid,
        characterId: cid,
        characterName: 'Alice',
        objectiveText: 'a quest from before the column existed',
        ambitions: const [bakery, sister],
      );

      expect(
        prompts.single,
        contains('Did completing that meaningfully advance one of these'),
      );
      expect(await ambitionMeta(named: sister), containsPair('progress', 20));
    });

    test('a tag naming an ambition the author has since deleted', () async {
      await svc('1 solid').onQuestAchieved(
        sessionId: sid,
        characterId: cid,
        characterName: 'Alice',
        objectiveText: 'did the thing',
        ambitions: const [bakery],
        servedAmbition: 'a goal that is no longer on the card',
      );

      expect(
        prompts.single,
        contains('Did completing that meaningfully advance one of these'),
        reason: 'a stale tag must not narrow the judge to a goal that is gone',
      );
      expect(await ambitionMeta(named: bakery), containsPair('progress', 20));
    });

    test('a tag naming an ambition that is already achieved', () async {
      // Drive bakery to 100 first, then complete another quest tagged to it.
      final s = svc('1 major');
      for (var i = 0; i < 3; i++) {
        await s.onQuestAchieved(
          sessionId: sid,
          characterId: cid,
          characterName: 'Alice',
          objectiveText: 'step $i',
          ambitions: const [bakery],
          servedAmbition: bakery,
        );
      }
      expect((await ambitionMeta(named: bakery))['progress'], 100);

      await svc('1 solid').onQuestAchieved(
        sessionId: sid,
        characterId: cid,
        characterName: 'Alice',
        objectiveText: 'one more oven',
        ambitions: const [bakery, sister],
        servedAmbition: bakery,
      );

      expect(
        prompts.single,
        isNot(contains('That quest was taken up in service of this ambition')),
        reason: 'an achieved ambition is off the open roster; pointing the '
            'judge at it would tick a goal already finished',
      );
      expect(
        (await ambitionMeta(named: bakery))['progress'],
        100,
        reason: 'and it must stay at 100, not climb past it',
      );
    });
  });
}
