// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// PWA twin of desktop season cards: rename, start day, add/remove 2–8.
// Overlap is a hard save block (same copy as desktop).

import { useMemo } from 'react';
import {
  allocSeasonId,
  applyRows,
  daysInMonth365,
  doyFromMonthDay,
  MAX_SEASONS,
  MIN_SEASONS,
  MONTH_SHORT,
  monthDayFromDoy,
  rowsFromBiome,
  startInLongestGap,
  type BiomeDraft,
  type SeasonRow,
} from '../lib/seasonCalendar';

export function ClimateSeasonEditor({
  biome,
  onChange,
  errors,
}: {
  biome: BiomeDraft;
  onChange: (next: BiomeDraft) => void;
  errors: string[];
}) {
  const rows = useMemo(() => rowsFromBiome(biome), [biome]);
  const emit = (next: SeasonRow[]) => onChange(applyRows(biome, next));
  const clash = (id: string) => errors.some((e) => e.includes(id));

  return (
    <div className="climate-season-editor">
      <div className="muted small" style={{ marginBottom: 8 }}>
        2–8 seasons. Same start twice cannot save. Leave a name blank to keep
        winter / spring / summer / autumn.
      </div>
      <div className="climate-season-grid">
        {rows.map((row) => (
          <div
            key={row.id}
            className={`climate-season-card${clash(row.id) ? ' clash' : ''}`}
          >
            <div className="climate-season-card-head">
              <input
                value={row.label}
                placeholder={
                  ['winter', 'spring', 'summer', 'autumn'].includes(row.id)
                    ? row.id[0].toUpperCase() + row.id.slice(1)
                    : 'New season'
                }
                onChange={(e) =>
                  emit(
                    rows.map((r) =>
                      r.id === row.id ? { ...r, label: e.target.value } : r,
                    ),
                  )
                }
              />
              {rows.length > MIN_SEASONS && (
                <button
                  type="button"
                  className="ghost"
                  title="Remove season"
                  onClick={() => emit(rows.filter((r) => r.id !== row.id))}
                >
                  ×
                </button>
              )}
            </div>
            <div className="climate-season-dates">
              <select
                value={row.month}
                onChange={(e) => {
                  const month = Number(e.target.value);
                  const cap = daysInMonth365(month);
                  emit(
                    rows.map((r) =>
                      r.id === row.id
                        ? { ...r, month, day: Math.min(r.day, cap) }
                        : r,
                    ),
                  );
                }}
              >
                {MONTH_SHORT.map((m, i) => (
                  <option key={m} value={i + 1}>
                    {m}
                  </option>
                ))}
              </select>
              <select
                value={row.day}
                onChange={(e) =>
                  emit(
                    rows.map((r) =>
                      r.id === row.id ? { ...r, day: Number(e.target.value) } : r,
                    ),
                  )
                }
              >
                {Array.from(
                  { length: daysInMonth365(row.month) },
                  (_, i) => i + 1,
                ).map((d) => (
                  <option key={d} value={d}>
                    {d}
                  </option>
                ))}
              </select>
            </div>
          </div>
        ))}
        {rows.length < MAX_SEASONS && (
          <button
            type="button"
            className="climate-season-add"
            onClick={() => {
              const id = allocSeasonId(rows.map((r) => r.id));
              const current = Object.fromEntries(
                rows.map((r) => [r.id, doyFromMonthDay(r.month, r.day)]),
              );
              const md = monthDayFromDoy(startInLongestGap(current));
              emit([
                ...rows,
                {
                  id,
                  label: `Season ${rows.length + 1}`,
                  month: md.month,
                  day: md.day,
                },
              ]);
            }}
          >
            + Season
          </button>
        )}
      </div>
      {errors.length > 0 && (
        <ul className="climate-season-errors">
          {errors.map((e) => (
            <li key={e}>⛔ {e}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
