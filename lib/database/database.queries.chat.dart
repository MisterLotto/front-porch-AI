// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Session and message queries (incl. per-chat theme overrides).

part of 'database.dart';

/// Session and message queries (incl. per-chat theme overrides).
extension AppDatabaseChatQueries on AppDatabase {
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

  /// Get the most recent activity time per character (drives the home-screen
  /// "Recent Activity" sort).
  ///
  /// Uses `updated_at`, which `_doSaveChat` bumps to now on every turn — not
  /// `created_at`, which is fixed when the chat is first started. Reading
  /// `created_at` meant "recent" ordered by when each chat was *opened*, so a
  /// character you talked to today inside an older session sank to the bottom.
  Future<Map<String, DateTime>> getLastActivityPerCharacter() async {
    final result = await customSelect(
      'SELECT character_id, MAX(updated_at) AS last_at '
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

  /// Lightweight per-session stats for the session picker: message count,
  /// user-message count, and the SECOND message's swipes/index (the preview
  /// line — the first message is the greeting). Two aggregate queries total,
  /// so listing sessions never hydrates whole transcripts — the old
  /// per-session getMessagesForSession loop made tapping a character
  /// O(sessions × messages) of row decoding before the chat could even open.
  Future<
    Map<
      String,
      ({int count, int userCount, String? previewSwipes, int previewIndex})
    >
  >
  getSessionListStats(List<String> sessionIds) async {
    if (sessionIds.isEmpty) return {};
    final placeholders = List.filled(sessionIds.length, '?').join(',');
    final vars = [for (final id in sessionIds) Variable.withString(id)];
    final counts = await customSelect(
      'SELECT session_id, COUNT(*) AS cnt, '
      'SUM(CASE WHEN is_user = 1 THEN 1 ELSE 0 END) AS user_cnt '
      'FROM messages WHERE session_id IN ($placeholders) '
      'AND deleted_at IS NULL GROUP BY session_id',
      variables: vars,
    ).get();
    final previews = await customSelect(
      'SELECT session_id, swipes, swipe_index FROM ('
      'SELECT session_id, swipes, swipe_index, '
      'ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY position ASC) AS rn '
      'FROM messages WHERE session_id IN ($placeholders) '
      'AND deleted_at IS NULL) WHERE rn = 2',
      variables: [for (final id in sessionIds) Variable.withString(id)],
    ).get();
    final previewBySession = <String, ({String swipes, int index})>{};
    for (final row in previews) {
      previewBySession[row.read<String>('session_id')] = (
        swipes: row.read<String>('swipes'),
        index: row.read<int>('swipe_index'),
      );
    }
    final map =
        <
          String,
          ({int count, int userCount, String? previewSwipes, int previewIndex})
        >{};
    for (final row in counts) {
      final id = row.read<String>('session_id');
      final preview = previewBySession[id];
      map[id] = (
        count: row.read<int>('cnt'),
        userCount: row.read<int?>('user_cnt') ?? 0,
        previewSwipes: preview?.swipes,
        previewIndex: preview?.index ?? 0,
      );
    }
    return map;
  }

  /// Mark a chat's world attachments as decided (see Sessions.worldsInitialized).
  Future<void> markChatWorldsInitialized(String chatId) async {
    await (update(sessions)..where((t) => t.id.equals(chatId)))
        .write(const SessionsCompanion(worldsInitialized: Value(true)));
  }

  /// Whether this chat's world attachments have been decided yet.
  Future<bool> chatWorldsInitialized(String chatId) async {
    final row = await (select(sessions)..where((t) => t.id.equals(chatId)))
        .getSingleOrNull();
    return row?.worldsInitialized ?? false;
  }

  Future<List<Session>> getSessionsForCharacter(String characterId) =>
      (select(sessions)
            ..where(
              (s) => s.characterId.equals(characterId) & s.deletedAt.isNull(),
            )
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

  /// Partial-update a session — only writes fields that are explicitly set
  /// (Value.present). Safe to call without providing the full row.
  Future<bool> patchSession(SessionsCompanion session) async {
    final rows = await (update(
      sessions,
    )..where((s) => s.id.equals(session.id.value))).write(session);
    await bumpSyncVersion();
    return rows > 0;
  }

  /// Set (or clear, with null) the per-chat avatar-gallery look for a session.
  /// Partial write — touches only [Sessions.selectedLookAvatarId].
  Future<void> setSelectedLookForSession(String sessionId, String? avatarId) =>
      patchSession(
        SessionsCompanion(
          id: Value(sessionId),
          selectedLookAvatarId: Value(avatarId),
        ),
      );

  /// Save per-chat theme overrides JSON for a session — raw SQL so no
  /// build_runner regeneration is needed.
  Future<void> setThemeOverrides(
    String sessionId,
    String? themeOverridesJson,
  ) async {
    await customUpdate(
      'UPDATE sessions SET theme_overrides = ? WHERE id = ?',
      variables: [Variable(themeOverridesJson), Variable(sessionId)],
      updates: {sessions},
    );
    await bumpSyncVersion();
  }

  /// Load per-chat theme overrides JSON for a session.
  Future<String?> getThemeOverrides(String sessionId) async {
    final rows = await customSelect(
      'SELECT theme_overrides FROM sessions WHERE id = ?',
      variables: [Variable(sessionId)],
    ).get();
    return rows.isNotEmpty ? rows.first.read<String?>('theme_overrides') : null;
  }

  /// Get the theme_overrides from the most recent non-deleted session for a
  /// given character or group. Used by startNewChat to inherit the previous
  /// chat's theme when starting a fresh session.
  Future<String?> getLastSessionThemeOverrides({
    String? characterId,
    String? groupId,
  }) async {
    final column = characterId != null ? 'character_id' : 'group_id';
    final id = characterId ?? groupId;
    if (id == null) return null;
    // Only sessions that actually CARRY a theme: created_at is stored at
    // second resolution, so two sessions made back-to-back tie on the sort
    // and "DESC LIMIT 1" picked an arbitrary one — if that was a fresh
    // themeless session, the inherited theme silently came back null (seen
    // as a CI-order flake in theme_overrides_test). Filtering to themed
    // sessions matches the intent ("the last theme the user actually used")
    // and rowid breaks any remaining same-second tie by insertion order.
    final rows = await customSelect(
      'SELECT theme_overrides FROM sessions WHERE $column = ? '
      'AND deleted_at IS NULL AND theme_overrides IS NOT NULL '
      'ORDER BY created_at DESC, rowid DESC LIMIT 1',
      variables: [Variable(id)],
    ).get();
    return rows.isNotEmpty ? rows.first.read<String?>('theme_overrides') : null;
  }

  Future<int> deleteSessionById(String id) async {
    // Hard delete: also delete all messages + journal cards + growth rings in
    // this session. (Journal cards and growth rings are strictly
    // session-scoped, so they die with the chat.)
    await (delete(messages)..where((m) => m.sessionId.equals(id))).go();
    await (delete(journalMemories)..where((j) => j.sessionId.equals(id))).go();
    await (delete(growthRings)..where((g) => g.sessionId.equals(id))).go();
    await (delete(growthState)..where((g) => g.sessionId.equals(id))).go();
    final count = await (delete(sessions)..where((s) => s.id.equals(id))).go();
    await bumpSyncVersion();
    return count;
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
    final withIds = msgs
        .map((m) => m.id.present ? m : m.copyWith(id: Value(_uuid.v4())))
        .toList();
    await batch((b) => b.insertAll(messages, withIds));
    await bumpSyncVersion();
  }

  Future<int> deleteMessagesForSession(String sessionId) async {
    final count = await (delete(
      messages,
    )..where((m) => m.sessionId.equals(sessionId))).go();
    await bumpSyncVersion();
    return count;
  }

  Future<int> deleteMessageById(String id) async {
    final count = await (delete(messages)..where((m) => m.id.equals(id))).go();
    await bumpSyncVersion();
    return count;
  }

  Future<void> updateMessage(MessagesCompanion message) async {
    await (update(
      messages,
    )..where((m) => m.id.equals(message.id.value))).write(message);
    await bumpSyncVersion();
  }
}
