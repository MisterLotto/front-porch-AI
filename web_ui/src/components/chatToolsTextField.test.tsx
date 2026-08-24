// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guard: the "Where we are" recap must survive a sidebar refetch. The tools
// snapshot is reloaded wholesale on every chat refresh (journal pass finishing,
// a message from another device, a socket reconnect), and the textarea used to
// be bound straight into that object — so anything typed since the last blur
// silently vanished. The draft may only be replaced when the SERVER's text
// actually changed (e.g. Regenerate wrote a new recap).

import { act } from 'react-dom/test-utils';
import { createRoot, type Root } from 'react-dom/client';
import { createElement } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../api/client', () => ({ api: { get: () => Promise.resolve({}), post: () => Promise.resolve({}) } }));

const { TextField, SummaryRecapField } = await import('./SummaryRecapField');

let container: HTMLDivElement;
let root: Root;

function render(value: string, onCommit: (v: string) => void) {
  act(() => {
    root.render(createElement(TextField, { value, rows: 4, onCommit }));
  });
}

function area(): HTMLTextAreaElement {
  return container.querySelector('textarea')!;
}

function type(text: string) {
  const el = area();
  act(() => {
    const setter = Object.getOwnPropertyDescriptor(
      HTMLTextAreaElement.prototype,
      'value',
    )!.set!;
    setter.call(el, text);
    el.dispatchEvent(new Event('input', { bubbles: true }));
  });
}

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

describe('ChatTools recap field', () => {
  it('keeps an in-progress edit when the snapshot refetches unchanged', () => {
    const commits: string[] = [];
    render('saved recap', (v) => commits.push(v));
    type('half-written new recap');
    // A chat refresh: same server text, brand-new snapshot object.
    render('saved recap', (v) => commits.push(v));
    expect(area().value).toBe('half-written new recap');
    expect(commits).toEqual([]);
  });

  it('commits the draft on blur', () => {
    const commits: string[] = [];
    render('saved recap', (v) => commits.push(v));
    type('rewritten');
    act(() => {
      // React maps onBlur onto the bubbling focusout event.
      area().dispatchEvent(new FocusEvent('focusout', { bubbles: true }));
    });
    expect(commits).toEqual(['rewritten']);
  });

  it('adopts a genuinely new server value (Regenerate)', () => {
    render('saved recap', () => {});
    type('mine');
    render('freshly generated recap', () => {});
    expect(area().value).toBe('freshly generated recap');
  });
});

function renderRecap(value: string, editing: boolean) {
  act(() => {
    root.render(
      createElement(SummaryRecapField, {
        value,
        editing,
        onCommit: () => {},
        onStartEditing: () => {},
        onStopEditing: () => {},
      }),
    );
  });
}

describe('SummaryRecapField', () => {
  it('shows formatted recap text, not a textarea, when not editing', () => {
    renderRecap('Where we left the porch light on.', false);
    expect(container.querySelector('textarea')).toBeNull();
    expect(container.textContent).toContain('porch light');
  });

  it('opens the editor when editing is true', () => {
    renderRecap('Where we left the porch light on.', true);
    expect(container.querySelector('textarea')).not.toBeNull();
    expect(area().value).toBe('Where we left the porch light on.');
  });

  it('stays in the editor when the recap is empty', () => {
    renderRecap('', false);
    expect(container.querySelector('textarea')).not.toBeNull();
  });
});
