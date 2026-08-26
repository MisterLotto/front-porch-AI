// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// In-chat Conversations drawer must expose a delete control (sibling of the
// library Chat History modal).

import { act } from 'react-dom/test-utils';
import { createRoot, type Root } from 'react-dom/client';
import { createElement } from 'react';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { ConversationsDrawer, type SessionSummary } from './ConversationsDrawer';

const session: SessionSummary = {
  id: 's1',
  preview: 'Coffee on the porch',
  message_count: 4,
  user_message_count: 2,
  date: '2026-08-21T14:05:00.000Z',
};

let container: HTMLDivElement;
let root: Root;

beforeEach(() => {
  (globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
});

afterEach(() => {
  act(() => root.unmount());
  container.remove();
});

describe('ConversationsDrawer', () => {
  it('shows a delete control per conversation', () => {
    act(() => {
      root.render(
        createElement(ConversationsDrawer, {
          sessions: [session],
          loading: false,
          activeSessionId: 's1',
          onLoad: () => {},
          onNew: () => {},
          onDelete: () => {},
          onClose: () => {},
          exportTitle: 'Misty',
          canExport: false,
          canImport: false,
          onImported: () => {},
        }),
      );
    });

    const trash = container.querySelector('button[aria-label="Delete chat"]');
    expect(trash).toBeTruthy();
  });
});
