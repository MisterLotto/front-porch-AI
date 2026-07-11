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

import 'package:flutter/material.dart';

import 'package:front_porch_ai/models/avatar_image.dart';
import 'package:front_porch_ai/services/avatar_gallery.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Overlay controls for the avatar GALLERY ("looks"): ‹ › chevrons pinned
/// bottom-left and a small "n / N" counter centered along the bottom, drawn on
/// top of the sidebar portrait. Shown only in plain chat (expressions off) when
/// there's more than one selectable face.
///
/// Placed as the child of a `Positioned.fill` inside the portrait `Stack`.
/// Pure presentation: it never resolves storage — the parent owns the look list
/// and the flip callback (which flows through ChatService so the portrait
/// repaints). Scrim styling mirrors the existing emotion-badge overlay.
class LookChevronBar extends StatelessWidget {
  const LookChevronBar({
    super.key,
    required this.looks,
    required this.selectedLookId,
    required this.hasLibraryFace,
    required this.onFlip,
  });

  /// The character's gallery looks (already filtered + ordered).
  final List<AvatarImage> looks;

  /// The per-chat selected look id, or null when the library face shows.
  final String? selectedLookId;

  /// Whether the character has a library face (`imagePath`) — when true it joins
  /// the ring as slot 1 so the chevrons can cycle back to the canonical portrait.
  final bool hasLibraryFace;

  /// Flip by delta (-1 previous, +1 next). The parent maps this through
  /// [flipLook] + persists the new selection.
  final ValueChanged<int> onFlip;

  @override
  Widget build(BuildContext context) {
    final total = looks.length + (hasLibraryFace ? 1 : 0);
    final pos = lookRingPosition(
      looks,
      selectedLookId,
      includeLibraryFace: hasLibraryFace,
    );
    // The pills sit on the portrait, so use a dark scrim + always-light
    // foreground in both themes (via resolve, per the theming rule) — same
    // treatment as the emotion-badge overlay next to it.
    final scrim = AppColors.resolve(
      context,
      Colors.black.withValues(alpha: 0.55),
      Colors.black.withValues(alpha: 0.4),
    );
    final fg = AppColors.resolve(context, Colors.white, Colors.white);

    return Stack(
      children: [
        // Chevrons, bottom-left.
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            decoration: BoxDecoration(
              color: scrim,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chevron(Icons.chevron_left, 'Previous look', -1, fg),
                _chevron(Icons.chevron_right, 'Next look', 1, fg),
              ],
            ),
          ),
        ),
        // Counter, centered along the bottom.
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scrim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pos / $total',
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chevron(IconData icon, String tooltip, int delta, Color fg) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: () => onFlip(delta),
        iconSize: 20,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: Icon(icon, color: fg),
      ),
    );
  }
}
