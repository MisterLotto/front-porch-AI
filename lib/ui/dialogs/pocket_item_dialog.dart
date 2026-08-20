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

import 'package:front_porch_ai/services/chat/chat.dart' show PocketSection;
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// What the add-item dialog hands back to its caller.
typedef PocketItemAdd = ({String name, PocketSection section, bool gift});

/// Add one item to a character's Pockets & Wardrobe by hand — the other half
/// of the ✕ eraser, with the two fictions kept honest by the two buttons:
///
///  * **Hand to them** — the user gives it in-scene; it lands in their hands
///    and the next reply has them accept it knowing where it came from.
///  * **Add quietly** — the Easter egg: the item appears out-of-band in the
///    chosen section, and the next reply has them SURPRISED by something they
///    cannot account for ("how did I end up with this?").
///
/// Item text follows the same "name (state)" chip convention the character
/// editor and the sidebar row already teach — nothing new to learn.
Future<PocketItemAdd?> showPocketItemDialog(
  BuildContext context, {
  required String characterName,
}) {
  return showDialog<PocketItemAdd>(
    context: context,
    builder: (context) => _PocketItemDialog(characterName: characterName),
  );
}

class _PocketItemDialog extends StatefulWidget {
  final String characterName;

  const _PocketItemDialog({required this.characterName});

  @override
  State<_PocketItemDialog> createState() => _PocketItemDialogState();
}

class _PocketItemDialogState extends State<_PocketItemDialog> {
  final _controller = TextEditingController();
  PocketSection _section = PocketSection.carrying;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit({required bool gift}) {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, section: _section, gift: gift));
  }

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.porchAmberOf(context);
    return AlertDialog(
      backgroundColor: AppColors.surfaceOf(context),
      title: Text(
        'Add an item',
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary(context)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary(context),
            ),
            decoration: InputDecoration(
              hintText: 'brass key (scuffed)',
              hintStyle: TextStyle(color: AppColors.textTertiary(context)),
              isDense: true,
            ),
            onSubmitted: (_) => _submit(gift: false),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final (label, section) in const [
                ('Wearing', PocketSection.worn),
                ('Carrying', PocketSection.carrying),
                ('Set aside', PocketSection.setAside),
              ])
                ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  selected: _section == section,
                  selectedColor: amber.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _section = section),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"Hand to ${widget.characterName}" gives it in-scene — they\'ll '
            'know it came from you. "Add quietly" slips it in; they\'ll be '
            'surprised to find it.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
        TextButton(
          onPressed: () => _submit(gift: false),
          child: Text('Add quietly', style: TextStyle(color: amber)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: amber,
            foregroundColor: AppColors.onChaosAccent,
          ),
          onPressed: () => _submit(gift: true),
          child: Text('Hand to ${widget.characterName}'),
        ),
      ],
    );
  }
}
