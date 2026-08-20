// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// 365-day season starts. Match lib/services/chat/season_calendar.dart.

export const EARTH_IDS = ['winter', 'spring', 'summer', 'autumn'] as const;
export const MIN_SEASONS = 2;
export const MAX_SEASONS = 8;
export const MONTH_SHORT = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
export const DOY_BEFORE = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
export const EARTH_STARTS: Record<string, number> = {
  winter: 335,
  spring: 60,
  summer: 152,
  autumn: 244,
};

export function daysInMonth365(month: number): number {
  if (month < 1 || month > 12) return 0;
  if (month === 12) return 31;
  return DOY_BEFORE[month] - DOY_BEFORE[month - 1];
}

export function doyFromMonthDay(month: number, day: number): number {
  const cap = daysInMonth365(month);
  const d = Math.min(Math.max(day, 1), cap || 1);
  return DOY_BEFORE[month - 1] + d;
}

export function monthDayFromDoy(doy: number): { month: number; day: number } {
  const d = Math.min(Math.max(doy, 1), 365);
  for (let m = 12; m >= 1; m--) {
    if (d > DOY_BEFORE[m - 1]) return { month: m, day: d - DOY_BEFORE[m - 1] };
  }
  return { month: 1, day: 1 };
}

export function formatDoy(doy: number): string {
  const { month, day } = monthDayFromDoy(doy);
  return `${MONTH_SHORT[month - 1]} ${day}`;
}

export function validateSeasonStarts(starts: Record<string, number>): string[] {
  const keys = Object.keys(starts);
  if (keys.length === 0) return [];
  const errors: string[] = [];
  if (keys.length < MIN_SEASONS) errors.push(`need at least ${MIN_SEASONS} seasons`);
  if (keys.length > MAX_SEASONS) errors.push(`at most ${MAX_SEASONS} seasons`);
  const byDay = new Map<number, string[]>();
  for (const [id, raw] of Object.entries(starts)) {
    if (raw < 1 || raw > 365) {
      errors.push(`${id}: start must be a day of the year (1–365)`);
    }
    const list = byDay.get(raw) ?? [];
    list.push(id);
    byDay.set(raw, list);
  }
  for (const [day, ids] of byDay) {
    if (ids.length < 2) continue;
    errors.push(
      `${ids.join(' and ')} both start on ${formatDoy(day)} — seasons cannot overlap`,
    );
  }
  return errors;
}

export function startsEqualEarth(starts: Record<string, number>): boolean {
  const keys = Object.keys(starts);
  if (keys.length === 0) return true;
  if (keys.length !== 4) return false;
  return EARTH_IDS.every((s) => starts[s] === EARTH_STARTS[s]);
}

export function allocSeasonId(taken: string[]): string {
  const have = new Set(taken);
  for (let i = 1; i < 40; i++) {
    const id = `s${i}`;
    if (!have.has(id)) return id;
  }
  return `s${taken.length + 1}`;
}

export function startInLongestGap(starts: Record<string, number>): number {
  const days = Object.values(starts).sort((a, b) => a - b);
  if (days.length === 0) return 1;
  let bestLen = -1;
  let bestMid = 1;
  for (let i = 0; i < days.length; i++) {
    const a = days[i];
    const b = days[(i + 1) % days.length];
    const len = i + 1 === days.length ? 365 - a + b : b - a;
    if (len <= bestLen) continue;
    bestLen = len;
    bestMid = ((a - 1 + Math.floor(len / 2)) % 365) + 1;
  }
  let d = bestMid;
  for (let n = 0; n < 365; n++) {
    if (!days.includes(d)) return d;
    d = (d % 365) + 1;
  }
  return 1;
}

export type BiomeDraft = {
  id: string;
  displayName: string;
  description: string;
  weights: Record<string, number[]>;
  baseTemp: Record<string, number>;
  diurnalAmplitude?: number;
  seasonLabels?: Record<string, string>;
  seasonStarts?: Record<string, number>;
  [key: string]: unknown;
};

export type SeasonRow = {
  id: string;
  label: string;
  month: number;
  day: number;
};

export function rowsFromBiome(biome: BiomeDraft): SeasonRow[] {
  const starts = biome.seasonStarts && Object.keys(biome.seasonStarts).length
    ? biome.seasonStarts
    : EARTH_STARTS;
  const ids = Object.keys(starts).length
    ? Object.keys(starts)
    : [...EARTH_IDS];
  const labels = biome.seasonLabels ?? {};
  return ids.map((id) => {
    const md = monthDayFromDoy(starts[id] ?? EARTH_STARTS[id] ?? 1);
    return { id, label: labels[id] ?? '', month: md.month, day: md.day };
  });
}

export function applyRows(biome: BiomeDraft, rows: SeasonRow[]): BiomeDraft {
  const seasonLabels: Record<string, string> = {};
  const seasonStarts: Record<string, number> = {};
  const weights = { ...biome.weights };
  const baseTemp = { ...biome.baseTemp };
  const keep = new Set(rows.map((r) => r.id));
  for (const key of Object.keys(weights)) {
    if (!keep.has(key)) delete weights[key];
  }
  for (const key of Object.keys(baseTemp)) {
    if (!keep.has(key)) delete baseTemp[key];
  }
  const srcId = keep.has('summer')
    ? 'summer'
    : (rows[0]?.id ?? 'summer');
  const srcW = weights[srcId] ?? biome.weights['summer'] ?? [50, 20, 12, 8, 4, 6, 0];
  const srcT = baseTemp[srcId] ?? biome.baseTemp['summer'] ?? 3;
  for (const r of rows) {
    seasonStarts[r.id] = doyFromMonthDay(r.month, r.day);
    if (r.label.trim()) seasonLabels[r.id] = r.label.trim();
    if (!weights[r.id]) weights[r.id] = [...srcW];
    if (baseTemp[r.id] === undefined) baseTemp[r.id] = srcT;
  }
  const out: BiomeDraft = {
    ...biome,
    id: 'custom',
    weights,
    baseTemp,
  };
  if (Object.keys(seasonLabels).length) out.seasonLabels = seasonLabels;
  else delete out.seasonLabels;
  if (startsEqualEarth(seasonStarts)) delete out.seasonStarts;
  else out.seasonStarts = seasonStarts;
  return out;
}
