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

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/pockets.dart';
import 'speaker_resolution.dart';

/// Pockets & Wardrobe fragment — what the speaker is wearing and carrying,
/// told to the model every turn.
///
/// This is the half that makes the record worth keeping. An inventory nobody
/// reads is a database; injected, it is the difference between a character who
/// is still holding the keys she picked up forty messages ago and one who is
/// mysteriously empty-handed the moment the prose scrolled away.
///
/// Gated by the caller on the Pockets switch alone — no Realism, no Needs, no
/// Journal, no Objectives. That independence is the settled ruling, not an
/// accident, and it is the reason this leaf takes no engine callbacks: there is
/// nothing here for a second switch to gate.
///
/// Per-speaker in groups via the shared [SpeakerCardResolver], the same
/// resolution every other identity fragment uses, so a group member is
/// described with THEIR pockets rather than whoever happens to be active.
class InventoryInjection with SpeakerCardResolver {
  @override
  final bool Function() getIsGroupNonObserverMode;
  @override
  final String Function() getCurrentSpeakerIdForRealism;
  @override
  final List<CharacterCard> Function() getGroupCharacters;
  @override
  final String Function(CharacterCard) getCharacterIdFromCard;
  @override
  final CharacterCard? Function() getActiveCharacter;

  /// The speaker's record for THIS chat, by the same character id the rest of
  /// the per-speaker state uses.
  final Pockets? Function(String characterId) getPockets;

  InventoryInjection({
    required this.getIsGroupNonObserverMode,
    required this.getCurrentSpeakerIdForRealism,
    required this.getGroupCharacters,
    required this.getCharacterIdFromCard,
    required this.getActiveCharacter,
    required this.getPockets,
  });

  /// Hard ceiling on the fragment, so a scene that accumulated a lot of clutter
  /// cannot quietly eat the context budget. The per-list caps in pockets.dart
  /// already bound the count; this bounds the characters.
  static const maxChars = 320;

  String buildInventoryInjection() {
    final card = speakerCard();
    if (card == null) return '';
    final p = getPockets(getCharacterIdFromCard(card));
    if (p == null || p.isEmpty) return '';

    final parts = [
      if (p.worn.isNotEmpty)
        'wearing ${p.worn.map((i) => i.display).join(', ')}',
      if (p.carrying.isNotEmpty)
        'carrying ${p.carrying.map((i) => i.display).join(', ')}',
    ];
    if (parts.isEmpty) return '';

    // Stated as fact rather than instruction. "Keep this consistent" invites a
    // model to narrate an inventory check; naming what she has lets it simply
    // be true, which is what the feature is for.
    final out = '${card.name} is ${parts.join('; ')}.';
    return out.length <= maxChars ? out : '${out.substring(0, maxChars)}…';
  }
}
