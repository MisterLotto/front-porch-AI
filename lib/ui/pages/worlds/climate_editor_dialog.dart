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

import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/ui/pages/worlds/climate_editor_chrome.dart';
import 'package:front_porch_ai/ui/pages/worlds/climate_editor_widgets.dart';
import 'package:front_porch_ai/ui/pages/worlds/climate_preview_panel.dart';
import 'package:front_porch_ai/ui/pages/worlds/climate_skin_row.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// The custom climate editor (living-worlds.md §3), laid out 1:1 against the
/// maintainer-approved mockup artifact: amber-gradient header with the
/// start-from select, a 4-across season-card grid, mono numerals, the rename
/// list with stance pills, and the darker inset preview column. Desktop-only
/// authoring by ruling; the produced biome JSON is consumed everywhere.
/// Returns the encoded biome JSON string on save, or null on cancel.
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
  final Map<String, TextEditingController> _skinFlavourCtls = {
    for (final c in kWeatherConditions) c: TextEditingController(),
  };
  double _diurnal = 1.0;
  BiomePreview? _preview;

  int _toDisplay(int c) => widget.fahrenheit ? WeatherSegments.tempF(c) : c;
  int _fromDisplay(int v) =>
      widget.fahrenheit ? ((v - 32) * 5 / 9).round() : v;
  String get _unit => widget.fahrenheit ? '°F' : '°C';

  @override
  void initState() {
    super.initState();
    final existing = Biome.tryParse(widget.existingBiomeJson);
    _templateId = existing != null ? 'custom' : Biome.desert.id;
    _seedFrom(existing ?? Biome.desert);
    // The mockup opens with the preview already computed.
    _preview = previewBiome(_buildDraft());
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
        _weightCtls[season]![i].text =
            '${i < weights.length ? weights[i] : 0}';
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
      _skinFlavourCtls[c]!.text = draft.flavour;
    }
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
    for (final c in _skinFlavourCtls.values) {
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
    final anyExtreme = ranks
        .any((r) => r < kClassicBandRange.$1 || r > kClassicBandRange.$2);
    if (!anyExtreme) return kClassicBandRange;
    final lo = ranks.reduce((a, b) => a < b ? a : b) - 1;
    final hi = ranks.reduce((a, b) => a > b ? a : b) + 1;
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
      baseTemp: {for (final s in kSeasons) s: _seasonBand[s]!.index},
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
    final errors = _buildDraft().validate();
    for (final e in _skins.entries) {
      if (e.value.active && e.value.stance == null) {
        errors.add(
          '${e.key}: a renamed weather needs a danger level — otherwise '
          'characters would picnic in it.',
        );
      }
    }
    // validate() speaks canonical °C; when the user's display unit is °F the
    // anchor they must type is °F, so the shown message says so too. Only
    // the known anchor message is rewritten — future validate() copy that
    // genuinely means storage-°C must pass through untouched.
    return widget.fahrenheit
        ? [
            for (final e in errors)
              e.replaceAll('set a display °C', 'set a display °F'),
          ]
        : errors;
  }

  void _refreshPreview() =>
      setState(() => _preview = previewBiome(_buildDraft()));

  @override
  Widget build(BuildContext context) {
    final errors = _blockingErrors();
    return Dialog(
      backgroundColor: AppColors.cardOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 760),
        child: Column(
          children: [
            // ── Header with the mockup's amber wash ──
            ClimateEditorHeader(
              worldName: widget.worldName,
              templateId: _templateId,
              onTemplate: (id) {
                if (id == 'custom') return;
                setState(() {
                  _templateId = id;
                  _seedFrom(Biome.builtInById(id)!);
                  _preview = previewBiome(_buildDraft());
                });
              },
              onClose: () => Navigator.pop(context),
            ),
            Divider(height: 1, color: AppColors.borderOf(context)),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _leftColumn(context)),
                  VerticalDivider(
                    width: 1,
                    color: AppColors.borderOf(context),
                  ),
                  // The mockup's darker inset preview column.
                  Expanded(
                    flex: 4,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.14),
                      child: _rightColumn(context),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.borderOf(context)),
            // ── Footer pills ──
            ClimateEditorFooter(
              canSave: errors.isEmpty,
              onCancel: () => Navigator.pop(context),
              onSave: () => Navigator.pop(
                context,
                jsonEncode(_buildDraft().toJson()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftColumn(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        ClimateSectionHeader(
          'Temperature by season',
          hint:
              'Extreme steps unlock the display $_unit — you type what the '
              'weather chip shows. Characters feel words, not numbers. '
              'Units follow Settings → General (°C/°F, default °C); storage '
              'stays °C so shared worlds are unit-agnostic.',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, season) in kSeasons.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: SeasonCard(
                  season: season,
                  band: _seasonBand[season]!,
                  anchorController: _anchorCtls[season]!,
                  needsAnchor: _needsAnchor(season),
                  unit: _unit,
                  onBand: (b) => setState(() => _seasonBand[season] = b),
                  onAnchorChanged: () => setState(() {}),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        ClimateSectionHeader(
          'Weather odds',
          hint: 'Per season — higher numbers are more common.',
        ),
        WeightsGrid(controllers: _weightCtls),
        const SizedBox(height: 20),
        ClimateSectionHeader('Day–night swing'),
        SwingSlider(
          value: _diurnal,
          onChanged: (v) => setState(() => _diurnal = v),
        ),
        Text(
          'How hard the temperature drops after sundown. Deserts and thin '
          'atmospheres swing hard.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary(context),
          ),
        ),
        const SizedBox(height: 20),
        ClimateSectionHeader(
          'Rename the weather',
          hint:
              'Every rename needs a danger level, so a lazy "acid rain" '
              'still behaves. Leave blank to keep the normal weather.',
        ),
        for (final c in kWeatherConditions)
          SkinEditRow(
            condition: c,
            draft: _skins[c]!,
            labelController: _skinLabelCtls[c]!,
            flavourController: _skinFlavourCtls[c]!,
            onLabel: (v) => setState(() => _skins[c]!.label = v),
            onEmoji: (v) => setState(() => _skins[c]!.emoji = v),
            onFlavour: (v) => setState(() => _skins[c]!.flavour = v),
            onStance: (st) => setState(() => _skins[c]!.stance = st),
          ),
        const SizedBox(height: 6),
        Text(
          'Standing facts about the place — air, gravity, what\'s '
          'underfoot — don\'t belong to the climate. They live in the '
          'world\'s Place traits, right below the climate picker.',
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: AppColors.textTertiary(context),
          ),
        ),
      ],
    );
  }

  Widget _rightColumn(BuildContext context) {
    final errors = _blockingErrors();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Runs the real weather engine over your numbers.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textTertiary(context),
                ),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.porchAmberOf(context),
                side: BorderSide(
                  color: AppColors.porchAmberOf(context).withValues(
                    alpha: 0.6,
                  ),
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _refreshPreview,
              child: const Text('Refresh preview'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_preview != null)
          ClimatePreviewPanel(
            preview: _preview!,
            biome: _buildDraft(),
            fahrenheit: widget.fahrenheit,
          ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final e in errors)
            Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: kClimateDanger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⛔ $e',
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  // theme-keep: mockup danger text tint
                  color: Color(0xFFF2B3A5),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
