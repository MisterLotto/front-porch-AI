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

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/models/needs_impact.dart';

/// Documented decay modifier for the `tickDecay` pipeline.
/// Name for logs; condition decides applicability; factor the multiplier.
/// Applied after base decay + time-of-day.
typedef DecayModifier = ({
  String name,
  bool Function(String key, Map<String, int> vector, NeedsSimulation ctx) condition,
  double Function(String key, int current, NeedsSimulation ctx) factor,
});

/// Plain (non-ChangeNotifier) domain service owning the Needs simulation.
///
/// After buffer/afterglow/post-climax-crash/arousal-suppression removal:
/// - Straight per-turn decay ticks (needDecay + time mods + remaining cross-boost modifiers).
/// - Scene deltas from model (reviewed by optional Director) applied via applySceneImpact.
/// - Catastrophe text when needs cross critical thresholds.
/// - No erotic buffers, no afterglow damp in decay, no crash multipliers, no suppression state.
///
/// 1:1 vs group per-speaker parity preserved via cbs + god impersonation.
/// Reset hygiene: initializeFresh/clearVector/resetBuffers (now just vector + pending catas + reason) called from god at all sites + both startNew.
///
/// Stateless w.r.t. card config; owner (god) owns resets.
class NeedsSimulation {
  final VoidCallback onNotify;
  final Future<void> Function() onSaveChat;

  final String Function() getTimeOfDay;
  final bool Function() getRealismEnabled;
  final bool Function() getObserverMode;
  final String Function() getCurrentSpeakerIdForRealism;
  final bool Function() getIsGroupNonObserverMode;
  final Map<String, int> Function(String charId) getGroupNeeds;
  final void Function(String charId, Map<String, int> needs) setGroupNeeds;
  final bool Function() getEnjoysLowHygiene;
  final bool Function() getNeedsSimEnabled;
  final Map<String, int>? Function()? getCustomDecayRates;

  Map<String, int> _vector = {};
  String? _pendingCatastrophe;
  String? _lastSceneReason; // from model/Director for better chip reasons on scene deltas

  NeedsSimulation({
    required this.onNotify,
    required this.onSaveChat,
    required this.getTimeOfDay,
    required this.getRealismEnabled,
    required this.getObserverMode,
    required this.getCurrentSpeakerIdForRealism,
    required this.getIsGroupNonObserverMode,
    required this.getGroupNeeds,
    required this.setGroupNeeds,
    required this.getEnjoysLowHygiene,
    required this.getNeedsSimEnabled,
    this.getCustomDecayRates,
  });

  Map<String, int> get vector => Map<String, int>.unmodifiable(_vector);
  String? get pendingCatastrophe => _pendingCatastrophe;

  // Buffer state and getters completely removed.

  static const List<String> needKeys = [
    'hunger', 'bladder', 'energy', 'social', 'fun', 'hygiene', 'comfort',
  ];

  static const Map<String, int> needDefaults = {
    'hunger': 75, 'bladder': 80, 'energy': 80, 'social': 65, 'fun': 65, 'hygiene': 75, 'comfort': 70,
  };

  static const Map<String, int> needDecay = {
    'hunger': 4, 'bladder': 6, 'energy': 3, 'social': 2, 'fun': 2, 'hygiene': 1, 'comfort': 2,
  };

  static const Map<String, int> needRestore = {
    'hunger': 50, 'bladder': 70, 'energy': 40, 'social': 45, 'fun': 40, 'hygiene': 35, 'comfort': 35,
  };
  static const int needRestoreDefault = 30;

  static const int needUrgentThreshold = 35;
  static const int needCriticalThreshold = 20;

  static const List<int> needStepUpperBounds = [0, 15, 30, 45, 65];

