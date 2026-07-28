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
import 'package:front_porch_ai/services/chat/weather_segments.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Sidebar weather glyph (Living Time §3, intra-day since v3) — the CURRENT
/// DAY-PART's condition emoji + numeric temperature in the user's unit,
/// rendered inside TimeStrip's header row. Riverpod codegen-native: the
/// parent hands down plain values and this widget watches the generated
/// provider families (named args, per-argument memoization), so the
/// deterministic recompute runs only when the story clock crosses a segment
/// boundary or the day/session changes — not on every sidebar rebuild.
/// Parent gates rendering (weather off → widget absent).
class WeatherChip extends ConsumerWidget {
  final String sessionSeed;
  final int dayCount;
  final DateTime date;
  final int hour;
  final bool fahrenheit;

  const WeatherChip({
    super.key,
    required this.sessionSeed,
    required this.dayCount,
    required this.date,
    required this.hour,
    required this.fahrenheit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(
      segmentWeatherProvider(
        sessionSeed: sessionSeed,
        dayCount: dayCount,
        date: date,
        hour: hour,
      ),
    );
    // Tomorrow via the memoized daily family — the walk is prefix-stable, so
    // this forecast is exactly what the next story day will be. The chip only
    // grows an arrow glyph when the day-level condition changes.
    final tomorrow = ref.watch(
      dailyWeatherProvider(
        sessionSeed: sessionSeed,
        dayCount: dayCount + 1,
        date: date.add(const Duration(days: 1)),
      ),
    );
    final changing = tomorrow.condition != now.day.condition;
    return Tooltip(
      message:
          'Now (${now.segment.name}): '
          '${WeatherSegments.label(now, fahrenheit: fahrenheit)}\n'
          'Today: ${WeatherEngine.label(now.day)} · ${now.day.season}\n'
          'Tomorrow: ${WeatherEngine.emoji(tomorrow.condition)} '
          '${WeatherEngine.label(tomorrow)}\n'
          'Story weather — deterministic for this chat, day, and hour.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            WeatherEngine.emoji(now.condition),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 3),
          Text(
            WeatherSegments.label(now, fahrenheit: fahrenheit),
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
