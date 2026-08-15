// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/utils/utils.dart';
import 'package:front_porch_ai/ui/widgets/story_begins_row.dart';
import 'package:front_porch_ai/ui/dialogs/group_settings/group_settings_support.dart';
import 'package:front_porch_ai/ui/dialogs/group_settings/member_baseline_seed.dart';

part 'realism_needs_tab.view.dart';
part 'realism_needs_tab.controls.dart';
part 'realism_needs_tab.member.dart';

class GroupRealismNeedsTab extends StatefulWidget {
  final ChatService chatService;
  final GroupChatRepository? groupRepo;
  const GroupRealismNeedsTab({super.key, required this.chatService, this.groupRepo});

  @override
  State<GroupRealismNeedsTab> createState() => _GroupRealismNeedsTabState();
}

class _GroupRealismNeedsTabState extends State<GroupRealismNeedsTab> {
  bool _realismEnabled = false;
  bool _passageOfTimeEnabled = true;
  bool _chaosModeEnabled = false;
  bool _chaosNsfwEnabled = false;
  bool _nsfwEnhancementsEnabled = false;

  // Group-wide Time & Day.
  String _groupTimeOfDay = 'morning';
  int _groupDayCount = 1;
  // Story Calendar seed for fresh sessions (story-calendar.md §3a).
  String? _groupStoryStartDate;
  String? _groupStoryStartTime;
  late final TextEditingController _groupDayCountController;

  List<CharacterCard> _chars = [];

  // Per-member Director/Verifier (Realism Verification) settings for groups.
  // Wired the same as 1:1 via per-member CharacterCard.frontPorchExtensions + impersonation.
  // UI exposed here for existing groups (previously only in creation flow).
  final Map<String, bool> _verificationEnabled = {};
  final Map<String, int> _verificationMaxReprocesses = {};
  final Map<String, int> _verificationStrictness = {};
  final Map<String, bool> _needsDirectorAuthority = {};

  // Baseline seeding state (only bond/trust/emotion/time/day)
  final Map<String, Map<String, dynamic>> _baselineSeeds = {};

  // Per-character editable realism baselines (seeded from baselineSeeds + card ext).
  final Map<String, int> _editShortTermBond = {};
  final Map<String, int> _editLongTermBond = {};
  final Map<String, int> _editTrustLevel = {};
  final Map<String, String> _editEmotion = {};
  final Map<String, String> _editEmotionIntensity = {};

  // Text controllers for inline editing fields.
  final Map<String, TextEditingController> _emotionControllers = {};

