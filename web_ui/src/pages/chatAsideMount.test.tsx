// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guard: the insight sidebar must not be MOUNTED where CSS hides it.
// `.chat-aside` is `display:none` below 1024px, but display:none does not
// unmount — so on a phone/tablet every chat refresh still fired the sidebar's
// own GETs (chat tools, and with the Stats drawer open, twice over) for a panel
// nobody could see. On the maintainer's Starlink/Tailscale link that is pure
// wasted round-trips per turn.

import { act } from 'react-dom/test-utils';
import { createRoot, type Root } from 'react-dom/client';
import { MemoryRouter } from 'react-router-dom';
import { createElement, type ReactNode } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const gets: string[] = [];

vi.mock('../api/client', () => ({
  api: {
    // `/api/chat/state` resolves so the page renders; everything else parks,
    // which is enough — we only care that the request was ISSUED.
    get: (path: string) => {
      gets.push(path);
      if (path === '/api/chat/state') return Promise.resolve(chatState);
      return new Promise(() => {});
    },
    post: () => new Promise(() => {}),
    upload: () => new Promise(() => {}),
  },
  ApiError: class ApiError extends Error {},
}));

vi.mock('../api/ws', () => ({
  ChatSocket: class {
    connect() {}
    close() {}
  },
}));

// `setAuthenticated` must keep a STABLE identity, exactly as the real
// useState setter does — `refresh` is a useCallback over it, and a fresh
// function each render would re-run the socket effect forever.
const auth = { setAuthenticated: () => {} };
vi.mock('../auth/AuthContext', () => ({ useAuth: () => auth }));

const chatState = {
  character: { name: 'Ann', id: 'c1' },
  sessionId: 's1',
  messages: [],
  isGenerating: false,
  cast: [{ id: 'c1', dbId: 'c1', name: 'Ann', isHost: true, realismEnabled: true }],
  realism: {
    realismEnabled: true,
    bond: { score: 0, tier: 'Acquaintance', percent: 0 },
    longTerm: { score: 0, tier: 'Acquaintance', percent: 0 },
    trust: { level: 0, tier: 'Wary', percent: 0 },
    emotion: 'neutral',
    emotionIntensity: 'mild',
    mood: 'neutral',
    arousal: { level: 0, tier: 'calm' },
    fixation: '',
    needsEnabled: false,
    needs: {},
  },
};

const { ChatPage } = await import('./ChatPage');

function wrap(children: ReactNode) {
  return createElement(MemoryRouter, null, children);
}

let container: HTMLDivElement;
let root: Root;

async function renderAt(width: number) {
  (window as { innerWidth: number }).innerWidth = width;
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
  act(() => {
    root.render(wrap(createElement(ChatPage)));
  });
  // Let the resolved /api/chat/state land and the tree re-render.
  await act(async () => {
    await Promise.resolve();
  });
}

/** The sidebar's own snapshot fetch — present only when it is mounted. */
function sidebarGets() {
  return gets.filter((p) => p.startsWith('/api/chat/tools'));
}

beforeEach(() => {
  (globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  // jsdom has no Element.scrollTo; the transcript auto-scroll effect calls it.
  (Element.prototype as unknown as { scrollTo: () => void }).scrollTo = () => {};
  gets.length = 0;
});

afterEach(() => {
  act(() => root.unmount());
  container.remove();
});

describe('ChatPage insight column mounting', () => {
  it('does not mount (or fetch for) the hidden sidebar on a phone', async () => {
    await renderAt(430);
    expect(container.querySelector('.chat-aside')).toBeNull();
    expect(sidebarGets()).toEqual([]);
  });

  it('does not mount it on a tablet either — CSS hides it below 1024', async () => {
    await renderAt(820);
    expect(container.querySelector('.chat-aside')).toBeNull();
    expect(sidebarGets()).toEqual([]);
  });

  it('mounts it on desktop, where it is the only insight surface', async () => {
    await renderAt(1280);
    expect(container.querySelector('.chat-aside')).not.toBeNull();
    expect(sidebarGets().length).toBeGreaterThan(0);
  });
});
