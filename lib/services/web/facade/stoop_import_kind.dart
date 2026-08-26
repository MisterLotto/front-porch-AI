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

/// How a Stoop download should import.
///
/// Payload type (backend) wins over the client hint. A `SOLO` label — the
/// default the phone always sends — is upgraded when the card is a world
/// envelope or a group; otherwise the WORLD-shape fallback never ran, because
/// the PWA always POSTs `type`.
String stoopImportKind({
  String? clientType,
  String? payloadType,
  Map<String, dynamic>? card,
}) {
  var kind = _normType(payloadType) ?? _normType(clientType);
  if (card != null) {
    if (stoopCardLooksLikeWorld(card) && (kind == null || kind == 'SOLO')) {
      return 'WORLD';
    }
    if (_hasMembers(card) && (kind == null || kind == 'SOLO')) {
      return 'GROUP';
    }
  }
  return kind ?? 'SOLO';
}

/// True when [card] is a `.fpworld` envelope rather than a V2 character or
/// group card. Character lorebooks use `character_book`; worlds use `biome`
/// / `place_traits` / a top-level `lorebook`.
bool stoopCardLooksLikeWorld(Map<String, dynamic> card) {
  if (_hasMembers(card)) return false;
  if (card.containsKey('first_mes') || card.containsKey('personality')) {
    return false;
  }
  return card.containsKey('biome') ||
      card.containsKey('place_traits') ||
      card['lorebook'] is Map;
}

bool _hasMembers(Map<String, dynamic> card) =>
    card.containsKey('members') || card.containsKey('raw_member_data');

String? _normType(String? raw) {
  if (raw == null) return null;
  final u = raw.trim().toUpperCase();
  if (u == 'SOLO' || u == 'GROUP' || u == 'WORLD') return u;
  return null;
}