  @override
  void initState() {
    super.initState();
    widget.chatService.addListener(_onServiceChanged);
    _initializeFromService();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _initializeFromService() {
    final cs = widget.chatService;
    _chars = cs.groupCharacters;

    _realismEnabled = cs.realismEnabled;
    _passageOfTimeEnabled = cs.timeService.passageOfTimeEnabled;
    _chaosModeEnabled = cs.chaosModeService.chaosModeEnabled;
    _chaosNsfwEnabled = cs.chaosModeService.chaosNsfwEnabled;
    // Group NSFW Enhancements (arousal/Lust + post-climax cooldowns). Uses the
    // stable per-member group flag (the live nsfwService scalar is per-speaker
    // volatile in groups); the write side propagates to every member.
    _nsfwEnhancementsEnabled = cs.isGroupNsfwEnabled;

    // Group-wide Time & Day, plus the per-member seed blob the ENGINE reads on
    // a fresh chat (parseGroupRealismSeeds → GroupMemberRealism).
    Map<String, dynamic> perCharSeeds = const {};
    final group = cs.activeGroup;
    if (group != null) {
      final gs = group.defaultMemberRealismState;
      if (gs.isNotEmpty && gs != '{}') {
        final map = (jsonDecode(gs) as Map<String, dynamic>?) ?? {};
        _groupTimeOfDay = (map['timeOfDay'] as String?) ?? 'morning';
        _groupDayCount = (map['dayCount'] as num?)?.toInt() ?? 1;
        _groupStoryStartDate = map['storyStartDate'] as String?;
        _groupStoryStartTime = map['storyStartTime'] as String?;
        perCharSeeds =
            (map['perChar'] as Map?)?.cast<String, dynamic>() ?? const {};
      }
    }
    _groupDayCountController = TextEditingController(
      text: _groupDayCount.toString(),
    );

    // Load immutable creation baseline seeds (only the allowed fields)
    _baselineSeeds.clear();
    for (final c in _chars) {
      final id = _getCharId(c);
      _baselineSeeds[id] = Map<String, dynamic>.from(
        cs.getBaselineSeedForGroupCharacter(c),
      );

      // Load per-member Director/Verifier settings (if present on the member's card ext)
      _verificationEnabled[id] =
          c.frontPorchExtensions?.realismVerificationEnabled ?? false;
      _verificationMaxReprocesses[id] =
          c.frontPorchExtensions?.realismVerificationMaxReprocesses ?? 1;
      _verificationStrictness[id] =
          c.frontPorchExtensions?.realismVerificationStrictness ?? 3;
      _needsDirectorAuthority[id] =
          c.frontPorchExtensions?.realismNeedsDirectorAuthority ?? false;

      // Load the three relationship sliders. Their key mapping, the legacy
      // repair and the clamps all live in the shared leaf (and are tested
      // there) — this is a bug-prone corner, not a two-liner.
      final seed = _baselineSeeds[id]!;
      final bond = bondBaselineFromSeeds(
        baselineSeed: seed,
        perCharSeed: (perCharSeeds[id] as Map?)?.cast<String, dynamic>(),
      );
      _editShortTermBond[id] = bond.shortTerm;
      _editLongTermBond[id] = bond.longTerm;
      _editTrustLevel[id] = bond.trust;
      _editEmotion[id] = (seed['emotion'] as String?) ?? 'neutral';
      _editEmotionIntensity[id] =
          (seed['emotionIntensity'] as String?) ?? 'moderate';
    }
  }

  // --- Per-member Director/Verifier updates ---
  void _updateMemberVerificationEnabled(CharacterCard char, bool value) {
    final id = _getCharId(char);
    setState(() {
      _verificationEnabled[id] = value;
      char.frontPorchExtensions =
          (char.frontPorchExtensions ?? FrontPorchExtensions()).copyWith(
            realismVerificationEnabled: value,
          );
      char.frontPorchExtensions?.ensureStableId();
    });

    persistGroupMemberPref(widget.chatService, id, 'verificationEnabled', value);
  }

  void _updateMemberVerificationMaxReprocesses(CharacterCard char, int value) {
    final id = _getCharId(char);
    setState(() {
      _verificationMaxReprocesses[id] = value;
      char.frontPorchExtensions =
          (char.frontPorchExtensions ?? FrontPorchExtensions()).copyWith(
            realismVerificationMaxReprocesses: value,
          );
      char.frontPorchExtensions?.ensureStableId();
    });

    persistGroupMemberPref(widget.chatService, id, 'verificationMaxReprocesses', value);
  }

  void _updateMemberVerificationStrictness(CharacterCard char, int value) {
    final id = _getCharId(char);
    setState(() {
      _verificationStrictness[id] = value;
      char.frontPorchExtensions =
          (char.frontPorchExtensions ?? FrontPorchExtensions()).copyWith(
            realismVerificationStrictness: value,
          );
      char.frontPorchExtensions?.ensureStableId();
    });

    persistGroupMemberPref(widget.chatService, id, 'verificationStrictness', value);
  }

  void _updateMemberNeedsDirectorAuthority(CharacterCard char, bool value) {
    final id = _getCharId(char);
    setState(() {
      _needsDirectorAuthority[id] = value;
      char.frontPorchExtensions =
          (char.frontPorchExtensions ?? FrontPorchExtensions()).copyWith(
            realismNeedsDirectorAuthority: value,
          );
      char.frontPorchExtensions?.ensureStableId();
    });

    persistGroupMemberPref(widget.chatService, id, 'needsDirectorAuthority', value);
  }


  /// Public setState bridge for the part-file extensions
  /// (same pattern as settings_page's rebuildState).
  void rebuildState(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => _buildRealismTabBody(context);

  // ── Editable realism baseline update methods ──

  void _updateEditShortTermBond(CharacterCard char, int value) {
    final id = _getCharId(char);
    setState(() {
      _editShortTermBond[id] = value;
    });
    _applyEditToBaselineSeedAndCard(char, id);
  }

  void _updateEditLongTermBond(CharacterCard char, int value) {
    final id = _getCharId(char);
    setState(() {
      _editLongTermBond[id] = value;
    });
    _applyEditToBaselineSeedAndCard(char, id);
  }

  void _updateEditTrustLevel(CharacterCard char, int value) {
    final id = _getCharId(char);
    setState(() {
      _editTrustLevel[id] = value;
    });
    _applyEditToBaselineSeedAndCard(char, id);
  }

  void _updateEditEmotion(CharacterCard char, String value) {
    final id = _getCharId(char);
    setState(() {
      _editEmotion[id] = value;
    });
    _applyEditToBaselineSeedAndCard(char, id);
  }

  void _updateEditEmotionIntensity(CharacterCard char, String value) {
    final id = _getCharId(char);
    setState(() {
      _editEmotionIntensity[id] = value;
    });
    _applyEditToBaselineSeedAndCard(char, id);
  }

  void _applyEditToBaselineSeedAndCard(CharacterCard char, String id) {
    final ext = char.frontPorchExtensions ?? FrontPorchExtensions();
    char.frontPorchExtensions = ext.copyWith(
      shortTermBond: _editShortTermBond[id] ?? 50,
      longTermBond: _editLongTermBond[id] ?? 50,
      trustLevel: _editTrustLevel[id] ?? 50,
      characterEmotion: _editEmotion[id] ?? 'neutral',
      emotionIntensity: _editEmotionIntensity[id] ?? 'moderate',
    );

    // Update the baseline seed via ChatService.
    try {
      widget.chatService.setBaselineSeedForGroupCharacter(char, {
        'affection': _editShortTermBond[id] ?? 50,
        'longTermScore': _editLongTermBond[id] ?? 50,
        'trust': _editTrustLevel[id] ?? 50,
        'emotion': _editEmotion[id] ?? 'neutral',
        'emotionIntensity': _editEmotionIntensity[id] ?? 'moderate',
      });
    } catch (_) {
      // Non-fatal
    }

    // Persist to group defaultMemberRealismState.
    try {
      final group = widget.chatService.activeGroup;
      if (group != null) {
        final map =
            group.defaultMemberRealismState.isNotEmpty &&
                group.defaultMemberRealismState != '{}'
            ? (jsonDecode(group.defaultMemberRealismState)
                      as Map<String, dynamic>? ??
                  {})
            : <String, dynamic>{};
        final perChar = (map['perChar'] as Map<String, dynamic>? ?? {})
            .cast<String, dynamic>();
        final current = (perChar[id] as Map<String, dynamic>? ?? {})
            .cast<String, dynamic>();
        // ENGINE key names — the card-ext names written here before made four
        // of the five sliders a no-op (GroupMemberRealism reads only
        // affection/longTermScore/trust/emotion/emotionIntensity and passes
        // everything else through untouched).
        applyBaselineToMemberSeed(
          current,
          affection: _editShortTermBond[id] ?? 50,
          longTermScore: _editLongTermBond[id] ?? 50,
          trust: _editTrustLevel[id] ?? 50,
          emotion: _editEmotion[id] ?? 'neutral',
          emotionIntensity: _editEmotionIntensity[id] ?? 'moderate',
        );
        perChar[id] = current;
        map['perChar'] = perChar;
        group.defaultMemberRealismState = jsonEncode(map);
      }
    } catch (_) {
      // Non-fatal
    }
  }

  // Must be byte-identical to the id every service stores a member under
  // (ChatService._getCharacterIdFromCard). The hand-rolled version answered ''
  // for a member with no avatar file and truncated at the first dot otherwise,
  // so the perChar seed landed under a key the engine never looks up.
  String _getCharId(CharacterCard c) => c.stableGroupId;

  @override
  void dispose() {
    widget.chatService.removeListener(_onServiceChanged);
    _groupDayCountController.dispose();
    super.dispose();
  }

  Widget _sliderRow(
    String label,
    int value,
    int min,
    int max,
    String tierName,
    Color color,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
              ),
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min > 0 ? (max - min) ~/ 10 : 0,
                label: value.toString(),
                onChanged: (d) => onChanged(d.round()),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            child: Text(
              value.toString(),
              style: TextStyle(fontSize: 10, color: color),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _updateRealism(bool value) {
    setState(() {
      _realismEnabled = value;
    });
    widget.chatService.setRealismEnabled(value);
  }

  void _updatePassageOfTime(bool value) {
    setState(() {
      _passageOfTimeEnabled = value;
    });
    // Through the ChatService wrapper (saves + notifies) — the raw
    // TimeService setter is side-effect-free, so the old direct call never
    // persisted the toggle beyond this dialog's local state.
    widget.chatService.setPassageOfTimeEnabled(value);
  }

  void _updateChaosMode(bool value) {
    setState(() {
      _chaosModeEnabled = value;
    });
    // ChatService wrapper — saves + notifies (the raw service does neither).
    widget.chatService.setChaosModeEnabled(value);
  }

  void _updateChaosNsfw(bool value) {
    setState(() {
      _chaosNsfwEnabled = value;
    });
    widget.chatService.setChaosNsfwEnabled(value);
  }

  void _updateNsfwEnhancements(bool value) {
    setState(() {
      _nsfwEnhancementsEnabled = value;
    });
    // Same setter the sidebar gear uses; in a group it propagates the flag to
    // every member's realism state (1:1 just sets the scalar).
    widget.chatService.setNsfwCooldownEnabled(value);
  }

  void _updateGroupTimeOfDay(String value) {
    setState(() {
      _groupTimeOfDay = value;
    });
    _persistGroupTimeDay();
  }

  void _updateGroupDayCount(int value) {
    setState(() {
      _groupDayCount = value;
    });
    _groupDayCountController.text = value.toString();
    _persistGroupTimeDay();
  }

  void _persistGroupTimeDay() {
    final group = widget.chatService.activeGroup;
    if (group == null) return;
    try {
      final map =
          group.defaultMemberRealismState.isNotEmpty &&
              group.defaultMemberRealismState != '{}'
          ? (jsonDecode(group.defaultMemberRealismState)
                    as Map<String, dynamic>?) ??
                {}
          : <String, dynamic>{};
      map['timeOfDay'] = _groupTimeOfDay;
      map['dayCount'] = _groupDayCount;
      if (_groupStoryStartDate != null) {
        map['storyStartDate'] = _groupStoryStartDate;
      } else {
        map.remove('storyStartDate');
      }
      if (_groupStoryStartTime != null) {
        map['storyStartTime'] = _groupStoryStartTime;
      } else {
        map.remove('storyStartTime');
      }
      group.defaultMemberRealismState = jsonEncode(map);
    } catch (_) {
      // Non-fatal
    }
  }

  void _resetAllRealismStates() {
    final cs = widget.chatService;
    if (cs.activeGroup == null) return;

    for (final c in cs.groupCharacters) {
      cs.resetRealismForGroupCharacter(c);
    }
  }

  void _resetCharacterRealism(CharacterCard character) {
    widget.chatService.resetRealismForGroupCharacter(character);
  }

  // Helper for chaos pressure color (matches _ChaosModeSection in chat_page)
  Color _pressureColorFor(int pressure) {
    final t = (pressure / 100).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFF2EC4B6), const Color(0xFFE63946), t)!;
  }

}
