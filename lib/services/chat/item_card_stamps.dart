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

import 'package:front_porch_ai/database/database.dart';

import 'journal_physics.dart';
import 'journal_store.dart';
import 'pockets.dart' show sameItem;

/// The rewind stamp for an item-memory card a turn RETIRED.
///
/// Item cards ("I set my car keys down — on the hallway table") are hard
/// deleted the moment a later turn moves the same thing: a pickup clears the
/// placement session-wide, and a new placement supersedes the old one. That is
/// right while the turn stands — one live answer to "where are my keys" — but
/// a delete is not a rewind, and regenerating or deleting that turn used to
/// leave the diary permanently silent about an item the pockets record had
/// correctly put back on the table.
///
/// So the turn carries what it deleted, exactly the way it already carries
/// `pockets_before`: enough of the card to re-plant it (its text, its item, its
/// receipts, its story stamp, its heat) and nothing that would make it a
/// different memory.
class ItemCardStamp {
  final String owner;
  final String item;
  final String content;
  final List<int> positions;
  final int? storyDay;
  final String? storyClock;
  final double heat;
  final bool pinned;

  const ItemCardStamp({
    required this.owner,
    required this.item,
    required this.content,
    this.positions = const [],
    this.storyDay,
    this.storyClock,
    this.heat = 1.0,
    this.pinned = false,
  });

  Map<String, dynamic> toJson() => {
    'char': owner,
    'item': item,
    'content': content,
    if (positions.isNotEmpty) 'positions': positions,
    if (storyDay != null) 'day': storyDay,
    if (storyClock != null) 'clock': storyClock,
    'heat': heat,
    if (pinned) 'pinned': true,
  };

  /// Forgiving by design — the stamp rides message metadata, which older
  /// builds wrote without it and users hand-edit through .fpchat imports.
  static ItemCardStamp? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final owner = raw['char'];
    final item = raw['item'];
    final content = raw['content'];
    if (owner is! String || owner.isEmpty) return null;
    if (item is! String || item.isEmpty) return null;
    if (content is! String || content.isEmpty) return null;
    return ItemCardStamp(
      owner: owner,
      item: item,
      content: content,
      positions: [
        for (final p in (raw['positions'] as List? ?? const []))
          if (p is num) p.toInt(),
      ],
      storyDay: (raw['day'] as num?)?.toInt(),
      storyClock: raw['clock'] as String?,
      heat: (raw['heat'] as num?)?.toDouble() ?? 1.0,
      pinned: raw['pinned'] == true,
    );
  }

  static List<ItemCardStamp> listFrom(Object? raw) => [
    if (raw is List)
      for (final e in raw) ?fromJson(e),
  ];
}

/// Every live item card in [cards] that is about [item] — the ones a retire is
/// about to delete. Same predicate the retire itself uses (item kind + the
/// shared [sameItem] name rule), so a stamp is produced for exactly the cards
/// that disappear, never for a card the retire would have left alone.
List<ItemCardStamp> itemCardStampsFrom(
  Iterable<JournalMemoryData> cards,
  String item,
) {
  if (item.isEmpty) return const [];
  final out = <ItemCardStamp>[];
  for (final card in cards) {
    if (!JournalPhysics.isItemCard(card)) continue;
    final name = JournalPhysics.itemOf(card) ?? '';
    if (!sameItem(name, item)) continue;
    final (day, clock) = JournalStore.stampOf(card);
    out.add(
      ItemCardStamp(
        owner: card.characterId,
        item: name,
        content: card.content,
        positions: _receiptsOf(card),
        storyDay: day,
        storyClock: clock?.toIso8601String(),
        heat: card.heat,
        pinned: card.pinned,
      ),
    );
  }
  return out;
}

/// A card's message-position receipts, forgivingly (the column is a nullable
/// JSON array and a card may legitimately have none).
List<int> _receiptsOf(JournalMemoryData card) {
  final raw = card.sourceMessageIds;
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    return [
      if (decoded is List)
        for (final p in decoded)
          if (p is num) p.toInt(),
    ];
  } catch (_) {
    return const [];
  }
}
