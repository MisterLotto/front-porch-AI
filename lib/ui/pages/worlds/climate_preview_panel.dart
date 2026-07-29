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

import 'package:front_porch_ai/services/chat/biome_preview.dart';
import 'package:front_porch_ai/services/chat/weather_engine.dart';
import 'package:front_porch_ai/ui/pages/worlds/climate_editor_widgets.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// The preview panel: per-season condition bars + warnings + a sample week.
class ClimatePreviewPanel extends StatelessWidget {
  const ClimatePreviewPanel({
    super.key,
    required this.preview,
  });

  final BiomePreview preview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClimateSectionHeader(
          'Preview',
          hint: '${40 * 50} simulated days per season',
        ),
        for (final s in preview.seasons) _seasonRow(context, s),
        const SizedBox(height: 10),
        ClimateSectionHeader('A sample week (winter)'),
        Row(
          children: [
            for (final d in preview.sampleWeek)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      WeatherEngine.emoji(d.condition),
                      style: const TextStyle(fontSize: 15),
                    ),
                    Text(
                      WeatherEngine.tempWord(d.temp),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: AppColors.textTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (preview.errors.isNotEmpty || preview.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClimateSectionHeader('What the preview noticed'),
          for (final e in preview.errors)
            _notice(context, e, isError: true),
          for (final w in preview.warnings)
            _notice(context, w, isError: false),
        ],
      ],
    );
  }

  Widget _seasonRow(BuildContext context, SeasonDistribution s) {
    final entries = s.conditionShare.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final summary = entries
        .take(3)
        .map((e) => '${(e.value * 100).round()}% ${e.key}')
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              s.season,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(BuildContext context, String text, {required bool isError}) {
    final color = isError ? AppColors.logError : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isError ? '⛔ ' : '⚠️ ', style: const TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                color: color ?? AppColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
