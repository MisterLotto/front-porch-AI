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

/// A [SpellCheckService] backed by the native macOS `NSSpellChecker` and Windows `ISpellChecker` APIs.
///
/// Communicates with `SpellCheckPlugin` (Swift/C++) over the
/// `front_porch_ai/spell_check` method channel.
///
/// This is the correct spell-check approach for macOS and Windows desktop Flutter apps.
/// Flutter's built-in [DefaultSpellCheckService] is documented as
/// "currently only supported by Android and iOS" and returns empty results
/// on desktop. Flutter's `nativeSpellCheckServiceDefined` path requires the
/// Flutter engine to register a native handler, which is unreliable on
/// desktop. Calling the native APIs directly via a method channel
/// bypasses both limitations.
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
            end:   map['endIndex']   as int,
          ),
          (map['suggestions'] as List<dynamic>).cast<String>(),
        );
      }).toList();
    } catch (_) {
      // Channel not registered (non-macOS build) or NSSpellChecker error.
      return null;
    }
  }
}
