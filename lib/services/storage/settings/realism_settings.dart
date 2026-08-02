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
  bool _weatherFahrenheit = false;
  bool _absenceBannerEnabled = true;
  bool _absenceAckEnabled = false;
  int _absenceThresholdHours = 24;
  bool _dreamsEnabled = true;
  bool _ambitionsEnabled = true;
  bool _promiseLedgerEnabled = true;
  List<String> _bannedPhrases = [];

  bool get realismDefault => _realismDefault;
  bool get nsfwCooldownDefault => _nsfwCooldownDefault;
  bool get passageOfTimeDefault => _passageOfTimeDefault;
  bool get realismOneShotEval => _realismOneShotEval;

  /// Living Time story weather (living-time-features.md §3). Effective only
  /// when realism + passage-of-time are on — ChatService gates that.
  bool get weatherEnabled => _weatherEnabled;

  /// Display temperatures in °F instead of °C (§3 v3). Display-only: the
  /// canonical unit is °C everywhere internally, and the generation prompt
  /// carries no numbers at all (words-only contract).
  bool get weatherFahrenheit => _weatherFahrenheit;

  /// Living Time absence awareness (living-time-features.md §2). Banner is
  /// app-voice and default ON; the in-character acknowledgment is default
  /// OFF by explicit maintainer decision (can read as creepy). Threshold in
  /// hours before either fires.
  bool get absenceBannerEnabled => _absenceBannerEnabled;
  bool get absenceAckEnabled => _absenceAckEnabled;
  int get absenceThresholdHours => _absenceThresholdHours;

  /// Living Time dreams (living-time-features.md §1). Effective only when
  /// realism + passage-of-time + the Journal are on — ChatService gates.
  bool get dreamsEnabled => _dreamsEnabled;

  /// Long-term character goals. Independent of the Realism Engine on purpose:
  /// the goals themselves are authored on the character card, so they are never
  /// stale and cost nothing extra to inject. Only their PROGRESS annotation
  /// comes from the engine, and a progress figure that stops moving is far less
  /// misleading than a stale fact would be.
  bool get ambitionsEnabled => _ambitionsEnabled;

  /// The promise/debt ledger. Also independent of Realism, but NOT free and NOT
  /// unconditional: detection is one extra model call per reply, and storage is
  /// the Journal (one journal card per commitment), so it does nothing with the
  /// Journal switched off. Both facts are surfaced in the settings copy —
  /// spending a user's tokens without telling them is not acceptable.
  bool get promiseLedgerEnabled => _promiseLedgerEnabled;
  List<String> get bannedPhrases => List.unmodifiable(_bannedPhrases);

  void load() {
    _realismDefault = prefs?.getBool(k('realism_default')) ?? false;
    _nsfwCooldownDefault = prefs?.getBool(k('nsfw_cooldown_default')) ?? false;
    _passageOfTimeDefault =
        prefs?.getBool(k('passage_of_time_default')) ?? true;
    _realismOneShotEval = prefs?.getBool(k('realism_one_shot_eval')) ?? false;
    _weatherEnabled = prefs?.getBool(k('weather_enabled')) ?? true;
    _weatherFahrenheit = prefs?.getBool(k('weather_fahrenheit')) ?? false;
    _absenceBannerEnabled =
        prefs?.getBool(k('absence_banner_enabled')) ?? true;
    _absenceAckEnabled = prefs?.getBool(k('absence_ack_enabled')) ?? false;
    _absenceThresholdHours =
        prefs?.getInt(k('absence_threshold_hours')) ?? 24;
    _dreamsEnabled = prefs?.getBool(k('dreams_enabled')) ?? true;
    _ambitionsEnabled = prefs?.getBool(k('ambitions_enabled')) ?? true;
    _promiseLedgerEnabled =
        prefs?.getBool(k('promise_ledger_enabled')) ?? true;

    final bannedJson = prefs?.getString(k('banned_phrases'));
    if (bannedJson != null) {
      try {
        _bannedPhrases = List<String>.from(jsonDecode(bannedJson) as List);
      } catch (_) {
        _bannedPhrases = [];
      }
    }
  }

  Future<void> setAmbitionsEnabled(bool value) async {
    _ambitionsEnabled = value;
    await prefs?.setBool(k('ambitions_enabled'), value);
    notify();
  }

  Future<void> setPromiseLedgerEnabled(bool value) async {
    _promiseLedgerEnabled = value;
    await prefs?.setBool(k('promise_ledger_enabled'), value);
    notify();
  }

  Future<void> setWeatherEnabled(bool value) async {
    _weatherEnabled = value;
    await prefs?.setBool(k('weather_enabled'), value);
    notify();
  }

  Future<void> setWeatherFahrenheit(bool value) async {
    _weatherFahrenheit = value;
    await prefs?.setBool(k('weather_fahrenheit'), value);
    notify();
  }

  Future<void> setAbsenceBannerEnabled(bool value) async {
    _absenceBannerEnabled = value;
    await prefs?.setBool(k('absence_banner_enabled'), value);
    notify();
  }

  Future<void> setAbsenceAckEnabled(bool value) async {
    _absenceAckEnabled = value;
    await prefs?.setBool(k('absence_ack_enabled'), value);
    notify();
  }

  Future<void> setAbsenceThresholdHours(int value) async {
    _absenceThresholdHours = value;
    await prefs?.setInt(k('absence_threshold_hours'), value);
    notify();
  }

  Future<void> setDreamsEnabled(bool value) async {
    _dreamsEnabled = value;
    await prefs?.setBool(k('dreams_enabled'), value);
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
