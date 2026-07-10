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

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/image_prompt/expression_prompts.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/utils/utils.dart';

/// Step 1 of the Expression-pack dialog: the setup form. Owns its own local
/// choices (set size, variation strength, replace-existing, optional
/// vision-described portrait grounding) and reports them once on Start; the
/// dialog then builds the generation session from them.
class ExpressionPackSetup extends StatefulWidget {
  const ExpressionPackSetup({
    super.key,
    required this.baseImage,
    required this.characterName,
    required this.onCancel,
    required this.onStart,
    required this.onDescribePortrait,
  });

  final Uint8List baseImage;
  final String characterName;
  final VoidCallback onCancel;
  final void Function({
    required bool fullSet,
    required double denoise,
    required bool replaceExisting,
    String? appearanceDetail,
  })
  onStart;

  /// Dialog-owned "describe the base portrait with the vision model" call.
  /// Returns the description on success, null when the call failed (this form
  /// shows its inline error), or '' when the dialog already explained the
  /// problem itself (vision-incapable model — no extra error here).
  final Future<String?> Function() onDescribePortrait;

  @override
  State<ExpressionPackSetup> createState() => _ExpressionPackSetupState();
}

class _ExpressionPackSetupState extends State<ExpressionPackSetup> {
  bool _fullSet = false;
  double _denoise = 0.5;
  bool _replaceExisting = true;
  bool _describing = false;
  String? _appearanceDetail;
  bool _addToPrompt = true;
  String? _describeError;

  Future<void> _describe() async {
    setState(() {
      _describing = true;
      _describeError = null;
    });
    final result = await widget.onDescribePortrait();
    if (!mounted) return;
    setState(() {
      _describing = false;
      if (result == null) {
        _describeError = 'Couldn\'t get a description — try again or skip it.';
      } else if (result.isNotEmpty) {
        _appearanceDetail = result;
        _addToPrompt = true;
      }
      // result == '' → the dialog already showed the "no vision model"
      // explanation; nothing more to say here.
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = (_fullSet ? kFullExpressionSet : kCuratedExpressionSet)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                widget.baseImage,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Every emotion is generated from this base portrait, so the '
                'whole pack stays recognizably ${widget.characterName}.',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _portraitGrounding(context),
        const SizedBox(height: 16),
        _setChoice(
          context,
          selected: !_fullSet,
          title: 'Starter (${kCuratedExpressionSet.length} emotions)',
          subtitle: 'the essentials, quick to generate',
          emotions: kCuratedExpressionSet,
          onTap: () => setState(() => _fullSet = false),
        ),
        const SizedBox(height: 8),
        _setChoice(
          context,
          selected: _fullSet,
          title: 'Full (${kFullExpressionSet.length} emotions)',
          subtitle: 'every expression the chat can show',
          emotions: kFullExpressionSet,
          onTap: () => setState(() => _fullSet = true),
        ),
        const SizedBox(height: 16),
        Text(
          'Variation strength',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _denoise,
                min: 0.30,
                max: 0.70,
                divisions: 8,
                activeColor: AppColors.formMasterAccent,
                inactiveColor: AppColors.borderOf(context),
                onChanged: (v) => setState(() => _denoise = v),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                _denoise.toStringAsFixed(2),
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        Text(
          'Higher = more expressive, less faithful to the base.',
          style: TextStyle(
            color: AppColors.textTertiary(context),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _replaceExisting,
                activeColor: AppColors.formMasterAccent,
                onChanged: (v) => setState(() => _replaceExisting = v ?? true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Replace existing images with the same emotion',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Generates $count images one at a time — you can keep, re-roll, or '
          'drop each one before importing.',
          style: TextStyle(
            color: AppColors.textTertiary(context),
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => widget.onStart(
                fullSet: _fullSet,
                denoise: _denoise,
                replaceExisting: _replaceExisting,
                appearanceDetail:
                    (_addToPrompt &&
                        _appearanceDetail != null &&
                        _appearanceDetail!.trim().isNotEmpty)
                    ? _appearanceDetail!.trim()
                    : null,
              ),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.formMasterAccent,
                foregroundColor: AppColors.resolve(
                  context,
                  Colors.white,
                  Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Optional vision grounding: have the text LLM describe the base portrait
  /// and append that description to every slot's prompt for a more faithful
  /// likeness. Advisory and skippable — the button resolves vision capability
  /// only when clicked (a probe call can cost tokens on some remotes).
  Widget _portraitGrounding(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Portrait grounding',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Let the AI describe the portrait so every expression keeps the '
          'likeness — optional.',
          style: TextStyle(
            color: AppColors.textTertiary(context),
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _describing ? null : _describe,
          icon: _describing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: AppColors.iconSecondary(context),
                ),
          label: Text(
            _appearanceDetail == null
                ? 'Describe portrait with AI vision'
                : 'Describe again',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.borderOf(context)),
          ),
        ),
        if (_describeError != null) ...[
          const SizedBox(height: 6),
          Text(
            _describeError!,
            style: TextStyle(
              color: AppColors.negativeAccentOf(context),
              fontSize: 11.5,
            ),
          ),
        ],
        if (_appearanceDetail != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 110),
              child: SingleChildScrollView(
                child: SelectableText(
                  _appearanceDetail!,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _addToPrompt,
                  activeColor: AppColors.formMasterAccent,
                  onChanged: (v) => setState(() => _addToPrompt = v ?? true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add to prompt',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _setChoice(
    BuildContext context, {
    required bool selected,
    required String title,
    required String subtitle,
    required List<String> emotions,
    required VoidCallback onTap,
  }) {
    final accent = AppColors.formMasterAccent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardOf(context) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accent : AppColors.borderOf(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 16,
                  color: selected ? accent : AppColors.iconSecondary(context),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textTertiary(context),
                      fontSize: 11.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              emotions.map((e) => EmotionLabels.emoji[e] ?? '🎭').join(' '),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
