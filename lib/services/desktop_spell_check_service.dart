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

import 'dart:ui' show Locale, TextRange;

import 'package:flutter/services.dart'
    show MethodChannel, SpellCheckService, SuggestionSpan;

/// A [SpellCheckService] backed by the platform's own spell checker: macOS
/// `NSSpellChecker`, Windows `ISpellChecker`, and Linux Enchant (which fronts
/// whichever hunspell/aspell dictionaries the user has installed).
///
/// Communicates with `SpellCheckPlugin` (Swift / C++ / C++-GObject) over the
/// `front_porch_ai/spell_check` method channel. All three runners implement
/// the identical contract:
///
///   send    `spellCheck` with `[languageTag, text]`
///   receive `List<Map>` of `{startIndex, endIndex, suggestions}`, or null
///
/// Indices are UTF-16 code units so they can be used as [TextRange] bounds
/// directly.
///
/// This is the correct spell-check approach for desktop Flutter apps.
/// Flutter's built-in [DefaultSpellCheckService] is documented as
/// "currently only supported by Android and iOS" and returns empty results
/// on desktop. Flutter's `nativeSpellCheckServiceDefined` path requires the
/// Flutter engine to register a native handler, which is unreliable on
/// desktop. Calling the native APIs directly via a method channel
/// bypasses both limitations.
///
/// Linux is best-effort by nature: unlike macOS and Windows, the OS does not
/// guarantee a spell checker exists. The runner loads Enchant with `dlopen`
/// and replies null when it or the locale's dictionary is missing, which lands
/// in the same "no results" branch as any other empty answer.
class DesktopSpellCheckService implements SpellCheckService {
  static const _channel = MethodChannel('front_porch_ai/spell_check');

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    try {
      final rawResults = await _channel.invokeMethod<List<dynamic>>(
        'spellCheck',
        <String>[locale.toLanguageTag(), text],
      );
      if (rawResults == null) return null;

      return rawResults.map((dynamic item) {
        final map = item as Map<dynamic, dynamic>;
        return SuggestionSpan(
          TextRange(
            start: map['startIndex'] as int,
            end: map['endIndex'] as int,
          ),
          (map['suggestions'] as List<dynamic>).cast<String>(),
        );
      }).toList();
    } catch (_) {
      // Channel not registered (mobile/web build) or a native checker error.
      return null;
    }
  }
}
