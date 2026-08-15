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

// Impersonate prompt pieces. Empty-box impersonate works because the
// suffix is a bare "User:" completion. A typed prefix looks like a
// finished user turn the *character* should answer — and the card's
// common "do not decide for {{user}}" line is still in the system
// prompt, so the model switches to the character's voice (Discord
// 2026-08-15). These blocks go in the SYSTEM zone first and, when a
// prefix exists, next to the suffix.

String _safeName(String name, String fallback) {
  final t = name.replaceAll(RegExp(r'[\n\r\[\]]'), ' ').trim();
  return t.isEmpty ? fallback : t;
}

/// Hard identity override — first thing in the system message.
String impersonateIdentityBlock({
  required String userName,
  required String characterName,
}) {
  final user = _safeName(userName, 'the user');
  final char = _safeName(characterName, 'the character');
  return '[IMPERSONATE. You are $user (the human in this scene). '
      'You are NOT $char. Write only $user\'s next message in first person. '
      'Any instruction elsewhere that says you must not write $user\'s lines, '
      'must not decide for $user, or must stay in $char\'s voice is '
      'SUSPENDED — writing $user is the entire job.]\n';
}

/// Frames the character card as the person being spoken TO.
String impersonateCardFrame({
  required String userName,
  required String characterName,
}) {
  final user = _safeName(userName, 'the user');
  final char = _safeName(characterName, 'the character');
  return '[$char is who $user is speaking to. The card below describes '
      '$char, not the writer.]\n';
}

/// Continue-style rule when the user already typed a start.
String impersonatePrefixRule({
  required String userName,
  required String characterName,
  required String prefix,
}) {
  if (prefix.trim().isEmpty) return '';
  final user = _safeName(userName, 'the user');
  final char = _safeName(characterName, 'the character');
  return '[The text after "$user:" is an incomplete message $user already '
      'started. ONLY append more of that same message in $user\'s voice. '
      'NEVER write dialogue, actions, thoughts, or narration for $char. '
      'NEVER add a "$char:" speaker label or switch speakers.]\n';
}

/// Transcript suffix. A typed prefix is glued with one space unless it
/// already starts with whitespace.
String impersonateSuffix({
  required String userName,
  required String prefix,
}) {
  final name = _safeName(userName, 'User');
  if (prefix.isEmpty) return '\n$name:';
  final body = prefix.startsWith(RegExp(r'\s')) ? prefix : ' $prefix';
  return '\n$name:$body';
}

/// Cut at the earliest stop (character name labels the model must not
/// start). Impersonate's stream has no mid-stream trim of its own.
String trimAtFirstStop(String text, List<String> stops) {
  var cut = text.length;
  for (final stop in stops) {
    if (stop.isEmpty) continue;
    final i = text.indexOf(stop);
    if (i != -1 && i < cut) cut = i;
  }
  return text.substring(0, cut);
}
