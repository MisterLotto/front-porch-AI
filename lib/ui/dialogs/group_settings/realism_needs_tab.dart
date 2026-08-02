// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/ui/widgets/story_begins_row.dart';
import 'package:front_porch_ai/ui/dialogs/group_settings/group_settings_support.dart';

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

    // Group-wide Time & Day.
    final group = cs.activeGroup;
    if (group != null) {
      final gs = group.defaultMemberRealismState;
      if (gs.isNotEmpty && gs != '{}') {
        final map = (jsonDecode(gs) as Map<String, dynamic>?) ?? {};
        _groupTimeOfDay = (map['timeOfDay'] as String?) ?? 'morning';
        _groupDayCount = (map['dayCount'] as num?)?.toInt() ?? 1;
        _groupStoryStartDate = map['storyStartDate'] as String?;
        _groupStoryStartTime = map['storyStartTime'] as String?;
      }
    }
    _groupDayCountController = TextEditingController(
      text: _groupDayCount.toString(),
    );

    // Load immutable creation baseline seeds (only the allowed fields)
    _baselineSeeds.clear();
    for (final c in _chars) {
      _baselineSeeds[_getCharId(c)] = Map<String, dynamic>.from(
        cs.getBaselineSeedForGroupCharacter(c),
      );
      final id = _getCharId(c);

      // Load per-member Director/Verifier settings (if present on the member's card ext)
      _verificationEnabled[id] =
          c.frontPorchExtensions?.realismVerificationEnabled ?? false;
      _verificationMaxReprocesses[id] =
          c.frontPorchExtensions?.realismVerificationMaxReprocesses ?? 1;
      _verificationStrictness[id] =
          c.frontPorchExtensions?.realismVerificationStrictness ?? 3;
      _needsDirectorAuthority[id] =
          c.frontPorchExtensions?.realismNeedsDirectorAuthority ?? false;

      // Load editable realism baselines from baseline seed + card extensions.
      final seed = _baselineSeeds[id]!;
      // These three must map to the three keys the engine actually reads:
      // affection / longTermScore / trust. Long-Term Bond used to LOAD from
      // 'trust' and, worse, SAVE into it — so dragging a ±300 bond slider
      // overwrote the ±100 trust baseline, while Trust Level never persisted
      // at all. longTermScore falls back to affection, matching what
      // RelationshipService does when seeding a member that predates the key.
      final rawTrust = (seed['trust'] as num?)?.toInt();
      final rawLongTerm = (seed['longTermScore'] as num?)?.toInt();

      // Repair for groups edited under the old code. Back then this editor
      // SAVED the Long-Term Bond slider into 'trust', so a group that was ever
      // edited has a ±300 bond number sitting in a ±100 trust field. Left
      // alone, that value now reaches a Slider declared min -100 / max 100,
      // which asserts and takes the whole Group Settings dialog down.
      //
      // |trust| > 100 is impossible for a real trust value, so when there is
      // also no 'longTermScore' the number can only have come from that slider.
      // Move it back where it was meant to go and give trust its default —
      // the old code never stored a real trust value, so there is none to
      // recover, and inventing one from a bond score would be worse.
      final poisoned = rawLongTerm == null && rawTrust != null && rawTrust.abs() > 100;

      _editShortTermBond[id] = ((seed['affection'] as num?)?.toInt() ?? 50)
          .clamp(-300, 300);
      _editLongTermBond[id] =
          (poisoned
                  ? rawTrust
                  : rawLongTerm ?? (seed['affection'] as num?)?.toInt() ?? 50)
              .clamp(-300, 300);
      _editTrustLevel[id] = (poisoned ? 50 : rawTrust ?? 50).clamp(-100, 100);
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
        current['shortTermBond'] = _editShortTermBond[id] ?? 50;
        current['longTermBond'] = _editLongTermBond[id] ?? 50;
        current['trustLevel'] = _editTrustLevel[id] ?? 50;
        current['characterEmotion'] = _editEmotion[id] ?? 'neutral';
        current['emotionIntensity'] = _editEmotionIntensity[id] ?? 'moderate';
        perChar[id] = current;
        map['perChar'] = perChar;
        group.defaultMemberRealismState = jsonEncode(map);
      }
    } catch (_) {
      // Non-fatal
    }
  }

  String _getCharId(CharacterCard c) => c.imagePath != null
      ? c.imagePath!.split('/').last.split('.').first
      : c.name;

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
