// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Regression guard for the single-flight refresh LATCH in stoopApi.
//
// The latch (`refreshing`) exists so a burst of parallel 401s spends one
// refresh token. It used to be armed even on the "there is no refresh token"
// path, where nothing ever cleared it again — so once a signed-out-but-still-
// rendered page made one authenticated call, refresh-and-retry was dead for
// the rest of the page's life. Signing back in inside the same page (the web
// UI never reloads) did not heal it: the next access-token expiry produced a
// hard 401 with no refresh attempt at all.
//
// These tests drive the public surface only (stoop.me + mocked fetch) and
// assert on the fetch call log, so they fail if the latch regresses no matter
// how the internals are rearranged.

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { accessToken, hasStoopSession, stoop } from './stoopApi';

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status });
}

let paths: string[] = [];

function mockFetch(handler: (path: string, init: RequestInit) => Response) {
  vi.stubGlobal(
    'fetch',
    vi.fn(async (path: string, init: RequestInit) => {
      paths.push(path);
      return handler(path, init);
    }),
  );
}

/** The signed-in-again state: fresh tokens, but the access one is stale. */
function reSignIn() {
  localStorage.setItem('stoop_access_token', 'stale-2');
  localStorage.setItem('stoop_refresh_token', 'ref-good');
}

/** Refresh works; any call carrying a stale access token 401s. */
function healthyBackend() {
  mockFetch((path, init) => {
    if (path === '/api/stoop/auth/refresh') {
      return jsonResponse(200, { accessToken: 'fresh', refreshToken: 'ref-3' });
    }
    const headers = init.headers as Record<string, string>;
    if (headers['X-Stoop-Token'] !== 'fresh') {
      return jsonResponse(401, { error: 'invalid_token' });
    }
    return jsonResponse(200, { user: { id: 'u1' }, policyVersion: '3' });
  });
}

beforeEach(() => {
  localStorage.clear();
  paths = [];
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('single-flight refresh latch', () => {
  it('a 401 with no refresh token does not disable refresh for later calls', async () => {
    // Phase 1 — the poisoning event: the shell still thinks the user is signed
    // in (StoopContext keeps `user` set), but localStorage holds no refresh
    // token, so this call 401s with nothing to refresh.
    localStorage.setItem('stoop_access_token', 'orphan');
    mockFetch(() => jsonResponse(401, { error: 'stoop_not_signed_in' }));
    await expect(stoop.me()).rejects.toMatchObject({ status: 401 });
    expect(paths).toEqual(['/api/stoop/me']); // no refresh attempted — correct

    // Phase 2 — the user signs in again in place (no page reload), then the
    // new access token expires. Refresh-and-retry MUST still happen.
    vi.unstubAllGlobals();
    paths = [];
    reSignIn();
    healthyBackend();

    const r = await stoop.me();
    expect(r.user.id).toBe('u1');
    expect(paths).toEqual([
      '/api/stoop/me',
      '/api/stoop/auth/refresh',
      '/api/stoop/me',
    ]);
    expect(accessToken()).toBe('fresh');
  });

  it('recovers after a dead refresh token, a token-less 401, and re-login', async () => {
    // The full chain from the field report: dead refresh token clears the
    // session, a later call 401s with no token at all, then the user signs
    // back in inside the same page.
    localStorage.setItem('stoop_access_token', 'stale');
    localStorage.setItem('stoop_refresh_token', 'ref-dead');
    mockFetch(() => jsonResponse(401, { error: 'invalid_token' }));
    await expect(stoop.me()).rejects.toMatchObject({ status: 401 });
    expect(hasStoopSession()).toBe(false);

    await expect(stoop.me()).rejects.toMatchObject({ status: 401 });

    vi.unstubAllGlobals();
    paths = [];
    reSignIn();
    healthyBackend();

    await expect(stoop.me()).resolves.toMatchObject({ user: { id: 'u1' } });
    expect(paths).toContain('/api/stoop/auth/refresh');
  });

  it('still spends only one refresh token for a burst of parallel 401s', async () => {
    localStorage.setItem('stoop_access_token', 'stale');
    localStorage.setItem('stoop_refresh_token', 'ref-good');
    let refreshes = 0;
    mockFetch((path, init) => {
      if (path === '/api/stoop/auth/refresh') {
        refreshes++;
        return jsonResponse(200, { accessToken: 'fresh', refreshToken: 'ref-3' });
      }
      const headers = init.headers as Record<string, string>;
      if (headers['X-Stoop-Token'] !== 'fresh') {
        return jsonResponse(401, { error: 'invalid_token' });
      }
      return jsonResponse(200, { user: { id: 'u1' }, policyVersion: '3' });
    });

    const all = await Promise.all([stoop.me(), stoop.me(), stoop.me()]);
    expect(all.every((r) => r.user.id === 'u1')).toBe(true);
    expect(refreshes).toBe(1);
  });
});