  static const Map<String, List<String>> needSteppedText = {
    'hunger': [
      '''A violent stomach cramp doubles them over. They are genuinely starving — vision swimming, knees weak, barely able to stay upright. The hunger has become a real physical crisis.''',
      '''Sharp, gnawing cramps twist through them. They feel light-headed and shaky, and their thoughts keep drifting uncontrollably to food. They are struggling to focus on anything else.''',
      '''Their stomach feels painfully hollow and tight. A constant, distracting ache that makes them restless and short-tempered. They keep thinking about when they might be able to eat.''',
      '''A steady, empty feeling sits in their stomach. Their thoughts occasionally wander toward food and they feel a bit distracted or low-energy.''',
      '''A quiet, background emptiness in their stomach. It is not urgent, but they are aware of it and would welcome a chance to eat soon.''',
    ],
    'bladder': [
      '''They lose control completely. A sudden, hot rush — they are wetting themselves right now in the current scene. The humiliation is immediate and overwhelming.''',
      '''They are fighting with everything they have not to lose control. Thighs pressed tight, constantly shifting, voice tight with strain. They are very close to having an accident.''',
      '''A strong, insistent pressure has built up. They are visibly uncomfortable and keep looking for a polite way to excuse themselves soon.''',
      '''A steady, distracting pressure low in their belly. They feel the need more and more and would like to find a bathroom before too long.''',
      '''A faint but persistent urge to use the restroom sits at the back of their mind, making them slightly restless.''',
    ],
    'energy': [
      '''Their body gives out completely. Mid-sentence their eyes flutter and they collapse — slumping to the floor or into {{user}}'s arms, fully unconscious from exhaustion.''',
      '''They are barely staying awake. Head nodding, speech slow and heavy, eyes unfocused. They may drift off at any moment.''',
      '''A heavy, crushing tiredness has settled over them. Every movement feels like effort and their thoughts are slow. They desperately want to rest.''',
      '''A deep weariness is weighing on them. They move a little slower and seem less animated than usual, clearly running low on energy.''',
      '''A comfortable, heavy tiredness sits behind their eyes. They would happily curl up and rest if the opportunity arose.''',
    ],
    'social': [
      '''The loneliness has become overwhelming. They feel hollow and raw, on the edge of breaking down if they cannot have real, meaningful connection with someone soon.''',
      '''They feel painfully isolated. The lack of real connection is starting to hurt, and they may become unusually quiet, clingy, or emotionally fragile.''',
      '''A deep ache for genuine connection sits in their chest. Casual interaction feels hollow and they keep seeking more meaningful moments or closeness.''',
      '''They are feeling the absence of real companionship. They seem a little more eager for meaningful conversation or physical closeness than usual.''',
      '''A quiet, gentle craving for real connection makes them a bit more warm and attentive than normal.''',
    ],
    'fun': [
      '''The boredom has become torturous. They feel dangerously restless and may suddenly do something reckless or wildly inappropriate just to feel *something* again.''',
      '''They are deeply restless and bored out of their mind. They fidget constantly and will suggest almost anything to break the monotony.''',
      '''A heavy restlessness has settled over them. Everything feels dull and they keep looking for any excuse to do something more stimulating.''',
      '''They are noticeably bored and fidgety. The current situation feels flat and they are actively hoping for a change of pace.''',
      '''A mild restlessness makes them a little more eager for something fun or different to happen.''',
    ],
    'hygiene': [
      '''They feel filthy and overwhelmed by it. The grime or smell is so strong it is making them physically uncomfortable and self-conscious to the point of distress.''',
      '''They feel genuinely dirty and are very aware of it. They keep wanting to cover themselves or pull away from contact until they can clean up.''',
      '''A persistent feeling of being grimy clings to them. They are self-conscious and keep thinking about when they can wash or change.''',
      '''They are starting to feel noticeably unkempt. A quiet discomfort with their own state makes them want to freshen up soon.''',
      '''A faint, background sense of being a little grubby makes them mildly self-conscious.''',
    ],
    'comfort': [
      '''The physical discomfort has become unbearable. They cannot stay like this any longer and will do whatever it takes to find relief, even if it disrupts everything else happening.''',
      '''Their body is in real distress — too hot, too cold, cramped, or aching badly. They are constantly shifting and struggling to focus on anything else.''',
      '''A strong physical discomfort is wearing on them. They keep adjusting their position or environment, clearly unable to settle.''',
      '''They are noticeably uncomfortable. A persistent physical irritation (temperature, pressure, stiffness) makes it hard for them to fully relax.''',
      '''A mild but persistent physical discomfort sits in the background, making them slightly restless.''',
    ],
  };

