// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Web mirror of parseWorkHoursRange / formatWorkHoursRange in
// lib/services/chat/presence_derive.dart. Desktop pickers and these <input
// type="time"> controls write the same card `hours` string so At work lights
// for the same range on both sides. Period words are not hours.

const RANGE_RE =
  /(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?\s*(?:[-–—]|\s+to\s+)\s*(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?/;

export const DEFAULT_START_MIN = 9 * 60;
export const DEFAULT_END_MIN = 17 * 60;

function toMinutes(h: number | null, minuteStr: string | undefined, ampm: string | undefined): number | null {
  if (h == null || h < 0 || h > 24) return null;
  if (h === 24) {
    if (minuteStr != null && minuteStr !== '00') return null;
    return 0;
  }
  const minute = minuteStr == null || minuteStr === '' ? 0 : Number.parseInt(minuteStr, 10);
  if (!Number.isFinite(minute) || minute < 0 || minute > 59) return null;
  let hour = h;
  if (ampm != null) {
    const pm = ampm.startsWith('p');
    if (h === 12) hour = pm ? 12 : 0;
    else if (h > 12) return null;
    else hour = pm ? h + 12 : h;
  } else if (h > 23) {
    return null;
  }
  return hour * 60 + minute;
}

function fmtMin(minutes: number): string {
  const clamped = ((minutes % 1440) + 1440) % 1440;
  const h = Math.floor(clamped / 60);
  const m = clamped % 60;
  const h12 = h % 12 === 0 ? 12 : h % 12;
  const suffix = h < 12 ? 'am' : 'pm';
  if (m === 0) return `${h12}${suffix}`;
  return `${h12}:${String(m).padStart(2, '0')}${suffix}`;
}

/** Start/end as minutes from midnight. Null for empty or period words. */
export function parseWorkHoursRange(hours: string): [number, number] | null {
  const h = hours.toLowerCase().trim();
  if (!h) return null;
  const m = RANGE_RE.exec(h);
  if (!m) return null;
  const start = toMinutes(m[1] ? Number.parseInt(m[1], 10) : null, m[2], m[3]);
  const end = toMinutes(m[4] ? Number.parseInt(m[4], 10) : null, m[5], m[6]);
  if (start == null || end == null) return null;
  let s = start;
  let e = end;
  if (m[3] == null && m[6] == null && e <= s && Math.floor(e / 60) <= 12 && Math.floor(s / 60) <= 12) {
    e += 12 * 60;
  }
  return [s, e];
}

/** Card `hours` from two minute-of-day values: "9am–5pm" / "9:30am–5:15pm". */
export function formatWorkHoursRange(startMin: number, endMin: number): string {
  return `${fmtMin(startMin)}–${fmtMin(endMin)}`;
}

export function minutesToHHMM(min: number): string {
  const clamped = ((min % 1440) + 1440) % 1440;
  const h = Math.floor(clamped / 60);
  const m = clamped % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

export function hhmmToMinutes(hhmm: string): number | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm.trim());
  if (!m) return null;
  const h = Number.parseInt(m[1], 10);
  const min = Number.parseInt(m[2], 10);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/** DateTime.weekday values (1=Mon … 7=Sun). Missing card field resolves here. */
export const DEFAULT_WORK_DAYS = [1, 2, 3, 4, 5];

export const WORK_DAY_LETTERS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

export function sanitizeWorkDays(raw: unknown[]): number[] {
  const days = new Set<number>();
  for (const e of raw) {
    const n = typeof e === 'number' ? e : typeof e === 'string' ? Number.parseInt(e.trim(), 10) : NaN;
    if (Number.isInteger(n) && n >= 1 && n <= 7) days.add(n);
  }
  return [...days].sort((a, b) => a - b);
}

/** Missing/null → Mon–Fri. Written [] stays empty (never at work). */
export function resolveWorkDays(workDays: number[] | null | undefined): number[] {
  if (workDays == null) return [...DEFAULT_WORK_DAYS];
  return sanitizeWorkDays(workDays);
}

/** Card JSON: key missing → null. `[]` → never at work. All junk → null. */
export function parseWorkDaysField(raw: unknown, present: boolean): number[] | null {
  if (!present) return null;
  if (!Array.isArray(raw)) return null;
  if (raw.length === 0) return [];
  const out = sanitizeWorkDays(raw);
  return out.length === 0 ? null : out;
}

function minutesInRange(minutes: number, start: number, end: number): boolean {
  if (start === end) return minutes === start;
  if (start < end) return minutes >= start && minutes < end;
  return minutes >= start || minutes < end;
}

/** Hours plus weekday. Overnight after midnight belongs to yesterday. */
export function onShift(opts: {
  hours: string;
  clockMinutes: number;
  weekday: number;
  workDays?: number[] | null;
}): boolean {
  const range = parseWorkHoursRange(opts.hours);
  if (!range) return false;
  const days = resolveWorkDays(opts.workDays);
  if (days.length === 0) return false;
  const [start, end] = range;
  const overnightEarly = start > end && opts.clockMinutes < end;
  const day = overnightEarly ? (opts.weekday === 1 ? 7 : opts.weekday - 1) : opts.weekday;
  return days.includes(day) && minutesInRange(opts.clockMinutes, start, end);
}
