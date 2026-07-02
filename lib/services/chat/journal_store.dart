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

import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:front_porch_ai/database/database.dart';

/// The Journal — card persistence (docs/design/journal-memory.md §5).
///
/// Plain leaf owning the DB half of the shared ops applier. Cards are
/// strictly scoped per (sessionId, characterId) — no read or write ever
/// crosses chats; deleting a chat cascades in [AppDatabase.deleteSessionById].
///
/// Holds the database via a closure (not a constructor value) because
/// ChatService receives its AppDatabase post-construction via setDatabase and
/// the leaves are `late final` fields. Direct DB access mirrors MemoryService/
/// CharacterRepository (callbacks are reserved for mutable god *state*).
///
/// No bumpSyncVersion on writes, matching the MessageEmbeddings precedent
/// (derived, session-local data).
class JournalStore {
  final AppDatabase? Function() getDb;

  JournalStore({required this.getDb});

  /// All cards for one diary owner in one chat — pinned first, then oldest
  /// first. This exact order is what the maintenance prompt numbers its
  /// 1-based handles by and what the injection builder renders, so the three
  /// surfaces always agree.
  Future<List<JournalMemoryData>> cardsFor(
    String sessionId,
    String characterId,
  ) async {
    final db = getDb();
    if (db == null) return const [];
    return db.getJournalCards(sessionId, characterId);
  }

  /// Insert a new memory. Enforces the per-owner cap by retiring the oldest
  /// unpinned card first (phase 1 heat is uniform, so oldest-unpinned is the
  /// coldest; phase 2 will switch this to lowest-heat). The raw transcript
  /// stays in RAG, so a trimmed card is a demotion, not a loss.
  Future<void> addCard({
    required String sessionId,
    required String characterId,
    required String content,
    required String category,
    String? emotionLabel,
    String? emotionIntensity,
    List<int> sourcePositions = const [],
    required int maxCards,
  }) async {
    final db = getDb();
    if (db == null) return;
    final existing = await db.getJournalCards(sessionId, characterId);
    if (existing.length >= maxCards) {
      // getJournalCards orders pinned DESC then createdAt ASC, so the first
      // unpinned entry is the oldest unpinned card.
      for (final card in existing) {
        if (!card.pinned) {
          await db.deleteJournalCard(card.id);
          break;
        }
      }
    }
    await db.insertJournalCard(
      // id deliberately absent — filled by insertJournalCard (UUID).
      JournalMemoriesCompanion(
        sessionId: Value(sessionId),
        characterId: Value(characterId),
        content: Value(content),
        category: Value(category),
        emotionLabel: Value(emotionLabel),
        emotionIntensity: Value(emotionIntensity),
        sourceMessageIds: Value(
          sourcePositions.isEmpty ? null : jsonEncode(sourcePositions),
        ),
      ),
    );
  }

  /// Edit a card in place. On the first feeling change the original emotion
  /// is preserved in originalEmotionLabel ("feelings that heal" — the diary
  /// can show "once felt sad, now feels proud").
  Future<void> reviseCard(
    JournalMemoryData card, {
    String? content,
    String? feeling,
  }) async {
    final db = getDb();
    if (db == null) return;
    final feelingChanged =
        feeling != null && feeling.isNotEmpty && feeling != card.emotionLabel;
    await db.updateJournalCard(
      card.id,
      JournalMemoriesCompanion(
        content: content != null && content.isNotEmpty
            ? Value(content)
            : const Value.absent(),
        emotionLabel: feelingChanged ? Value(feeling) : const Value.absent(),
        originalEmotionLabel:
            feelingChanged && card.originalEmotionLabel == null
            ? Value(card.emotionLabel)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> retireCard(String id) async {
    await getDb()?.deleteJournalCard(id);
  }

  Future<void> setPinned(String id, bool pinned) async {
    final db = getDb();
    if (db == null) return;
    await db.updateJournalCard(
      id,
      JournalMemoriesCompanion(
        pinned: Value(pinned),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
