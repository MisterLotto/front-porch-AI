import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ── Table Definitions ─────────────────────────────────────────────────

/// Characters table - stores metadata extracted from PNG tEXt chunks.
/// The PNG file remains the source of truth for import/export interop.
class Characters extends Table {
  IntColumn get id => integer().autoIncrement()();
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
  IntColumn get folderId => integer().nullable().references(Folders, #id)();
  TextColumn get lorebook => text().nullable()(); // JSON blob
  TextColumn get worldNames => text().withDefault(const Constant('[]'))(); // JSON array
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Chat sessions - one per conversation thread.
class Sessions extends Table {
  TextColumn get id => text()(); // timestamp-based ID
  IntColumn get characterId => integer().nullable().references(Characters, #id)();
  TextColumn get groupId => text().nullable().references(Groups, #id)();
  TextColumn get name => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get authorNote => text().withDefault(const Constant(''))();
  IntColumn get authorNoteDepth => integer().withDefault(const Constant(4))();
  TextColumn get parentSession => text().nullable()();
  IntColumn get forkIndex => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Individual chat messages within a session.
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  IntColumn get position => integer()(); // ordering within session
  TextColumn get sender => text()();
  BoolColumn get isUser => boolean()();
  TextColumn get characterId => text().nullable()(); // for group chats
  TextColumn get swipes => text().withDefault(const Constant('[]'))(); // JSON array
  IntColumn get swipeIndex => integer().withDefault(const Constant(0))();
  TextColumn get swipeDurations => text().withDefault(const Constant('[]'))(); // JSON array
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

  @override
  Set<Column> get primaryKey => {id};
}

/// Character folder organization.
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get parentId => integer().nullable()();
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

  @override
  Set<Column> get primaryKey => {id};
}

/// World/lorebook definitions.
class Worlds extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get lorebook => text().nullable()(); // JSON blob
  TextColumn get linkedCharacterName => text().nullable()();
}

// ── Database Definition ───────────────────────────────────────────────

@DriftDatabase(tables: [Characters, Sessions, Messages, Groups, Folders, Personas, Worlds])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.e);

  static AppDatabase? _instance;
  static String? _dbPath;

