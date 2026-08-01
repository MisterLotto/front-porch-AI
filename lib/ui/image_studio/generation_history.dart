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
// but WITHOUT ANY WARRANTY, without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Session-local history strip (thumbnails of prior generations in this studio invocation).
/// Click restores image + its prompt for comparison or re-accept (per spec).
class GenerationHistory extends StatelessWidget {
  final List<({String prompt, Uint8List bytes, String style})> entries;
  final void Function(({String prompt, Uint8List bytes, String style}))
  onRestore;

  const GenerationHistory({
    super.key,
    required this.entries,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generation history (this session)',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (first, second) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final e = entries[index];
              return GestureDetector(
                onTap: () => onRestore(e),
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        // Strip thumbnails — decode small, not at gen size.
                        child: Image.memory(
                          e.bytes,
                          fit: BoxFit.cover,
                          cacheWidth: 192,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: AppColors.resolve(
                            context,
                            AppColors.background,
                            AppColors.lightBorder,
                          ), // scrim for thumbnail overlay (AppColors only)
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            e.style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Records used directly (structural typing). No named public alias to keep surface tiny.
