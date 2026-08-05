// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import { api } from './api/client';

const STORAGE_KEY = 'fpai_spell_check_language';

/**
 * Keeps the browser's spell checker on the language the user actually writes
 * in, matching the desktop's Settings → Spell Check Language.
 *
 * Why this exists at all: the browser defaults to the device's language. A
 * user with a German phone or a Polish laptop who role-plays in English gets
 * every English word underlined — the same bug the desktop had, arriving by a
 * different route. The desktop owns the setting; the web obeys it.
 *
 * It is applied to <html> rather than to each textarea because `lang` is
 * inherited: one assignment covers the composer, the message editor, the
 * character forms and anything added later, with no per-component wiring to
 * forget.
 */
export function applySpellCheckLang(tag: string | undefined | null): void {
  if (!tag) return;
  if (tag === 'off') {
    // No dictionary can express "off", so strip the hint and let the elements'
    // own spellCheck={false} handle it; nothing here can force a browser to
    // stop checking entirely.
    document.documentElement.removeAttribute('lang');
    localStorage.setItem(STORAGE_KEY, tag);
    return;
  }
  // BCP 47 wants a hyphen; the desktop stores dictionary tags (en_US).
  document.documentElement.lang = tag.replace('_', '-');
  localStorage.setItem(STORAGE_KEY, tag);
}

/**
 * Restores the last known language synchronously at boot, so the very first
 * keystrokes are checked correctly instead of waiting on a round trip. The
 * fetch that follows corrects it if the desktop's setting has since changed.
 */
export function restoreSpellCheckLang(): void {
  applySpellCheckLang(localStorage.getItem(STORAGE_KEY));
}

/** Pulls the authoritative value from the desktop. Failure is not worth
 * surfacing — the cached value, or the browser default, still works. */
export async function syncSpellCheckLang(): Promise<void> {
  try {
    const settings = await api.get<{ spellCheckLanguage?: string }>(
      '/api/settings',
    );
    applySpellCheckLang(settings.spellCheckLanguage);
  } catch {
    /* offline or an older desktop build that does not send the key */
  }
}
