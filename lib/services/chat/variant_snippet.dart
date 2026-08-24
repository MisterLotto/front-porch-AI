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

import 'package:front_porch_ai/utils/utils.dart';

/// First [maxWords] words of [text] for the variant-picker row, think-stripped
/// and collapsed to a single line. Empty input yields an empty snippet.
String variantSnippet(String text, {int maxWords = 15}) {
  final cleaned = stripThinkTags(text).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return '';
  final words = cleaned.split(' ');
  if (words.length <= maxWords) return cleaned;
  return '${words.take(maxWords).join(' ')}…';
}

/// One row in the shared greet/swipe picker.
class VariantOption {
  final int index;
  final String snippet;
  final int charCount;
  final bool isCurrent;

  const VariantOption({
    required this.index,
    required this.snippet,
    required this.charCount,
    required this.isCurrent,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'snippet': snippet,
    'charCount': charCount,
    'current': isCurrent,
  };
}

/// Build picker rows from the full variant texts. [currentIndex] is clamped
/// so a stale swipe cursor never marks two rows (or none) as current.
List<VariantOption> buildVariantOptions(List<String> texts, int currentIndex) {
  if (texts.isEmpty) return const [];
  final current = currentIndex.clamp(0, texts.length - 1);
  return [
    for (var i = 0; i < texts.length; i++)
      VariantOption(
        index: i,
        snippet: variantSnippet(texts[i]),
        charCount: texts[i].length,
        isCurrent: i == current,
      ),
  ];
}

/// First greet keeps the card's starting emotion; alternative greets get
/// reading-the-room (the post-greeting eval) on commit. Not a per-greet
/// setting — just which path runs when the picker (or chevron) lands.
bool shouldReadRoomForGreeting(int index) => index > 0;
