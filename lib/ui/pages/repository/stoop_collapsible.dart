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

import 'stoop_glass.dart';

TextStyle stoopSectionTitleStyle(BuildContext context) =>
    stoopDisplay(context, size: 16.5, weight: FontWeight.w600);

/// The Stoop card panel's collapsible section shell, in its own leaf.
///
/// It lived in stoop_card_sections.dart, which the identity sections then had
/// to import while stoop_card_sections imported them back — a genuine import
/// cycle (Grok, 2026-08-07). Dart tolerates cycles; they still make both files
/// impossible to reason about alone and break the moment either is split
/// again. The shared widget belongs below both, not inside one of them.

/// A titled, default-collapsed section matching the panel's type styling.
class StoopCollapsible extends StatelessWidget {
  final String title;
  final Widget? child;
  final bool initiallyExpanded;

  const StoopCollapsible({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (child == null) return const SizedBox.shrink();
    // Hub .hub-sect: a bordered card row whose disclosure marker is amber.
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        gradient: stoopCardGradient(context),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: stoopBorder(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          initiallyExpanded: initiallyExpanded,
          iconColor: stoopAmberText(context),
          collapsedIconColor: stoopAmberText(context),
          title: Text(title, style: stoopSectionTitleStyle(context)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            Align(alignment: Alignment.centerLeft, child: child!),
          ],
        ),
      ),
    );
  }
}
