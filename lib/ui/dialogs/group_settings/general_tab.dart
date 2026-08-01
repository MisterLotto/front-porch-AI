// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later


import 'package:flutter/material.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';
import 'package:front_porch_ai/ui/dialogs/group_settings/group_settings_support.dart';

part 'general_tab.cards.dart';

class GroupGeneralTab extends StatefulWidget {
  final ChatService chatService;
  final GroupChatRepository? groupRepo;
  const GroupGeneralTab({super.key, required this.chatService, this.groupRepo});

  @override
  State<GroupGeneralTab> createState() => _GroupGeneralTabState();
}

class _GroupGeneralTabState extends State<GroupGeneralTab> {
  // Local editing controllers and state (applied on Save)
  late final StyledTextController _nameController;
  late final StyledTextController _scenarioController;
  late final StyledTextController _firstMessageController;

  TurnOrder _turnOrder = TurnOrder.roundRobin;
  bool _autoAdvance = false;
  bool _directorModeDefault = false;

  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadFromActiveGroup();
  }

  void _loadFromActiveGroup() {
    final g = widget.chatService.activeGroup;

    if (g != null) {
      _nameController = StyledTextController(
        preset: StyledTextPreset.prose,
        text: g.name,
      );
      _scenarioController = StyledTextController(
        preset: StyledTextPreset.prose,
        text: g.scenario,
      );
      _firstMessageController = StyledTextController(
        preset: StyledTextPreset.prose,
        text: g.firstMessage,
      );
      _turnOrder = g.turnOrder;
      _autoAdvance = g.autoAdvance;
      _directorModeDefault = g.directorMode;
    } else {
      _nameController = StyledTextController(preset: StyledTextPreset.prose, text: '');
      _scenarioController = StyledTextController(preset: StyledTextPreset.prose, text: '');
      _firstMessageController = StyledTextController(preset: StyledTextPreset.prose, text: '');
      _turnOrder = TurnOrder.roundRobin;
      _autoAdvance = false;
      _directorModeDefault = false;
    }

    _hasUnsavedChanges = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scenarioController.dispose();
    _firstMessageController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  void _setTurnOrder(TurnOrder order) {
    if (_turnOrder == order) return;
    setState(() {
      _turnOrder = order;
      _hasUnsavedChanges = true;
    });
  }

  void _setAutoAdvance(bool value) {
    if (_autoAdvance == value) return;
    setState(() {
      _autoAdvance = value;
      _hasUnsavedChanges = true;
    });
  }

  void _setDirectorModeDefault(bool value) {
    if (_directorModeDefault == value) return;
    setState(() {
      _directorModeDefault = value;
      _hasUnsavedChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.chatService.activeGroup;

    if (group == null) {
      return const Center(
        child: Text(
          'No active group chat selected.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.tune, color: Colors.tealAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'General — ${group.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Basic group identity, opening message, and conversation flow rules. All changes apply live after Save.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 16),

                // ── Identity ───────────────────────────────────────────────
                GroupSectionHeader(
                  'Identity',
                  Icons.label_outline,
                  Colors.tealAccent,
                ),
                const SizedBox(height: 8),

                // Group Name
                const Text(
                  'Group Name',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _nameController,
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. The Fellowship',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary(context),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.borderOf(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.borderOf(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.tealAccent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 14),

                // Scenario
                const Text(
                  'Scenario',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Group-level scenario override (blank = use first character\'s scenario).',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _scenarioController,
                  maxLines: 4,
                  minLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText:
                        'The scene, time period, and situation for this group conversation...',
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.tealAccent),
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 14),

                // First Message
                const Text(
                  'First Message / Greeting',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Custom opening message shown when the group starts or is reset (blank = use first character\'s greeting).',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _firstMessageController,
                  maxLines: 3,
                  minLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'The group\'s initial greeting or narration...',
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.tealAccent),
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 20),

                // ── Turn Management ────────────────────────────────────────
                GroupSectionHeader(
                  'Turn Management',
                  Icons.swap_horiz,
                  Colors.purpleAccent,
                ),
                const SizedBox(height: 8),

                const Text(
                  'Turn Order Strategy',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _buildTurnStrategyCard(
                        TurnOrder.roundRobin,
                        'Round Robin',
                        'Characters respond in a fixed repeating order. Predictable and fair.',
                        Icons.repeat,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTurnStrategyCard(
                        TurnOrder.random,
                        'Random',
                        'Any eligible character may speak next. More spontaneous and lively.',
                        Icons.shuffle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Auto-advance
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.play_circle_outline,
                            size: 18,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Auto-advance',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _autoAdvance,
                            activeTrackColor: Colors.greenAccent,
                            onChanged: _setAutoAdvance,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.only(left: 26),
                        child: Text(
                          'After a character finishes responding, automatically prompt the next speaker. Works with both turn orders and Director Mode.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                ..._directorModeSection(),
              ],
            ),
          ),
        ),

        // ── Save bar ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.borderOf(context))),
            color: AppColors.surfaceContainerOf(context),
          ),
          child: Row(children: []),
        ),
      ],
    );
  }

}
