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
import 'package:front_porch_ai/services/chat/relationship_service.dart';

/// Plain (non-ChangeNotifier) prompt injection builder owning the
/// relationship context text (_getRelationshipInjection),
/// inter-character private feelings (_getInterCharacterFeelingsInjection),
/// and trust-calibrated behavioral frame (_getTrustBehaviorInjection).
///
/// Extracted as step 8 of Stage 3 (prompt_injection/* leaf).
/// Full bodies moved verbatim from god (with group 1:1 dispatch branches
/// preserved exactly via granular cbs; no behavior change).
///
/// Depends on RelationshipService (for scores/tiers/fixation/spatial/trust +
/// group scalar load via its own cbs) + god cross-state cbs for active/group/
/// observer/speaker (mirrors relationship/ nsfw/ lore precedent for group
/// per-char + inter).
///
/// ChatService owns via late final _relationshipInjection + thin delegations
/// at the 3 call sites in realism block assembly. 0 @Deprecated shims.
/// 0 new god private _ methods (thins + late final + existing cbs passed).
///
/// 1:1 vs group parity preserved exactly (group uses speaker id + _groupRealism
/// via rel service + god cbs for names/ids; 1:1 uses direct scalars + activeChar;
/// inter-char only fires in group >=2 non-obs per original guard).
///
/// Boundaries kept in god (per plan):
/// - _groupRealism map itself, capture/restore for snapshots, UI sidebar
///   relationship bars, _get* calls in assembly stay thin.
/// - Inter-char tracking flag + getInterCharacterRelationships (on rel service)
///   used by builder via service.
/// - Some mood/tier name getters delegated from god (cbs here for builder).
///
/// aug exercising only passive/qualified (no prompt-specific aug file edits;
/// relationship injection in realism paths hit by pre-existing in key suites;
/// full builder only in dedicated + manual per step7 precedent).
/// oneShot vs normal relationship injection parity qualified (text identical
/// via same assembly + service state; dispatch preserved).
///
/// Part of the 8 prompt_injection builders (relationship_injection combines the
/// three related rel/inter/trust builders per plan grouping to 8 files).
class RelationshipInjection {
  final RelationshipService relationshipService;

  final bool Function() getRealismEnabled;
  final bool Function() getIsGroupNonObserverMode;
  final String Function() getCurrentSpeakerIdForRealism;
  final List<CharacterCard> Function() getGroupCharacters;
  final CharacterCard? Function() getActiveCharacter;
  final String Function() getShortTermTierName;
  final String Function() getLongTermTierName;
  final String Function() getMoodLabel;
  final bool Function() getShouldTrackInterCharacterRelationships;
  final int Function(String charId, String key, {int defaultValue}) getGroupInt;
  final String Function(CharacterCard) getCharacterIdFromCard;
  final Map<String, int> Function(String speakerId)
  getInterCharacterRelationships;

  RelationshipInjection({
    required this.relationshipService,
    required this.getRealismEnabled,
    required this.getIsGroupNonObserverMode,
    required this.getCurrentSpeakerIdForRealism,
    required this.getGroupCharacters,
    required this.getActiveCharacter,
    required this.getShortTermTierName,
    required this.getLongTermTierName,
    required this.getMoodLabel,
    required this.getShouldTrackInterCharacterRelationships,
    required this.getGroupInt,
    required this.getCharacterIdFromCard,
    required this.getInterCharacterRelationships,
  });

  // ── Public surface (thin delegations from god _get* call the matching build*) ──

