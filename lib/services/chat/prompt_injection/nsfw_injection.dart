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
      String arousalDesc;
      if (nsfwService.arousalLevel <= -2) {
        arousalDesc =
            'completely unaroused and physically repulsed. They will actively reject, recoil from, or shut down any sexual advance';
      } else if (nsfwService.arousalLevel == 0) {
        arousalDesc =
            'physically neutral — sex is the furthest thing from their mind. Any sexual advance feels out of place';
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
        // NOTE: We do NOT instruct climax here. The arousal number describes the
        // character's state of DESIRE, not progress toward orgasm. Climax happens
        // organically in the scene — _checkClimaxInResponse evaluates afterward.
        statePrompt +=
            ' $charName is currently $arousalDesc.\n'
            ' IMPORTANT: Arousal at maximum means $charName is overwhelmed with desire — '
            'it does NOT mean they are climaxing or have climaxed. Do NOT write orgasm or '
            'post-orgasm behavior unless the physical activity in the scene has naturally '
            "built to that point through {{user}}'s direct actions. $charName is desperate "
            'and aching but still in the moment, not past it.\n';
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
