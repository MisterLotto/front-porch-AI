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

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/ambition_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/behavioral_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/emotion_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/needs_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/nsfw_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/promise_debt_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/relationship_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/time_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/weather_injection.dart';

/// The words-only state block composer (docs/design/prompt-state-injection.md
/// §3): the ONE place the model receives the speaker's live internal state.
///
/// Thin by contract — this class only GATES, ORDERS, and WRAPS the fragments
/// the leaf builders produce; all ladder/stepped prose lives in the leaves
/// (file-size rule + single source per fact). No simulation scalar ever
/// appears here: every number was translated to banded language upstream, so
/// stat-bleed ("my hunger at 41…") is structurally impossible rather than
/// merely discouraged. Salience-gated fragments return '' and vanish. (In
/// practice the bond+tension line renders whenever realism is on — a
/// deliberate anti-drift anchor — so the block only fully disappears when
/// realism is off or every builder is inactive; "quiet" means ~130 tokens,
/// not zero.)
///
/// Output shape (macro-resolved by the assembly call site — fragments may
/// carry {{user}}):
///
/// ```
/// [How NAME is right now:
/// time line
/// bond+tension (+voice note)
/// trust calibration
/// mood line
/// 0-3 need lines
/// body/arousal line
/// fixation / position lines
/// private group feelings
/// Express all of this only through NAME's behavior, body language, and
/// voice — never quote meters, scores, percentages, turn counts, or system
/// terms.]
/// ```
///
/// Replaces the old "Current Metrics" sheet + 8 restating sub-blocks + three
/// collation paragraphs (~700-1200 tokens, every fact 2-3×, and a literal
/// "use these numbers directly" instruction that CAUSED the reported
/// stat-bleed). 1:1↔group parity rides the leaves' per-speaker dispatch,
/// exactly as before; one-shot parity holds because both eval paths share
/// this single assembly-time block.
class RealismStateInjection {
  final RelationshipInjection relationshipInjection;
  final EmotionInjection emotionInjection;
  final TimeInjection timeInjection;
  final WeatherInjection weatherInjection;
  final AmbitionInjection ambitionInjection;
  final PromiseDebtInjection promiseDebtInjection;
  final BehavioralInjection behavioralInjection;
  final NsfwInjection nsfwInjection;
  final NeedsInjection needsInjection;

  final bool Function() getRealismEnabled;

  /// Whether the story clock is actually advancing — under the engine, or on
  /// the standalone scene-time eval. Gates the scene-facts fragments (see
  /// [_sceneFactsEnabled]).
  ///
  /// Optional for the same reason as the two below: existing callers and the
  /// protected prompt_injection_test keep compiling. Absent falls back to
  /// [getRealismEnabled], which is byte-for-byte the behaviour those callers
  /// had before the standalone clock existed.
  final bool Function()? getClockRunningOverride;

  bool getClockRunning() =>
      (getClockRunningOverride ?? getRealismEnabled).call();

  /// Long-term goals. Independent of realism: card-authored, never stale.
  ///
  /// Optional so existing callers (and the protected prompt_injection_test)
  /// keep compiling; absent means "on", which matches how these behaved
  /// whenever realism was enabled.
  final bool Function()? getAmbitionsEnabled;

  /// The promise ledger. Independent of realism, but stored as Journal cards,
  /// so the caller's predicate must also require the Journal. Optional for the
  /// same reason as above.
  final bool Function()? getPromisesEnabled;
  final bool Function() getIsGroupNonObserverMode;
  final String Function() getCurrentSpeakerIdForRealism;
  final List<CharacterCard> Function() getGroupCharacters;
  final CharacterCard? Function() getActiveCharacter;
  final String Function(CharacterCard) getCharacterIdFromCard;

  RealismStateInjection({
    required this.relationshipInjection,
    required this.emotionInjection,
    required this.timeInjection,
    required this.weatherInjection,
    this.getAmbitionsEnabled,
    this.getPromisesEnabled,
    required this.ambitionInjection,
    required this.promiseDebtInjection,
    required this.behavioralInjection,
    required this.nsfwInjection,
    required this.needsInjection,
    required this.getRealismEnabled,
    this.getClockRunningOverride,
    required this.getIsGroupNonObserverMode,
    required this.getCurrentSpeakerIdForRealism,
    required this.getGroupCharacters,
    required this.getActiveCharacter,
    required this.getCharacterIdFromCard,
  });

