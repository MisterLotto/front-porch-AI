// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/app_text_field.dart';
import 'package:front_porch_ai/ui/widgets/greeting_seed_form.dart';
import 'package:front_porch_ai/ui/widgets/styled_text_controller.dart';

/// Alternate greetings + Realism/Needs opening seeds for a **custom group
/// first_message**. Same picker the 1:1 bubble uses, stored on the group blob.
class GroupAlternateGreetingsEditor extends StatefulWidget {
  final List<String> greetings;
  final List<GreetingRealismSeed?> seeds;
  final void Function(List<String> greetings, List<GreetingRealismSeed?> seeds)
  onChanged;
  final bool showNeeds;

  const GroupAlternateGreetingsEditor({
    super.key,
    required this.greetings,
    required this.seeds,
    required this.onChanged,
    this.showNeeds = true,
  });

  @override
  State<GroupAlternateGreetingsEditor> createState() =>
      _GroupAlternateGreetingsEditorState();
}

class _GroupAlternateGreetingsEditorState
    extends State<GroupAlternateGreetingsEditor> {
  late List<StyledTextController> _controllers;
  late List<GreetingRealismSeed?> _seeds;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  void _syncFromWidget() {
    _controllers = [
      for (final g in widget.greetings)
        StyledTextController(preset: StyledTextPreset.prose, text: g),
    ];
    _seeds = alignGreetingSeeds(widget.seeds, _controllers.length);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged([
      for (final c in _controllers) c.text,
    ], List<GreetingRealismSeed?>.from(_seeds));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.swap_horiz,
              color: AppColors.porchHoneyOf(context),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Alternate Greetings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _controllers.add(
                    StyledTextController(preset: StyledTextPreset.prose),
                  );
                  _seeds.add(null);
                });
                _emit();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        Text(
          'Used when this group has its own opening line. Leave the first '
          'message blank to use the first member\'s greetings instead.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary(context),
          ),
        ),
        if (_controllers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No alternate greetings yet',
              style: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 13,
              ),
            ),
          ),
        for (var i = 0; i < _controllers.length; i++) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _controllers[i],
                  maxLines: 4,
                  onChanged: (_) => _emit(),
                  decoration: InputDecoration(
                    labelText: 'Greeting ${i + 2}',
                    hintText: 'Another way the scene opens...',
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _controllers[i].dispose();
                    _controllers.removeAt(i);
                    _seeds.removeAt(i);
                  });
                  _emit();
                },
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: AppColors.negativeAccentOf(context),
                  size: 20,
                ),
                tooltip: 'Remove greeting',
              ),
            ],
          ),
          GreetingSeedForm(
            seed: i < _seeds.length ? _seeds[i] : null,
            showNeeds: widget.showNeeds,
            showInventory: true,
            onChanged: (next) {
              setState(() {
                while (_seeds.length <= i) {
                  _seeds.add(null);
                }
                _seeds[i] = next;
              });
              _emit();
            },
          ),
        ],
      ],
    );
  }
}
