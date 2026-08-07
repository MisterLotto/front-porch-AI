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

import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// A short list of short phrases, edited as chips — the shape the approved
/// Porch Life sketch uses for Ambitions and (next) Likes & Dislikes.
///
/// Why chips rather than the newline-separated TextField this replaced: the
/// old field asked the author to encode a list as text and hoped they read
/// "(one per line)". A blank line, a trailing space, or a paragraph pasted in
/// all produced silently wrong entries, and nothing on screen said how many
/// items you actually had. Chips make the unit of entry visible, so the cap
/// and the count can be honest.
///
/// Deliberately generic: [accent] is the only visual variation (the sketch
/// draws ambitions amber-bordered and preference chips plain), so Likes &
/// Dislikes can reuse this without a second widget.
class ChipListEditor extends StatefulWidget {
  const ChipListEditor({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    this.helper,
    this.hintText = 'Type and press enter',
    this.maxItems = 8,
    this.maxChars = 80,
    this.accent = false,
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  /// One line under the label explaining what the list is FOR. The sketch
  /// carries this copy for every chip list, and it is where the
  /// identity-not-quests distinction gets said.
  final String? helper;

  final String hintText;
  final int maxItems;
  final int maxChars;

  /// Amber-bordered chips (the sketch's treatment for Ambitions) instead of
  /// the plain inset used for ordinary preference lists.
  final bool accent;

  @override
  State<ChipListEditor> createState() => _ChipListEditorState();
}

class _ChipListEditorState extends State<ChipListEditor> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _full => widget.values.length >= widget.maxItems;

  void _commit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    // Case-insensitive dedup: "Open a bakery" and "open a bakery" are the same
    // ambition to every consumer of this list, and two of them would be
    // injected into the prompt twice.
    final exists = widget.values.any(
      (v) => v.toLowerCase() == raw.toLowerCase(),
    );
    if (!exists && !_full) {
      widget.onChanged([...widget.values, raw]);
    }
    _controller.clear();
    // Stay open for rapid entry — these lists are usually written in one go.
    if (_full) setState(() => _adding = false);
  }

  void _remove(String value) =>
      widget.onChanged(widget.values.where((v) => v != value).toList());

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.porchAmberOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.textTertiary(context),
              ),
            ),
            const Spacer(),
            // The count is only interesting as you approach the cap; showing
            // "0 of 8" on an empty list reads as a chore.
            if (widget.values.isNotEmpty)
              Text(
                '${widget.values.length} of ${widget.maxItems}',
                style: TextStyle(
                  fontSize: 11,
                  color: _full ? amber : AppColors.textTertiary(context),
                ),
              ),
          ],
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helper!,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final v in widget.values)
              _Chip(value: v, accent: widget.accent, onRemove: () => _remove(v)),
            if (_adding && !_full)
              SizedBox(
                width: 210,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  maxLength: widget.maxChars,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary(context),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary(context),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: amber.withValues(alpha: .5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: amber),
                    ),
                  ),
                  onSubmitted: (_) => _commit(),
                  onTapOutside: (_) {
                    _commit();
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  onEditingComplete: _commit,
                ),
              )
            else if (!_full)
              _AddChip(onTap: () => setState(() => _adding = true)),
          ],
        ),
        if (_full) ...[
          const SizedBox(height: 6),
          Text(
            'That is the most this list holds — remove one to add another.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary(context)),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.value,
    required this.accent,
    required this.onRemove,
  });

  final String value;
  final bool accent;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.porchAmberOf(context);
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerOf(context),
        border: Border.all(
          color: accent ? amber.withValues(alpha: .55) : AppColors.borderOf(context),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            color: AppColors.textTertiary(context),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.porchAmberOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: amber.withValues(alpha: .55)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '+ add',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: amber,
            ),
          ),
        ),
      ),
    );
  }
}
