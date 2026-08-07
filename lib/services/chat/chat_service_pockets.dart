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

/// The Pockets & Wardrobe post-generation pass — the one place the eval is
/// fired and its result stored.
///
/// Kept to a single small extension rather than inlined into the six-phase
/// generation pipeline, because the pipeline part is already long and this is
/// self-contained: read the speaker's record, ask what changed, write it back.
extension ChatServicePockets on ChatService {
  /// Runs the detection pass for the speaker who just replied.
  ///
  /// Gated HERE and nowhere else, so there is exactly one place the feature is
  /// switched on. The eval leaf itself consults no settings — that separation
  /// is what stops a second gate appearing somewhere later and disagreeing
  /// with this one.
  Future<void> _runPocketsPass(String reply) async {
    if (!_storageService.realismSettings.pocketsEnabled) return;
    if (reply.trim().isEmpty) return;

    final speaker = _activeCharacter;
    if (speaker == null) return;
    final charId = _getCharacterIdFromCard(speaker);

    // Seed from the card the first time this chat asks: an author who wrote
    // `frontPorchExtensions.inventory` expects her to START with those things,
    // not to acquire them by accident later.
    final record =
        pocketsFor(charId) ??
        Pockets.fromJson(speaker.frontPorchExtensions?.inventory);

    final receipts = await _pocketsEval.evaluateAndApply(
      charName: speaker.name,
      pockets: record,
      reply: reply,
    );

    // Store even when nothing changed: the first turn is what promotes a
    // card-seeded record into the chat, and without this it would be re-seeded
    // (and re-diffed against) every single turn.
    setPocketsFor(charId, record);

    if (receipts.isEmpty) return;

    // Receipts ride the message metadata the same way needs deltas do, so the
    // bubble can show what changed without a second storage path.
    final msg = _messages.isNotEmpty ? _messages.last : null;
    if (msg != null && !msg.isUser) {
      msg.metadata = {...?msg.metadata, 'pocket_changes': receipts};
      await _saveChat();
    }
    notifyListeners();
  }
}
