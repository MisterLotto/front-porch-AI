// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// PocketAddRow payload contract — desktop dialog parity for the three
// fictions: Give (gift → carrying), Add (quiet Easter egg), Put on
// (Wearing correction, no gift, no surprise). Empty input is a no-op.

import { act } from 'react-dom/test-utils';
import { createRoot, type Root } from 'react-dom/client';
import { createElement } from 'react';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { PocketAddRow, type PocketAddFn } from './PocketAddRow';

let container: HTMLDivElement;
let root: Root;

type Call = [string, string, boolean, boolean?];

function render(onAdd: PocketAddFn) {
  act(() => {
    root.render(createElement(PocketAddRow, { onAdd }));
  });
}

function typeName(text: string) {
  const el = container.querySelector('input')!;
  act(() => {
    const setter = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype,
      'value',
    )!.set!;
    setter.call(el, text);
    el.dispatchEvent(new Event('input', { bubbles: true }));
  });
}

function setSection(value: string) {
  const el = container.querySelector('select') as HTMLSelectElement;
  act(() => {
    const setter = Object.getOwnPropertyDescriptor(
      HTMLSelectElement.prototype,
      'value',
    )!.set!;
    setter.call(el, value);
    el.dispatchEvent(new Event('change', { bubbles: true }));
  });
}

function click(label: string) {
  const btn = [...container.querySelectorAll('button')].find(
    (b) => b.textContent === label,
  );
  expect(btn, `button "${label}"`).toBeTruthy();
  act(() => {
    btn!.click();
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

describe('PocketAddRow', () => {
  it('Give still forces carrying and gift', () => {
    const calls: Call[] = [];
    render((section, name, gift, correction) => {
      calls.push([section, name, gift, correction]);
    });
    typeName('pocket watch');
    click('Give');
    expect(calls).toEqual([['carrying', 'pocket watch', true, false]]);
  });

  it('Wearing + Put on is a correction onto worn', () => {
    const calls: Call[] = [];
    render((section, name, gift, correction) => {
      calls.push([section, name, gift, correction]);
    });
    setSection('worn');
    expect(container.textContent).toContain('Put on');
    expect(container.textContent).not.toContain('Give');
    typeName('coat (buttoned)');
    click('Put on');
    expect(calls).toEqual([['worn', 'coat (buttoned)', false, true]]);
  });

  it('Wearing does not render Add; Put on is a correction', () => {
    const calls: Call[] = [];
    render((section, name, gift, correction) => {
      calls.push([section, name, gift, correction]);
    });
    setSection('worn');
    const labels = [...container.querySelectorAll('button')].map(
      (b) => b.textContent,
    );
    expect(labels).not.toContain('Add');
    expect(labels).not.toContain('Give');
    expect(labels).toEqual(['Put on']);
    typeName('Pink sundress (freshly washed)');
    click('Put on');
    expect(calls).toEqual([
      ['worn', 'Pink sundress (freshly washed)', false, true],
    ]);
  });

  it('Carrying + Add stays the quiet Easter egg', () => {
    const calls: Call[] = [];
    render((section, name, gift, correction) => {
      calls.push([section, name, gift, correction]);
    });
    typeName('brass key');
    click('Add');
    expect(calls).toEqual([['carrying', 'brass key', false, false]]);
  });

  it('empty input submits nothing', () => {
    const calls: Call[] = [];
    render((section, name, gift, correction) => {
      calls.push([section, name, gift, correction]);
    });
    click('Give');
    setSection('worn');
    click('Put on');
    expect(calls).toEqual([]);
  });
});