  /// Hygiene descriptions for a character with "enjoys low hygiene" set. For
  /// them the whole scale is inverted: being DIRTY is comfort, being CLEAN is
  /// the aversive state. The normal [needSteppedText] is all phrased "dirty =
  /// bad", so reusing it after the step inversion would describe a freshly-
  /// scrubbed character as "feeling filthy" — the exact opposite of the truth.
  /// This list is worst-first like the others (index 0 = scrubbed unbearably
  /// clean → index 4 = only faintly too fresh). This is an ODOR/MUSK preference
  /// ONLY: the character is soothed by their own unwashed body scent and put off
  /// by feeling soap-clean. It is NOT a drive to make a mess — no seeking dirt,
  /// mud, or filth acts (a character once dumped a mop bucket over herself off
  /// the old wording). The distress is missing their natural scent; the comfort
  /// is simply remaining unwashed and musky. Neutral voice (they/them).
  static const List<String> hygieneSteppedTextWhenEnjoysLow = [
    '''Scrubbed and scentless in a way that feels wrong on their skin — their familiar musk scoured completely away. It leaves them exposed and on edge, quietly wishing they still smelled like themselves. (This is about missing their own natural scent, not about seeking out filth.)''',
    '''Uncomfortably fresh — too soft, too soapy, their natural scent washed thin. The absence of their usual body musk puts them off-balance; they'd rather not have washed so thoroughly.''',
    '''Still a little too clean for their taste. Without their familiar musk they feel oddly self-conscious, as if something comforting is missing.''',
    '''Starting to feel a touch over-scrubbed; part of them misses the settled, lived-in comfort of their own unwashed scent.''',
    '''A faint just-washed freshness lingers that they find mildly unsatisfying next to their natural musk.''',
  ];

  // Mandatory "this just happened" events fired when a HARD-EVENT need bottoms
  // out (≤0). Neutral voice (they/them). Each line carries its OWN observable
  // evidence, so the injection wrapper stays generic (no bladder-centric list).
  // Deliberately NO social/fun entries — those are moods, not discrete events
  // (the old "fun=0 → do something dangerous/sexual/chaotic" line was a model-
  // derailment vector); they max out as intense distress in the stepped text
  // instead. Hygiene is skipped entirely for "enjoys low hygiene" characters
  // (for them 0 hygiene is comfort, not a crisis).
  static const Map<String, String> needCatastropheText = {
    'hunger':
        '''Starvation buckles them — they sag, grey-faced and unsteady, and have to catch themselves on the nearest support just to stay upright. Their body has hit its limit and it shows.''',
    'bladder':
        '''Their control gives out. It's happening right now, in the scene — a hot, unstoppable release, fabric darkening, a spreading wet patch, the smell of it. The accident is occurring this instant, not a warning or a near-miss.''',
    'energy':
        '''Exhaustion drops them mid-action — their knees buckle and they collapse, briefly blacking out as they slump to the floor or the nearest surface. They come to a few seconds later, dazed and groggy, barely able to keep their eyes open or form a clear thought.''',
    'hygiene':
        '''Their own grime and body odor turn undeniable this turn — sharp enough that they notice it on their own skin, or the people around them visibly react to it. It's an unmistakable, distracting presence in the scene.''',
    'comfort':
        '''The strain becomes unbearable — the cramped position, the temperature, the pressure, the restraint, whatever is causing it. They have to shift, break contact with the source, or otherwise ease it; they can't simply hold still through it any longer.''',
  };

