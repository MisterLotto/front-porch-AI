// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Display names for spell check dictionary tags. Mirrors
// lib/utils/spell_check_languages.dart — the two surfaces show the same menu,
// so they must read the same way. Keep them in step.

const LANGUAGES: Record<string, string> = {
  af: 'Afrikaans', ar: 'Arabic', be: 'Belarusian', bg: 'Bulgarian',
  bn: 'Bengali', ca: 'Catalan', cs: 'Czech', da: 'Danish', de: 'German',
  el: 'Greek', en: 'English', es: 'Spanish', et: 'Estonian', eu: 'Basque',
  fa: 'Persian', fi: 'Finnish', fr: 'French', ga: 'Irish', gl: 'Galician',
  he: 'Hebrew', hi: 'Hindi', hr: 'Croatian', hu: 'Hungarian',
  id: 'Indonesian', is: 'Icelandic', it: 'Italian', ja: 'Japanese',
  ko: 'Korean', lt: 'Lithuanian', lv: 'Latvian', ms: 'Malay',
  nb: 'Norwegian Bokmål', nl: 'Dutch', nn: 'Norwegian Nynorsk',
  no: 'Norwegian', pl: 'Polish', pt: 'Portuguese', ro: 'Romanian',
  ru: 'Russian', sk: 'Slovak', sl: 'Slovenian', sq: 'Albanian',
  sr: 'Serbian', sv: 'Swedish', ta: 'Tamil', th: 'Thai', tr: 'Turkish',
  uk: 'Ukrainian', vi: 'Vietnamese', zh: 'Chinese',
};

const REGIONS: Record<string, string> = {
  AT: 'Austria', AU: 'Australia', BR: 'Brazil', CA: 'Canada',
  CH: 'Switzerland', DE: 'Germany', ES: 'Spain', FR: 'France',
  GB: 'United Kingdom', IE: 'Ireland', IN: 'India', IT: 'Italy',
  MX: 'Mexico', NL: 'Netherlands', NZ: 'New Zealand', PT: 'Portugal',
  US: 'United States', ZA: 'South Africa',
};

/** `en_US` -> "English (United States)"; unknown tags return unchanged. */
export function spellCheckLabel(tag: string): string {
  const parts = tag.replace('-', '_').split('_');
  const language = LANGUAGES[parts[0].toLowerCase()];
  if (!language) return tag;
  if (parts.length < 2) return language;
  const region = REGIONS[parts[1].toUpperCase()];
  return region ? `${language} (${region})` : `${language} (${parts[1]})`;
}

/** Sorted by how the label reads, not by raw code. */
export function sortedByLabel(tags: string[]): string[] {
  return [...new Set(tags)].sort((a, b) =>
    spellCheckLabel(a).toLowerCase().localeCompare(spellCheckLabel(b).toLowerCase()),
  );
}
