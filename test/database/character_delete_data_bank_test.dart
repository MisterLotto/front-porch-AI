// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Character delete cascaded chats but not Data Bank / chat-less objectives,
// which key by filename-id (audit P1). Those rows kept injecting until
// Database Cleanup ran by hand.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(sameIsolate: true));
  tearDown(() async => db.close());

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('c');

  test(
    'soft-deleting a character drops Data Bank keyed by filename-id',
    () async {
      await db
          .into(db.characters)
          .insert(
            CharactersCompanion.insert(
              id: 'uuid-bank',
              name: 'Mara',
              imagePath: const Value('/tmp/Mara_178.png'),
            ),
          );
      await db.insertDataBankEntry(
        DataBankEntriesCompanion.insert(
          id: 'bank-1',
          characterId: 'Mara_178',
          title: 'keys',
          content: 'She keeps the spare under the mat.',
        ),
      );
      await db
          .into(db.objectives)
          .insert(
            ObjectivesCompanion.insert(
              id: 'obj-bankless',
              characterId: 'Mara_178',
              objective: 'a quest with no chat',
            ),
          );

      await db.softDeleteCharacterById('uuid-bank');

      expect(
        await count(
          "SELECT COUNT(*) AS c FROM data_bank_entries WHERE character_id = 'Mara_178'",
        ),
        0,
      );
      expect(
        await count(
          "SELECT COUNT(*) AS c FROM objectives WHERE id = 'obj-bankless'",
        ),
        0,
      );
    },
  );

  test('another character\'s Data Bank is untouched', () async {
    await db
        .into(db.characters)
        .insert(
          CharactersCompanion.insert(
            id: 'uuid-keep',
            name: 'Sam',
            imagePath: const Value('/tmp/Sam_1.png'),
          ),
        );
    await db
        .into(db.characters)
        .insert(
          CharactersCompanion.insert(
            id: 'uuid-drop',
            name: 'Mara',
            imagePath: const Value('/tmp/Mara_1.png'),
          ),
        );
    await db.insertDataBankEntry(
      DataBankEntriesCompanion.insert(
        id: 'bank-keep',
        characterId: 'Sam_1',
        title: 'hat',
        content: 'the yellow one',
      ),
    );
    await db.insertDataBankEntry(
      DataBankEntriesCompanion.insert(
        id: 'bank-drop',
        characterId: 'Mara_1',
        title: 'keys',
        content: 'under the mat',
      ),
    );

    await db.softDeleteCharacterById('uuid-drop');

    expect(
      await count(
        "SELECT COUNT(*) AS c FROM data_bank_entries WHERE character_id = 'Sam_1'",
      ),
      1,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS c FROM data_bank_entries WHERE character_id = 'Mara_1'",
      ),
      0,
    );
  });
}
