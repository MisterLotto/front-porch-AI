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
import 'settings_base.dart';

/// Realism Engine + Needs simulation + related defaults (oneShot, banned
/// phrases, per-char enjoys hygiene is in CharacterCard / group member
/// JSON, not here).
///
/// Lifted Stage 7.
class RealismSettings with SettingsBase {
  bool _realismDefault = false;
  bool _nsfwCooldownDefault = false;
  bool _passageOfTimeDefault = true;
  bool _realismOneShotEval = false;
  bool _weatherEnabled = true;
  List<String> _bannedPhrases = [];

  bool get realismDefault => _realismDefault;
  bool get nsfwCooldownDefault => _nsfwCooldownDefault;
  bool get passageOfTimeDefault => _passageOfTimeDefault;
  bool get realismOneShotEval => _realismOneShotEval;

  /// Living Time story weather (living-time-features.md §3). Effective only
  /// when realism + passage-of-time are on — ChatService gates that.
  bool get weatherEnabled => _weatherEnabled;
  List<String> get bannedPhrases => List.unmodifiable(_bannedPhrases);

  void load() {
    _realismDefault = prefs?.getBool(k('realism_default')) ?? false;
    _nsfwCooldownDefault = prefs?.getBool(k('nsfw_cooldown_default')) ?? false;
    _passageOfTimeDefault =
        prefs?.getBool(k('passage_of_time_default')) ?? true;
    _realismOneShotEval = prefs?.getBool(k('realism_one_shot_eval')) ?? false;
    _weatherEnabled = prefs?.getBool(k('weather_enabled')) ?? true;

    final bannedJson = prefs?.getString(k('banned_phrases'));
    if (bannedJson != null) {
      try {
        _bannedPhrases = List<String>.from(jsonDecode(bannedJson) as List);
      } catch (_) {
        _bannedPhrases = [];
      }
    }
  }

  Future<void> setWeatherEnabled(bool value) async {
    _weatherEnabled = value;
    await prefs?.setBool(k('weather_enabled'), value);
    notify();
  }

  Future<void> setRealismOneShotEval(bool value) async {
    _realismOneShotEval = value;
    await prefs?.setBool(k('realism_one_shot_eval'), value);
    notify();
  }

  Future<void> setRealismDefault(bool value) async {
    _realismDefault = value;
    await prefs?.setBool(k('realism_default'), value);
    notify();
  }

  Future<void> setNsfwCooldownDefault(bool value) async {
    _nsfwCooldownDefault = value;
    await prefs?.setBool(k('nsfw_cooldown_default'), value);
    notify();
  }

  Future<void> setPassageOfTimeDefault(bool value) async {
    _passageOfTimeDefault = value;
    await prefs?.setBool(k('passage_of_time_default'), value);
    notify();
  }

  Future<void> setBannedPhrases(List<String> value) async {
    _bannedPhrases = value.where((s) => s.isNotEmpty).toList();
    await prefs?.setString(k('banned_phrases'), jsonEncode(_bannedPhrases));
    notify();
  }
}
