// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Display names for spell check dictionary tags.
///
/// The native side reports raw tags — `en_US`, `de_DE`, `pt_BR` — because that
/// is what the dictionaries are called on disk. Showing those in a Settings
/// menu is user-hostile, so they are mapped here. Anything unrecognised falls
/// back to the tag itself rather than being hidden: a user who installed an
/// unusual dictionary should still be able to select it.
library;

const Map<String, String> _languageNames = {
  'af': 'Afrikaans',
  'ar': 'Arabic',
  'be': 'Belarusian',
  'bg': 'Bulgarian',
  'bn': 'Bengali',
  'ca': 'Catalan',
  'cs': 'Czech',
  'da': 'Danish',
  'de': 'German',
  'el': 'Greek',
  'en': 'English',
  'es': 'Spanish',
  'et': 'Estonian',
  'eu': 'Basque',
  'fa': 'Persian',
  'fi': 'Finnish',
  'fr': 'French',
  'ga': 'Irish',
  'gl': 'Galician',
  'he': 'Hebrew',
  'hi': 'Hindi',
  'hr': 'Croatian',
  'hu': 'Hungarian',
  'id': 'Indonesian',
  'is': 'Icelandic',
  'it': 'Italian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'lt': 'Lithuanian',
  'lv': 'Latvian',
  'ms': 'Malay',
  'nb': 'Norwegian Bokmål',
  'nl': 'Dutch',
  'nn': 'Norwegian Nynorsk',
  'no': 'Norwegian',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ro': 'Romanian',
  'ru': 'Russian',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'sq': 'Albanian',
  'sr': 'Serbian',
  'sv': 'Swedish',
  'ta': 'Tamil',
  'th': 'Thai',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'vi': 'Vietnamese',
  'zh': 'Chinese',
};

const Map<String, String> _regionNames = {
  'AT': 'Austria',
  'AU': 'Australia',
  'BR': 'Brazil',
  'CA': 'Canada',
  'CH': 'Switzerland',
  'DE': 'Germany',
  'ES': 'Spain',
  'FR': 'France',
  'GB': 'United Kingdom',
  'IE': 'Ireland',
  'IN': 'India',
  'IT': 'Italy',
  'MX': 'Mexico',
  'NL': 'Netherlands',
  'NZ': 'New Zealand',
  'PT': 'Portugal',
  'US': 'United States',
  'ZA': 'South Africa',
};

/// `en_US` -> "English (United States)", `de` -> "German", `xx_YY` -> "xx_YY".
String spellCheckLanguageLabel(String tag) {
  final normalized = tag.replaceAll('-', '_');
  final parts = normalized.split('_');
  final language = _languageNames[parts.first.toLowerCase()];
  if (language == null) return tag;
  if (parts.length < 2) return language;
  final region = _regionNames[parts[1].toUpperCase()];
  return region == null ? '$language (${parts[1]})' : '$language ($region)';
}

/// Sorts tags by their display label so the picker reads alphabetically to a
/// human ("Dutch, English, French"), not by raw code ("de, en, fr" — which
/// happens to agree here but does not for, say, Basque/eu vs Estonian/et).
List<String> sortedByLabel(Iterable<String> tags) {
  final list = tags.toSet().toList();
  list.sort(
    (a, b) => spellCheckLanguageLabel(
      a,
    ).toLowerCase().compareTo(spellCheckLanguageLabel(b).toLowerCase()),
  );
  return list;
}