  /// Recovery floor by need CLASS after a catastrophe (no magic per-need +N):
  ///   body-reset — a physiological event that (partly) empties the meter:
  ///     bladder (just went → nearly empty), hunger (stabilized, not fed),
  ///     energy (came to groggy, NOT a full rest — user said collapse-and-groggy,
  ///     not fall-asleep).
  ///   crisis-vent — a behavioral/sensory peak with only partial relief:
  ///     hygiene, comfort (the moment passes; nothing was actually cleaned/fixed).
  static const Map<String, int> needPostCatastropheFloor = {
    'bladder': 85,
    'hunger': 70,
    'energy': 65,
    'hygiene': 55,
    'comfort': 60,
  };

  /// The only needs that fire a hard catastrophe (see [needCatastropheText]).
  static const List<String> catastropheNeeds = [
    'bladder',
    'energy',
    'hunger',
    'comfort',
    'hygiene',
  ];

  // Decay modifiers (non-buffer ones retained; afterglow_damp and suppression-conditioned ones removed or simplified).
  static final List<DecayModifier> decayModifiers = <DecayModifier>[
    (
      name: 'low_energy_hunger_boost',
      condition: (key, vector, ctx) => key == 'hunger' && (vector['energy'] ?? 50) <= 30,
      factor: (key, current, ctx) => 1.35,
    ),
    (
      name: 'low_energy_comfort_boost',
      condition: (key, vector, ctx) => key == 'comfort' && (vector['energy'] ?? 50) <= 25,
      factor: (key, current, ctx) => 1.25,
    ),
    (
      name: 'low_fun_social_boost',
      condition: (key, vector, ctx) => key == 'social' && (vector['fun'] ?? 50) <= 20,
      factor: (key, current, ctx) => 1.4,
    ),
    (
      name: 'low_bladder_comfort_boost',
      condition: (key, vector, ctx) => key == 'comfort' && (vector['bladder'] ?? 50) <= 20,
      factor: (key, current, ctx) => 1.25,
    ),
    // (enjoys low hygiene arousal mutation and other buffer-dependent modifiers removed with the buffers)
  ];

  void initializeFresh() {
    _vector = Map<String, int>.from(needDefaults);
    _pendingCatastrophe = null;
    _lastSceneReason = null;
    // No buffer state to zero.
  }

  /// THE single per-key decay rule (rate + modifier pipeline + clamp), shared
  /// by the 1:1 tick, the group tick, and the group per-speaker decay in the
  /// realism dance — so a group member decays exactly like the same card in a
  /// 1:1 chat (parity). [vector] is the live map the modifier conditions read;
  /// pass the map being decayed so later keys see earlier keys' decayed values
  /// (the historical in-loop semantics).
  int decayedValueFor(
    String key,
    int current,
    Map<String, int> vector,
    Map<String, int> customRates,
  ) {
    int decay = customRates[key] ?? needDecay[key] ?? 0;
    for (final mod in decayModifiers) {
      if (mod.condition(key, vector, this)) {
        decay = (decay * mod.factor(key, current, this)).round();
      }
    }
    return (current - decay).clamp(0, 100);
  }

  /// Initialize the needs vector from card-specific baseline values.
  ///
  /// Used when starting a new chat so that the character's
  /// [FrontPorchExtensions] baseline needs (needsBaselineHunger, etc.)
  /// are respected instead of the hardcoded [needDefaults].
  void initializeFreshWithDefaults(Map<String, int> defaults) {
    _vector = Map<String, int>.from(defaults);
    _pendingCatastrophe = null;
    _lastSceneReason = null;
    // No buffer state to zero.
  }

  void clearVector() {
    _vector.clear();
    _pendingCatastrophe = null;
    _lastSceneReason = null;
  }

  void resetBuffers() {
    // Buffer reset is now a no-op (buffers expunged). Kept for god reset hygiene calls.
    _pendingCatastrophe = null;
    _lastSceneReason = null;
  }

  void applySceneImpact(NeedsImpact impact) {
    if (impact.deltas.isNotEmpty) {
      for (final entry in impact.deltas.entries) {
        final k = entry.key;
        if (_vector.containsKey(k)) {
          _vector[k] = (_vector[k]! + entry.value).clamp(0, 100);
        }
      }
    }
    if (impact.reason != null && impact.reason!.isNotEmpty) {
      _lastSceneReason = impact.reason;
    }
    onSaveChat();
    onNotify();
  }

