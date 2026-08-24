// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act } from 'react-dom/test-utils';
import { createRoot, type Root } from 'react-dom/client';
import { createElement } from 'react';

const get = vi.fn();
const post = vi.fn();

vi.mock('../api/client', () => ({
  api: {
    get: (...args: unknown[]) => get(...args),
    post: (...args: unknown[]) => post(...args),
  },
}));

const { variantKindLabel, VariantPickerModal } = await import('./VariantPickerModal');

describe('variantKindLabel', () => {
  it('labels card greets as Greet', () => {
    expect(variantKindLabel('greet')).toBe('Greet');
  });

  it('labels regen swipes as Regen, including the old swipe kind', () => {
    expect(variantKindLabel('regen')).toBe('Regen');
    expect(variantKindLabel('swipe')).toBe('Regen');
    expect(variantKindLabel(undefined)).toBe('Regen');
  });
});

describe('VariantPickerModal cards', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
    get.mockReset();
    post.mockReset();
    post.mockResolvedValue({});
  });

  afterEach(() => {
    act(() => root.unmount());
    container.remove();
  });

  it('renders the prose card, not an HTML-comment snippet, and jump Go picks', async () => {
    get.mockResolvedValue({
      kind: 'greet',
      title: 'Select greet',
      currentIndex: 0,
      variants: [
        {
          index: 0,
          snippet: 'Elara curtsies deeply',
          text:
            '*Elara curtsies deeply — which causes her monumental presence.*',
          charCount: 1124,
          tokenCount: 281,
          current: true,
          kind: 'greet',
        },
        {
          index: 1,
          snippet: 'She is dusting the shelf',
          text: '*Elara is dusting the bookshelf when you enter.*',
          charCount: 888,
          tokenCount: 222,
          current: false,
          kind: 'greet',
        },
      ],
    });

    await act(async () => {
      root.render(
        createElement(VariantPickerModal, {
          messageIndex: 0,
          onClose: () => {},
          onPicked: () => {},
        }),
      );
    });
    await act(async () => {
      await Promise.resolve();
    });

    expect(container.textContent).toContain('Select greet');
    expect(container.textContent).toContain('Elara curtsies deeply');
    expect(container.textContent).not.toContain('<!--');
    expect(container.textContent).toContain('#1');
    expect(container.textContent).toContain('Current');
    expect(container.textContent).toContain('1124 characters');
    expect(container.querySelector('.variant-card.current')).not.toBeNull();
    expect(container.querySelector('#variant-jump-field')).not.toBeNull();

    const jump = container.querySelector('#variant-jump-field') as HTMLInputElement;
    await act(async () => {
      const setter = Object.getOwnPropertyDescriptor(
        HTMLInputElement.prototype,
        'value',
      )!.set!;
      setter.call(jump, '2');
      jump.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await act(async () => {
      (container.querySelector('.variant-jump-go') as HTMLButtonElement).click();
    });

    expect(post).toHaveBeenCalledWith('/api/chat/select-variant', {
      messageIndex: 0,
      variantIndex: 1,
    });
  });
});
