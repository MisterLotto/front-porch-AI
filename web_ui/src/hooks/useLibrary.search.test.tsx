// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards the library search fetch: (1) typing a word costs ONE request, not
// one per letter, and (2) a slow earlier response can never overwrite a newer
// one. Both used to be unguarded — over a slow uplink the broad "a" body kept
// transferring after the narrow "ann" body had arrived, so the grid settled on
// results for a query the user had already moved past, with the spinner
// already cleared.

import { act } from 'react-dom/test-utils';
import { createRoot, type Root } from 'react-dom/client';
import { MemoryRouter } from 'react-router-dom';
import { createElement, type ReactNode } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

type Pending = { path: string; resolve: (v: unknown) => void };
const pending: Pending[] = [];

vi.mock('../api/client', () => ({
  api: {
    get: (path: string) =>
      new Promise((resolve) => {
        pending.push({ path, resolve });
      }),
    post: () => Promise.resolve({}),
  },
  ApiError: class ApiError extends Error {},
}));

vi.mock('../api/ws', () => ({
  ChatSocket: class {
    connect() {}
    close() {}
  },
}));

const { useLibrary } = await import('./useLibrary');

type Lib = ReturnType<typeof useLibrary>;
let latest: Lib | null = null;

function Probe() {
  latest = useLibrary();
  return null;
}

function wrap(children: ReactNode) {
  return createElement(MemoryRouter, null, children);
}

let container: HTMLDivElement;
let root: Root;

/** Requests for the character list only (folders/groups load once on mount). */
function charRequests() {
  return pending.filter((p) => p.path.startsWith('/api/characters'));
}

/** The most recent character-list request (tsconfig lib predates Array.at). */
function lastCharRequest(): Pending {
  const all = charRequests();
  return all[all.length - 1];
}

beforeEach(() => {
  vi.useFakeTimers();
  (globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  pending.length = 0;
  latest = null;
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
  act(() => {
    root.render(wrap(createElement(Probe)));
  });
});

afterEach(() => {
  act(() => root.unmount());
  container.remove();
  vi.useRealTimers();
});

describe('useLibrary search', () => {
  it('debounces keystrokes into a single request', () => {
    const before = charRequests().length;
    act(() => latest!.setSearch('a'));
    act(() => latest!.setSearch('an'));
    act(() => latest!.setSearch('ann'));
    expect(charRequests().length).toBe(before); // nothing fired yet
    act(() => {
      vi.advanceTimersByTime(300);
    });
    const fired = charRequests().slice(before);
    expect(fired.length).toBe(1);
    expect(fired[0].path).toContain('search=ann');
  });

  it('ignores a stale response that lands after a newer one', async () => {
    act(() => latest!.setSearch('a'));
    act(() => {
      vi.advanceTimersByTime(300);
    });
    const broad = lastCharRequest();
    expect(broad.path).toContain('search=a');

    act(() => latest!.setSearch('ann'));
    act(() => {
      vi.advanceTimersByTime(300);
    });
    const narrow = lastCharRequest();
    expect(narrow.path).toContain('search=ann');

    // The narrow (current) answer arrives first…
    await act(async () => {
      narrow.resolve([{ id: 'ann', name: 'Ann', tags: [], hasAvatar: false, messageCount: 0, folderId: '' }]);
    });
    expect(latest!.chars.map((c) => c.id)).toEqual(['ann']);
    expect(latest!.loading).toBe(false);

    // …then the abandoned broad one finally lands. It must change nothing.
    await act(async () => {
      broad.resolve([
        { id: 'ann', name: 'Ann', tags: [], hasAvatar: false, messageCount: 0, folderId: '' },
        { id: 'alice', name: 'Alice', tags: [], hasAvatar: false, messageCount: 0, folderId: '' },
      ]);
    });
    expect(latest!.chars.map((c) => c.id)).toEqual(['ann']);
  });
});
