// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// AI Enhance context assembly against a REAL in-memory AppDatabase: the recap
// comes from Sessions.summary, journal cards are keyed by the character's
// stableGroupId (NOT the UUID — the documented identity gotcha), transcript
// text honors swipeIndex, and <think> blocks never leak into the grounding.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/database/database.dart' hide World;
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chargen/enhance_context.dart';
import 'package:front_porch_ai/utils/utils.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(sameIsolate: true);
  });

  tearDown(() async {
    await db.close();
  });

  final card = CharacterCard(
    name: 'Nina',
    imagePath: '/tmp/chars/Nina_1782587668376.png',
  );

  Future<void> seedSession({String? summary}) => db.insertSession(
        SessionsCompanion.insert(
          id: 's1',
          name: const Value('Chat with Nina'),
          characterId: const Value('uuid-nina'),
          summary: Value(summary),
        ),
      );

  Future<void> seedMessage({
    required int position,
    required List<String> swipes,
    int swipeIndex = 0,
    bool isUser = false,
  }) =>
      db.insertMessage(
        MessagesCompanion.insert(
          id: 'm$position',
          sessionId: 's1',
          position: position,
          sender: isUser ? 'User' : 'Nina',
          isUser: isUser,
          swipes: Value(jsonEncode(swipes)),
          swipeIndex: Value(swipeIndex),
        ),
      );

  test('recap from Sessions.summary; empty when Journal never ran', () async {
    await seedSession(summary: '  We grew close over coffee.  ');
    final ctx = await buildEnhanceContext(db: db, card: card, sessionId: 's1');
    expect(ctx.recap, 'We grew close over coffee.');

    await db.insertSession(SessionsCompanion.insert(id: 's2'));
    final bare = await buildEnhanceContext(db: db, card: card, sessionId: 's2');
    expect(bare.recap, isEmpty);
  });

  test('journal cards fetched by stableGroupId, not the UUID', () async {
    await seedSession();
    await db.insertJournalCard(
      JournalMemoriesCompanion.insert(
        id: 'j1',
        sessionId: 's1',
        characterId: card.stableGroupId, // Nina_1782587668376
        content: 'He remembered my birthday.',
      ),
    );
    // A card keyed by the UUID (the WRONG key) must NOT be picked up.
    await db.insertJournalCard(
      JournalMemoriesCompanion.insert(
        id: 'j2',
        sessionId: 's1',
        characterId: 'uuid-nina',
        content: 'wrong-key card',
      ),
    );
    final ctx = await buildEnhanceContext(db: db, card: card, sessionId: 's1');
    expect(ctx.memoryCards, ['He remembered my birthday.']);
  });

  test('transcript honors swipeIndex and strips <think> blocks', () async {
    await seedSession();
    await seedMessage(position: 0, swipes: ['Hi Nina!'], isUser: true);
    await seedMessage(
      position: 1,
      swipes: ['rejected swipe', '<think>internal</think>Hello there.'],
      swipeIndex: 1,
    );
    // A think-only reply becomes blank after the strip and is dropped.
    await seedMessage(position: 2, swipes: ['<think>only thoughts</think>']);

    final ctx = await buildEnhanceContext(db: db, card: card, sessionId: 's1');
    expect(ctx.turns, [
      (speaker: 'User', text: 'Hi Nina!'),
      (speaker: 'Nina', text: 'Hello there.'),
    ]);
    expect(ctx.userTurnCount, 1);
  });

  test('corrupt swipes JSON is skipped, not fatal', () async {
    await seedSession();
    await db.insertMessage(
      MessagesCompanion.insert(
        id: 'bad',
        sessionId: 's1',
        position: 0,
        sender: 'Nina',
        isUser: false,
        swipes: const Value('not json'),
      ),
    );
    await seedMessage(position: 1, swipes: ['Still here.']);
    final ctx = await buildEnhanceContext(db: db, card: card, sessionId: 's1');
    expect(ctx.turns.single.text, 'Still here.');
  });
}
