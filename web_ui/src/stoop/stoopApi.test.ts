// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Unit tests for the Stoop browser session: token persistence in
// localStorage, the transparent refresh-and-retry on 401 (single-flight),
// session clearing when the refresh token is dead, and the error-code → human
// text mapping. Mocked fetch only — no network.

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  accessToken,
  clearStoopSession,
  hasStoopSession,
  stoop,
  StoopError,
  stoopErrorText,
} from './stoopApi';

type FetchArgs = { path: string; init: RequestInit };

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status });
}

let calls: FetchArgs[] = [];

function mockFetch(handler: (path: string, init: RequestInit) => Response | Promise<Response>) {
  vi.stubGlobal(
    'fetch',
    vi.fn(async (path: string, init: RequestInit) => {
      calls.push({ path, init });
      return handler(path, init);
    }),
  );
}

beforeEach(() => {
  localStorage.clear();
  calls = [];
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('stoop session store', () => {
  it('starts signed out', () => {
    expect(hasStoopSession()).toBe(false);
    expect(accessToken()).toBeNull();
  });

  it('persists tokens in localStorage after login and clears them on demand', async () => {
    mockFetch(() =>
      jsonResponse(200, {
        user: { id: 'u1', displayName: 'Ada' },
        accessToken: 'acc-1',
        refreshToken: 'ref-1',
        policyVersion: '3',
      }),
    );
    const r = await stoop.login('a@b.c', 'password123');
    expect(r.policyVersion).toBe('3');
    expect(localStorage.getItem('stoop_access_token')).toBe('acc-1');
    expect(localStorage.getItem('stoop_refresh_token')).toBe('ref-1');
    expect(hasStoopSession()).toBe(true);

    clearStoopSession();
    expect(hasStoopSession()).toBe(false);
  });

  it('creates a stable install id and keeps it across logout', async () => {
    mockFetch(() =>
      jsonResponse(200, {
        user: {},
        accessToken: 'a',
        refreshToken: 'r',
      }),
    );
    await stoop.login('a@b.c', 'password123');
    const id = localStorage.getItem('stoop_install_id');
    expect(id).toBeTruthy();
    const loginBody = JSON.parse(String(calls[0].init.body)) as { installId: string };
    expect(loginBody.installId).toBe(id);

    await stoop.logout();
    expect(localStorage.getItem('stoop_install_id')).toBe(id);
    expect(hasStoopSession()).toBe(false);
  });

  // Issue #160: served over plain http:// on a LAN IP the browser is in an
  // INSECURE context, where crypto.randomUUID is undefined. Login threw a
  // TypeError before the request was sent and surfaced as the generic
  // "Something went wrong". localhost is a secure context, which is exactly
  // why it never reproduced on a dev machine.
  it('signs in from an insecure context (no crypto.randomUUID)', async () => {
    // getRandomValues stays: it is NOT secure-context-gated, unlike randomUUID.
    vi.stubGlobal('crypto', {
      getRandomValues: (a: Uint8Array) => {
        for (let i = 0; i < a.length; i++) a[i] = (i * 7 + 3) & 0xff;
        return a;
      },
    });
    mockFetch(() =>
      jsonResponse(200, { user: {}, accessToken: 'a', refreshToken: 'r' }),
    );

    await expect(stoop.login('a@b.c', 'password123')).resolves.toBeTruthy();

    const id = localStorage.getItem('stoop_install_id') ?? '';
    expect(id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    const body = JSON.parse(String(calls[0].init.body)) as { installId: string };
    expect(body.installId).toBe(id);
  });

  it('still signs in with no crypto object at all (Math.random floor)', async () => {
    vi.stubGlobal('crypto', undefined);
    mockFetch(() =>
      jsonResponse(200, { user: {}, accessToken: 'a', refreshToken: 'r' }),
    );
    await expect(stoop.login('a@b.c', 'password123')).resolves.toBeTruthy();
    expect(localStorage.getItem('stoop_install_id')).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
  });
});

describe('401 refresh-and-retry', () => {
  it('refreshes once and retries the original call', async () => {
    localStorage.setItem('stoop_access_token', 'stale');
    localStorage.setItem('stoop_refresh_token', 'ref-ok');
    mockFetch((path, init) => {
      if (path === '/api/stoop/auth/refresh') {
        return jsonResponse(200, { accessToken: 'fresh', refreshToken: 'ref-2' });
      }
      const headers = init.headers as Record<string, string>;
      if (headers['X-Stoop-Token'] === 'stale') {
        return jsonResponse(401, { error: 'invalid_token' });
      }
      return jsonResponse(200, { user: { id: 'u1' }, policyVersion: '3' });
    });

    const r = await stoop.me();
    expect(r.user.id).toBe('u1');
    expect(accessToken()).toBe('fresh');
    expect(localStorage.getItem('stoop_refresh_token')).toBe('ref-2');
    // stale /me → refresh → retried /me
    expect(calls.map((c) => c.path)).toEqual([
      '/api/stoop/me',
      '/api/stoop/auth/refresh',
      '/api/stoop/me',
    ]);
  });

  it('clears the session when the refresh token is dead', async () => {
    localStorage.setItem('stoop_access_token', 'stale');
    localStorage.setItem('stoop_refresh_token', 'ref-dead');
    mockFetch((path) =>
      path === '/api/stoop/auth/refresh'
        ? jsonResponse(401, { error: 'invalid_token' })
        : jsonResponse(401, { error: 'invalid_token' }),
    );

    await expect(stoop.me()).rejects.toMatchObject({ status: 401 });
    expect(hasStoopSession()).toBe(false);
  });

  it('propagates non-401 upstream codes untouched', async () => {
    localStorage.setItem('stoop_access_token', 'ok');
    mockFetch(() => jsonResponse(429, { error: 'rate_limited' }));
    await expect(stoop.me()).rejects.toMatchObject({ status: 429, code: 'rate_limited' });
  });
});

describe('stoopErrorText', () => {
  it('maps known upstream codes to friendly text', () => {
    expect(stoopErrorText(new StoopError(401, 'invalid_credentials'))).toMatch(/email or password/i);
    expect(stoopErrorText(new StoopError(401, 'two_factor_required'))).toMatch(/two-factor/i);
    expect(stoopErrorText(new StoopError(403, 'underage'))).toMatch(/18/);
    expect(stoopErrorText(new StoopError(502, 'stoop_unreachable'))).toMatch(/unreachable/i);
  });

  it('falls back sanely for unknown errors', () => {
    expect(stoopErrorText(new Error('boom'))).toMatch(/something went wrong/i);
    expect(stoopErrorText(new StoopError(500, 'weird_code'))).toContain('weird_code');
  });
});
