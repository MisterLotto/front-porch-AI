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
import '../sidebar_tokens.dart';

/// Read-only text panel for Scenario/Description inside the Story Tools
/// accordion (replaces the old chevron-collapse SidebarSection). The text
/// arrives already macro-resolved. Long content (> ~300 chars) is clamped to
/// 8 lines with a "Show more"/"Show less" toggle.
class StaticTextPanel extends StatefulWidget {
  final String title;
  final String content;
  final IconData icon;

  const StaticTextPanel({
    super.key,
    required this.title,
    required this.content,
    this.icon = Icons.description_outlined,
  });

  @override
  State<StaticTextPanel> createState() => _StaticTextPanelState();
}

class _StaticTextPanelState extends State<StaticTextPanel> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.content.length > 300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarSubHeader(
          icon: widget.icon,
          label: widget.title,
          accent: AppColors.porchHoneyOf(context),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.content,
                maxLines: isLong && !_showAll ? 8 : null,
                overflow: isLong && !_showAll
                    ? TextOverflow.ellipsis
                    : TextOverflow.visible,
                style: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 12,
                ),
              ),
              if (isLong)
                InkWell(
                  onTap: () => setState(() => _showAll = !_showAll),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _showAll ? 'Show less' : 'Show more',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.porchHoneyOf(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