  void applyNeedsDeltas(Map<String, int> deltas, {bool fromSexualActivity = false}) {
    // Kept for any legacy direct callers; delegates to impact path (no buffer side effects).
    applySceneImpact(NeedsImpact(deltas: deltas));
  }

  Map<String, dynamic> computeNeedsDeltasWithReasons(Map<String, int> pre) {
    final out = <String, dynamic>{};
    for (final k in needKeys) {
      final before = pre[k] ?? 0;
      final after = _vector[k] ?? before;
      final delta = after - before;
      String reason = 'Stable';
      if (delta > 0) reason = 'Scene action';
      if (delta < 0) reason = 'Natural decay';
      if (_lastSceneReason != null && _lastSceneReason!.isNotEmpty) reason = _lastSceneReason!;
      if (delta != 0) {
        out[k] = {'delta': delta, 'reason': reason};
      }
    }
    return out;
  }

  void tickDecay() {
    if (!getNeedsSimEnabled() || !getRealismEnabled()) return;

    final customRates = getCustomDecayRates?.call() ?? {};
    final isGroupNonObserver = getIsGroupNonObserverMode();
    if (isGroupNonObserver) {
      final sid = getCurrentSpeakerIdForRealism();
      var needs = getGroupNeeds(sid);
      if (needs.isEmpty) {
        needs = Map.fromEntries(needKeys.map((k) => MapEntry(k, 80)));
      }

      for (final key in needKeys) {
        final current = needs[key] ?? 80;
        needs[key] = decayedValueFor(key, current, needs, customRates);
      }
      setGroupNeeds(sid, needs);
      return;
    }

    // 1:1 scalar path (pure decay + simplified modifiers, no buffer damp/crash)
    for (final key in needKeys) {
      final current = _vector[key];
      if (current == null) continue;
      _vector[key] = decayedValueFor(key, current, _vector, customRates);
    }

    // Fire a catastrophe if any hard-event need bottomed out this tick.
    applyCatastropheIfNeeded();

    onSaveChat();
    onNotify();
  }

  /// When a hard-event need has bottomed out (≤0) this turn, arm ONE mandatory
  /// catastrophe (the worst such need) for the prompt builder and lift that
  /// need to its recovery floor so it can't instantly re-fire. Operates on the
  /// live [_vector] — the 1:1 host's (called from [tickDecay]), or a group
  /// speaker's after their scalars are loaded (called from the realism dance),
  /// so 1:1 and group behave identically. Hygiene is skipped for "enjoys low
  /// hygiene" characters (0 hygiene is comfort, not a crisis, for them).
  void applyCatastropheIfNeeded() {
    if (!getNeedsSimEnabled() || !getRealismEnabled()) return;
    if (_pendingCatastrophe != null) return; // one pending event at a time
    final enjoysLow = getEnjoysLowHygiene();
    String? worst;
    int worstVal = 1; // only needs at 0 or below qualify
    for (final key in catastropheNeeds) {
      if (key == 'hygiene' && enjoysLow) continue;
      final v = _vector[key];
      if (v == null) continue;
      if (v <= 0 && v < worstVal) {
        worstVal = v;
        worst = key;
      }
    }
    if (worst == null) return;
    _pendingCatastrophe = needCatastropheText[worst];
    _vector[worst] = needPostCatastropheFloor[worst] ?? 50;
    debugPrint(
      '[Realism:Needs] ⚠️ CATASTROPHE armed for $worst → floor ${_vector[worst]}',
    );
  }

  // applyLongGenerationNeedsDecay, getInjectionEffectiveStep, and other buffer-aware helpers simplified or removed.
  // For injection, owner falls back to basic step from current vector.

  void restoreFromSnapshot(Map<dynamic, dynamic> needsData) {
    if (needsData['vector'] is Map) {
      // Tolerant restore for snapshots that may come from JSON (numbers as num)
      // or mixed dynamic maps (e.g. persisted realism_state['needs'] or pre_state).
      // Also tolerates the 'deltas' sibling key that capture now includes.
      final raw = needsData['vector'] as Map;
      _vector = {
        for (final e in raw.entries)
          if (e.value is num) e.key.toString(): (e.value as num).toInt(),
      };
    }
    // No buffer restore.
    _lastSceneReason = null;
  }

