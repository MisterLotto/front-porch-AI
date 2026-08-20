// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import { act } from 'react-dom/test-utils';
import { createRoot, type Root } from 'react-dom/client';
import { createElement } from 'react';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { ClimateSeasonEditor } from './ClimateSeasonEditor';
import type { BiomeDraft } from '../lib/seasonCalendar';

const temperate = (): BiomeDraft => ({
  id: 'temperate',
  displayName: 'Temperate',
  description: '',
  weights: {
    winter: [50, 20, 12, 8, 4, 6, 0],
    spring: [50, 20, 12, 8, 4, 6, 0],
    summer: [50, 20, 12, 8, 4, 6, 0],
    autumn: [50, 20, 12, 8, 4, 6, 0],
  },
  baseTemp: { winter: 0, spring: 2, summer: 3, autumn: 2 },
});

let container: HTMLDivElement;
let root: Root;

describe('ClimateSeasonEditor start date', () => {
  beforeEach(() => {
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
  });
  afterEach(() => {
    act(() => root.unmount());
    container.remove();
  });

  it('uses a date input, not month/day dropdowns', () => {
    act(() => {
      root.render(
        createElement(ClimateSeasonEditor, {
          biome: temperate(),
          onChange: () => {},
          errors: [],
        }),
      );
    });
    expect(container.querySelectorAll('select').length).toBe(0);
    const dates = container.querySelectorAll('input[type="date"]');
    expect(dates.length).toBe(4);
    expect((dates[1] as HTMLInputElement).value.endsWith('-03-01')).toBe(true);
    expect((dates[1] as HTMLInputElement).value.startsWith('2001')).toBe(false);
    expect(container.textContent).toContain('Mar 1');
  });
});
