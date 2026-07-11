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

import 'package:front_porch_ai/models/avatar_image.dart';

/// Pure resolution for the per-character avatar GALLERY ("looks"). Kept
/// deliberately free of I/O and of where the per-chat selection is STORED — it
/// takes the selected-look id as an input — so it's trivially unit-testable and
/// decoupled from the `sessions` column decision.
///
/// Product contract (agreed with the maintainer + Grok): the look COLLECTION is
/// global per character; which look is SHOWING is per chat. Chevrons appear only
/// in plain chat (expression images off) when there's more than one look. Looks
/// never enter the emotion pipeline. Selecting a look must never rewrite the
/// character's `imagePath` (the library face stays put on the home grid).

/// The gallery looks among [avatarImages] (isLook), ordered by displayOrder.
/// Expression images are filtered out.
List<AvatarImage> looksFrom(List<AvatarImage>? avatarImages) =>
    (avatarImages ?? const <AvatarImage>[]).where((a) => a.isLook).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

/// The expression images among [avatarImages] (NOT looks). The emotion pipeline
/// must resolve through this so a gallery look can never be picked as an
/// expression (Grok must-fix: partition looks out of the expression system).
List<AvatarImage> expressionsFrom(List<AvatarImage>? avatarImages) =>
    (avatarImages ?? const <AvatarImage>[]).where((a) => !a.isLook).toList();

/// What the chat sidebar should show in plain chat, plus whether to offer the
/// look chevrons.
class LookDisplay {
  /// The look to show, or null → fall back to the character's `imagePath`.
  final AvatarImage? look;

  /// Whether to render the ‹ › chevrons (more than one look, plain chat).
  final bool showChevrons;

  const LookDisplay({required this.look, required this.showChevrons});

  /// Nothing to override (expressions on, or no looks) — caller uses its normal
  /// portrait/expression path.
  static const LookDisplay passthrough = LookDisplay(
    look: null,
    showChevrons: false,
  );

  @override
  bool operator ==(Object other) =>
      other is LookDisplay &&
      other.look?.id == look?.id &&
      other.showChevrons == showChevrons;

  @override
  int get hashCode => Object.hash(look?.id, showChevrons);
}

/// Resolve the plain-chat portrait choice.
///
/// - Expressions ON → [LookDisplay.passthrough]: the emotion pipeline owns the
///   face, no look, no chevrons.
/// - Expressions OFF → the per-chat [selectedLookId] if it STILL exists → else
///   the character's `imagePath` (signalled by [hasImagePath]) → else the first
///   look. A stale/deleted selection falls through instead of blanking the face.
///
/// Chevrons show whenever the ring has more than one selectable face — i.e. the
/// looks plus the library face (`imagePath`) when present. This matches
/// [flipLook]'s `includeLibraryFace` ring, so a single look alongside a library
/// portrait is still reachable (you can toggle between the two).
LookDisplay resolveLookDisplay({
  required bool expressionEnabled,
  required List<AvatarImage> looks,
  required bool hasImagePath,
  String? selectedLookId,
}) {
  if (expressionEnabled) return LookDisplay.passthrough;

  AvatarImage? selected;
  if (selectedLookId != null) {
    for (final l in looks) {
      if (l.id == selectedLookId) {
        selected = l;
        break;
      }
    }
  }
  // No valid selection: prefer the library face (imagePath); only fall to the
  // first look when there's no imagePath at all.
  if (selected == null && !hasImagePath && looks.isNotEmpty) {
    selected = looks.first;
  }

  final ringSize = looks.length + (hasImagePath ? 1 : 0);
  return LookDisplay(look: selected, showChevrons: ringSize > 1);
}

/// Decode the per-chat look selection stored (JSON) in the session's
/// `selectedLookAvatarId` column into a `{characterId: lookAvatarId}` map.
///
/// The map (not a single id) is what lets a GROUP chat remember a distinct look
/// per participant while 1:1 is just a one-entry map — one code path, group
/// parity by construction (mirrors the existing `group_realism_state` house
/// style). Deliberately defensive: null / empty / malformed / non-map / bad
/// entries all collapse to an empty map and this NEVER throws, so a corrupt
/// column can't blank the portrait.
Map<String, String> decodeSelectedLooks(String? raw) {
  if (raw == null || raw.isEmpty) return <String, String>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, String>{};
    final out = <String, String>{};
    decoded.forEach((k, v) {
      if (k is String && v is String && k.isNotEmpty && v.isNotEmpty) {
        out[k] = v;
      }
    });
    return out;
  } catch (_) {
    return <String, String>{};
  }
}

/// Encode the per-chat look selection map back to JSON for storage. An empty
/// map encodes to `null` so the column clears (never stores a bare `{}`).
String? encodeSelectedLooks(Map<String, String> selection) =>
    selection.isEmpty ? null : jsonEncode(selection);

/// The look id to select when flipping the chevrons by [delta] (+1 next, -1
/// previous) from the currently [selectedLookId], wrapping around. Null → the
/// character's library face (`imagePath`) should show.
///
/// With [includeLibraryFace] (set when the character HAS an `imagePath`), the
/// ring is `[library face, look0, look1, …]` of N+1 slots, so the chevrons can
/// always cycle back to the canonical portrait (returns null for that slot).
/// Without it (no library face), the ring is just the N looks and a flip from a
/// non-look state steps in from the appropriate end.
String? flipLook(
  List<AvatarImage> looks,
  String? selectedLookId,
  int delta, {
  bool includeLibraryFace = false,
}) {
  if (looks.isEmpty) return null;
  if (includeLibraryFace) {
    final n = looks.length + 1; // slot 0 = library face
    final atLook = looks.indexWhere((l) => l.id == selectedLookId);
    final current = (selectedLookId == null || atLook < 0) ? 0 : atLook + 1;
    final next = ((current + delta) % n + n) % n;
    return next == 0 ? null : looks[next - 1].id;
  }
  final n = looks.length;
  final current = looks.indexWhere((l) => l.id == selectedLookId);
  if (current < 0) {
    // No library face and nothing selected → step in from the appropriate end.
    return delta >= 0 ? looks.first.id : looks.last.id;
  }
  final next = ((current + delta) % n + n) % n;
  return looks[next].id;
}

/// 1-based position of the currently shown face in the chevron ring, for the
/// counter. Mirrors [flipLook]: with [includeLibraryFace] the library face is
/// slot 1 and looks are 2..N+1; otherwise looks are 1..N. A null or stale
/// selection resolves to the first shown face (slot 1).
int lookRingPosition(
  List<AvatarImage> looks,
  String? selectedLookId, {
  bool includeLibraryFace = false,
}) {
  final i = looks.indexWhere((l) => l.id == selectedLookId);
  if (selectedLookId == null || i < 0) return 1;
  return includeLibraryFace ? i + 2 : i + 1;
}