  /// Singleton access. Call [AppDatabase.instance()] to get the shared database.
  static Future<AppDatabase> instance() async {
    if (_instance != null) return _instance!;
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'KoboldManager', 'front_porch.db'));
    await file.parent.create(recursive: true);
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Future schema migrations go here
    },
  );

  // ── Character Queries ───────────────────────────────────────────────

  Future<List<Character>> getAllCharacters() => select(characters).get();

  Stream<List<Character>> watchAllCharacters() => select(characters).watch();

  Future<Character> getCharacterById(int id) =>
      (select(characters)..where((c) => c.id.equals(id))).getSingle();

  Future<Character?> getCharacterByImagePath(String path) =>
      (select(characters)..where((c) => c.imagePath.equals(path))).getSingleOrNull();

  Future<int> insertCharacter(CharactersCompanion character) =>
      into(characters).insert(character);

  Future<bool> updateCharacter(CharactersCompanion character) =>
      update(characters).replace(character);

  Future<int> deleteCharacterById(int id) =>
      (delete(characters)..where((c) => c.id.equals(id))).go();

  // ── Session Queries ─────────────────────────────────────────────────

  Future<List<Session>> getSessionsForCharacter(int characterId) =>
      (select(sessions)
        ..where((s) => s.characterId.equals(characterId))
        ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
      .get();

  Future<List<Session>> getSessionsForGroup(String groupId) =>
      (select(sessions)
        ..where((s) => s.groupId.equals(groupId))
        ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
      .get();

  Future<Session?> getSessionById(String id) =>
      (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> insertSession(SessionsCompanion session) =>
      into(sessions).insert(session);

  Future<int> upsertSession(SessionsCompanion session) =>
      into(sessions).insertOnConflictUpdate(session);

  Future<bool> updateSession(SessionsCompanion session) =>
      update(sessions).replace(session);

  Future<int> deleteSessionById(String id) =>
      (delete(sessions)..where((s) => s.id.equals(id))).go();

  // ── Message Queries ─────────────────────────────────────────────────

  Future<List<Message>> getMessagesForSession(String sessionId) =>
      (select(messages)
        ..where((m) => m.sessionId.equals(sessionId))
        ..orderBy([(m) => OrderingTerm.asc(m.position)]))
      .get();

  Stream<List<Message>> watchMessagesForSession(String sessionId) =>
      (select(messages)
        ..where((m) => m.sessionId.equals(sessionId))
        ..orderBy([(m) => OrderingTerm.asc(m.position)]))
      .watch();

  Future<int> insertMessage(MessagesCompanion message) =>
      into(messages).insert(message);

  Future<void> insertMessages(List<MessagesCompanion> msgs) async {
    await batch((b) => b.insertAll(messages, msgs));
  }

  Future<int> deleteMessagesForSession(String sessionId) =>
      (delete(messages)..where((m) => m.sessionId.equals(sessionId))).go();

  Future<int> deleteMessageById(int id) =>
      (delete(messages)..where((m) => m.id.equals(id))).go();

  Future<void> updateMessage(MessagesCompanion message) async {
    await (update(messages)..where((m) => m.id.equals(message.id.value)))
        .write(message);
  }

  // ── Group Queries ───────────────────────────────────────────────────

  Future<List<Group>> getAllGroups() => select(groups).get();

  Stream<List<Group>> watchAllGroups() => select(groups).watch();

  Future<Group?> getGroupById(String id) =>
      (select(groups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<int> insertGroup(GroupsCompanion group) =>
      into(groups).insert(group);

  Future<bool> updateGroup(GroupsCompanion group) =>
      update(groups).replace(group);

  Future<int> deleteGroupById(String id) =>
      (delete(groups)..where((g) => g.id.equals(id))).go();

  // ── Folder Queries ──────────────────────────────────────────────────

  Future<List<Folder>> getAllFolders() => select(folders).get();

  Future<int> insertFolder(FoldersCompanion folder) =>
      into(folders).insert(folder);

  Future<int> deleteFolderById(int id) =>
      (delete(folders)..where((f) => f.id.equals(id))).go();

  Future<void> updateFolder(FoldersCompanion folder) async {
    await (update(folders)..where((f) => f.id.equals(folder.id.value)))
        .write(folder);
  }

  // ── Persona Queries ─────────────────────────────────────────────────

  Future<List<Persona>> getAllPersonas() => select(personas).get();

  Future<Persona?> getActivePersona() =>
      (select(personas)..where((p) => p.isActive.equals(true))).getSingleOrNull();

  Future<int> insertPersona(PersonasCompanion persona) =>
      into(personas).insert(persona);

  Future<bool> updatePersona(PersonasCompanion persona) =>
      update(personas).replace(persona);

  Future<int> deletePersonaById(String id) =>
      (delete(personas)..where((p) => p.id.equals(id))).go();

  Future<void> setActivePersona(String id) async {
    await transaction(() async {
      // Deactivate all
      await (update(personas)).write(const PersonasCompanion(isActive: Value(false)));
      // Activate the chosen one
      await (update(personas)..where((p) => p.id.equals(id)))
          .write(const PersonasCompanion(isActive: Value(true)));
    });
  }

  // ── World Queries ───────────────────────────────────────────────────

  Future<List<World>> getAllWorlds() => select(worlds).get();

  Stream<List<World>> watchAllWorlds() => select(worlds).watch();

  Future<int> insertWorld(WorldsCompanion world) =>
      into(worlds).insert(world);

  Future<bool> updateWorld(WorldsCompanion world) =>
      update(worlds).replace(world);

  Future<int> deleteWorldById(int id) =>
      (delete(worlds)..where((w) => w.id.equals(id))).go();

  Future<World?> getWorldByName(String name) =>
      (select(worlds)..where((w) => w.name.equals(name))).getSingleOrNull();
}
