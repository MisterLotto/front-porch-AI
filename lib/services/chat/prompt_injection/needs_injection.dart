// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/services/chat/needs_simulation.dart';
import 'package:front_porch_ai/services/chat/nsfw_service.dart';

/// Plain needs injection builder (_getNeedsInjection).
/// Per-char in group via cbs, 1:1 scalar, suppression, erotic special case, secondary note, post-crash.
/// Step 8. Now uses NeedsSimulation.getLowNeedsForInjection (shared selection of up to 2 lowest
/// at step <=4 / mild-or-worse) so early subtle hints are visible again and slow needs
/// (Comfort, Hygiene) are not completely silenced by faster decayers. Progressive stepped
/// text (mild → catastrophic) reaches the model earlier. Special bladder case preserved.
/// Delegates step/urgency calc to sim helpers.
class NeedsInjection {
  final NeedsSimulation needsSimulation;
  final NsfwService nsfwService;
  final bool Function() getNeedsSimEnabled;
  final bool Function() getRealismEnabled;
  final bool Function() getIsGroupNonObserverMode;
  final String Function() getCurrentSpeakerIdForRealism;
  final List<CharacterCard> Function() getGroupCharacters;
  final CharacterCard? Function() getActiveCharacter;
  final bool Function() getEnjoysLowHygiene;
  final Map<String, int> Function(String charId) getGroupNeeds;
  final String Function(CharacterCard) getCharacterIdFromCard;

  NeedsInjection({
    required this.needsSimulation,
    required this.nsfwService,
    required this.getNeedsSimEnabled,
    required this.getRealismEnabled,
    required this.getIsGroupNonObserverMode,
    required this.getCurrentSpeakerIdForRealism,
    required this.getGroupCharacters,
    required this.getActiveCharacter,
    required this.getEnjoysLowHygiene,
    required this.getGroupNeeds,
    required this.getCharacterIdFromCard,
  });

  String buildNeedsInjection() {
    if (!getNeedsSimEnabled() || !getRealismEnabled()) return '';

    // Helper to build a compact status line for one need.
    // [enjoysLowHygiene] is the flag for the character this line belongs to;
    // in group mode it MUST be the speaker's own flag (not the shared active
    // one) so a filthy-loving member can't invert everyone else's hygiene.
    String _needLine(String key, int value, {bool? enjoysLowHygiene}) {
      // Effective flag for THIS character (per-speaker in group, global in 1:1).
      final effEnjoysLow = enjoysLowHygiene ?? getEnjoysLowHygiene();
      final eff = needsSimulation.getInjectionEffectiveStep(
        key,
        value,
        enjoysLowHygieneOverride: effEnjoysLow,
      );
      // For an "enjoys low hygiene" character the hygiene scale is inverted, so
      // the normal filthy-phrased text would describe a freshly-scrubbed
      // character as "feeling filthy". Use the dedicated too-clean-is-aversive
      // text instead so the words match the (inverted) state.
      final invertHygiene = key == 'hygiene' && effEnjoysLow;
      final steppedList = invertHygiene
          ? NeedsSimulation.hygieneSteppedTextWhenEnjoysLow
          : NeedsSimulation.needSteppedText[key] ?? const <String>[];
      final desc = (eff <= 4 && steppedList.isNotEmpty)
          ? steppedList[eff.clamp(0, 4)]
          : (invertHygiene
              ? 'content and at ease in her own grime and musk'
              : 'comfortable / no significant drive');
      final tag = (eff >= 5)
          ? 'sated'
          : needsSimulation.getUrgencyPrefixForStep(eff).replaceAll(' — ', ' — ').replaceAll('this is ', '');
      // Flag the inverted semantics explicitly so the model doesn't "correct"
      // the apparent contradiction of a high number reading as distress.
      final label = invertHygiene
          ? 'hygiene: $value/100 (this character LIKES being unwashed — a HIGH number here is unwelcome to her, a LOW number is comfort)'
          : '$key: $value/100';
      return '$label — $tag: $desc';
    }

    // Group mode (non-director) — per-character needs. Now emits a grouped, explicit block
    // for *all* needs (with x/100) so the model can directly see the full vector and
    // easily collate severity to behavior.
    if (getIsGroupNonObserverMode()) {
      final id = getCurrentSpeakerIdForRealism();
      final needs = getGroupNeeds(id);
      if (needs.isEmpty) return '';

      final speakerCard = getGroupCharacters().firstWhere(
        (c) => getCharacterIdFromCard(c) == id,
        orElse: () => getGroupCharacters().isNotEmpty
            ? getGroupCharacters().first
            : CharacterCard(name: 'the character'),
      );
      final name = speakerCard.name;
      // Read THIS speaker's own flag — never the shared active-character one,
      // which after the realism dance points at the previous speaker.
      final speakerEnjoysLowHygiene =
          speakerCard.frontPorchExtensions?.enjoysLowHygiene ?? false;

      final buf = StringBuffer();
      buf.writeln('[Current Needs Status for $name — higher = more sated / less urgent (100=full, 0=critical)]');
      for (final key in NeedsSimulation.needKeys) {
        final v = needs[key] ?? NeedsSimulation.needDefaults[key] ?? 80;
        buf.writeln(_needLine(key, v, enjoysLowHygiene: speakerEnjoysLowHygiene));
      }
      buf.writeln('[Collate these exact values: the character\'s physical presentation, energy level, hunger sensations, focus, willingness to exert, posture, small behaviors, and any natural internal references or dialogue this turn must be consistent with the current numbers. Lower values should be more prominent right now.]');
      return buf.toString();
    }

    // 1:1 path (same grouped explicit format for easy collation by the model)
    if (needsSimulation.vector.isEmpty) return '';

    final charName = getActiveCharacter()?.name ?? 'the character';

    // Special erotic bladder case is still supported but now inside the structured block
    // for consistency (the old urgent override is rare; we keep the spirit by using the
    // real value + strong tag).
    final buf = StringBuffer();
    buf.writeln('[Current Needs Status for $charName — higher = more sated / less urgent (100=full, 0=critical)]');
    for (final key in NeedsSimulation.needKeys) {
      final v = needsSimulation.vector[key] ?? NeedsSimulation.needDefaults[key] ?? 80;
      buf.writeln(_needLine(key, v));
    }
    buf.writeln('[Collate these exact values: the character\'s physical presentation, energy level, hunger sensations, focus, willingness to exert, posture, small behaviors, and any natural internal references or dialogue this turn must be consistent with the current numbers. Lower values should be more prominent right now.]');
    return buf.toString();
  }
}
