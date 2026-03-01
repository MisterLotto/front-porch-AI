import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:front_porch_ai/app_version.dart';

part 'database.g.dart';

const _uuid = Uuid();

// ── Table Definitions ─────────────────────────────────────────────────

/// Characters table - stores metadata extracted from PNG tEXt chunks.
/// The PNG file remains the source of truth for import/export interop.
class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get personality => text().withDefault(const Constant(''))();
  TextColumn get scenario => text().withDefault(const Constant(''))();
  TextColumn get firstMessage => text().withDefault(const Constant(''))();
  TextColumn get mesExample => text().withDefault(const Constant(''))();
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();
  TextColumn get postHistoryInstructions => text().withDefault(const Constant(''))();
  TextColumn get alternateGreetings => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get imagePath => text().nullable()();
  TextColumn get ttsVoice => text().nullable()();
  TextColumn get folderId => text().nullable()();
  TextColumn get lorebook => text().nullable()(); // JSON blob
  TextColumn get worldNames => text().withDefault(const Constant('[]'))(); // JSON array
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Chat sessions - one per conversation thread.
class Sessions extends Table {
  TextColumn get id => text()(); // timestamp-based ID
  TextColumn get characterId => text().nullable()();
  TextColumn get groupId => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get authorNote => text().withDefault(const Constant(''))();
  IntColumn get authorNoteDepth => integer().withDefault(const Constant(4))();
  TextColumn get summary => text().nullable()(); // rolling chat summary
  IntColumn get summaryLastIndex => integer().nullable()(); // message index at last summary update
  TextColumn get parentSession => text().nullable()();
  IntColumn get forkIndex => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Individual chat messages within a session.
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  IntColumn get position => integer()(); // ordering within session
  TextColumn get sender => text()();
  BoolColumn get isUser => boolean()();
  TextColumn get characterId => text().nullable()(); // for group chats
  TextColumn get swipes => text().withDefault(const Constant('[]'))(); // JSON array
  IntColumn get swipeIndex => integer().withDefault(const Constant(0))();
  TextColumn get swipeDurations => text().withDefault(const Constant('[]'))(); // JSON array
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Group chat definitions.
class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get characterIds => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get turnOrder => text().withDefault(const Constant('roundRobin'))();
  BoolColumn get autoAdvance => boolean().withDefault(const Constant(false))();
  BoolColumn get directorMode => boolean().withDefault(const Constant(false))();
  TextColumn get firstMessage => text().withDefault(const Constant(''))();
  TextColumn get scenario => text().withDefault(const Constant(''))();
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Character folder organization.
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User personas.
class Personas extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get name => text().withDefault(const Constant('User'))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get persona => text().withDefault(const Constant(''))();
  TextColumn get avatarPath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// World/lorebook definitions.
class Worlds extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get lorebook => text().nullable()(); // JSON blob
  TextColumn get linkedCharacterName => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row sync metadata for version-based cloud sync.
class SyncMeta extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastModifiedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Database Definition ───────────────────────────────────────────────

@DriftDatabase(tables: [Characters, Sessions, Messages, Groups, Folders, Personas, Worlds, SyncMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.e);

  static AppDatabase? _instance;
  static String? _dbPath;

  /// Singleton access. Call [AppDatabase.instance()] to get the shared database.
  ///
  /// Pre-release builds (alpha/beta/rc/dev) automatically use a separate
  /// `front_porch_beta.db` to protect the production database from schema
  /// changes that may be incompatible with the stable release.
  static Future<AppDatabase> instance() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    final rootPath = prefs.getString('root_path');
    final basePath = rootPath ?? (await getApplicationDocumentsDirectory()).path;
    final dbDir = p.join(basePath, 'KoboldManager');

    // Choose database filename based on release type
    final dbName = isPreRelease ? 'front_porch_beta.db' : 'front_porch.db';
    final file = File(p.join(dbDir, dbName));
    await file.parent.create(recursive: true);

    // For pre-release: if no beta DB exists yet, copy the production DB
    // so users get all their data without modifying the stable database.
    if (isPreRelease && !file.existsSync()) {
      final prodFile = File(p.join(dbDir, 'front_porch.db'));
      if (prodFile.existsSync()) {
        debugPrint('[DB] Pre-release build — copying production DB to beta DB');
        await prodFile.copy(file.path);
      }
    }

    _dbPath = file.path;
    _instance = AppDatabase._internal(NativeDatabase.createInBackground(file));
    return _instance!;
  }

