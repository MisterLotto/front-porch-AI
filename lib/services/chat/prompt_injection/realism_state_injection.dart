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
import 'package:front_porch_ai/services/chat/prompt_injection/behavioral_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/emotion_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/needs_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/nsfw_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/relationship_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/time_injection.dart';
import 'package:front_porch_ai/services/chat/relationship_service.dart';
import 'package:front_porch_ai/services/chat/time_service.dart';

/// Central composer for the entire "speaker internal state" realism bundle
/// (relationship + emotion + time + trust/behavioral + nsfw cooldown/arousal + needs + inter-char).
///
/// This is the single place that decides the *format and grouping* of all the
/// live scalar state the model receives for the current speaker. The goal is
/// maximum legibility for the LLM: explicit numbers (x/100, scores, tiers, day count, etc.)
/// first, followed by the richer guidance text from the sub-builders, all under
/// one clear parent block with a strong collation instruction.
///
/// This replaces the previous ad-hoc string concatenation of 8 separate builders
/// in ChatService. It follows the step-8 extraction pattern but adds a "presentation
/// layer" on top so the model can more easily see and collate the full snapshot
/// (exactly the problem reported with needs/energy not being "seen" or acted on).
///
/// 1:1 vs group parity is preserved via the sub-builders' existing cbs + speaker
/// impersonation in the god.
///
/// The sub-builders are still used for their content (so their individual logic
/// and tests remain authoritative); this class only controls ordering, grouping,
/// and the addition of explicit numeric "data" sections where they exist.
///
/// No god private methods were added for this (the thin _getRealismStateInjection
/// + late final wiring is the public surface, matching all other prompt_injection
/// leaves).
class RealismStateInjection {
  final RelationshipInjection relationshipInjection;
  final EmotionInjection emotionInjection;
  final TimeInjection timeInjection;
  final BehavioralInjection behavioralInjection;
  final NsfwInjection nsfwInjection;
  final NeedsInjection needsInjection;

  // Raw data providers so we can emit explicit "Current Values" numbers
  // alongside the prose guidance (this is the key improvement for collation).
  final NeedsSimulation needsSimulation;
  final RelationshipService relationshipService;
  final TimeService timeService;
  final NsfwService nsfwService; // for arousal/cooldown numbers in the metrics header

  final bool Function() getRealismEnabled;
  final bool Function() getIsGroupNonObserverMode;
  final String Function() getCurrentSpeakerIdForRealism;
  final List<CharacterCard> Function() getGroupCharacters;
  final CharacterCard? Function() getActiveCharacter;
  final String Function(CharacterCard) getCharacterIdFromCard;

  RealismStateInjection({
    required this.relationshipInjection,
    required this.emotionInjection,
    required this.timeInjection,
    required this.behavioralInjection,
    required this.nsfwInjection,
    required this.needsInjection,
    required this.needsSimulation,
    required this.relationshipService,
    required this.timeService,
    required this.nsfwService,
    required this.getRealismEnabled,
    required this.getIsGroupNonObserverMode,
    required this.getCurrentSpeakerIdForRealism,
    required this.getGroupCharacters,
    required this.getActiveCharacter,
    required this.getCharacterIdFromCard,
  });

