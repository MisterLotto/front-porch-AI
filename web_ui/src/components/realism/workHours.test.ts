// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Same tables as test/services/chat/presence_derive_test.dart for the
// format/parse helpers. Desktop and web write one `hours` string.

import { describe, expect, it } from 'vitest';

import {
  DEFAULT_WORK_DAYS,
  formatWorkHoursRange,
  hhmmToMinutes,
  minutesToHHMM,
  onShift,
  parseWorkDaysField,
  parseWorkHoursRange,
  resolveWorkDays,
} from './workHours';
import { realismFromDetail } from './realismTypes';

describe('work hours clock range', () => {
  it('writes the card string the parser reads', () => {
    expect(formatWorkHoursRange(9 * 60, 17 * 60)).toBe('9am–5pm');
    expect(formatWorkHoursRange(9 * 60 + 30, 17 * 60 + 15)).toBe('9:30am–5:15pm');
    expect(parseWorkHoursRange('9am–5pm')).toEqual([9 * 60, 17 * 60]);
    expect(parseWorkHoursRange('9:30am–5:15pm')).toEqual([9 * 60 + 30, 17 * 60 + 15]);
  });

  it('rejects period words', () => {
    expect(parseWorkHoursRange('mornings')).toBeNull();
    expect(parseWorkHoursRange('whenever')).toBeNull();
    expect(parseWorkHoursRange('dawn–dusk')).toBeNull();
    expect(parseWorkHoursRange('')).toBeNull();
  });

  it('bumps a bare 9-5 into the afternoon', () => {
    expect(parseWorkHoursRange('9-5')).toEqual([9 * 60, 17 * 60]);
  });

  it('round-trips the time input', () => {
    expect(minutesToHHMM(9 * 60)).toBe('09:00');
    expect(minutesToHHMM(17 * 60 + 15)).toBe('17:15');
    expect(hhmmToMinutes('09:00')).toBe(9 * 60);
    expect(hhmmToMinutes('17:15')).toBe(17 * 60 + 15);
  });
});

describe('occupation and hours survive detail -> form -> save body', () => {
  it('carries the stored pair off the detail block', () => {
    const rv = realismFromDetail({ occupation: 'librarian', hours: '9am–5pm' });
    expect(rv.occupation).toBe('librarian');
    expect(rv.hours).toBe('9am–5pm');
  });

  it('reaches the save body through the spread the edit page uses', () => {
    const rv = realismFromDetail({ occupation: 'librarian', hours: '9am–5pm' });
    const body = { name: 'Rachel', description: 'edited', ...rv };
    expect(body.occupation).toBe('librarian');
    expect(body.hours).toBe('9am–5pm');
  });

  it('defaults to empty, never undefined', () => {
    expect(realismFromDetail(null).occupation).toBe('');
    expect(realismFromDetail(null).hours).toBe('');
  });
});

describe('occupationBrief survives detail -> form -> save body', () => {
  it('carries the engine key off the detail block', () => {
    const rv = realismFromDetail({
      occupation: 'librarian',
      occupationBrief: 'shelves returns, then reads until close',
      hours: '9am–5pm',
    });
    expect(rv.occupationBrief).toBe('shelves returns, then reads until close');
  });

  it('reaches the save body as occupationBrief, not a second key', () => {
    const rv = realismFromDetail({
      occupation: 'librarian',
      occupationBrief: 'Keeps the lamp and logs the ships',
    });
    const body = { name: 'Rachel', description: 'edited', ...rv };
    expect(body.occupationBrief).toBe('Keeps the lamp and logs the ships');
    expect(body).not.toHaveProperty('occupation_brief');
    expect(body).not.toHaveProperty('jobBrief');
  });

  it('empty brief is an empty string so today stays today', () => {
    expect(realismFromDetail(null).occupationBrief).toBe('');
    expect(realismFromDetail({ occupation: 'librarian' }).occupationBrief).toBe('');
    const body = { name: 'Rachel', ...realismFromDetail({ occupation: 'librarian' }) };
    expect(body.occupationBrief).toBe('');
  });
});

describe('workDays survive detail -> form -> save body', () => {
  it('missing key stays null, not an empty week', () => {
    const rv = realismFromDetail({ occupation: 'librarian', hours: '9am–5pm' });
    expect(rv.workDays).toBeNull();
    expect(resolveWorkDays(rv.workDays)).toEqual(DEFAULT_WORK_DAYS);
  });

  it('written [] reaches the save body as []', () => {
    const rv = realismFromDetail({
      occupation: 'clerk',
      hours: '9am–5pm',
      workDays: [],
    });
    expect(rv.workDays).toEqual([]);
    const body = { name: 'Rachel', ...rv };
    expect(body.workDays).toEqual([]);
  });

  it('a stored weekday list reaches the save body', () => {
    const rv = realismFromDetail({
      occupation: 'clerk',
      hours: '9am–5pm',
      workDays: [1, 2, 3, 4, 5, 6],
    });
    expect(rv.workDays).toEqual([1, 2, 3, 4, 5, 6]);
  });
});

describe('onShift weekday gate', () => {
  const afternoon = 14 * 60 + 30;
  it('missing days is off on Saturday', () => {
    expect(onShift({ hours: '9-5', clockMinutes: afternoon, weekday: 6 })).toBe(false);
  });
  it('missing days is on on Tuesday', () => {
    expect(onShift({ hours: '9-5', clockMinutes: afternoon, weekday: 2 })).toBe(true);
  });
  it('overnight Friday shift is on Saturday 1am', () => {
    expect(onShift({ hours: '10pm–2am', clockMinutes: 60, weekday: 6, workDays: DEFAULT_WORK_DAYS })).toBe(true);
  });
  it('Saturday-only night shift is off Saturday 1am', () => {
    expect(onShift({ hours: '10pm–2am', clockMinutes: 60, weekday: 6, workDays: [6] })).toBe(false);
  });
  it('parseWorkDaysField missing vs empty vs junk', () => {
    expect(parseWorkDaysField(undefined, false)).toBeNull();
    expect(parseWorkDaysField([], true)).toEqual([]);
    expect(parseWorkDaysField([1, 2, 99, '3'], true)).toEqual([1, 2, 3]);
    expect(parseWorkDaysField([99, 'nope'], true)).toBeNull();
  });
});