  /// The absolute path to the database file on disk.
  static String? get dbFilePath => _dbPath;

  /// Flush WAL (Write-Ahead Log) to the main database file.
  /// Call this before uploading the .db file to ensure it's self-contained.
  Future<void> checkpoint() async {
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  /// Close the database and clear the singleton so the next call to
  /// [instance()] will open a fresh connection to the file on disk.
  /// Used after cloud sync downloads a new .db file.
  static Future<void> closeAndReset() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
  }

  /// For testing: create an in-memory database.
  factory AppDatabase.forTesting() {
    return AppDatabase._internal(NativeDatabase.createInBackground(File(':memory:')));
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      // Seed the sync_meta row on fresh installs
      await customInsert(
        'INSERT OR IGNORE INTO sync_meta (id, version, last_modified_at) '
        'VALUES (1, 0, ?)',
        variables: [Variable(DateTime.now().millisecondsSinceEpoch ~/ 1000)],
      );
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // v1→v2: create sync_meta table
        await customStatement(
          'CREATE TABLE IF NOT EXISTS sync_meta ('
          'id INTEGER NOT NULL DEFAULT 1, '
          'version INTEGER NOT NULL DEFAULT 0, '
          'last_modified_at INTEGER NOT NULL DEFAULT 0, '
          'PRIMARY KEY (id))',
        );
        await customInsert(
          'INSERT OR IGNORE INTO sync_meta (id, version, last_modified_at) '
          'VALUES (1, 0, ?)',
          variables: [Variable(DateTime.now().millisecondsSinceEpoch ~/ 1000)],
        );
      }
      if (from < 3) {
        // v2→v3: migrate int PKs to text UUIDs, add updatedAt/deletedAt
        await _migrateToUuids();
      }
      if (from < 4) {
        // v3→v4: add summary columns to sessions
        await customStatement('ALTER TABLE sessions ADD COLUMN summary TEXT');
        await customStatement('ALTER TABLE sessions ADD COLUMN summary_last_index INTEGER');
      }
    },
  );

  /// Migrate all int-keyed tables to UUID text PKs.
  /// Creates new tables, copies data with generated UUIDs, drops old, renames.
  Future<void> _migrateToUuids() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // ── Folders ──────────────────────────────────────────────────
    await customStatement(
      'CREATE TABLE folders_new ('
      'id TEXT NOT NULL, name TEXT NOT NULL, parent_id TEXT, '
      'updated_at INTEGER NOT NULL DEFAULT $now, '
      'deleted_at INTEGER, PRIMARY KEY (id))',
    );
    // Build oldId→uuid map
    final oldFolders = await customSelect('SELECT id, name, parent_id FROM folders').get();
    final folderIdMap = <int, String>{}; // old int → new uuid
    for (final row in oldFolders) {
      final oldId = row.read<int>('id');
      folderIdMap[oldId] = _uuid.v4();
    }
    for (final row in oldFolders) {
      final oldId = row.read<int>('id');
      final newId = folderIdMap[oldId]!;
      final oldParent = row.readNullable<int>('parent_id');
      final newParent = oldParent != null ? folderIdMap[oldParent] : null;
      await customInsert(
        'INSERT INTO folders_new (id, name, parent_id, updated_at) VALUES (?, ?, ?, ?)',
        variables: [Variable(newId), Variable(row.read<String>('name')),
                     Variable(newParent), Variable(now)],
      );
    }
    await customStatement('DROP TABLE folders');
    await customStatement('ALTER TABLE folders_new RENAME TO folders');

    // ── Characters ───────────────────────────────────────────────
    await customStatement(
      'CREATE TABLE characters_new ('
      'id TEXT NOT NULL, name TEXT NOT NULL, '
      'description TEXT NOT NULL DEFAULT \'\', personality TEXT NOT NULL DEFAULT \'\', '
      'scenario TEXT NOT NULL DEFAULT \'\', first_message TEXT NOT NULL DEFAULT \'\', '
      'mes_example TEXT NOT NULL DEFAULT \'\', system_prompt TEXT NOT NULL DEFAULT \'\', '
      'post_history_instructions TEXT NOT NULL DEFAULT \'\', '
      'alternate_greetings TEXT NOT NULL DEFAULT \'[]\', '
      'tags TEXT NOT NULL DEFAULT \'[]\', '
      'image_path TEXT, tts_voice TEXT, folder_id TEXT, '
      'lorebook TEXT, world_names TEXT NOT NULL DEFAULT \'[]\', '
      'created_at INTEGER NOT NULL DEFAULT $now, '
      'updated_at INTEGER NOT NULL DEFAULT $now, '
      'deleted_at INTEGER, PRIMARY KEY (id))',
    );
    final oldChars = await customSelect('SELECT * FROM characters').get();
    final charIdMap = <int, String>{}; // old int → new uuid
    for (final row in oldChars) {
      final oldId = row.read<int>('id');
      charIdMap[oldId] = _uuid.v4();
    }
    for (final row in oldChars) {
      final oldId = row.read<int>('id');
      final newId = charIdMap[oldId]!;
      final oldFolderId = row.readNullable<int>('folder_id');
      final newFolderId = oldFolderId != null ? folderIdMap[oldFolderId] : null;
      await customInsert(
        'INSERT INTO characters_new (id, name, description, personality, scenario, '
        'first_message, mes_example, system_prompt, post_history_instructions, '
        'alternate_greetings, tags, image_path, tts_voice, folder_id, '
        'lorebook, world_names, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(newId), Variable(row.read<String>('name')),
          Variable(row.read<String>('description')), Variable(row.read<String>('personality')),
          Variable(row.read<String>('scenario')), Variable(row.read<String>('first_message')),
          Variable(row.read<String>('mes_example')), Variable(row.read<String>('system_prompt')),
          Variable(row.read<String>('post_history_instructions')),
          Variable(row.read<String>('alternate_greetings')),
          Variable(row.read<String>('tags')),
          Variable(row.readNullable<String>('image_path')),
          Variable(row.readNullable<String>('tts_voice')),
          Variable(newFolderId),
          Variable(row.readNullable<String>('lorebook')),
          Variable(row.read<String>('world_names')),
          Variable(row.read<int>('created_at')),
          Variable(row.read<int>('updated_at')),
        ],
      );
    }
    await customStatement('DROP TABLE characters');
    await customStatement('ALTER TABLE characters_new RENAME TO characters');

    // ── Sessions (already text PK, just remap characterId int→text, add deletedAt) ──
    await customStatement(
      'CREATE TABLE sessions_new ('
      'id TEXT NOT NULL, character_id TEXT, group_id TEXT, '
      'name TEXT, description TEXT, '
      'author_note TEXT NOT NULL DEFAULT \'\', '
      'author_note_depth INTEGER NOT NULL DEFAULT 4, '
      'parent_session TEXT, fork_index INTEGER, '
      'created_at INTEGER NOT NULL DEFAULT $now, '
      'updated_at INTEGER NOT NULL DEFAULT $now, '
      'deleted_at INTEGER, PRIMARY KEY (id))',
    );
    final oldSessions = await customSelect('SELECT * FROM sessions').get();
    for (final row in oldSessions) {
      final oldCharId = row.readNullable<int>('character_id');
      final newCharId = oldCharId != null ? charIdMap[oldCharId] : null;
      await customInsert(
        'INSERT INTO sessions_new (id, character_id, group_id, name, description, '
        'author_note, author_note_depth, parent_session, fork_index, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(row.read<String>('id')),
          Variable(newCharId),
          Variable(row.readNullable<String>('group_id')),
          Variable(row.readNullable<String>('name')),
          Variable(row.readNullable<String>('description')),
          Variable(row.read<String>('author_note')),
          Variable(row.read<int>('author_note_depth')),
          Variable(row.readNullable<String>('parent_session')),
          Variable(row.readNullable<int>('fork_index')),
          Variable(row.read<int>('created_at')),
          Variable(row.read<int>('updated_at')),
        ],
      );
    }
    await customStatement('DROP TABLE sessions');
    await customStatement('ALTER TABLE sessions_new RENAME TO sessions');

    // ── Messages (int PK → text UUID, add updatedAt/deletedAt) ──
    await customStatement(
      'CREATE TABLE messages_new ('
      'id TEXT NOT NULL, session_id TEXT NOT NULL, '
      'position INTEGER NOT NULL, sender TEXT NOT NULL, '
      'is_user INTEGER NOT NULL, character_id TEXT, '
      'swipes TEXT NOT NULL DEFAULT \'[]\', '
      'swipe_index INTEGER NOT NULL DEFAULT 0, '
      'swipe_durations TEXT NOT NULL DEFAULT \'[]\', '
      'updated_at INTEGER NOT NULL DEFAULT $now, '
      'deleted_at INTEGER, PRIMARY KEY (id))',
    );
    final oldMsgs = await customSelect('SELECT * FROM messages').get();
    for (final row in oldMsgs) {
      await customInsert(
        'INSERT INTO messages_new (id, session_id, position, sender, is_user, '
        'character_id, swipes, swipe_index, swipe_durations, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(_uuid.v4()), // generate UUID for each message
          Variable(row.read<String>('session_id')),
          Variable(row.read<int>('position')),
          Variable(row.read<String>('sender')),
          Variable(row.read<bool>('is_user') ? 1 : 0),
          Variable(row.readNullable<String>('character_id')),
          Variable(row.read<String>('swipes')),
          Variable(row.read<int>('swipe_index')),
          Variable(row.read<String>('swipe_durations')),
          Variable(now),
        ],
      );
    }
    await customStatement('DROP TABLE messages');
    await customStatement('ALTER TABLE messages_new RENAME TO messages');

    // ── Groups (already text PK, just add updatedAt/deletedAt) ──
    await customStatement('ALTER TABLE groups ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $now');
    await customStatement('ALTER TABLE groups ADD COLUMN deleted_at INTEGER');

    // ── Personas (already text PK, just add updatedAt/deletedAt) ──
    await customStatement('ALTER TABLE personas ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $now');
    await customStatement('ALTER TABLE personas ADD COLUMN deleted_at INTEGER');

    // ── Worlds (int PK → text UUID, add updatedAt/deletedAt) ──
    await customStatement(
      'CREATE TABLE worlds_new ('
      'id TEXT NOT NULL, name TEXT NOT NULL UNIQUE, '
      'description TEXT NOT NULL DEFAULT \'\', '
      'lorebook TEXT, linked_character_name TEXT, '
      'updated_at INTEGER NOT NULL DEFAULT $now, '
      'deleted_at INTEGER, PRIMARY KEY (id))',
    );
    final oldWorlds = await customSelect('SELECT * FROM worlds').get();
    for (final row in oldWorlds) {
      await customInsert(
        'INSERT INTO worlds_new (id, name, description, lorebook, linked_character_name, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(_uuid.v4()),
          Variable(row.read<String>('name')),
          Variable(row.read<String>('description')),
          Variable(row.readNullable<String>('lorebook')),
          Variable(row.readNullable<String>('linked_character_name')),
          Variable(now),
        ],
      );
    }
    await customStatement('DROP TABLE worlds');
    await customStatement('ALTER TABLE worlds_new RENAME TO worlds');
  }

  // ── Sync Meta Queries ────────────────────────────────────────────────

  /// Get the current sync version (0 if no row exists yet).
  Future<int> getSyncVersion() async {
    try {
      final rows = await customSelect(
        'SELECT version FROM sync_meta WHERE id = 1',
      ).get();
      return rows.isNotEmpty ? rows.first.read<int>('version') : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Increment the sync version counter. Call after every meaningful write.
  Future<void> bumpSyncVersion() async {
    await customUpdate(
      'UPDATE sync_meta SET version = version + 1, '
      'last_modified_at = ? WHERE id = 1',
      variables: [Variable(DateTime.now().millisecondsSinceEpoch ~/ 1000)],
      updates: {syncMeta},
    );
  }

  // ── Character Queries ───────────────────────────────────────────────

  Future<List<Character>> getAllCharacters() =>
      (select(characters)..where((c) => c.deletedAt.isNull())).get();

  Stream<List<Character>> watchAllCharacters() =>
      (select(characters)..where((c) => c.deletedAt.isNull())).watch();

  Future<Character> getCharacterById(String id) =>
      (select(characters)..where((c) => c.id.equals(id))).getSingle();

  Future<Character?> getCharacterByImagePath(String path) =>
      (select(characters)..where((c) => c.imagePath.equals(path) & c.deletedAt.isNull())).getSingleOrNull();

  Future<int> insertCharacter(CharactersCompanion character) async {
    // Ensure UUID is set
    if (!character.id.present) {
      character = character.copyWith(id: Value(_uuid.v4()));
    }
    final result = await into(characters).insert(character);
    await bumpSyncVersion();
    return result;
  }

  /// Insert a character and return its UUID (convenience for callers that need the ID).
  Future<String> insertCharacterReturningId(CharactersCompanion character) async {
    final id = character.id.present ? character.id.value : _uuid.v4();
    character = character.copyWith(id: Value(id));
    await into(characters).insert(character);
    await bumpSyncVersion();
    return id;
  }

  Future<bool> updateCharacter(CharactersCompanion character) async {
    final result = await update(characters).replace(character);
    await bumpSyncVersion();
    return result;
  }

  /// Update ONLY the imagePath for a character (preserves all other data).
  Future<void> updateCharacterImagePath(String id, String newPath) async {
    await (update(characters)..where((c) => c.id.equals(id)))
        .write(CharactersCompanion(imagePath: Value(newPath)));
    await bumpSyncVersion();
  }

  Future<int> deleteCharacterById(String id) async {
    // Soft delete: set deletedAt instead of removing
    await (update(characters)..where((c) => c.id.equals(id)))
        .write(CharactersCompanion(deletedAt: Value(DateTime.now())));
    await bumpSyncVersion();
    return 1;
  }

  // ── Session Queries ─────────────────────────────────────────────────

  /// Get total message count per character (for home screen badges).
  Future<Map<String, int>> getMessageCountsPerCharacter() async {
    final result = await customSelect(
      'SELECT s.character_id, COUNT(m.id) AS cnt '
      'FROM sessions s JOIN messages m ON m.session_id = s.id '
      'WHERE s.character_id IS NOT NULL AND s.deleted_at IS NULL AND m.deleted_at IS NULL '
      'AND m.is_user = 1 '
      'GROUP BY s.character_id',
    ).get();
    final map = <String, int>{};
    for (final row in result) {
      final charId = row.read<String>('character_id');
      final count = row.read<int>('cnt');
      map[charId] = count;
    }
    return map;
  }

  /// Get the most recent session update time per character.
  Future<Map<String, DateTime>> getLastActivityPerCharacter() async {
    final result = await customSelect(
      'SELECT character_id, MAX(created_at) AS last_at '
      'FROM sessions '
      'WHERE character_id IS NOT NULL AND deleted_at IS NULL '
      'GROUP BY character_id',
    ).get();
    final map = <String, DateTime>{};
    for (final row in result) {
      final charId = row.read<String>('character_id');
      final lastAt = row.read<DateTime>('last_at');
      map[charId] = lastAt;
    }
    return map;
  }

  Future<List<Session>> getSessionsForCharacter(String characterId) =>
      (select(sessions)
        ..where((s) => s.characterId.equals(characterId) & s.deletedAt.isNull())
        ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
      .get();

  Future<List<Session>> getSessionsForGroup(String groupId) =>
      (select(sessions)
        ..where((s) => s.groupId.equals(groupId) & s.deletedAt.isNull())
        ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
      .get();

  Future<Session?> getSessionById(String id) =>
      (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> insertSession(SessionsCompanion session) async {
    final result = await into(sessions).insert(session);
    await bumpSyncVersion();
    return result;
  }

  Future<int> upsertSession(SessionsCompanion session) async {
    final result = await into(sessions).insertOnConflictUpdate(session);
    await bumpSyncVersion();
    return result;
  }

  Future<bool> updateSession(SessionsCompanion session) async {
    final result = await update(sessions).replace(session);
    await bumpSyncVersion();
    return result;
  }

  Future<int> deleteSessionById(String id) async {
    await (update(sessions)..where((s) => s.id.equals(id)))
        .write(SessionsCompanion(deletedAt: Value(DateTime.now())));
    await bumpSyncVersion();
    return 1;
  }

  // ── Message Queries ─────────────────────────────────────────────────

  Future<List<Message>> getMessagesForSession(String sessionId) =>
      (select(messages)
        ..where((m) => m.sessionId.equals(sessionId) & m.deletedAt.isNull())
        ..orderBy([(m) => OrderingTerm.asc(m.position)]))
      .get();

  Stream<List<Message>> watchMessagesForSession(String sessionId) =>
      (select(messages)
        ..where((m) => m.sessionId.equals(sessionId) & m.deletedAt.isNull())
        ..orderBy([(m) => OrderingTerm.asc(m.position)]))
      .watch();

  Future<int> insertMessage(MessagesCompanion message) async {
    if (!message.id.present) {
      message = message.copyWith(id: Value(_uuid.v4()));
    }
    final result = await into(messages).insert(message);
    await bumpSyncVersion();
    return result;
  }

  Future<void> insertMessages(List<MessagesCompanion> msgs) async {
    final withIds = msgs.map((m) =>
      m.id.present ? m : m.copyWith(id: Value(_uuid.v4())),
    ).toList();
    await batch((b) => b.insertAll(messages, withIds));
    await bumpSyncVersion();
  }

  Future<int> deleteMessagesForSession(String sessionId) async {
    await (update(messages)..where((m) => m.sessionId.equals(sessionId)))
        .write(MessagesCompanion(deletedAt: Value(DateTime.now())));
    await bumpSyncVersion();
    return 1;
  }

  Future<int> deleteMessageById(String id) async {
    await (update(messages)..where((m) => m.id.equals(id)))
        .write(MessagesCompanion(deletedAt: Value(DateTime.now())));
    await bumpSyncVersion();
    return 1;
  }

  Future<void> updateMessage(MessagesCompanion message) async {
    await (update(messages)..where((m) => m.id.equals(message.id.value)))
        .write(message);
    await bumpSyncVersion();
  }

  // ── Group Queries ───────────────────────────────────────────────────

  Future<List<Group>> getAllGroups() =>
      (select(groups)..where((g) => g.deletedAt.isNull())).get();

  Stream<List<Group>> watchAllGroups() =>
      (select(groups)..where((g) => g.deletedAt.isNull())).watch();

  Future<Group?> getGroupById(String id) =>
      (select(groups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<int> insertGroup(GroupsCompanion group) async {
    final result = await into(groups).insert(group);
    await bumpSyncVersion();
    return result;
  }

  Future<bool> updateGroup(GroupsCompanion group) async {
    final result = await update(groups).replace(group);
    await bumpSyncVersion();
    return result;
  }

  Future<int> deleteGroupById(String id) async {
    await (update(groups)..where((g) => g.id.equals(id)))
        .write(GroupsCompanion(deletedAt: Value(DateTime.now())));
    await bumpSyncVersion();
    return 1;
  }

  // ── Folder Queries ──────────────────────────────────────────────────

  Future<List<Folder>> getAllFolders() =>
      (select(folders)..where((f) => f.deletedAt.isNull())).get();

  Future<String> insertFolder(FoldersCompanion folder) async {
    final id = folder.id.present ? folder.id.value : _uuid.v4();
    folder = folder.copyWith(id: Value(id));
    await into(folders).insert(folder);
    await bumpSyncVersion();
    return id;
  }

  Future<int> deleteFolderById(String id) async {
    await (update(folders)..where((f) => f.id.equals(id)))
        .write(FoldersCompanion(deletedAt: Value(DateTime.now())));
    await bumpSyncVersion();
    return 1;
  }

  Future<void> updateFolder(FoldersCompanion folder) async {
    await (update(folders)..where((f) => f.id.equals(folder.id.value)))
        .write(folder);
    await bumpSyncVersion();
  }

  // ── Persona Queries ─────────────────────────────────────────────────

  Future<List<Persona>> getAllPersonas() =>
      (select(personas)..where((p) => p.deletedAt.isNull())).get();

  Future<Persona?> getActivePersona() =>
      (select(personas)..where((p) => p.isActive.equals(true) & p.deletedAt.isNull())).getSingleOrNull();

  Future<int> insertPersona(PersonasCompanion persona) async {
    final result = await into(personas).insert(persona);
    await bumpSyncVersion();
    return result;
  }

  Future<bool> updatePersona(PersonasCompanion persona) async {
    final result = await update(personas).replace(persona);
    await bumpSyncVersion();
    return result;
  }

  Future<int> deletePersonaById(String id) async {
    await (update(personas)..where((p) => p.id.equals(id)))
        .write(PersonasCompanion(deletedAt: Value(DateTime.now())));
    await bumpSyncVersion();
    return 1;
  }

  Future<void> setActivePersona(String id) async {
    await transaction(() async {
      // Deactivate all
      await (update(personas)).write(const PersonasCompanion(isActive: Value(false)));
      // Activate the chosen one
      await (update(personas)..where((p) => p.id.equals(id)))
          .write(const PersonasCompanion(isActive: Value(true)));
    });
    await bumpSyncVersion();
  }

  // ── World Queries ───────────────────────────────────────────────────

  Future<List<World>> getAllWorlds() =>
      (select(worlds)..where((w) => w.deletedAt.isNull())).get();

  Stream<List<World>> watchAllWorlds() =>
      (select(worlds)..where((w) => w.deletedAt.isNull())).watch();

  Future<String> insertWorld(WorldsCompanion world) async {
    final id = world.id.present ? world.id.value : _uuid.v4();
    world = world.copyWith(id: Value(id));
    await into(worlds).insert(world);
    await bumpSyncVersion();
    return id;
  }

  Future<bool> updateWorld(WorldsCompanion world) async {
    final result = await update(worlds).replace(world);
    await bumpSyncVersion();
    return result;
  }

  Future<int> deleteWorldById(String id) async {
    await (update(worlds)..where((w) => w.id.equals(id)))
        .write(WorldsCompanion(deletedAt: Value(DateTime.now())));
    await bumpSyncVersion();
    return 1;
  }

  Future<World?> getWorldByName(String name) =>
      (select(worlds)..where((w) => w.name.equals(name) & w.deletedAt.isNull())).getSingleOrNull();

  // ── Soft Delete Cleanup ─────────────────────────────────────────────

  /// Permanently remove rows soft-deleted more than 30 days ago.
  Future<void> purgeSoftDeletes() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffEpoch = cutoff.millisecondsSinceEpoch ~/ 1000;
    for (final table in ['messages', 'sessions', 'characters', 'folders',
                          'groups', 'personas', 'worlds']) {
      await customUpdate(
        'DELETE FROM $table WHERE deleted_at IS NOT NULL AND deleted_at < ?',
        variables: [Variable(cutoffEpoch)],
      );
    }
  }
}