  String buildRelationshipInjection() {
    if (!getRealismEnabled()) return '';

    // Keeps tier warmth in-voice: the meter says HOW MUCH the character has
    // warmed, the persona says WHAT that looks like. Without this line, high
    // tiers read as an instruction to become generically sweet, which erased
    // tsundere/dominant/abrasive characters' texture as bonds grew.
    const voiceNote =
        'Express this through the character\'s own personality and voice — warmth from a harsh, '
        'guarded, or dominant character surfaces in THEIR fashion (grudging, teasing, subtle acts '
        'of care), never as generic sweetness that erases who they are.';

    // Group mode (non-director): use the current speaker's stored values
    if (getIsGroupNonObserverMode()) {
      final id = getCurrentSpeakerIdForRealism();
      final chars = getGroupCharacters();
      final name = chars
          .firstWhere(
            (c) => getCharacterIdFromCard(c) == id,
            orElse: () => chars.first,
          )
          .name;

      final longTier = getGroupInt(id, 'longTermTier');
      final shortTier = getGroupInt(id, 'relationshipTier');

      String bondGuidance;
      if (longTier >= 7) {
        bondGuidance =
            'Their Long-Term Commitment is unbreakable: $name fully trusts {{user}} and views them as a soulmate/life partner.';
      } else if (longTier >= 4) {
        bondGuidance =
            'Their Long-Term Trust is strong: $name feels a deepening, stable connection and sees a real future with {{user}}.';
      } else if (longTier <= -4) {
        bondGuidance =
            'Their Long-Term Trust is broken: $name holds deep-seated resentment and fundamentally distrusts {{user}}. Even if short-term mood improves, the underlying hostility remains.';
      } else {
        bondGuidance = 'Their Long-Term Bond is developing normally.';
      }

      String tensionGuidance;
      switch (shortTier) {
        case 10:
          tensionGuidance =
              'Short-Term Tension is Devoted: $name is completely open, vulnerable, and emotionally intertwined with {{user}}.';
          break;
        case 9:
        case 8:
          tensionGuidance =
              'Short-Term Tension is Enamored/Devoted: $name is deeply attached and prioritizes {{user}} above their own needs.';
          break;
        case 7:
          tensionGuidance =
              'Short-Term Tension is Warm/Affectionate: $name feels genuinely fond and connected to {{user}}.';
          break;
        // Group path uses coarser tiers (only high positive special-cased for brevity; negatives + mid default to neutral per original)
        default:
          tensionGuidance =
              'Short-Term Tension is neutral to slightly distant.';
      }

      return '[Relationship Context for $name:\n$bondGuidance\n$tensionGuidance\n$voiceNote]\n';
    }

    // 1:1 / Director path (original scalar logic)
    final charName = getActiveCharacter()?.name ?? 'the character';

    String bondGuidance;
    if (relationshipService.longTermTier >= 7) {
      bondGuidance =
          'Their Long-Term Commitment is unbreakable: $charName fully trusts {{user}} and views them as a soulmate/life partner.';
    } else if (relationshipService.longTermTier >= 4) {
      bondGuidance =
          'Their Long-Term Trust is strong: $charName feels a deepening, stable connection and sees a real future with {{user}}.';
    } else if (relationshipService.longTermTier <= -4) {
      bondGuidance =
          'Their Long-Term Trust is broken: $charName holds deep-seated resentment and fundamentally distrusts {{user}}. Even if short-term mood improves, the underlying hostility remains.';
    } else {
      bondGuidance = 'Their Long-Term Bond is developing normally.';
    }

    String tensionGuidance;
    switch (relationshipService.relationshipTier) {
      case 10:
        tensionGuidance =
            'Short-Term Tension is Devoted: $charName is completely open, vulnerable, and emotionally intertwined with {{user}}.';
        break;
      case 9:
      case 8:
        tensionGuidance =
            'Short-Term Tension is Enamored/Devoted: $charName is deeply attached and prioritizes {{user}} above their own needs.';
        break;
      case 7:
        tensionGuidance =
            'Short-Term Tension is Intimate: $charName is exceptionally close, vulnerable, and completely open right now.';
        break;
      case 6:
        tensionGuidance =
            'Short-Term Tension is Close: $charName shares personal thoughts and feels emotionally connected.';
        break;
      case 5:
        tensionGuidance =
            'Short-Term Tension is Amiable: $charName is warm and friendly, engaging openly.';
        break;
      case 4:
        tensionGuidance =
            'Short-Term Tension is Friendly: $charName is warm, playful, and shares personal thoughts freely.';
        break;
      case 3:
        tensionGuidance =
            'Short-Term Tension is Warm: $charName is comfortable and approachable.';
        break;
      case 2:
        tensionGuidance =
            'Short-Term Tension is Receptive: $charName is open to conversation and mildly interested.';
        break;
      case 1:
      case 0:
        tensionGuidance =
            'Short-Term Tension is Neutral: $charName engages naturally based on their established personality — neither particularly warm nor distant.';
        break;
      case -1:
        tensionGuidance =
            'Short-Term Tension is Reserved: $charName is cautious and holding back.';
        break;
      case -2:
        tensionGuidance =
            'Short-Term Tension is Cool: $charName is polite but maintains emotional distance.';
        break;
      case -3:
        tensionGuidance =
            'Short-Term Tension is Unimpressed: $charName is indifferent and unengaged.';
        break;
      case -4:
        tensionGuidance =
            'Short-Term Tension is Annoyed: $charName is mildly bothered and slightly sarcastic.';
        break;
      case -5:
        tensionGuidance =
            'Short-Term Tension is Disliked: $charName is cold and dismissive.';
        break;
      case -6:
        tensionGuidance =
            'Short-Term Tension is Hostile: $charName is openly antagonistic.';
        break;
      case -7:
        tensionGuidance =
            'Short-Term Tension is Adversarial: $charName is combative and argumentative.';
        break;
      case -8:
        tensionGuidance =
            'Short-Term Tension is Disdain: $charName holds contemptuous views of {{user}}.';
        break;
      case -9:
        tensionGuidance =
            'Short-Term Tension is Contempt: $charName is demeaning and disrespectful.';
        break;
      case -10:
        tensionGuidance =
            'Short-Term Tension is Vitriolic: $charName actively hates {{user}} with pure hostility.';
        break;
      default:
        tensionGuidance = '';
    }

    return '[OOC Note regarding Relationship:\n'
        ' Long-Term Status: ${getLongTermTierName()} (${relationshipService.longTermScore} points)\n'
        ' Short-Term Tension: ${getShortTermTierName()}\n'
        ' Current Mood: ${getMoodLabel()}\n'
        '$bondGuidance\n'
        '$tensionGuidance\n'
        '$voiceNote\n]';
  }