  String buildRealismStateInjection() {
    if (!getRealismEnabled()) return '';

    final buf = StringBuffer();

    // Strong top-level header so the model knows this entire block is the
    // authoritative current snapshot for the speaker. All numbers and guidance
    // below must be collated together.
    buf.writeln('[Speaker Internal State — authoritative current snapshot for the speaking character]');
    buf.writeln('Higher need values = more satisfied. Use the explicit numbers + guidance below to keep physicality, energy, emotion, relationships, focus, and small behaviors consistent.');
    buf.writeln();

    // --- Explicit numeric snapshot (the part that was previously hard to "see") ---
    buf.writeln('--- Current Metrics (use these numbers directly) ---');

    // Needs (full vector, as requested — grouped with x/100 and status)
    if (needsSimulation.vector.isNotEmpty || getIsGroupNonObserverMode()) {
      final needsMap = getIsGroupNonObserverMode()
          ? _getGroupNeedsForSpeaker()
          : needsSimulation.vector;
      if (needsMap.isNotEmpty) {
        // Resolve THIS speaker's own hygiene-preference flag. In group mode the
        // shared active-character pointer is the previous speaker after the
        // realism dance, so reading the global flag would invert every member's
        // hygiene when any one member enjoys being filthy (the "hygiene 88 shows
        // catastrophic" bleed). 1:1 uses the active/host card (same as global).
        final speakerCard = getIsGroupNonObserverMode()
            ? getGroupCharacters().firstWhere(
                (c) =>
                    getCharacterIdFromCard(c) == getCurrentSpeakerIdForRealism(),
                orElse: () => getActiveCharacter() ?? CharacterCard(name: ''),
              )
            : getActiveCharacter();
        final speakerEnjoysLowHygiene =
            speakerCard?.frontPorchExtensions?.enjoysLowHygiene ?? false;
        buf.writeln('Needs (higher = more sated):');
        for (final key in NeedsSimulation.needKeys) {
          final v = needsMap[key] ?? NeedsSimulation.needDefaults[key] ?? 80;
          final eff = needsSimulation.getInjectionEffectiveStep(
            key,
            v,
            enjoysLowHygieneOverride: speakerEnjoysLowHygiene,
          );
          final status = eff >= 5 ? 'sated' : 'needs attention';
          buf.writeln('  $key: $v/100 ($status)');
        }
      }
    }

    // Relationship scalars (bond/trust/fixation/spatial + tiers)
    buf.writeln('Relationship with {{user}}:');
    buf.writeln('  Bond (long-term): ${relationshipService.longTermScore}');
    buf.writeln('  Tension (short-term): ${relationshipService.relationshipTier} (${relationshipService.shortTermTierName})');
    if (relationshipService.activeFixation.isNotEmpty) {
      buf.writeln('  Current Fixation: ${relationshipService.activeFixation}');
    }
    if (relationshipService.spatialStance.isNotEmpty) {
      buf.writeln('  Spatial Stance: ${relationshipService.spatialStance}');
    }

    // Emotion
    final emo = _currentEmotion;
    if (emo.isNotEmpty) {
      final intensity = _currentEmotionIntensity;
      buf.writeln('Emotion: $emo ($intensity)');
    }

    // Time
    if (timeService.timeOfDay.isNotEmpty) {
      final day = timeService.dayCount;
      buf.writeln('Time: ${timeService.timeOfDay.replaceAll('_', ' ')}, Day $day');
    }

    // Arousal / refractory (from nsfw). Only state a cooldown when one is
    // actually running: the old line printed the FEATURE toggle as
    // "cooldown active: true" on every turn forever, so the model kept
    // playing the character as post-climax long after the refractory ended
    // (and the eval then scored every message with a negative lust delta).
    if (nsfwService.nsfwCooldownEnabled) {
      if (nsfwService.cooldownTurnsRemaining > 0) {
        final total = nsfwService.cooldownTurnsTotal > 0
            ? nsfwService.cooldownTurnsTotal
            : nsfwService.cooldownTurnsRemaining;
        buf.writeln(
          'Arousal level: ${nsfwService.arousalLevel} (post-climax refractory: '
          '${nsfwService.cooldownTurnsRemaining} of $total turns left — sated '
          'and recovering, not averse)',
        );
      } else {
        buf.writeln('Arousal level: ${nsfwService.arousalLevel}');
      }
    }

    buf.writeln('--- End Metrics ---');
    buf.writeln();

    // --- Narrative / guidance sections (composed from the specialized builders) ---
    // These provide the immersive + directive flavor. The model should treat the
    // metrics above as the ground truth numbers and the sections below as style/interpretation guidance.

    final rel = relationshipInjection.buildRelationshipInjection();
    if (rel.isNotEmpty) buf.writeln(rel);

    final emoText = emotionInjection.buildEmotionInjection();
    if (emoText.isNotEmpty) buf.writeln(emoText);

    final timeText = timeInjection.buildTimeInjection();
    if (timeText.isNotEmpty) buf.writeln(timeText);

    final trust = relationshipInjection.buildTrustBehaviorInjection();
    if (trust.isNotEmpty) buf.writeln(trust);

    final behavioral = behavioralInjection.buildBehavioralMechanicsInjection();
    if (behavioral.isNotEmpty) buf.writeln(behavioral);

    final nsfw = nsfwInjection.buildNsfwCooldownInjection();
    if (nsfw.isNotEmpty) buf.writeln(nsfw);

    final needsText = needsInjection.buildNeedsInjection();
    if (needsText.isNotEmpty) buf.writeln(needsText);

    final inter = relationshipInjection.buildInterCharacterFeelingsInjection();
    if (inter.isNotEmpty) buf.writeln(inter);

    // Final collation reminder
    buf.writeln('[Collate everything above: the numeric metrics are the current truth. The character\'s body, energy, hunger, emotions, trust level, spatial position, and any internal references must feel consistent with those numbers and the guidance in the sections. Do not ignore low needs or high trust just because the scene is dramatic.]');

    return buf.toString();
  }

  // --- Helpers for raw data in group vs 1:1 (mirrors patterns in the sub-builders) ---

  Map<String, int> _getGroupNeedsForSpeaker() {
    // In group the scalars are loaded per-speaker (via _loadGroupRealismIntoScalars)
    // before prompt assembly. Fall back to the scalar vector (defensive for 1:1 parity in tests).
    return needsSimulation.vector;
  }

  String get _currentEmotion {
    // The emotion injection already handles the scalar vs group load.
    // We call the builder and parse lightly, or we could expose a getter.
    // For simplicity in this first version we use a best-effort from the emotion builder output.
    final e = emotionInjection.buildEmotionInjection();
    final match = RegExp(r'Current Emotional State: (\w+)').firstMatch(e);
    return match?.group(1) ?? '';
  }

  String get _currentEmotionIntensity {
    final e = emotionInjection.buildEmotionInjection();
    final match = RegExp(r'\((\w+)\)').firstMatch(e);
    return match?.group(1) ?? 'moderate';
  }
}
