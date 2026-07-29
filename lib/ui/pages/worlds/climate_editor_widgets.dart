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

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/chat/weather_biomes.dart';
import 'package:front_porch_ai/services/chat/weather_engine.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Thermal-ordered band choices for the per-season dropdowns.
const List<TempBand> kBandChoices = [
  TempBand.cryogenic,
  TempBand.cold,
  TempBand.cool,
  TempBand.mild,
  TempBand.warm,
  TempBand.hot,
  TempBand.furnace,
  TempBand.inferno,
];

String bandLabel(TempBand b) => switch (b) {
  TempBand.cryogenic => 'Cryogenic — kills the unprotected',
  TempBand.cold => 'Cold',
  TempBand.cool => 'Cool',
  TempBand.mild => 'Mild',
  TempBand.warm => 'Warm',
  TempBand.hot => 'Hot',
  TempBand.furnace => 'Furnace — beyond survival',
  TempBand.inferno => 'Inferno — incinerating',
};

/// Draft skin row state: stance stays null until the author picks one, which
/// is what lets Save enforce "a rename needs a danger level".
class SkinDraft {
  String label = '';
  String emoji = '';
  WeatherStance? stance;
  String flavour = '';

  bool get active => label.trim().isNotEmpty;
}

String stanceLabel(WeatherStance s) => switch (s) {
  WeatherStance.pleasant => 'Pleasant',
  WeatherStance.ordinary => 'Ordinary',
  WeatherStance.harsh => 'Harsh',
  WeatherStance.dangerous => 'Dangerous',
  WeatherStance.deadly => 'Deadly',
};

/// Section header in the dialog's warm-porch register.
class ClimateSectionHeader extends StatelessWidget {
  const ClimateSectionHeader(this.title, {super.key, this.hint});
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: AppColors.porchAmberOf(context),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(
            hint!,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary(context),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// The 4-season × 7-condition weights grid. Small numeric fields; higher =
/// more common. Controllers are owned by the dialog (survive rebuilds).
class WeightsGrid extends StatelessWidget {
  const WeightsGrid({super.key, required this.controllers});

  /// season → 7 controllers in [kWeatherConditions] order.
  final Map<String, List<TextEditingController>> controllers;

  @override
  Widget build(BuildContext context) {
    final tertiary = AppColors.textTertiary(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(64),
        columnWidths: const {0: FixedColumnWidth(70)},
        children: [
          TableRow(
            children: [
              const SizedBox.shrink(),
              for (final c in kWeatherConditions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    c[0].toUpperCase() + c.substring(1),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: tertiary),
                  ),
                ),
            ],
          ),
          for (final season in kSeasons)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    season[0].toUpperCase() + season.substring(1),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                for (final ctl in controllers[season]!)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: TextField(
                      controller: ctl,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 7),
                        filled: true,
                        fillColor: AppColors.surfaceContainerOf(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              BorderSide(color: AppColors.borderOf(context)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One season's temperature row: thermal band dropdown + the unit-aware
/// anchor field that unlocks when an extreme is reachable.
class SeasonBandRow extends StatelessWidget {
  const SeasonBandRow({
    super.key,
    required this.season,
    required this.band,
    required this.anchorController,
    required this.needsAnchor,
    required this.unit,
    required this.onBand,
    required this.onAnchorChanged,
  });

  final String season;
  final TempBand band;
  final TextEditingController anchorController;
  final bool needsAnchor;
  final String unit;
  final ValueChanged<TempBand> onBand;
  final VoidCallback onAnchorChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              season[0].toUpperCase() + season.substring(1),
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          Expanded(
            child: DropdownButton<TempBand>(
              value: band,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final b in kBandChoices)
                  DropdownMenuItem(
                    value: b,
                    child: Text(
                      bandLabel(b),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
              onChanged: (b) {
                if (b != null) onBand(b);
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: needsAnchor
                ? TextField(
                    controller: anchorController,
                    keyboardType:
                        const TextInputType.numberWithOptions(signed: true),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.porchAmberOf(context),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: '$unit shown',
                      suffixStyle: TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary(context),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => onAnchorChanged(),
                  )
                : Text(
                    'auto $unit',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary(context),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One condition's rename row: label + emoji + mandatory stance, and (when
/// the rename is active) a flavour line capped to the runtime's 140 chars.
class SkinEditRow extends StatelessWidget {
  const SkinEditRow({
    super.key,
    required this.condition,
    required this.draft,
    required this.labelController,
    required this.emojiController,
    required this.flavourController,
    required this.onLabel,
    required this.onEmoji,
    required this.onFlavour,
    required this.onStance,
  });

  final String condition;
  final SkinDraft draft;
  final TextEditingController labelController;
  final TextEditingController emojiController;
  final TextEditingController flavourController;
  final ValueChanged<String> onLabel;
  final ValueChanged<String> onEmoji;
  final ValueChanged<String> onFlavour;
  final ValueChanged<WeatherStance?> onStance;

  InputDecoration _dec(BuildContext context, String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        counterText: '',
        hintStyle: TextStyle(
          fontSize: 11.5,
          color: AppColors.textTertiary(context),
        ),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final missingStance = draft.active && draft.stance == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(
                  '${WeatherEngine.emoji(WeatherCondition.values[kWeatherConditions.indexOf(condition)])} '
                  '$condition',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary(context),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: labelController,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: _dec(context, 'rename (e.g. Dust Squall)'),
                  onChanged: onLabel,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 44,
                child: TextField(
                  controller: emojiController,
                  enabled: draft.active,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                  decoration: _dec(context, '🌪️'),
                  onChanged: onEmoji,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<WeatherStance?>(
                value: draft.stance,
                hint: Text(
                  missingStance ? 'Pick one!' : 'Danger',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: missingStance
                        ? AppColors.logError
                        : AppColors.textTertiary(context),
                  ),
                ),
                underline: const SizedBox.shrink(),
                items: [
                  for (final s in WeatherStance.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(
                        stanceLabel(s),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                onChanged: draft.active ? onStance : null,
              ),
            ],
          ),
          if (draft.active)
            Padding(
              padding: const EdgeInsets.only(left: 68, top: 4),
              child: TextField(
                controller: flavourController,
                maxLength: 140,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
                decoration: _dec(
                  context,
                  'one flavour line (optional) — '
                  '"rust-red columns wander the plain"',
                ),
                onChanged: onFlavour,
              ),
            ),
        ],
      ),
    );
  }
}
