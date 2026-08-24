// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared greet / regenerated-swipe picker. One GET lists snippets; tapping a
// row POSTs select-variant and closes (commit-once).

import { useEffect, useState } from 'react';
import { api } from '../api/client';

interface VariantRow {
  index: number;
  snippet: string;
  charCount: number;
  current: boolean;
}

interface Payload {
  kind: string;
  title: string;
  currentIndex: number;
  variants: VariantRow[];
}

export function VariantPickerModal({
  messageIndex,
  onClose,
  onPicked,
}: {
  messageIndex: number;
  onClose: () => void;
  onPicked: () => void;
}) {
  const [payload, setPayload] = useState<Payload | null>(null);
  const [err, setErr] = useState('');

  useEffect(() => {
    let cancelled = false;
    api
      .get<Payload>(`/api/chat/variants?messageIndex=${messageIndex}`)
      .then((p) => {
        if (!cancelled) setPayload(p);
      })
      .catch(() => {
        if (!cancelled) setErr('Could not load variants.');
      });
    return () => {
      cancelled = true;
    };
  }, [messageIndex]);

  const pick = async (variantIndex: number) => {
    await api.post('/api/chat/select-variant', { messageIndex, variantIndex });
    onPicked();
  };

  return (
    <div className="drawer-backdrop center" onClick={onClose}>
      <div
        className="modal variant-picker-modal"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="drawer-head">
          <span>{payload?.title ?? 'Select variant'}</span>
          <button className="link-btn" onClick={onClose}>Close</button>
        </div>
        {err && <p className="muted small">{err}</p>}
        {!payload && !err && <p className="muted small">Loading…</p>}
        {payload && (
          <ul className="variant-picker-list">
            {payload.variants.map((v) => (
              <li key={v.index}>
                <button
                  type="button"
                  className={`variant-picker-row${v.current ? ' current' : ''}`}
                  onClick={() => void pick(v.index)}
                >
                  <span className="variant-picker-snippet">
                    {v.snippet || '(empty)'}
                  </span>
                  <span className="variant-picker-meta">
                    <span className="muted small">{v.charCount} characters</span>
                    {v.current && <span className="variant-current-mark">Current</span>}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
