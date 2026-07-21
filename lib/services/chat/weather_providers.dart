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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:front_porch_ai/services/chat/weather_engine.dart';

/// Riverpod surface for weather (Living Time, first Riverpod-native feature
/// per the 2026-07-21 maintainer directive).
///
/// The engine is pure, so the provider layer is a memoizing family over a
/// value-typed inputs record: widgets watch [dailyWeatherProvider(inputs)]
/// and rebuild only when the inputs actually change (records have structural
/// ==). The inputs are handed down from the existing Provider-based widget
/// tree (TimeStrip already holds the ChatService) — this is the documented
/// bridge for this feature: state crosses at the widget boundary as plain
/// values, so no ChangeNotifier is wrapped and no Provider.of appears in new
/// widgets.
typedef WeatherInputs = ({String sessionSeed, int dayCount, DateTime date});

final dailyWeatherProvider = Provider.autoDispose
    .family<DailyWeather, WeatherInputs>(
      (ref, inputs) => WeatherEngine.weatherFor(
        sessionSeed: inputs.sessionSeed,
        dayCount: inputs.dayCount,
        date: inputs.date,
      ),
    );
