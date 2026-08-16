// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Journal review-first modal — GrowthReviewModal twin (audit P2.12).
// Parked proposals + optional recap; Apply uses the same applier autonomous
// mode uses; Discard writes nothing (cursor still advances).

import { useEffect, useState } from 'react';
import { api, ApiError } from '../api/client';

interface ReviewOp {
  action: 'add' | 'revise' | 'retire' | 'pin';
  text: string;
  oldContent: string;
  category: string;
  feeling: string;
}
interface ReviewBatch {
  pending: boolean;
  recap?: string | null;
  recapAccepted?: boolean;
  owners: Array<{ ownerName: string; ops: ReviewOp[] }>;
}

const ACTION_LABEL: Record<ReviewOp['action'], string> = {
  add: 'New memory',
  revise: 'Reworded',
  retire: 'Retire',
  pin: 'Pin',
};

function opBody(op: ReviewOp): string {
  switch (op.action) {
    case 'add':
      return op.text;
    case 'revise':
      return op.oldContent
        ? `${op.oldContent} → ${op.text}`
        : op.text;
    case 'retire':
      return op.oldContent || op.text;
    case 'pin':
      return op.oldContent || op.text;
  }
}

export function JournalReviewModal({ onClose }: { onClose: () => void }) {
  const [batch, setBatch] = useState<ReviewBatch | null>(null);
  const [rejected, setRejected] = useState<Set<string>>(new Set());
  const [recapOn, setRecapOn] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    api
      .get<ReviewBatch>('/api/chat/tools/journal/review')
      .then((b) => {
        setBatch(b);
        setRecapOn(b.recapAccepted !== false);
      })
      .catch((e) => setError(e instanceof ApiError ? e.message : 'Failed to load review'));
  }, []);

  const toggle = (key: string) =>
    setRejected((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });

  const settle = async (apply: boolean) => {
    setBusy(true);
    setError('');
    try {
      await api.post('/api/chat/tools/journal/review', {
        apply,
        rejected: [...rejected],
        recapAccepted: recapOn,
      });
      onClose();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Failed to apply');
      setBusy(false);
    }
  };

  return (
    <div className="drawer-backdrop center" onClick={() => !busy && onClose()}>
      <div className="modal growth-review-modal" onClick={(e) => e.stopPropagation()}>
        <div className="drawer-head">
          <span>📖 Journal to review</span>
          <button className="link-btn" onClick={onClose} disabled={busy}>Close</button>
        </div>
        {!batch && !error && <div className="centered"><div className="spinner" /></div>}
        {batch && !batch.pending && (
          <p className="muted small">Nothing waiting — it was settled elsewhere.</p>
        )}
        {batch?.pending && (
          <>
            <p className="muted small">Uncheck anything that doesn&apos;t ring true, then apply.</p>
            <div className="growth-review-list">
              {batch.owners.map((owner, o) => (
                <div key={o}>
                  {batch.owners.length > 1 && (
                    <div className="growth-review-owner">{owner.ownerName}&apos;s journal</div>
                  )}
                  {owner.ops.map((op, i) => {
                    const key = `${o}:${i}`;
                    const checked = !rejected.has(key);
                    return (
                      <label key={key} className={`growth-proposal${checked ? '' : ' off'}`}>
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={() => toggle(key)}
                        />
                        <span>
                          <span className={`growth-chip act-${op.action}`}>{ACTION_LABEL[op.action]}</span>
                          <span className={op.action === 'retire' ? 'struck' : ''}> {opBody(op)}</span>
                        </span>
                      </label>
                    );
                  })}
                </div>
              ))}
              {batch.recap != null && batch.recap !== '' && (
                <label className={`growth-proposal${recapOn ? '' : ' off'}`}>
                  <input
                    type="checkbox"
                    checked={recapOn}
                    onChange={() => setRecapOn((v) => !v)}
                  />
                  <span>
                    <span className="growth-chip act-add">Recap</span>
                    <span> {batch.recap}</span>
                  </span>
                </label>
              )}
            </div>
            {error && <p className="error">{error}</p>}
            <div className="modal-actions">
              <button className="danger" onClick={() => settle(false)} disabled={busy}>Discard all</button>
              <button className="primary" onClick={() => settle(true)} disabled={busy}>
                {busy ? 'Applying…' : 'Apply selected'}
              </button>
            </div>
          </>
        )}
        {error && !batch && <p className="error">{error}</p>}
      </div>
    </div>
  );
}
