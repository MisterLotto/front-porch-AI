// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Phone/PWA Stoop restore must not wipe the saved login on a hiccup.
// tryRefresh is already 401-only; StoopContext used to clear on ANY
// me() failure and undid that (1.3 independent-review leftover).

import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  StoopError,
  hasStoopSession,
  shouldWipeStoopSessionAfterRestoreError,
} from './stoopApi';

beforeEach(() => {
  localStorage.clear();
  localStorage.setItem('stoop_access_token', 'access');
  localStorage.setItem('stoop_refresh_token', 'refresh');
});

afterEach(() => {
  localStorage.clear();
});

describe('shouldWipeStoopSessionAfterRestoreError', () => {
  it('keeps the saved login on a 502 / unreachable hiccup', () => {
    expect(shouldWipeStoopSessionAfterRestoreError(new StoopError(502, 'stoop_unreachable'))).toBe(
      false,
    );
    expect(hasStoopSession()).toBe(true);
  });

  it('keeps the saved login on a dropped packet (not a StoopError)', () => {
    expect(shouldWipeStoopSessionAfterRestoreError(new TypeError('Failed to fetch'))).toBe(false);
    expect(hasStoopSession()).toBe(true);
  });

  it('keeps tokens when a 401 still has a session (refresh hiccuped)', () => {
    // call() already ran tryRefresh; a 502 on refresh leaves tokens in place.
    expect(shouldWipeStoopSessionAfterRestoreError(new StoopError(401, 'invalid_token'))).toBe(
      false,
    );
    expect(hasStoopSession()).toBe(true);
  });

  it('may wipe only when the session is already gone (dead refresh)', () => {
    localStorage.clear();
    expect(shouldWipeStoopSessionAfterRestoreError(new StoopError(401, 'invalid_token'))).toBe(
      true,
    );
  });
});
