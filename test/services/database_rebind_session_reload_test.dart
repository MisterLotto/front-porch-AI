// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A RESTORE MUST NOT BE SILENTLY UNDONE BY THE OPEN CHAT (1.3 sweep,
// 2026-08-15).
//
// reopenAndRebindDatabase re-pointed ChatService at the new database but
// never reloaded the open session, so `_messages` stayed the PRE-swap
// transcript — and the next `_saveChat` upserted those messages back into
// the restored database, un-restoring the open conversation. The rebind now
// calls `reloadCurrentSession()` (the same call reunification already made)
// and `StoryRepository.loadProjects()`.
//
// This suite pins the MECHANISM: reloadCurrentSession after an
// updateDatabase swap replaces the in-memory transcript with the new
// database's rows. The call SITE in reopenAndRebindDatabase needs the full
// provider tree to exercise; it is covered by reading — flagged in the
// sweep report as a candidate for a widget-pump test.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/database/database.dart' hide World;
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reloadCurrentSession after a database swap replaces the in-memory '
    'transcript with the restored rows',
    () async {
      final storage = StorageService();
      final oldDb = AppDatabase.forTesting(sameIsolate: true);
      final newDb = AppDatabase.forTesting(sameIsolate: true);
      addTearDown(() async {
        await oldDb.close();
        await newDb.close();
      });

      final chat = ChatService(
        KoboldService(storage),
        UserPersonaService(oldDb),
        storage,
        WorldRepository(storage, oldDb),
      )..setDatabase(oldDb);
      addTearDown(chat.dispose);

      await chat.setActiveCharacter(
        CharacterCard(name: 'Snapshot', firstMessage: 'Before the restore.')
          ..dbId = 'char-snap',
      );
      final sessionId = chat.currentSessionId!;
      final preSwapCount = chat.messages.length;
      expect(preSwapCount, greaterThan(0));

      // The "restored snapshot": same session id, but a DIFFERENT transcript
      // (one message, different text) in the new database.
      await newDb.insertSession(
        SessionsCompanion.insert(
          id: sessionId,
          characterId: const Value('char-snap'),
        ),
      );
      await newDb.insertMessage(
        MessagesCompanion.insert(
          id: 'm-restored',
          sessionId: sessionId,
          position: 0,
          sender: 'Snapshot',
          isUser: false,
          swipes: const Value('["The restored line."]'),
        ),
      );

      chat.updateDatabase(newDb);
      await chat.reloadCurrentSession();

      expect(
        chat.messages.map((m) => m.text).toList(),
        ['The restored line.'],
        reason: 'the open chat must show the swapped database\'s transcript — '
            'keeping the pre-swap messages is how a restore un-restored '
            'itself on the next save',
      );
    },
  );
}