  /// Phase 2: Invisible inter-character relationship injection.
  /// Returns private guidance for the *current speaker* describing how they
  /// secretly feel about the other members of the group. This is NEVER shown
  /// in the UI (the sidebar bars remain strictly user-focused). It exists only
  /// to let the LLM make the speaker react realistically to their groupmates.
  ///
  /// Example output:
  /// [Private feelings of Alice toward other group members]
  /// - Bob: slightly wary of (-18)
  /// - Charlie: fond of (+42)
  String buildInterCharacterFeelingsInjection() {
    if (!getRealismEnabled()) return '';
    if (!getIsGroupNonObserverMode()) return '';
    if (!getShouldTrackInterCharacterRelationships()) return '';
    final chars = getGroupCharacters();
    if (chars.length < 2) return '';

    final speakerId = getCurrentSpeakerIdForRealism();
    if (speakerId.isEmpty) return '';

    final relationships = getInterCharacterRelationships(speakerId);
    if (relationships.isEmpty) return '';

    final speakerName = chars
        .firstWhere(
          (c) => getCharacterIdFromCard(c) == speakerId,
          orElse: () => chars.first,
        )
        .name;

    final buffer = StringBuffer();
    buffer.writeln(
      '[Private feelings of $speakerName toward other group members (internal, not visible to {{user}})]',
    );

    for (final entry in relationships.entries) {
      final otherId = entry.key;
      final delta = entry.value;

      final otherChar = chars.firstWhere(
        (c) => getCharacterIdFromCard(c) == otherId,
        orElse: () => chars.first,
      );
      final otherName = otherChar.name;

      String attitude;
      if (delta >= 60) {
        attitude = 'deeply fond of / protective toward';
      } else if (delta >= 25) {
        attitude = 'warm and friendly toward';
      } else if (delta >= 5) {
        attitude = 'mildly positive toward';
      } else if (delta <= -60) {
        attitude = 'strongly hostile toward / resents';
      } else if (delta <= -25) {
        attitude = 'wary and negative toward';
      } else if (delta <= -5) {
        attitude = 'cool or distrustful toward';
      } else {
        attitude = 'neutral toward';
      }

      buffer.writeln('- $otherName: $attitude ($delta)');
    }
    buffer.writeln();
    return buffer.toString();
  }

  /// Injects a trust-calibrated behavioral frame based on existing trust level (now via RelationshipService).
  /// Tells the model how much of the character's inner self to surface — but
  /// deliberately avoids prescribing specific behaviors, letting the character
  /// persona define what "opening up" actually looks like for THIS character.
  /// Trust tier 0 is now truly neutral — neither trusting nor distrustful.
  String buildTrustBehaviorInjection() {
    if (!getRealismEnabled() || getActiveCharacter() == null) return '';
    final charName = getActiveCharacter()!.name;
    final tier = relationshipService.trustTier; // now -7 to +7

    String frame;
    if (tier <= -5) {
      frame =
          'is deeply distrustful and paranoid toward {{user}} specifically. They question every motive, '
          'stay guarded and evasive, and read even positive gestures as an angle being worked.';
    } else if (tier <= -3) {
      frame =
          'is slow to open with {{user}}. They keep things surface-level, hold real vulnerability back, '
          'and quietly test {{user}}\'s intentions before showing anything true.';
    } else if (tier <= -1) {
      frame =
          'holds {{user}} a little at arm\'s length, keeping deeper feelings and secrets in reserve until '
          '{{user}} gives them more reason to lower their guard.';
    } else if (tier == 0) {
      frame =
          'has no particular trust or distrust of {{user}} yet — they engage on the merits of the moment, '
          'neither assuming the best nor the worst.';
    } else if (tier <= 2) {
      frame =
          'is beginning to trust {{user}}, giving them the benefit of the doubt and letting them a little '
          'further past the usual guard than they would a stranger.';
    } else if (tier <= 4) {
      frame =
          'genuinely trusts {{user}} — the social mask is down. They share real feelings and speak more '
          'candidly than they would with most people. What that looks like depends entirely on $charName\'s '
          'own character — an introvert might just hold eye contact longer or say one true thing; an '
          'expressive one might open up more.';
    } else {
      frame =
          'trusts {{user}} at a level that is rare for them — fully themselves, no performance, no guard. '
          'They may reveal things they have never told anyone, in whatever form is authentic to $charName.';
    }

    return '[Trust Calibration — $charName $frame'
        ' This governs only how far $charName lets {{user}} past their guard — how much vulnerability, '
        'candor, and real feeling they risk — NOT their baseline temperament. A warm, funny, or open '
        'character stays exactly that warm and funny at every trust level (trust only changes how deep it '
        'goes); a cold or prickly one stays cold. Never mute $charName\'s natural personality to signal '
        'caution — express any guardedness through what they hold back, not by becoming flatter than they are.]\n';
  }
}
