// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// The beta "import your stable database" offer used to ask whether the beta
// .db FILE was absent — a question that can never be true by the time any UI
// runs, because startup opens (and therefore creates) that file before the
// first frame. The offer was dead for the whole beta channel. The honest
// question is whether the beta library is still EMPTY, which also refuses to
// overwrite a beta library the user has already put work into.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting());
  tearDown(() async => db.close());

  test('a freshly created database reports no user content', () async {
    // This is the state the beta build is in when the import offer must fire:
    // the file exists (it was just created), the library is empty.
    expect(await db.hasNoUserContent(), isTrue);
  });

  test('one character is enough to withdraw the offer', () async {
    await db.insertCharacter(CharactersCompanion(name: const Value('Nina')));
    expect(await db.hasNoUserContent(), isFalse);
  });

  test('a chat with no characters still counts as content', () async {
    await db.insertSession(SessionsCompanion.insert(id: 's-1'));
    expect(await db.hasNoUserContent(), isFalse);
  });

  test('a group counts as content', () async {
    await db.insertGroup(GroupsCompanion.insert(id: 'g-1', name: 'The Porch'));
    expect(await db.hasNoUserContent(), isFalse);
  });

  test('the default persona a fresh install seeds is not content', () async {
    await db.insertPersona(
      PersonasCompanion.insert(id: 'p-1', name: const Value('User')),
    );
    expect(await db.hasNoUserContent(), isTrue);
  });
}
