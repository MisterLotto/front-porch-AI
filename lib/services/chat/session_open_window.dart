// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

/// First paint of a chat: last [kSessionOpenWindow] rows, then older
/// rows page in on the UI isolate in [kSessionOlderPage] chunks with a
/// yield between pages so the chat screen stays live.
const kSessionOpenWindow = 24;
const kSessionOlderPage = 200;

/// In-memory suffix of a session while older rows are still loading.
///
/// Persist MUST write [basePosition] + index, never the raw index: a
/// 24-row snapshot saved as positions 0–23 would overwrite the start of
/// a long chat. [upsertMessagesPreservingTail] only protects positions
/// *past* the snapshot, not under it.
class SessionHistoryWindow {
  int basePosition = 0;
  int epoch = 0;
  Future<void>? backfill;
  bool hasMore = false;

  bool get isBackfilling => backfill != null;

  void reset() {
    epoch++;
    backfill = null;
    basePosition = 0;
    hasMore = false;
  }
}

/// DB `position` for in-memory index [index] of a (possibly windowed) list.
int persistMessagePosition({required int base, required int index}) =>
    base + index;
