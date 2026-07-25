// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/group_chat_repository.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/ui/dialogs/group_settings/group_settings_support.dart';

part 'needs_tab.member.dart';

const _kHunger = 'hunger';
const _kBladder = 'bladder';
const _kEnergy = 'energy';
const _kSocial = 'social';
const _kFun = 'fun';
const _kHygiene = 'hygiene';
const _kComfort = 'comfort';

  // Engine default decay per need (== NeedsSimulation.needDecay / the
  // FrontPorchExtensions decay defaults) — used to seed a reset.
const Map<String, int> _defaultDecayRates = {
    _kHunger: 4,
    _kBladder: 6,
    _kEnergy: 3,
    _kSocial: 2,
    _kFun: 2,
    _kHygiene: 1,
    _kComfort: 2,
  };

class GroupNeedsTab extends StatefulWidget {
  final ChatService chatService;
  final GroupChatRepository? groupRepo;
  const GroupNeedsTab({super.key, required this.chatService, this.groupRepo});

  @override
  State<GroupNeedsTab> createState() => _GroupNeedsTabState();
}

class _GroupNeedsTabState extends State<GroupNeedsTab> {
  bool _needsSimEnabled = false;

  // Per-character needs baselines: char-id → field-name → value
  final Map<String, Map<String, int>> _needsBaselines = {};

  // Per-character needs decay rates ("tick rate"): char-id → field-name → value.
  // Each member decays at its own rate (parity with solo cards); persisted to
  // that member's card ext via ChatService.setGroupNeedsDecayRate(memberId: …).
  final Map<String, Map<String, int>> _decayRates = {};

  // Per-character static preference overrides (e.g. enjoys low hygiene) for this group.
  final Map<String, bool> _enjoysLowHygiene = {};

  List<CharacterCard> _chars = [];

  // Field name constants for needs baselines map keys.

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

    _needsSimEnabled = cs.needsSimEnabled;

