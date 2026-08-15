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

// Continue word-break glue (Discord 2026-08-15, adv997).
//
// The model is asked to extend the exact partial, but chat-completion
// backends often start the next word with no leading space — "garden.The"
// — whether the reply died mid-sentence or at a period. Users were editing
// a trailing space into the bubble before Continue. These helpers are that
// workaround: pad the prompt suffix so the model sees a word break, and
// insert one space at display/finalize so a no-space first token cannot
// mash. A model-emitted leading space is left-trimmed so we never double.

/// True when [text] has content that does not already end with whitespace.
bool continueNeedsJoiningSpace(String text) =>
    text.isNotEmpty && text.trimRight() == text;

/// Trailing space on the Continue prompt suffix so the model starts after
/// a word break. No-op when [partial] is empty or already ends in
/// whitespace (the user-edit workaround, or a prior pad).
String padContinuePartial(String partial) =>
    continueNeedsJoiningSpace(partial) ? '$partial ' : partial;

/// Glue pre-continue body + new tokens. One space when [prefix] does not
/// already end with whitespace; [newPart] is left-trimmed so a
/// model-emitted leading space does not double. Trailing whitespace on
/// the result is stripped to match the old `trimRight` finalize.
String glueContinueText(String prefix, String newPart) {
  final right = newPart.trimLeft();
  if (prefix.isEmpty) return right.trimRight();
  if (right.isEmpty) return prefix.trimRight();
  final joined = continueNeedsJoiningSpace(prefix)
      ? '$prefix $right'
      : '$prefix$right';
  return joined.trimRight();
}
