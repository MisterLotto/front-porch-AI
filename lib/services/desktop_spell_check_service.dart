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

/// A [SpellCheckService] backed by a native spell checker: macOS
/// `NSSpellChecker`, Windows `ISpellChecker`, and on Linux a hunspell engine
/// compiled into the app itself (`third_party/hunspell`).
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
/// Linux has no OS-guaranteed spell checker, so the app carries its own: the
/// engine is compiled in and an en_US dictionary ships in the bundle, with the
/// user's system dictionaries preferred when they exist. Nothing is dlopen'd
/// and no process is spawned. A language with no dictionary anywhere replies
/// null, which lands in the same "no results" branch as any other empty answer.
/// Sentinel [DesktopSpellCheckService.activeLanguage] value meaning "do not
/// spell check at all".
const String kSpellCheckOff = 'off';

class DesktopSpellCheckService implements SpellCheckService {
  static const _channel = MethodChannel('front_porch_ai/spell_check');

  /// The language every check runs against, as a dictionary tag (`en_US`), or
  /// [kSpellCheckOff]. Owned by StorageService, which writes it on load and on
  /// change; a static rather than an injected dependency because Flutter
  /// constructs this service deep inside widget code with no access to a
  /// Provider scope.
  ///
  /// **This is deliberately NOT the system locale, and that is the entire
  /// point.** Plenty of people run a German or Polish desktop and role-play
  /// with characters in English. Checking their English prose against a German
  /// dictionary underlines *most of the words in every sentence* — far worse
  /// than no spell check at all.
  ///
  /// The trigger is the OS **interface language**, not the region/format
  /// setting. Measured, because the difference is easy to get backwards:
  /// switching the region to Spain leaves the reported locale untouched, while
  /// switching the interface language to German makes
  /// `PlatformDispatcher.instance.locale` report `de_DE`. So "my locale is
  /// Spain and spell check stayed English" is correct behaviour, and a German
  /// or Polish *interface* is the case that breaks.
  ///
  /// Only one of the two paths was ever affected, and it is the one that
  /// matters most: [StyledTextController] read `PlatformDispatcher` directly,
  /// so the chat composer, both character editors, group settings and the
  /// lorebook/message-edit dialogs all inherited the interface language.
  /// [AppTextField]'s plain prose fields went through `Localizations.localeOf`,
  /// which resolves against MaterialApp's default `supportedLocales` of
  /// `[en_US]` and therefore already answered `en_US` on a German desktop.
  /// Routing everything through this one value removes the split as well as
  /// the bug.
  ///
  /// The default is English rather than the OS locale because the failure modes
  /// are not symmetric: guessing the chat language wrong in the "wall of red"
  /// direction makes users switch the feature off, while guessing it wrong the
  /// other way costs one trip to Settings.
  static String activeLanguage = 'en_US';

  static bool get isEnabled => activeLanguage != kSpellCheckOff;

  /// Language tags the platform can actually check, for the Settings picker.
  /// Returns an empty list when the channel is unavailable, so callers can
  /// fall back rather than present an empty menu.
  static Future<List<String>> availableLanguages() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'availableLanguages',
      );
      return raw?.cast<String>() ?? const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  /// The [locale] argument is **ignored**. Flutter passes the OS locale here
  /// (EditableText resolves it from `Localizations`), which is the wrong
  /// question — see [activeLanguage]. Every caller funnels through this one
  /// method, so overriding here fixes both the AppTextField path and the
  /// StyledTextController path at once.
  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    if (!isEnabled) return null;
    try {
      final rawResults = await _channel.invokeMethod<List<dynamic>>(
        'spellCheck',
        <String>[activeLanguage, text],
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
