// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Context Budget session column helpers (schema v44).

part of 'database.dart';

/// v43→v44: sessions.context_budget_json for Context Viewer backfill.
Future<void> migrateSessionsContextBudgetV44(AppDatabase db) async {
  try {
    await db.customStatement(
      'ALTER TABLE sessions ADD COLUMN context_budget_json TEXT',
    );
    debugPrint('[DB] v44: added sessions.context_budget_json');
  } catch (_) {
    // already present (re-run / dual-version)
  }
}

extension AppDatabaseContextBudget on AppDatabase {
  Future<void> setContextBudgetJson(
    String sessionId,
    String? contextBudgetJson,
  ) async {
    await customUpdate(
      'UPDATE sessions SET context_budget_json = ? WHERE id = ?',
      variables: [Variable(contextBudgetJson), Variable(sessionId)],
      updates: {sessions},
    );
    await bumpSyncVersion();
  }

  Future<String?> getContextBudgetJson(String sessionId) async {
    final rows = await customSelect(
      'SELECT context_budget_json FROM sessions WHERE id = ?',
      variables: [Variable(sessionId)],
    ).get();
    return rows.isNotEmpty
        ? rows.first.read<String?>('context_budget_json')
        : null;
  }
}
