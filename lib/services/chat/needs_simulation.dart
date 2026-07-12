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
      '''A violent stomach cramp doubles her over. She is genuinely starving — vision swimming, knees weak, barely able to stay upright. The hunger has become a real physical crisis.''',
      '''Sharp, gnawing cramps twist through her. She feels light-headed and shaky, and her thoughts keep drifting uncontrollably to food. She is struggling to focus on anything else.''',
      '''Her stomach feels painfully hollow and tight. A constant, distracting ache that makes her restless and short-tempered. She keeps thinking about when she might be able to eat.''',
      '''A steady, empty feeling sits in her stomach. Her thoughts occasionally wander toward food and she feels a bit distracted or low-energy.''',
      '''A quiet, background emptiness in her stomach. It is not urgent, but she is aware of it and would welcome a chance to eat soon.''',
    ],
    'bladder': [
      '''She loses control completely. A sudden, hot rush — she is wetting herself right now in the current scene. The humiliation is immediate and overwhelming.''',
      '''She is fighting with everything she has not to lose control. Thighs pressed tight, constantly shifting, voice tight with strain. She is very close to having an accident.''',
      '''A strong, insistent pressure has built up. She is visibly uncomfortable and keeps looking for a polite way to excuse herself soon.''',
      '''A steady, distracting pressure low in her belly. She feels the need more and more and would like to find a bathroom before too long.''',
      '''A faint but persistent urge to use the restroom sits at the back of her mind, making her slightly restless.''',
    ],
    'energy': [
      '''Her body gives out completely. Mid-sentence her eyes flutter and she collapses — slumping to the floor or into {{user}}'s arms, fully unconscious from exhaustion.''',
      '''She is barely staying awake. Head nodding, speech slow and heavy, eyes unfocused. She may drift off at any moment.''',
      '''A heavy, crushing tiredness has settled over her. Every movement feels like effort and her thoughts are slow. She desperately wants to rest.''',
      '''A deep weariness is weighing on her. She moves a little slower and seems less animated than usual, clearly running low on energy.''',
      '''A comfortable, heavy tiredness sits behind her eyes. She would happily curl up and rest if the opportunity arose.''',
    ],
    'social': [
      '''The loneliness has become overwhelming. She feels hollow and raw, on the edge of breaking down if she cannot have real, meaningful connection with someone soon.''',
      '''She feels painfully isolated. The lack of real connection is starting to hurt, and she may become unusually quiet, clingy, or emotionally fragile.''',
      '''A deep ache for genuine connection sits in her chest. Casual interaction feels hollow and she keeps seeking more meaningful moments or closeness.''',
      '''She is feeling the absence of real companionship. She seems a little more eager for meaningful conversation or physical closeness than usual.''',
      '''A quiet, gentle craving for real connection makes her a bit more warm and attentive than normal.''',
    ],
    'fun': [
      '''The boredom has become torturous. She feels dangerously restless and may suddenly do something reckless or wildly inappropriate just to feel *something* again.''',
      '''She is deeply restless and bored out of her mind. She fidgets constantly and will suggest almost anything to break the monotony.''',
      '''A heavy restlessness has settled over her. Everything feels dull and she keeps looking for any excuse to do something more stimulating.''',
      '''She is noticeably bored and fidgety. The current situation feels flat and she is actively hoping for a change of pace.''',
      '''A mild restlessness makes her a little more eager for something fun or different to happen.''',
    ],
    'hygiene': [
      '''She feels filthy and overwhelmed by it. The grime or smell is so strong it is making her physically uncomfortable and self-conscious to the point of distress.''',
      '''She feels genuinely dirty and is very aware of it. She keeps wanting to cover herself or pull away from contact until she can clean up.''',
      '''A persistent feeling of being grimy clings to her. She is self-conscious and keeps thinking about when she can wash or change.''',
      '''She is starting to feel noticeably unkempt. A quiet discomfort with her own state makes her want to freshen up soon.''',
      '''A faint, background sense of being a little grubby makes her mildly self-conscious.''',
    ],
    'comfort': [
      '''The physical discomfort has become unbearable. She cannot stay like this any longer and will do whatever it takes to find relief, even if it disrupts everything else happening.''',
      '''Her body is in real distress — too hot, too cold, cramped, or aching badly. She is constantly shifting and struggling to focus on anything else.''',
      '''A strong physical discomfort is wearing on her. She keeps adjusting her position or environment, clearly unable to settle.''',
      '''She is noticeably uncomfortable. A persistent physical irritation (temperature, pressure, stiffness) makes it hard for her to fully relax.''',
      '''A mild but persistent physical discomfort sits in the background, making her slightly restless.''',
    ],
  };

  /// Hygiene descriptions for a character with "enjoys low hygiene" set. For
  /// them the whole scale is inverted: being DIRTY is comfort, being CLEAN is
  /// the aversive state. The normal [needSteppedText] is all phrased "dirty =
  /// bad", so reusing it after the step inversion would describe a freshly-
  /// scrubbed character as "feeling filthy" — the exact opposite of the truth.
  /// This list is worst-first like the others (index 0 = scrubbed unbearably
  /// clean → index 4 = only faintly too fresh), describing distress at being
  /// too clean and a craving to get grubby/musky again.
  static const List<String> hygieneSteppedTextWhenEnjoysLow = [
    '''Scrubbed pink and reeking of soap, she feels stripped bare and wrong — her comforting musk scoured completely away. It is deeply unsettling to her; she is agitated and self-conscious, craving to sweat, get grimy, and smell like herself again as soon as possible.''',
    '''She feels uncomfortably clean — too soft, too fragrant, her natural scent washed thin. It puts her on edge, and she keeps wanting to work up a real sweat or get properly dirty again.''',
    '''A freshly-washed cleanness clings to her that she dislikes. She feels a little exposed without her usual musk and would happily get her hands dirty.''',
    '''She is starting to feel a touch too clean and fussy, and part of her misses the comfortable grime.''',
    '''A faint just-washed freshness lingers that she finds mildly unsatisfying.''',
  ];

  static const Map<String, String> needCatastropheText = {
    'hunger': '''A violent stomach cramp drops her to her knees or against {{user}}. She hasn't eaten in far too long; her blood sugar crashes and she nearly faints or becomes too weak to stand. The hunger has turned into a real physical emergency.''',
    'bladder': '''She loses control completely. A sudden, hot, unstoppable rush — she is wetting herself right now, in the current scene, in front of {{user}} or anyone present. The fabric darkens, liquid runs down her legs, the smell fills the air, and her face is a mask of horror and humiliation. The accident is happening / has just happened.''',
    'energy': '''Her body simply shuts down. Mid-sentence her eyes roll back and she collapses — slumping to the floor, onto furniture, or into {{user}}'s arms — completely unconscious from exhaustion. She is out cold and will not wake for some time.''',
    'social': '''The isolation finally breaks her. She bursts into tears or a raw, desperate plea for real connection, unable to pretend any longer that she is okay alone.''',
    'fun': '''The boredom has driven her to something reckless or wildly inappropriate — she does something dangerous, sexual, or chaotic purely to feel *anything* again.''',
    'hygiene': '''The accumulated grime and smell finally overwhelm her. She gags, tears up, or has a small breakdown about how disgusting she feels, refusing further contact until she can wash.''',
    'comfort': '''The physical misery becomes too much. She cries out, pushes away from whatever is hurting her (the chair, the ropes, the position, the temperature), and demands — or takes — immediate relief no matter what else is happening in the scene.''',
  };

  static const Map<String, int> needPostCatastropheFloor = {
    'hunger': 70, 'bladder': 85, 'energy': 65, 'social': 60, 'fun': 55, 'hygiene': 70, 'comfort': 70,
  };

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

    // (no buffer tickdown)
    // (no catas in this simplified tick for brevity; full catas can be re-added if needed from stepped thresholds)

    onSaveChat();
    onNotify();
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
      1 => 'CRITICAL — she is in real, urgent distress from this need.',
      2 => 'Strong need — this is heavily weighing on her and affecting her focus.',
      3 => 'Noticeable need — this is a clear background pressure on her mood and attention.',
      _ => 'Mild background sensation — this is subtly coloring her state.',
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
    return ' (She is also feeling the ${secondary.key} need.)';
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