    for (final c in _chars) {
      final id = _getCharId(c);
      final ext = c.frontPorchExtensions;

      // Seed needs baselines from character card extensions.
      _needsBaselines[id] = {
        _kHunger: ext?.needsBaselineHunger ?? 80,
        _kBladder: ext?.needsBaselineBladder ?? 80,
        _kEnergy: ext?.needsBaselineEnergy ?? 80,
        _kSocial: ext?.needsBaselineSocial ?? 80,
        _kFun: ext?.needsBaselineFun ?? 80,
        _kHygiene: ext?.needsBaselineHygiene ?? 80,
        _kComfort: ext?.needsBaselineComfort ?? 80,
      };

      // Seed per-member decay from ext (fallbacks = the engine's needDecay
      // defaults, which equal the FrontPorchExtensions decay defaults).
      _decayRates[id] = {
        _kHunger: ext?.needsDecayHunger ?? 4,
        _kBladder: ext?.needsDecayBladder ?? 6,
        _kEnergy: ext?.needsDecayEnergy ?? 3,
        _kSocial: ext?.needsDecaySocial ?? 2,
        _kFun: ext?.needsDecayFun ?? 2,
        _kHygiene: ext?.needsDecayHygiene ?? 1,
        _kComfort: ext?.needsDecayComfort ?? 2,
      };

      _enjoysLowHygiene[id] = ext?.enjoysLowHygiene ?? false;
    }
  }

  String _getCharId(CharacterCard c) => c.imagePath != null
      ? c.imagePath!.split('/').last.split('.').first
      : c.name;

  CharacterCard? _findCharById(String id) {
    for (final c in _chars) {
      if (_getCharId(c) == id) return c;
    }
    return null;
  }

  void _updateNeedsBaseline(String id, String field, int value) {
    setState(() {
      _needsBaselines[id] = {...?_needsBaselines[id], field: value};
      final char = _findCharById(id);
      if (char != null) {
        char.frontPorchExtensions =
            (char.frontPorchExtensions ?? FrontPorchExtensions()).copyWith(
              needsBaselineHunger: _needsBaselines[id]?[_kHunger] ?? 80,
              needsBaselineBladder: _needsBaselines[id]?[_kBladder] ?? 80,
              needsBaselineEnergy: _needsBaselines[id]?[_kEnergy] ?? 80,
              needsBaselineSocial: _needsBaselines[id]?[_kSocial] ?? 80,
              needsBaselineFun: _needsBaselines[id]?[_kFun] ?? 80,
              needsBaselineHygiene: _needsBaselines[id]?[_kHygiene] ?? 80,
              needsBaselineComfort: _needsBaselines[id]?[_kComfort] ?? 80,
            );
        char.frontPorchExtensions?.ensureStableId();
      }
    });
    _persistMemberNeedsPref(id, field, value);
  }

  // Local display update while a decay slider is dragged. The persist (member
  // card ext + PNG + DB row) is deferred to the slider's onChangeEnd →
  // ChatService.setGroupNeedsDecayRate(memberId: …) to avoid PNG-encode jank.
  void _updateMemberDecay(String id, String field, int value) {
    setState(() {
      _decayRates[id] = {...?_decayRates[id], field: value};
    });
  }

  void _updateMemberEnjoysLowHygiene(CharacterCard char, bool value) {
    final id = _getCharId(char);
    setState(() {
      _enjoysLowHygiene[id] = value;
      char.frontPorchExtensions =
          (char.frontPorchExtensions ?? FrontPorchExtensions()).copyWith(
            enjoysLowHygiene: value,
          );
        char.frontPorchExtensions?.ensureStableId();
    });
    persistGroupMemberPref(widget.chatService, id, 'enjoysLowHygiene', value);
  }


  void _persistMemberNeedsPref(String id, String field, int value) {
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
        // Store needs baselines under a nested 'needsBaselines' key.
        final needsBaselines =
            (current['needsBaselines'] as Map<String, dynamic>? ?? {})
                .cast<String, dynamic>();
        needsBaselines[field] = value;
        current['needsBaselines'] = needsBaselines;
        perChar[id] = current;
        map['perChar'] = perChar;
        group.defaultMemberRealismState = jsonEncode(map);
      }
    } catch (_) {
      // Non-fatal
    }
  }

  void _resetAllNeedsStates() {
    for (final c in _chars) {
      final id = _getCharId(c);
      setState(() {
        _needsBaselines[id] = {
          _kHunger: 80,
          _kBladder: 80,
          _kEnergy: 80,
          _kSocial: 80,
          _kFun: 80,
          _kHygiene: 80,
          _kComfort: 80,
        };
        _decayRates[id] = Map<String, int>.from(_defaultDecayRates);
        _enjoysLowHygiene[id] = false;
      });
      widget.chatService.resetRealismForGroupCharacter(c);
    }
  }

  void _resetCharacterNeeds(CharacterCard character) {
    final id = _getCharId(character);
    setState(() {
      _needsBaselines[id] = {
        _kHunger: 80,
        _kBladder: 80,
        _kEnergy: 80,
        _kSocial: 80,
        _kFun: 80,
        _kHygiene: 80,
        _kComfort: 80,
      };
      _decayRates[id] = Map<String, int>.from(_defaultDecayRates);
      _enjoysLowHygiene[id] = false;
    });
    widget.chatService.resetRealismForGroupCharacter(character);
  }

  @override
  void dispose() {
    widget.chatService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _updateNeedsSim(bool value) {
    setState(() {
      _needsSimEnabled = value;
    });
    widget.chatService.setNeedsSimEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.chatService;
    final group = cs.activeGroup;
    final isDirectorMode = cs.observerMode;

    if (group == null) {
      return const Center(
        child: Text(
          'No active group chat selected.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.battery_std,
                  color: Colors.tealAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Needs — ${group.name}',
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
              'Configure needs baselines and per-character settings for Needs Simulation in this group.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),

            // Director Mode notice
            if (isDirectorMode)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Director Mode is active. Needs Simulation is suspended for this group (narrative control only). Exit Director Mode to re-enable.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Needs Simulation master toggle
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
                        Icons.battery_std,
                        size: 18,
                        color: Colors.tealAccent,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Needs Simulation',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Switch(
                        value: _needsSimEnabled,
                        activeThumbColor: Colors.tealAccent,
                        onChanged: _updateNeedsSim,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Simulates need satisfaction (hunger, bladder, energy, social, fun, hygiene, comfort). Higher = more sated (100=full, 0=critical). Low values influence AI behavior and prompt injections.',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Per-character needs baselines + decay section
            Row(
              children: [
                const Icon(
                  Icons.people_alt,
                  size: 18,
                  color: Colors.tealAccent,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Per-Character Needs Baselines & Decay',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _resetAllNeedsStates,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Reset ALL',
                    style: TextStyle(fontSize: 11, color: Colors.tealAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Adjust each character\'s starting needs baselines and their per-turn decay ("tick rate"). Every member decays at its own rate, just like a solo character.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
            const SizedBox(height: 10),

            if (_chars.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No characters loaded for this group.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              )
            else
              ..._chars.asMap().entries.map(_buildMemberNeedsCard),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

}
