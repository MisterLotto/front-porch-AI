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

final _htmlCommentRe = RegExp(r'<!--.*?-->', dotAll: true);

/// Think-stripped greeting/swipe body with HTML comments removed. Card greets
/// often open with an author `<!-- [Context: …] -->` block — that must not be
/// the picker preview. Newlines are kept so the card can show real prose.
String variantDisplayText(String text) {
  final noThink = stripThinkTags(text);
  final noComments = noThink.replaceAll(_htmlCommentRe, '\n');
  final cleaned = noComments
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (cleaned.isEmpty) {
    return noThink.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  return cleaned;
}

/// First [maxWords] words of [text] for compact API snippets. Uses
/// [variantDisplayText] so HTML comments never leak into the one-line form.
String variantSnippet(String text, {int maxWords = 15}) {
  final cleaned = variantDisplayText(
    text,
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return '';
  final words = cleaned.split(' ');
  if (words.length <= maxWords) return cleaned;
  return '${words.take(maxWords).join(' ')}…';
}

/// Rough token estimate (same chars/4 floor as lorebook analysis).
int variantApproxTokens(int charCount) =>
    charCount <= 0 ? 0 : (charCount / 4).ceil();

/// Card greet vs a regenerated swipe. Pre-existing regen swipes on the
/// opening message must not be labeled as greets.
enum VariantKind { greet, regen }

String variantKindLabel(VariantKind kind) => switch (kind) {
  VariantKind.greet => 'Greet',
  VariantKind.regen => 'Regen',
};

/// Opening-message picker shows card greets only when that message has no
/// stored regen swipes. `swipeCount > 1` is a leftover of the old greet-regen
/// button — those rows are variants, not greets.
bool usesGreetingPicker({
  required int messageIndex,
  required bool isUser,
  required int greetCount,
  required int swipeCount,
}) {
  if (messageIndex != 0 || isUser) return false;
  if (swipeCount > 1) return false;
  return greetCount > 1;
}

/// One row in the shared greet/swipe picker.
class VariantOption {
  final int index;
  final String snippet;
  final String text;
  final int charCount;
  final int tokenCount;
  final bool isCurrent;
  final VariantKind kind;

  const VariantOption({
    required this.index,
    required this.snippet,
    required this.charCount,
    required this.isCurrent,
    this.text = '',
    this.tokenCount = 0,
    this.kind = VariantKind.regen,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'snippet': snippet,
    'text': text,
    'charCount': charCount,
    'tokenCount': tokenCount,
    'current': isCurrent,
    'kind': kind.name,
  };
}

/// Build picker rows from the full variant texts. [currentIndex] is clamped
/// so a stale swipe cursor never marks two rows (or none) as current.
List<VariantOption> buildVariantOptions(
  List<String> texts,
  int currentIndex, {
  VariantKind kind = VariantKind.regen,
}) {
  if (texts.isEmpty) return const [];
  final current = currentIndex.clamp(0, texts.length - 1);
  return [
    for (var i = 0; i < texts.length; i++)
      VariantOption(
        index: i,
        snippet: variantSnippet(texts[i]),
        text: variantDisplayText(texts[i]),
        charCount: texts[i].length,
        tokenCount: variantApproxTokens(texts[i].length),
        isCurrent: i == current,
        kind: kind,
      ),
  ];
}

/// First greet keeps the card's starting emotion; alternative greets get
/// reading-the-room (the post-greeting eval) on commit. Not a per-greet
/// setting — just which path runs when the picker (or chevron) lands.
bool shouldReadRoomForGreeting(int index) => index > 0;
