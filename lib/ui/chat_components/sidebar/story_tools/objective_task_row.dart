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

/// A single objective task row — checkbox, inline-editable description,
/// current-task marker, edit/save and delete buttons. Extracted from the old
/// ObjectiveSection so ObjectivePanel stays small.
class EditableTaskRow extends StatefulWidget {
  final String description;
  final bool completed;
  final bool isCurrent;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onEdit;

  const EditableTaskRow({
    super.key,
    required this.description,
    required this.completed,
    required this.isCurrent,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<EditableTaskRow> createState() => EditableTaskRowState();
}

class EditableTaskRowState extends State<EditableTaskRow> {
  bool _editing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.description);
  }

  @override
  void didUpdateWidget(EditableTaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.description != widget.description) {
      _controller.text = widget.description;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onEdit(_controller.text.trim());
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox
          GestureDetector(
            onTap: widget.onToggle,
            child: Icon(
              widget.completed
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 16,
              color: widget.completed
                  ? AppColors.bondHighOf(context)
                  : widget.isCurrent
                  ? AppColors.taskAccentOf(context)
                  : AppColors.iconSecondary(context),
            ),
          ),
          const SizedBox(width: 6),

          // Description or edit field
          Expanded(
            child: _editing
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 11,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceContainerOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: AppColors.taskAccentOf(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: AppColors.taskAccentOf(context),
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _save(),
                  )
                : GestureDetector(
                    onTap: widget.onToggle,
                    child: Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.completed
                            ? AppColors.textTertiary(context)
                            : widget.isCurrent
                            ? AppColors.textPrimary(context)
                            : AppColors.textSecondary(context),
                        decoration: widget.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
          ),

          // Current task indicator
          if (widget.isCurrent && !_editing)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                '◂',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.taskAccentOf(context),
                ),
              ),
            ),

          const SizedBox(width: 4),

          // Edit / Save button
          if (_editing)
            GestureDetector(
              onTap: _save,
              child: Icon(
                Icons.check,
                size: 14,
                color: AppColors.bondHighOf(context),
              ),
            )
          else
            GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: Icon(
                Icons.edit,
                size: 12,
                color: AppColors.iconSecondary(context),
              ),
            ),

          const SizedBox(width: 4),

          // Delete button
          GestureDetector(
            onTap: widget.onDelete,
            child: Icon(
              Icons.close,
              size: 12,
              color: AppColors.iconSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A secondary objective ("side quest") row — text + set-as-primary and clear
/// buttons. Extracted from the old ObjectiveSection body.
class SecondaryObjectiveRow extends StatelessWidget {
  final String objective;
  final VoidCallback onPromote;
  final VoidCallback onClear;

  const SecondaryObjectiveRow({
    super.key,
    required this.objective,
    required this.onPromote,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerOf(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle_outlined,
            size: 10,
            color: AppColors.iconSecondary(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              objective,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          InkWell(
            onTap: onPromote,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.keyboard_double_arrow_up,
                size: 14,
                color: AppColors.taskAccentOf(context),
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.close,
                size: 14,
                color: AppColors.negativeAccentOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