  String _speakerName() {
    if (getIsGroupNonObserverMode()) {
      final id = getCurrentSpeakerIdForRealism();
      final card = getGroupCharacters()
          .where((c) => getCharacterIdFromCard(c) == id)
          .firstOrNull;
      // Never fall back to getActiveCharacter() in group mode — it points at
      // the PREVIOUS speaker after the realism dance, and heading the block
      // with their name over this speaker's data is worse than a generic
      // label (review finding).
      return card?.name ?? 'the character';
    }
    return getActiveCharacter()?.name ?? 'the character';
  }

  /// SCENE FACTS: where and when the scene is, what this character is working
  /// toward, and what they owe. Four of the fragments below are these, and not
  /// one of them contains a realism check of its own — time_injection has no
  /// gate at all, weather gates on the weather being null, and ambitions and
  /// promises gate on having any.
  ///
  /// This getter covers only TIME and WEATHER now — ambitions and promises
  /// each answer to their own user-facing switch (getAmbitionsEnabled /
  /// getPromisesEnabled), because neither needs the engine: ambitions are
  /// card-authored text, promises are Journal cards detected from dialogue.
  ///
  /// And time and weather do not need the engine either. They need a clock
  /// that MOVES, which is what [getClockRunning] reports (updated 2026-08-06,
  /// superseding the 2026-08-02 "must stay gated on realism" note here).
  ///
  /// The old reasoning was sound for its facts: with the clock frozen, this
  /// fragment would inject the SAME timestamp every turn while the story
  /// visibly moved — a lie told once per turn. That is still true, and it is
  /// still what this gate prevents. The change is only in what unfreezes the
  /// clock: the engine used to be the sole driver, and now the standalone
  /// scene-time eval is a second one. When neither is running, this is false
  /// and the fragment is suppressed exactly as before. Weather follows for
  /// free — currentWeather is null unless the clock is moving.
  ///
  /// Do NOT weaken this to "passage of time is enabled". That flag defaults
  /// on and is inert without a driver, so it would resurrect precisely the
  /// frozen-timestamp lie this gate exists to stop.
  bool get _sceneFactsEnabled => getClockRunning();

  /// CHARACTER STATE: how this character is right now. Genuinely realism, and
  /// correctly gated.
  bool get _characterStateEnabled => getRealismEnabled();

  String buildRealismStateInjection() {
    // No blanket early return. One gate used to sit here and silently delete
    // all eleven fragments — including the four that are not realism features —
    // which made the coupling invisible to anyone reading a single builder.
    // Each fragment now declares which gate it answers to, in the original
    // order, so the emitted prompt is unchanged while the dependency is legible.
    final fragments = <String>[
      if (_sceneFactsEnabled) timeInjection.buildTimeInjection(),
      if (_sceneFactsEnabled) weatherInjection.buildWeatherInjection(),
      if (_characterStateEnabled)
        relationshipInjection.buildRelationshipInjection(),
      if (_characterStateEnabled)
        relationshipInjection.buildTrustBehaviorInjection(),
      if (_characterStateEnabled) emotionInjection.buildEmotionInjection(),
      if (_characterStateEnabled) needsInjection.buildNeedsInjection(),
      if (_characterStateEnabled) nsfwInjection.buildNsfwCooldownInjection(),
      if (getAmbitionsEnabled?.call() ?? true)
        ambitionInjection.buildAmbitionInjection(),
      if (getPromisesEnabled?.call() ?? true)
        promiseDebtInjection.buildPromiseDebtInjection(),
      if (_characterStateEnabled)
        behavioralInjection.buildBehavioralMechanicsInjection(),
      if (_characterStateEnabled)
        relationshipInjection.buildInterCharacterFeelingsInjection(),
    ].where((f) => f.trim().isNotEmpty).map((f) => f.trim()).toList();

    if (fragments.isEmpty) return '';

    final name = _speakerName();
    return '[How $name is right now:\n'
        '${fragments.join('\n')}\n'
        'Express all of this only through $name\'s behavior, body language, '
        'and voice — never quote meters, scores, percentages, turn counts, '
        'or system terms.]\n';
  }
}
