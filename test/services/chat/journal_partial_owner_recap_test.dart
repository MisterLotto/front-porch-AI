// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guard for the group partial-failure recap hole (release sweep _idx 135).
//
// Exactly ONE owner per pass is asked for the "Where we are" recap. That used
// to be rigidly owner 0, while the cursor advanced as soon as ANY owner's call
// came back — so a group whose FIRST speaker's call failed (a timeout, an
// empty local-model answer) lost that window's recap permanently: the cursor
// jumped past the window and nothing ever re-read it. The recap is now owed to
// the first owner whose call actually COMES BACK, which is still exactly one
// call's worth of prompt.
//
// 1:1 has no such hole (a lone owner's failure leaves the cursor untouched and
// the pass retries), so this is a group-vs-1:1 parity guard as much as a
// correctness one — both directions are pinned below.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/models/group_chat.dart';
import 'package:front_porch_ai/services/chat/journal_maintenance.dart';
import 'package:front_porch_ai/services/chat/journal_review.dart';
import 'package:front_porch_ai/services/chat/journal_store.dart';
import 'package:front_porch_ai/services/chat/pass_support.dart';

ChatMessage _msg(
  String sender,
  String text, {
  bool isUser = false,
  String? characterId,
  Map<String, dynamic>? metadata,
}) => ChatMessage(
  text: text,
  sender: sender,
  isUser: isUser,
  characterId: characterId,
  metadata: metadata,
);

void main() {
  late AppDatabase db;
  late JournalStore store;

  setUp(() {
    db = AppDatabase.forTesting();
    store = JournalStore(getDb: () => db);
  });

  tearDown(() async {
    await db.close();
  });

  final mara = CharacterCard(
    name: 'Mara',
    description: 'd',
    personality: 'p',
    scenario: 's',
  );
  final liv = CharacterCard(
    name: 'Liv',
    description: 'd',
    personality: 'p',
    scenario: 's',
  );

  JournalMaintenance build({
    required List<String?> responses,
    required List<ChatMessage> messages,
    CharacterCard? activeChar,
    GroupChat? group,
    List<CharacterCard> groupChars = const [],
    List<String>? prompts,
    void Function(String)? onRecap,
    void Function(int)? onCursor,
  }) {
    var running = false;
    var i = 0;
    return JournalMaintenance(
      store: store,
      probe: ToolTransportProbe(),
      review: JournalReview(
        store: store,
        getSessionId: () => 's1',
        setRecap: (t) => onRecap?.call(t),
        setCursor: (v) => onCursor?.call(v),
        onSaveChat: () async {},
        onNotify: () {},
        getMaxCards: () => 200,
      ),
      fireLLMEval: (p) async {
        prompts?.add(p);
        return i < responses.length ? responses[i++] : null;
      },
      fireToolEval: (p, t) async => null,
      stripThinkBlocks: (t) => t,
      getSessionId: () => 's1',
      getActiveCharacter: () => activeChar,
      getActiveGroup: () => group,
      getGroupCharacters: () => groupChars,
      getCharacterIdFromCard: (c) => c.name.toLowerCase(),
      getMessages: () => messages,
      getUserName: () => 'Sam',
      getCursor: () => 0,
      setCursor: (v) => onCursor?.call(v),
      getRecap: () => '',
      setRecap: (t) => onRecap?.call(t),
      getIsPassRunning: () => running,
      setIsPassRunning: (v) => running = v,
      getReviewFirst: () => false,
      getBackendIdentity: () => 'test-backend',
      getMaxCards: () => 200,
      onNotify: () {},
      onSaveChat: () async {},
      getCurrentStoryDay: () => 1,
      getCurrentStoryClockIso: () => '2026-06-30T09:00:00.000Z',
    );
  }

  List<ChatMessage> groupWindow() => [
    _msg('Sam', 'evening, you two', isUser: true),
    _msg('Mara', 'evening!', characterId: 'mara'),
    _msg('Liv', 'hm.', characterId: 'liv'),
  ];

  test('group: the recap survives the FIRST owner failing', () async {
    final recaps = <String>[];
    final cursors = <int>[];
    final messages = groupWindow();
    final m = build(
      responses: [
        null, // Mara's call comes back empty (busy backend)
        '<memory action="add" msgs="2">He interrupted my reading.</memory>'
            '<recap>A quiet evening that went sideways.</recap>',
      ],
      messages: messages,
      group: GroupChat(id: 'g1', name: 'The Porch'),
      groupChars: [mara, liv],
      onRecap: recaps.add,
      onCursor: cursors.add,
    );

    await m.runMaintenancePass();

    // The window the cursor is about to skip past MUST have produced its
    // recap — the second owner is asked for it once the first came back empty.
    expect(recaps, ['A quiet evening that went sideways.']);
    // …and the cursor still advances (one owner succeeded), so the window is
    // not re-read on the next pass.
    expect(cursors, [messages.length]);
    expect(await store.cardsFor('s1', 'mara'), isEmpty);
    expect(await store.cardsFor('s1', 'liv'), hasLength(1));
  });

  test('group: still exactly ONE recap ask per pass', () async {
    final recaps = <String>[];
    final m = build(
      responses: [
        '<memory action="add" msgs="1">He greeted us warmly.</memory>'
            '<recap>A warm evening together.</recap>',
        '<memory action="add" msgs="2">He interrupted my reading.</memory>'
            '<recap>must be ignored — Mara already answered</recap>',
      ],
      messages: groupWindow(),
      group: GroupChat(id: 'g1', name: 'The Porch'),
      groupChars: [mara, liv],
      onRecap: recaps.add,
    );

    await m.runMaintenancePass();

    expect(recaps, ['A warm evening together.']);
  });

  test('1:1 twin: a lone owner failing leaves the cursor for a retry',
      () async {
    final recaps = <String>[];
    final cursors = <int>[];
    final m = build(
      responses: [null],
      messages: [
        _msg('Sam', 'you okay?', isUser: true),
        _msg('Mara', 'better now', characterId: 'mara'),
      ],
      activeChar: mara,
      onRecap: recaps.add,
      onCursor: cursors.add,
    );

    await m.runMaintenancePass();

    expect(recaps, isEmpty);
    expect(cursors, isEmpty); // window is re-read next interval
  });
}
