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
/// Chevrons show whenever there's more than one look in plain chat, regardless
/// of which source is currently displayed.
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

  return LookDisplay(look: selected, showChevrons: looks.length > 1);
}

/// The look id to select when flipping the chevrons by [delta] (+1 next, -1
/// previous) from the currently [selectedLookId], wrapping around. When the
/// current selection isn't a look (the `imagePath` is showing), a forward flip
/// lands on the first look and a backward flip on the last. Null when there are
/// no looks.
String? flipLook(List<AvatarImage> looks, String? selectedLookId, int delta) {
  if (looks.isEmpty) return null;
  final n = looks.length;
  final current = looks.indexWhere((l) => l.id == selectedLookId);
  if (current < 0) {
    // imagePath is showing → step in from the appropriate end.
    return delta >= 0 ? looks.first.id : looks.last.id;
  }
  final next = ((current + delta) % n + n) % n;
  return looks[next].id;
}