  /// Clears the scene-level reason so the delta chip falls back to
  /// per-need reasons ("Scene action", "Natural decay", "Stable").
  void clearLastSceneReason() {
    _lastSceneReason = null;
  }

  void consumePendingCatastrophe() {
    _pendingCatastrophe = null;
  }

  int needRestoreAmount(String need) {
    return needRestore[need] ?? needRestoreDefault;
  }

  int getNeedStep(String need, int value) {
    for (int s = 0; s < needStepUpperBounds.length; s++) {
      if (value <= needStepUpperBounds[s]) return s;
    }
    return 5;
  }

  /// Effective stepped urgency for prompt injection.
  ///
  /// [enjoysLowHygieneOverride] lets the caller supply the flag for the SPECIFIC
  /// character whose need is being rendered. This is required in group chats:
  /// the shared [getEnjoysLowHygiene] callback reads the chat's *active*
  /// character, which — after the per-speaker realism dance restores the pointer
  /// — is the PREVIOUS speaker, not the one this line belongs to. Passing the
  /// speaker's own flag stops one filthy-loving member from inverting every
  /// other member's hygiene (the "hygiene 88 shows CATASTROPHIC" bleed). The 1:1
  /// path passes null and keeps using the global (active == host there).
  int getInjectionEffectiveStep(
    String need,
    int value, {
    bool? enjoysLowHygieneOverride,
  }) {
    int step = getNeedStep(need, value);
    final enjoysLow = enjoysLowHygieneOverride ?? getEnjoysLowHygiene();
    if (enjoysLow && need == 'hygiene') {
      step = (5 - step).clamp(0, 5);
    }
    return step;
  }

  String getUrgencyPrefixForStep(int effectiveStep) {
    return switch (effectiveStep) {
      0 => 'CATASTROPHIC — this has already happened and must be roleplayed immediately.',
      1 => 'CRITICAL — they are in real, urgent distress from this need.',
      2 => 'Strong need — this is heavily weighing on them and affecting their focus.',
      3 => 'Noticeable need — this is a clear background pressure on their mood and attention.',
      _ => 'Mild background sensation — this is subtly coloring their state.',
    };
  }

  String getSecondaryLowNeedNote(
    List<MapEntry<String, int>> sorted,
    String topKey,
    int effectiveStep,
  ) {
    // Relaxed to <=4 to match the new progressive early-hint policy (mild step-4 now visible).
    if (effectiveStep < 1 || effectiveStep > 4) return '';
    final secondary = sorted
        .where((e) => e.key != topKey && getNeedStep(e.key, e.value) <= 4)
        .firstOrNull;
    if (secondary == null) return '';
    return ' (They are also feeling the ${secondary.key} need.)';
  }

  /// Returns the lowest 1-2 needs that should receive background state text this turn
  /// (those whose effective step is 4 or lower, i.e. mild or worse after enjoys inversion).
  /// Always worst-first. Both 1:1 and group paths use this for consistent selection and
  /// so slow-decaying needs (Comfort, Hygiene) can appear even when not the absolute lowest.
  /// This revives the progressive early subtle hints (step 4 "Mild background sensation...")
  /// while still preventing constant high-value noise.
  List<({String key, int value, int effectiveStep})> getLowNeedsForInjection(
      Map<String, int> vector) {
    if (vector.isEmpty) return const [];
    final entries = vector.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final result = <({String key, int value, int effectiveStep})>[];
    for (final e in entries) {
      final eff = getInjectionEffectiveStep(e.key, e.value);
      if (eff <= 4) {
        result.add((key: e.key, value: e.value, effectiveStep: eff));
        if (result.length >= 2) break;
      }
    }
    return result;
  }

  String getPostCrashSuffixIfRelevant(String topKey) {
    return '';
  }
}
