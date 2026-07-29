// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/chat/biome_preview.dart';
import 'package:front_porch_ai/services/chat/weather_biomes.dart';
import 'package:front_porch_ai/services/chat/weather_engine.dart';
import 'package:front_porch_ai/services/chat/weather_segments.dart';
import 'package:front_porch_ai/ui/pages/worlds/climate_editor_widgets.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// The custom climate editor (living-worlds.md §3, mockup-approved
/// 2026-07-29). Desktop-only authoring by ruling; the produced biome JSON is
/// consumed everywhere. Returns the encoded biome JSON string on save, or
/// null on cancel.
///
/// Temperature anchors are entered in the user's display unit (the global
/// Settings → General °C/°F toggle) and stored canonically in °C, so a
/// shared world behaves identically for every user.
Future<String?> showClimateEditorDialog(
  BuildContext context, {
  required String worldName,
  String? existingBiomeJson,
  required bool fahrenheit,
}) {
  return showDialog<String?>(
    context: context,
    builder: (_) => _ClimateEditorDialog(
      worldName: worldName,
      existingBiomeJson: existingBiomeJson,
      fahrenheit: fahrenheit,
    ),
  );
}

class _ClimateEditorDialog extends StatefulWidget {
  const _ClimateEditorDialog({
    required this.worldName,
    required this.existingBiomeJson,
    required this.fahrenheit,
  });

  final String worldName;
  final String? existingBiomeJson;
  final bool fahrenheit;

  @override
  State<_ClimateEditorDialog> createState() => _ClimateEditorDialogState();
}

class _ClimateEditorDialogState extends State<_ClimateEditorDialog> {
  late String _templateId;
  final Map<String, TempBand> _seasonBand = {};
  // Controllers are allocated exactly ONCE (template switches only rewrite
  // their text) — reallocating in _seedFrom leaked the previous set and
  // could touch disposed fields mid-rebuild (Grok review).
  final Map<String, TextEditingController> _anchorCtls = {
    for (final s in kSeasons) s: TextEditingController(),
  };
  final Map<String, List<TextEditingController>> _weightCtls = {
    for (final s in kSeasons)
      s: [
        for (var i = 0; i < kWeatherConditions.length; i++)
          TextEditingController(),
      ],
  };
  final Map<String, SkinDraft> _skins = {
    for (final c in kWeatherConditions) c: SkinDraft(),
  };
  final Map<String, TextEditingController> _skinLabelCtls = {
    for (final c in kWeatherConditions) c: TextEditingController(),
  };
  double _diurnal = 1.0;
  BiomePreview? _preview;

  int _toDisplay(int c) =>
      widget.fahrenheit ? WeatherSegments.tempF(c) : c;
  int _fromDisplay(int v) =>
      widget.fahrenheit ? ((v - 32) * 5 / 9).round() : v;
  String get _unit => widget.fahrenheit ? '°F' : '°C';

  @override
  void initState() {
    super.initState();
    final existing = Biome.tryParse(widget.existingBiomeJson);
    _templateId = existing != null ? 'custom' : Biome.desert.id;
    _seedFrom(existing ?? Biome.desert);
  }

  void _seedFrom(Biome b) {
    for (final season in kSeasons) {
      final idx =
          (b.baseTemp[season] ?? 2).clamp(0, TempBand.values.length - 1);
      _seasonBand[season] = TempBand.values[idx];
      final anchor = b.displayAnchorsC[season];
      _anchorCtls[season]!.text =
          anchor != null ? '${_toDisplay(anchor)}' : '';
      final weights = b.weights[season] ??
          List<int>.filled(kWeatherConditions.length, 0);
      for (var i = 0; i < kWeatherConditions.length; i++) {
        _weightCtls[season]![i].text = '${i < weights.length ? weights[i] : 0}';
      }
    }
    _diurnal = b.diurnalAmplitude;
    for (final c in kWeatherConditions) {
      final skin = b.conditionSkin[c];
      final draft = _skins[c]!;
      draft.label = skin?.label ?? '';
      draft.emoji = skin?.emoji ?? '';
      draft.stance = skin?.stance;
      draft.flavour = skin?.flavour ?? '';
      _skinLabelCtls[c]!.text = draft.label;
    }
    _preview = null;
  }

