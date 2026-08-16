// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards for the 2026-08-08 no-absence rule
// (relationship_injection.dart class doc): the state block must never assert
// what the relationship does or does not CONTAIN, because the Journal is a
// second channel making claims about the same relationship off a different
// source, and any absence asserted here is one the cards can disprove.
//
// The bug these guard was measured, not imagined. An A/B run against Kimi 2.6
// mined 461 sentences where the model said its own prompt contradicted itself;
// 14 named the Journal against this file, e.g. "the notes say 'So far there is
// no particular trust or distrust' but the journal entries show intense trust
// and connection."
//
// Reuse note: the 35-closure RelationshipService/RelationshipInjection
// factories already exist in the sibling suite, and a second copy of them is
// exactly the duplication the project rules forbid. Importing a test library
// does not run its main().

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/journal_injection.dart';

import 'prompt_injection_test.dart'
    show createTestRelSvc, createTestRelationship;

/// Every rung of the bond ladder, by the RelationshipTiers scale.
const _ladderScores = [
  -300, -250, -200, -160, -120, -80, -50, -30, -15, -5, //
  0, 5, 15, 30, 50, 80, 120, 160, 200, 250, 300,
];

String _relFor({
  required int longTermScore,
  required int trustLevel,
  int affectionScore = 0,
}) {
  final svc = createTestRelSvc();
  svc.loadScalars(
    affectionScore: affectionScore,
    longTermScore: longTermScore,
    trustLevel: trustLevel,
  );
  return createTestRelationship(
    relSvc: svc,
    activeChar: CharacterCard(name: 'Alice'),
  ).buildRelationshipInjection();
}

void main() {
  group('the state block asserts no absence the Journal can falsify', () {
    test('neutral tiers: disposition survives, the absence claim is gone', () {
      final rel = _relFor(longTermScore: 0, trustLevel: 0);

      // The load-bearing half — the anti-guardedness disposition (spec §3).
      expect(rel, contains('merits of the moment'));
      expect(rel, contains('neither the best nor the worst'));

      // The falsifiable half — every way this used to claim the relationship
      // holds nothing.
      expect(rel, isNot(contains('no particular trust')));
      expect(rel, isNot(contains('there is no ')));
      expect(rel, isNot(contains('still developing')));
    });

    test('the bond ladder makes no trust claim at any rung', () {
      // Two ladders, two independent scalars. While the bond line said "fully
      // trusts" and "fundamentally distrusts them", a long love that survived
      // a betrayal put "fully trusts" two sentences above the trust
      // fragment's "deeply distrustful" — a flat self-contradiction inside one
      // block, with no Journal needed to produce it.
      for (final score in _ladderScores) {
        final rel = _relFor(
          longTermScore: score,
          trustLevel: 60, // tier 4 → the trust-0 fold is not in play
        );
        expect(
          rel.toLowerCase(),
          isNot(contains('trust')),
          reason: 'bond line leaked a trust claim at longTermScore $score',
        );
      }
    });

    test('the trust ladder does not date the relationship', () {
      final svc = createTestRelSvc();
      svc.loadScalars(
        affectionScore: 0,
        longTermScore: 0,
        trustLevel: 20, // tier 2 → the low-positive rung
      );
      final trust = createTestRelationship(
        relSvc: svc,
        activeChar: CharacterCard(name: 'Alice'),
      ).buildTrustBehaviorInjection();

      expect(trust, contains('benefit of the doubt'));
      expect(trust, contains('never the baseline temperament')); // tail intact
      // "is beginning to trust" is a claim about WHERE the relationship has
      // got to, which a diary of earned closeness contradicts outright.
      expect(trust, isNot(contains('beginning to trust')));
    });
  });

  group('the neutral trust fold cannot contradict the bond line', () {
    test('suppressed under a strong positive bond', () {
      final rel = _relFor(longTermScore: 250, trustLevel: 0);
      expect(rel, contains('soulmate or life partner'));
      expect(rel, isNot(contains('merits of the moment')));
      expect(rel, isNot(contains('neither the best nor the worst')));
    });

    test('suppressed under a hostile bond', () {
      final rel = _relFor(longTermScore: -250, trustLevel: 0);
      expect(rel, contains('deep-seated resentment'));
      expect(rel, isNot(contains('merits of the moment')));
      expect(rel, isNot(contains('neither the best nor the worst')));
    });

    test('still folded in when the bond line says nothing strong', () {
      expect(_relFor(longTermScore: 0, trustLevel: 0),
          contains('merits of the moment'));
      // The mild-soreness rung is a position, not silence — no fold there.
      expect(_relFor(longTermScore: -20, trustLevel: 0),
          isNot(contains('merits of the moment')));
    });
  });

  group('PARITY: 1:1 and group render the same relationship text', () {
    String groupRel({
      required int longTier,
      required int shortTier,
      required int trust,
    }) => createTestRelationship(
      groupRealism: {
        'Alice': {
          'longTermTier': longTier,
          'relationshipTier': shortTier,
          'trust': trust,
        },
      },
      isGroupNonObs: true,
      speakerId: 'Alice',
      groupChars: [CharacterCard(name: 'Alice'), CharacterCard(name: 'Bea')],
    ).buildRelationshipInjection();

    test('neutral: the fold rides both paths', () {
      expect(
        groupRel(longTier: 0, shortTier: 0, trust: 0),
        _relFor(longTermScore: 0, trustLevel: 0),
      );
    });

    test('strong bond + neutral trust: the fold is suppressed on both', () {
      expect(
        groupRel(longTier: 8, shortTier: 0, trust: 0),
        _relFor(longTermScore: 250, trustLevel: 0),
      );
    });
  });

  group('the Journal frame resolves what it overlaps', () {
    late AppDatabase db;
    late JournalStore store;

    setUp(() => db = AppDatabase.forTesting());
    tearDown(() async => db.close());

    Future<String> block() async {
      store = JournalStore(getDb: () => db);
      await store.addCard(
        sessionId: 's1',
        characterId: 'alice',
        content: 'He stayed all night when I was sick. I trust him with my '
            'life.',
        category: 'about_us',
        emotionLabel: 'grateful',
        maxCards: 200,
      );
      final injection = JournalInjection(
        store: store,
        getSessionId: () => 's1',
        getCurrentEmotion: () => '',
        getCurrentStoryDay: () => 1,
        getStoryStartDate: () => DateTime.utc(2026, 6, 30),
      );
      return (await injection.buildJournalBlock(
        characterId: 'alice',
        characterName: 'Alice',
        userName: 'Ben',
      )).text;
    }

    test('names the state notes, not just the recap and the transcript', () {
      // The one collision users actually hit is journal-vs-character-state,
      // and the old clause stopped at "the story recap or the lines above",
      // leaving it with no resolver anywhere in the prompt.
      expect(
        block(),
        completion(contains('where Alice stands with Ben')),
      );
    });

    test('keeps ONE ruling, stated once, in kind terms', () async {
      final text = await block();
      expect(text, contains('the feelings here are the truer guide'));
      expect('truer guide'.allMatches(text).length, 1);
      // Kind, not block: role frames may not assume a block exists (the
      // character-state block is absent with the Realism Engine off).
      expect(text, isNot(contains('How Alice is right now')));
      expect(text, contains('the story recap'));
    });
  });
}
