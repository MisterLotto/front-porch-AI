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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:front_porch_ai/services/chat/weather_engine.dart';
import 'package:front_porch_ai/services/chat/weather_providers.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Sidebar weather glyph (Living Time §3) — emoji + banded label, rendered
/// inside TimeStrip's header row. Riverpod codegen-native: the parent hands
/// down plain values and this widget watches the generated
/// [dailyWeatherProvider] family (named args, per-argument memoization), so
/// the deterministic recompute runs only when the story day/session actually
/// changes, not on every sidebar rebuild. Parent gates rendering (weather
/// off → widget absent).
class WeatherChip extends ConsumerWidget {
  final String sessionSeed;
  final int dayCount;
  final DateTime date;

  const WeatherChip({
    super.key,
    required this.sessionSeed,
    required this.dayCount,
    required this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(
      dailyWeatherProvider(
        sessionSeed: sessionSeed,
        dayCount: dayCount,
        date: date,
      ),
    );
    // Tomorrow via the same memoized family — the walk is prefix-stable, so
    // this forecast is exactly what the next story day will be. The chip only
    // grows an arrow glyph when the condition actually changes.
    final tomorrow = ref.watch(
      dailyWeatherProvider(
        sessionSeed: sessionSeed,
        dayCount: dayCount + 1,
        date: date.add(const Duration(days: 1)),
      ),
    );
    final changing = tomorrow.condition != weather.condition;
    return Tooltip(
      message:
          '${WeatherEngine.label(weather)} · ${weather.season}\n'
          'Tomorrow: ${WeatherEngine.emoji(tomorrow.condition)} '
          '${WeatherEngine.label(tomorrow)}\n'
          'Story weather — deterministic for this chat and day.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            WeatherEngine.emoji(weather.condition),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 3),
          Text(
            WeatherEngine.label(weather),
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary(context),
            ),
          ),
          if (changing) ...[
            const SizedBox(width: 4),
            Text(
              '→',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary(context),
              ),
            ),
            const SizedBox(width: 2),
            Text(
              WeatherEngine.emoji(tomorrow.condition),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
