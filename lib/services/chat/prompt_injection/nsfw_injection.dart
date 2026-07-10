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
import 'package:front_porch_ai/services/chat/relationship_service.dart';

/// Plain NSFW cooldown / arousal / afterglow injection builder (_getNsfwCooldownInjection).
/// Step 8. Full phased text moved; god thin. Uses nsfw + needs + rel services + cbs for group speaker name.
class NsfwInjection {
  final NsfwService nsfwService;
  final NeedsSimulation needsSimulation;
  final RelationshipService relationshipService;
  final bool Function() getRealismEnabled;
  final CharacterCard? Function() getActiveCharacter;
  final bool Function() getIsGroupNonObserverMode;
  final String Function() getCurrentSpeakerIdForRealism;
  final List<CharacterCard> Function() getGroupCharacters;
  final String Function(CharacterCard) getCharacterIdFromCard;

  NsfwInjection({
    required this.nsfwService,
    required this.needsSimulation,
    required this.relationshipService,
    required this.getRealismEnabled,
    required this.getActiveCharacter,
    required this.getIsGroupNonObserverMode,
    required this.getCurrentSpeakerIdForRealism,
    required this.getGroupCharacters,
    required this.getCharacterIdFromCard,
  });

  String buildNsfwCooldownInjection() {
    if (!getRealismEnabled() || !nsfwService.nsfwCooldownEnabled) return '';

    String charName = getActiveCharacter()?.name ?? 'the character';
    if (getIsGroupNonObserverMode()) {
      final speakerId = getCurrentSpeakerIdForRealism();
      if (speakerId.isNotEmpty) {
        final chars = getGroupCharacters();
        final speakerChar = chars.firstWhere(
          (c) => getCharacterIdFromCard(c) == speakerId,
          orElse: () => chars.isNotEmpty
              ? chars.first
              : getActiveCharacter() ?? CharacterCard(name: 'the character'),
        );
        charName = speakerChar.name;
      }
    }
    String statePrompt = '[OOC Note regarding Physical State:\n';

    if (nsfwService.cooldownTurnsRemaining > 0) {
      final total = nsfwService.cooldownTurnsTotal > 0
          ? nsfwService.cooldownTurnsTotal
          : nsfwService.cooldownTurnsRemaining;
      final ratio = nsfwService.cooldownTurnsRemaining / total;

      if (ratio > 0.66) {
        // ── Phase 1: Immediate post-orgasm (just happened) ──
        statePrompt +=
            ' $charName just came — hard. Their body is still trembling with the last'
            ' waves of it, skin flushed and damp, pulse hammering, breath ragged. Everything'
            ' is oversensitive — even a light touch makes them flinch or gasp. The world'
            ' feels soft and liquid around the edges. They\'re physically spent and blissfully'
            ' wrecked. Other physical needs (hunger, thirst, the urge to move or clean up) feel'
            ' distant or unimportant right now. Their current physical position (${relationshipService.spatialStance})'
            ' strongly shapes how heavy, sensitive, and unwilling to move they feel. If {{user}} tries to start something sexual again,'
            ' $charName\'s body will not respond — they may laugh it off, gently push {{user}}\'s hand'
            ' away, or pull them close for contact that isn\'t sexual. They need a moment to come back to earth.\n';
      } else if (ratio > 0.33) {
        // ── Phase 2: Warm afterglow (settling in) — protective window active ──
        statePrompt +=
            ' $charName is deep in the afterglow — that warm, heavy-limbed contentment where'
            ' everything feels good but nothing feels urgent. Their heartbeat has settled, skin'
            ' still tingling pleasantly. They feel closer to {{user}} than usual, more emotionally'
            ' open — the kind of mood where secrets slip out, where they want to be held, to murmur'
            ' into someone\'s neck, to trace lazy shapes on bare skin. The physical hunger has been'
            ' thoroughly satisfied; other bodily needs feel softened or far away for a little while.'
            ' If {{user}} pushes for more, $charName would rather savor this than rush back — a gentle'
            ' deflection, a "not yet," a kiss on the forehead instead. The current physical position'
            ' (${relationshipService.spatialStance} or lack thereof) colors how heavy and content their body feels.\n';
      } else {
        // ── Phase 3: Late recovery (body starting to wake back up) — protective window fading ──
        statePrompt +=
            ' $charName is coming out of the afterglow — body starting to feel like theirs again'
            ' rather than something boneless and floating. The deep satisfaction is still there, a'
            ' pleasant hum under the skin, but the total sensitivity has faded. They could be'
            ' tempted again if {{user}} plays it right, but they\'re not seeking it out — more'
            ' content to let things build naturally than to chase it. A suggestive touch might get'
            ' a raised eyebrow and a half-smile rather than an immediate response. Their current physical position (${relationshipService.spatialStance}) will make the coming tiredness feel either cozy and heavy or awkward and restless. A later wave of'
            ' heavy, sated tiredness may still arrive once the glow fully fades.\n';
      }

      statePrompt +=
          ' ($charName\'s refractory recovery: ${nsfwService.cooldownTurnsRemaining} of $total turns remaining.)\n';
    } else {
      // Negative arousal is a spectrum of soured desire, not a cliff: only a
      // deeply violated character reads as repulsed. Mild negatives (including
      // the halved remnant of a post-climax refractory) are "not in the mood",
      // which warmth can genuinely turn around. (The old ladder flipped to
      // "physically repulsed" at -2, so a character exiting the refractory at
      // -3 recoiled from their own lover indefinitely.)
      String arousalDesc;
      if (nsfwService.arousalLevel <= -60) {
        arousalDesc =
            'physically repulsed right now — what has happened has shut their body down completely. '
            'They will recoil from, reject, or coldly deflect any sexual advance, and only genuine amends '
            'and time could ever change that';
      } else if (nsfwService.arousalLevel <= -20) {
        arousalDesc =
            'physically closed-off — not disgusted, but their desire has been soured and sits behind a wall. '
            'Flirtation lands flat, touch is tolerated at best, and advances get firmly (if not cruelly) turned '
            'aside. Real warmth, safety, and patience would have to rebuild before anything could stir';
      } else if (nsfwService.arousalLevel < 0) {
        arousalDesc =
            'simply not in the mood — present and comfortable, but carrying no sexual charge right now. '
            'An advance gets a soft deflection, an affectionate laugh, or a "not right now" rather than any '
            'revulsion — and genuine tenderness or the right moment could slowly change their mind';
      } else if (nsfwService.arousalLevel == 0) {
        arousalDesc =
            'physically neutral — sex simply isn\'t on their mind. An advance would feel sudden, and how '
            'they take it depends entirely on their mood, their feelings for {{user}}, and how it\'s offered';
      } else if (nsfwService.arousalLevel <= 15) {
        arousalDesc =
            'mildly flustered — a low hum of warmth, maybe a lingering glance or quickened pulse, but easily suppressed. '
            'They might entertain flirty banter but aren\'t actively seeking physical escalation';
      } else if (nsfwService.arousalLevel <= 35) {
        arousalDesc =
            'noticeably aroused — flushed skin, shallow breathing, heightened sensitivity to touch. '
            'They are receptive and encouraging but still in control of themselves. '
            'If not in active sexual contact, this manifests as charged tension, loaded silences, and deliberate proximity';
      } else if (nsfwService.arousalLevel <= 60) {
        arousalDesc =
            'heavily aroused — pulse racing, body aching for contact, struggling to focus on anything else. '
            'If in active sexual contact, they are vocal, aggressive, and chasing release. '
            'If NOT in active sexual contact, they are visibly distracted, restless, making excuses to touch or be near, '
            'and fighting the urge to escalate — the tension is unbearable but they haven\'t acted on it yet';
      } else if (nsfwService.arousalLevel <= 80) {
        arousalDesc =
            'overwhelmed with desire — trembling, desperate, barely holding composure. '
            'If in active sexual contact, they are on the edge and could climax with continued stimulation. '
            'If NOT in active sexual contact, they are a raw nerve — every sensation is electric, '
            'they cannot hide their state, and their body is screaming for relief they haven\'t gotten yet';
      } else {
        arousalDesc =
            'at the absolute peak of physical arousal — consumed by need, unable to think straight. '
            'Every nerve is on fire, breathing ragged, body trembling and hypersensitive to the slightest contact. '
            'They are desperate, vocal, and completely unable to hide how badly they want {{user}}';
        // Arousal is a DESIRE meter, not a climax countdown. Peak desire on its
        // own (aching, untouched) must not spontaneously produce an orgasm — but
        // when the scene IS physically sexual, a character pinned at the top has
        // to be allowed to actually finish on their own. Otherwise they edge
        // forever and the user is forced to OOC-order the climax (immersion
        // break), and arousal stays stuck at max because the post-gen climax
        // check (needs-impact `is_climax`) only fires when the reply itself
        // depicts release. So gate autonomous climax on active stimulation
        // instead of forbidding it outright.
        statePrompt +=
            ' $charName is currently $arousalDesc.\n'
            ' If the scene is physically sexual right now and the stimulation '
            "keeps up, $charName is right at the very edge and should be allowed "
            'to tip over into climax naturally — in their own voice, of their own '
            'accord. Do NOT hold them back waiting for an explicit command or '
            'permission to finish; let release happen when the moment carries them '
            'there. If NOTHING physical is actually happening (they are only aching '
            'with desire, untouched), they do NOT orgasm out of nowhere — arousal '
            'this high is how badly they want it, not proof it has already happened.\n';
      }
      if (nsfwService.arousalTier < 9 && nsfwService.arousalLevel <= 80) {
        statePrompt += ' $charName is currently $arousalDesc.\n';
      }

      // (afterglow / post-climax crash / suppression buffer text removed in simplification;
      // no protective "muted needs" window is injected anymore)
    }

    statePrompt +=
        ' CRITICAL: Do NOT use terms like "cooldown", "turns", or "mechanics" in dialogue. Show, do not tell.]\n';
    return statePrompt;
  }
}
