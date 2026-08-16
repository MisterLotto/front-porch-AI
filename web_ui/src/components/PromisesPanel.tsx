// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Promises panel — web mirror of the desktop Journal's "Promises" tab
// (maintainer request 2026-08-04: promise cards were buried among the memory
// cards). Open commitments first with manual Kept/Broken resolution — the
// escape hatch when the automatic detection misses a fulfillment. Resolution
// routes through the same server-side applier as automatic detection, so the
// trust/bond effects apply identically. Group-aware: scoped to the focused
// participant like GrowthPanel/MilestonesPanel.

import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';

interface PromiseRow {
  id: string;
  text: string;
  party: 'user' | 'char' | string;
  status: 'open' | 'kept' | 'broken' | string;
}
interface PromisesData {
  owner: string | null;
  ownerName: string | null;
  promises: PromiseRow[];
}

const STATUS_BADGE: Record<string, string> = {
  open: '⏳ Open',
  kept: '✅ Kept',
  broken: '💔 Broken',
};

export function PromisesPanel({
  focusedId,
  reloadKey,
}: {
  focusedId?: string | null;
  reloadKey: number;
}) {
  const [data, setData] = useState<PromisesData | null>(null);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<string | null>(null);

  const load = useCallback(() => {
    const q = focusedId ? `?owner=${encodeURIComponent(focusedId)}` : '';
    api
      .get<PromisesData>(`/api/chat/tools/promises${q}`)
      .then(setData)
      .catch(() => setData({ owner: null, ownerName: null, promises: [] }));
  }, [focusedId]);

  useEffect(() => {
    load();
  }, [load, reloadKey]);

  const resolve = async (row: PromiseRow, kept: boolean) => {
    setBusy(true);
    setNote(null);
    try {
      const r = await api.post<{ ok: boolean }>('/api/chat/tools/promise-resolve', {
        owner: data?.owner,
        cardId: row.id,
        kept,
      });
      setNote(
        r.ok
          ? kept
            ? 'Marked kept — trust and bond updated.'
            : 'Marked broken — trust and bond updated.'
          : 'Couldn’t resolve it right now — wait for the current reply to finish, then try again.',
      );
      if (r.ok) load();
    } catch {
      setNote('Couldn’t reach the app — try again.');
    } finally {
      setBusy(false);
    }
  };

  const rows = data?.promises ?? [];
  if (data === null) return <p className="muted milestones-empty">Loading…</p>;
  if (rows.length === 0) {
    return (
      <p className="muted milestones-empty">
        No promises yet. When someone gives their word in this chat, it lands
        here — and you can mark it kept or broken yourself if the app misses
        the moment.
      </p>
    );
  }

  return (
    <div className="promises-panel">
      {rows.map((row) => (
        <div key={row.id} className={`promise-row promise-${row.status}`}>
          <div className="promise-head">
            <span className={`promise-badge promise-badge-${row.status}`}>
              {STATUS_BADGE[row.status] ?? row.status}
            </span>
            <span className="muted small">
              {row.party === 'user' ? 'Your word' : `${data?.ownerName ?? 'Their'}’s word`}
            </span>
          </div>
          <div className="promise-text">{row.text}</div>
          {row.status === 'open' && (
            <div className="promise-actions">
              <button disabled={busy} onClick={() => void resolve(row, true)}>
                Mark kept
              </button>
              <button disabled={busy} onClick={() => void resolve(row, false)}>
                Mark broken
              </button>
            </div>
          )}
        </div>
      ))}
      {note && <p className="muted milestones-empty">{note}</p>}
    </div>
  );
}
