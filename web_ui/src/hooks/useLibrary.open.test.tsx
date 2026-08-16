// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Library card tap must leave for /chat BEFORE the select POST finishes —
// the desktop twin is navigate-first + isLoadingSession overlay.

import { act } from 'react-dom/test-utils';
import { createRoot, type Root } from 'react-dom/client';
import { MemoryRouter } from 'react-router-dom';
import { createElement, type ReactNode } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const navigated: Array<string | { pathname?: string; search?: string }> = [];
let resolvePost: ((v: unknown) => void) | null = null;

vi.mock('react-router-dom', async () => {
  const real = await vi.importActual<typeof import('react-router-dom')>('react-router-dom');
  return {
    ...real,
    useNavigate: () => (to: string) => {
      navigated.push(to);
    },
  };
});

vi.mock('../api/client', () => ({
  api: {
    get: () => Promise.resolve({ characters: [], folders: [], groups: [] }),
    post: () =>
      new Promise((resolve) => {
        resolvePost = resolve;
      }),
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

beforeEach(() => {
  (globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  navigated.length = 0;
  resolvePost = null;
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
});

describe('useLibrary open', () => {
  it('navigates to chat before the select POST resolves', async () => {
    const open = latest!.openCharacter({
      id: 'c1',
      name: 'Ann',
      tags: [],
      hasAvatar: false,
      messageCount: 1,
      folderId: '',
    });
    expect(navigated[0]).toBe('/chat?opening=1');
    expect(navigated).toHaveLength(1);
    await act(async () => {
      resolvePost?.({});
      await open;
    });
    expect(navigated[1]).toBe('/chat');
  });
});