  @override
  void dispose() {
    for (final c in _anchorCtls.values) {
      c.dispose();
    }
    for (final list in _weightCtls.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    for (final c in _skinLabelCtls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Whether [season]'s picked band can reach an extreme with ±1 jitter
  /// under the derived range — mirrors Biome.validate's anchor rule.
  bool _needsAnchor(String season) {
    final range = _derivedRange();
    final rank = _seasonBand[season]!.rank;
    final lo = (rank - 1).clamp(range.$1, range.$2);
    final hi = (rank + 1).clamp(range.$1, range.$2);
    return lo < kClassicBandRange.$1 || hi > kClassicBandRange.$2;
  }

  /// Reachable span derived from the chosen bands: classic stays classic;
  /// anything extreme widens to base±1 around the chosen bands.
  (int, int) _derivedRange() {
    final ranks = [for (final s in kSeasons) _seasonBand[s]!.rank];
    final anyExtreme = ranks.any((r) =>
        r < kClassicBandRange.$1 || r > kClassicBandRange.$2);
    if (!anyExtreme) return kClassicBandRange;
    var lo = ranks.reduce((a, b) => a < b ? a : b) - 1;
    var hi = ranks.reduce((a, b) => a > b ? a : b) + 1;
    return (
      lo.clamp(kFullBandRange.$1, kFullBandRange.$2),
      hi.clamp(kFullBandRange.$1, kFullBandRange.$2),
    );
  }

  Biome _buildDraft() {
    final range = _derivedRange();
    return Biome(
      id: 'custom',
      displayName: widget.worldName.trim().isEmpty
          ? 'Custom climate'
          : widget.worldName.trim(),
      description: 'Custom climate for ${widget.worldName}',
      weights: {
        for (final s in kSeasons)
          s: [
            for (final ctl in _weightCtls[s]!)
              (int.tryParse(ctl.text.trim()) ?? 0).clamp(0, 999),
          ],
      },
      baseTemp: {
        for (final s in kSeasons) s: _seasonBand[s]!.index,
      },
      bandRange: range,
      displayAnchorsC: {
        for (final s in kSeasons)
          if (_needsAnchor(s) &&
              int.tryParse(_anchorCtls[s]!.text.trim()) != null)
            s: _fromDisplay(int.parse(_anchorCtls[s]!.text.trim()))
                .clamp(-273, 2000),
      },
      diurnalAmplitude: _diurnal,
      conditionSkin: {
        for (final e in _skins.entries)
          if (e.value.active && e.value.stance != null)
            e.key: ConditionSkin(
              label: e.value.label.trim(),
              emoji: e.value.emoji.trim().isEmpty
                  ? null
                  : e.value.emoji.trim(),
              stance: e.value.stance!,
              flavour: e.value.flavour.trim().isEmpty
                  ? null
                  : e.value.flavour.trim(),
            ),
      },
    );
  }

  List<String> _blockingErrors() {
    final draft = _buildDraft();
    final errors = draft.validate();
    for (final e in _skins.entries) {
      if (e.value.active && e.value.stance == null) {
        errors.add(
          '${e.key}: a renamed weather needs a danger level — otherwise '
          'characters would picnic in it.',
        );
      }
    }
    return errors;
  }

  void _refreshPreview() =>
      setState(() => _preview = previewBiome(_buildDraft()));

  @override
  Widget build(BuildContext context) {
    final errors = _blockingErrors();
    return Dialog(
      backgroundColor: AppColors.cardOf(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Custom Climate — ${widget.worldName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _templateId,
                    underline: const SizedBox.shrink(),
                    items: [
                      if (_templateId == 'custom')
                        const DropdownMenuItem(
                          value: 'custom',
                          child: Text('Current custom'),
                        ),
                      for (final b in Biome.builtIns)
                        DropdownMenuItem(
                          value: b.id,
                          child: Text('Start from: ${b.displayName}'),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null || id == 'custom') return;
                      setState(() {
                        _templateId = id;
                        _seedFrom(Biome.builtInById(id)!);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _leftColumn(context)),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 4, child: _rightColumn(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.formMasterAccent,
                      foregroundColor: AppColors.onChaosAccent,
                    ),
                    onPressed: errors.isEmpty
                        ? () => Navigator.pop(
                              context,
                              jsonEncode(_buildDraft().toJson()),
                            )
                        : null,
                    child: const Text('Save climate'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftColumn(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClimateSectionHeader(
          'Temperature by season',
          hint: 'Extreme steps unlock the display $_unit — you type what '
              'the weather chip shows. Characters feel words, not numbers.',
        ),
        for (final season in kSeasons)
          SeasonBandRow(
            season: season,
            band: _seasonBand[season]!,
            anchorController: _anchorCtls[season]!,
            needsAnchor: _needsAnchor(season),
            unit: _unit,
            onBand: (b) => setState(() => _seasonBand[season] = b),
            onAnchorChanged: () => setState(() {}),
          ),
        const SizedBox(height: 16),
        ClimateSectionHeader(
          'Weather odds',
          hint: 'Per season — higher numbers are more common.',
        ),
        WeightsGrid(controllers: _weightCtls),
        const SizedBox(height: 16),
        ClimateSectionHeader('Day–night swing'),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _diurnal.clamp(0.2, 4.0),
                min: 0.2,
                max: 4.0,
                divisions: 19,
                activeColor: AppColors.formMasterAccent,
                onChanged: (v) => setState(() => _diurnal = v),
              ),
            ),
            SizedBox(
              width: 88,
              child: Text(
                '${_diurnal.toStringAsFixed(1)}× Earth',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.porchAmberOf(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClimateSectionHeader(
          'Rename the weather',
          hint: 'Every rename needs a danger level, so a lazy "acid rain" '
              'still behaves. Leave blank to keep the normal weather.',
        ),
        for (final c in kWeatherConditions)
          SkinEditRow(
            condition: c,
            draft: _skins[c]!,
            labelController: _skinLabelCtls[c]!,
            onLabel: (v) => setState(() => _skins[c]!.label = v),
            onStance: (st) => setState(() => _skins[c]!.stance = st),
          ),
      ],
    );
  }



  Widget _rightColumn(BuildContext context) {
    final errors = _blockingErrors();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Runs the real weather engine over your numbers.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary(context),
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _refreshPreview,
              child: const Text('Refresh preview'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_preview != null)
          ClimatePreviewPanel(preview: _preview!)
        else
          Text(
            'Tap Refresh preview to simulate this climate.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
        if (_preview == null && errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '⛔ $e',
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.logError),
              ),
            ),
        ],
      ],
    );
  }
}
