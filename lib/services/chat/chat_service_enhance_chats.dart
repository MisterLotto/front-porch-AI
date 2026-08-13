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

part of '../chat_service.dart';

/// AI Enhance's "bring your chats along" step: copy every 1:1 chat of the
/// BASE character onto the freshly saved "(Enhanced)" copy.
///
/// Deliberately a round-trip through the `.fpchat` exporter/importer
/// (maintainer direction, 2026-08-13) rather than a hand-rolled row copier:
/// the codec already carries messages, swipes, realism stamps, journal
/// cards, growth rings, objectives and images, the importer seeds live
/// realism so the copies cannot bleed into each other, and its background
/// RAG backfill re-embeds the copied history — a second implementation of
/// any of that would be exactly the parallel path the project bans.
extension ChatServiceEnhanceChats on ChatService {
  /// Copies every chat of [from] onto [to]; returns how many were copied.
  ///
  /// Two phases with ONE active-card flip each way: export every session
  /// under [from], then import each package under [to]. The packages name
  /// the BASE character, so the importer's mismatch callback answers
  /// "continue" — the enhanced copy IS that character, and the whole point
  /// is keeping the stamps. Imports run oldest-first so the newest chat is
  /// the one left OPEN under [to] when the copy finishes — the user lands
  /// in the enhanced character exactly where they left the original.
  ///
  /// Throws [ChatImportBusy] when a turn is live (same contract as
  /// [importChatPackage]); the caller owns surfacing that.
  Future<int> copyChatsForEnhance({
    required CharacterCard from,
    required CharacterCard to,
    void Function(int done, int total)? onProgress,
  }) async {
    // Guard BEFORE the export phase, not just inside importChatPackage:
    // phase 1 flips the active character/session, which must never happen
    // under a reply that is still streaming or settling.
    if (_isTurnBusy) throw ChatImportBusy();
    final sessions = await getSessionsForId(from.stableGroupId);
    if (sessions.isEmpty) return 0;

    // Phase 1 — export under the base card. Newest-first as listed; kept in
    // memory (each package is independently bounded by the codec's own
    // uncompressed ceiling, and a typical character has a handful of chats).
    final packages = <Uint8List>[];
    await setActiveCharacter(from);
    for (final s in sessions) {
      await loadSession(s['id'] as String);
      final bytes = await exportToFpchat();
      if (bytes != null) packages.add(bytes);
    }

    // Phase 2 — import under the enhanced card, oldest-first (see doc).
    await setActiveCharacter(to);
    var copied = 0;
    for (final bytes in packages.reversed) {
      final result = await importChatPackage(
        bytes,
        onCharacterMismatch: (_, _) async => true,
      );
      if (result.fullRestore) copied++;
      onProgress?.call(copied, packages.length);
    }
    return copied;
  }
}
