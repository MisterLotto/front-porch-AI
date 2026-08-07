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

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/preference_phrases.dart';
import 'speaker_resolution.dart';

/// Likes & Dislikes fragment for the words-only state block — what this
/// character is drawn to and what puts them off, so they ACT on it.
///
/// DELIBERATELY NOT REALISM-GATED. This is the half of the feature that needs
/// no engine: acting on a preference is characterisation, not scoring. A user
/// with the Realism Engine off still gets a character who lights up at
/// thunderstorms and bristles at being interrupted; what they lose is the
/// SCORING half (bond/trust deltas weighted by those preferences), which lives
/// in the eval prompts and goes quiet on its own. Gating this on realism would
/// repeat the exact bug docs/design/feature-independence.md was written to end
/// — a switch silently disabling something unrelated to it.
///
/// Phrased as TENDENCIES, never as instructions. The design doc names the
/// failure mode outright: a character told "you like being read to" as a rule
/// starts steering every scene toward books. "Drawn to" and "puts them off"
/// colour reactions to what is already happening instead.
///
/// The 18+ pair is a separate line, included only when the caller says NSFW is
/// on, so a card carrying intimate preferences stays silent about them in a
/// non-NSFW chat rather than relying on the model's discretion.
class PreferencesInjection with SpeakerCardResolver {
  @override
  final bool Function() getIsGroupNonObserverMode;
  @override
  final String Function() getCurrentSpeakerIdForRealism;
  @override
  final List<CharacterCard> Function() getGroupCharacters;
  @override
  final String Function(CharacterCard) getCharacterIdFromCard;
  @override
  final CharacterCard? Function() getActiveCharacter;

  /// Whether 18+ content is live for this chat. Only the intimate pair
  /// consults it; the everyday lists are always available.
  final bool Function() getNsfwEnabled;

  PreferencesInjection({
    required this.getIsGroupNonObserverMode,
    required this.getCurrentSpeakerIdForRealism,
    required this.getGroupCharacters,
    required this.getCharacterIdFromCard,
    required this.getActiveCharacter,
    required this.getNsfwEnabled,
  });

  /// Hard ceiling on the whole fragment. Per-phrase and per-list bounds live in
  /// preference_phrases.dart, shared with the scoring block.
  static const maxChars = 420;

  String buildPreferencesInjection() {
    final card = speakerCard();
    final ext = card?.frontPorchExtensions;
    if (ext == null) return '';

    final lines = <String>[];

    final likes = sanitizePreferencePhrases(ext.likes);
    final dislikes = sanitizePreferencePhrases(ext.dislikes);
    if (likes.isNotEmpty || dislikes.isNotEmpty) {
      final parts = [
        if (likes.isNotEmpty) 'drawn to ${likes.join(', ')}',
        if (dislikes.isNotEmpty) 'put off by ${dislikes.join(', ')}',
      ];
      lines.add(
        'Tastes: ${parts.join('; ')} — these colour how they react to what '
        'is already happening; never steer the scene toward them.',
      );
    }

    if (getNsfwEnabled()) {
      final into = sanitizePreferencePhrases(ext.intimateInto);
      final notInto = sanitizePreferencePhrases(ext.intimateNotInto);
      if (into.isNotEmpty || notInto.isNotEmpty) {
        final parts = [
          if (into.isNotEmpty) 'warms to ${into.join(', ')}',
          if (notInto.isNotEmpty) 'not interested in ${notInto.join(', ')}',
        ];
        lines.add(
          'In intimate moments: ${parts.join('; ')} — only relevant when the '
          'scene is already there.',
        );
      }
    }

    if (lines.isEmpty) return '';
    final out = lines.join('\n');
    return out.length <= maxChars ? out : '${out.substring(0, maxChars)}…';
  }
}
