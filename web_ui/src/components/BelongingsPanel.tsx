// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Belongings panel — web mirror of the desktop Journal's "Belongings" tab.
// Placement memories (setdown / give / outfit change) used to be buried at
// the bottom of a long diary list; this is their own surface, like Promises.

import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';

interface BelongingRow {
  id: string;
  content: string;
  pinned: boolean;
  storyDay: number | null;
  item: string | null;
}

interface BelongingsData {
  owner: string | null;
  ownerName: string | null;
  belongings: BelongingRow[];
}

export function BelongingsPanel({
  focusedId,
  reloadKey,
}: {
  focusedId?: string | null;
  reloadKey: number;
}) {
  const [data, setData] = useState<BelongingsData | null>(null);

  const load = useCallback(() => {
    const q = focusedId ? `?owner=${encodeURIComponent(focusedId)}` : '';
    api
      .get<BelongingsData>(`/api/chat/tools/belongings${q}`)
      .then(setData)
      .catch(() => setData({ owner: null, ownerName: null, belongings: [] }));
  }, [focusedId]);

  useEffect(() => {
    load();
  }, [load, reloadKey]);

  const rows = data?.belongings ?? [];
  if (data === null) return <p className="muted milestones-empty">Loading…</p>;
  if (rows.length === 0) {
    return (
      <p className="muted milestones-empty">
        No belongings notes yet. When {data?.ownerName ?? 'they'} set something
        down, hand it over, or change outfits, a short placement memory lands
        here — so &quot;where are my keys?&quot; has an answer without scrolling
        the whole diary.
      </p>
    );
  }

  return (
    <div className="belongings-panel">
      {rows.map((row) => (
        <div key={row.id} className={`belonging-row${row.pinned ? ' pinned' : ''}`}>
          <div className="belonging-text">{row.content}</div>
          <div className="muted small">
            {row.storyDay != null ? `Day ${row.storyDay}` : 'Undated'}
            {row.item ? ` · ${row.item}` : ''}
            {row.pinned ? ' · pinned' : ''}
          </div>
        </div>
      ))}
    </div>
  );
}
