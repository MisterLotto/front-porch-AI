// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import { describe, expect, it } from 'vitest';
import {
  allocSeasonId,
  applyRows,
  doyFromMonthDay,
  EARTH_STARTS,
  monthDayFromDoy,
  seasonPickerIso,
  startInLongestGap,
  validateSeasonStarts,
  type BiomeDraft,
} from './seasonCalendar';

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

describe('seasonCalendar', () => {
  it('same start day is an overlap', () => {
    const errors = validateSeasonStarts({
      winter: 1,
      spring: 1,
      summer: 152,
      autumn: 244,
    });
    expect(errors.join(' ')).toMatch(/cannot overlap/);
    expect(errors.join(' ')).toMatch(/Jan 1/);
  });

  it('nine seasons cannot save', () => {
    const starts: Record<string, number> = {};
    for (let i = 1; i <= 9; i++) starts[`s${i}`] = i * 10;
    expect(validateSeasonStarts(starts).some((e) => e.includes('at most'))).toBe(
      true,
    );
  });

  it('empty starts are Earth (valid)', () => {
    expect(validateSeasonStarts({})).toEqual([]);
  });

  it('new start lands in a gap', () => {
    const d = startInLongestGap(EARTH_STARTS);
    expect(Object.values(EARTH_STARTS).includes(d)).toBe(false);
  });

  it('allocSeasonId skips taken', () => {
    expect(allocSeasonId(['s1', 'winter'])).toBe('s2');
  });

  it('Feb 29 is its own day, not Mar 1', () => {
    expect(doyFromMonthDay(2, 29)).toBe(60);
    expect(monthDayFromDoy(60)).toEqual({ month: 2, day: 29 });
    expect(doyFromMonthDay(3, 1)).toBe(61);
  });

  it('season picker ISO is this year, not 2001', () => {
    const iso = seasonPickerIso(3, 1, new Date('2026-08-20'));
    expect(iso).toBe('2026-03-01');
    expect(seasonPickerIso(2, 29, new Date('2026-08-20'))).toBe('2028-02-29');
  });

  it('applyRows omits Earth-equal starts', () => {
    const out = applyRows(temperate(), [
      { id: 'winter', label: '', month: 12, day: 1 },
      { id: 'spring', label: '', month: 3, day: 1 },
      { id: 'summer', label: 'High Sun', month: 6, day: 1 },
      { id: 'autumn', label: '', month: 9, day: 1 },
    ]);
    expect(out.seasonStarts).toBeUndefined();
    expect(out.seasonLabels).toEqual({ summer: 'High Sun' });
  });
});
