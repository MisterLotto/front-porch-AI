// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Web mirror of the desktop ChipListEditor (lib/ui/widgets/chip_list_editor.dart).
// The approved Porch Life sketch draws Ambitions — and, next, Likes & Dislikes —
// as one short phrase per chip rather than a newline-encoded textarea, because a
// textarea asks the author to encode a list as text and then hopes they read
// "(one per line)".
//
// Kept deliberately generic (only `accent` varies the look) so Likes & Dislikes
// reuses this rather than growing a second component.

import { useState } from 'react';

export function ChipList({
  label,
  helper,
  values,
  onChange,
  placeholder = 'Type and press enter',
  maxItems = 8,
  maxChars = 80,
  accent = false,
}: {
  label: string;
  helper?: string;
  values: string[];
  onChange: (v: string[]) => void;
  placeholder?: string;
  maxItems?: number;
  maxChars?: number;
  accent?: boolean;
}) {
  const [draft, setDraft] = useState('');
  const [adding, setAdding] = useState(false);
  const full = values.length >= maxItems;

  const commit = () => {
    const raw = draft.trim();
    if (!raw) {
      setAdding(false);
      return;
    }
    // Case-insensitive dedup — two spellings of the same ambition would be
    // injected into the prompt twice.
    const exists = values.some((v) => v.toLowerCase() === raw.toLowerCase());
    if (!exists && !full) onChange([...values, raw]);
    setDraft('');
    if (values.length + 1 >= maxItems) setAdding(false);
  };

  return (
    <div className="realism-field">
      <div style={{ display: 'flex', alignItems: 'baseline' }}>
        <span className="realism-head" style={{ margin: 0 }}>{label}</span>
        {values.length > 0 && (
          <span className="chiplist-count">{values.length} of {maxItems}</span>
        )}
      </div>
      {helper && <p className="muted small" style={{ margin: '4px 0 8px' }}>{helper}</p>}
      <div className="chiplist">
        {values.map((v) => (
          <span key={v} className={`chiplist-chip${accent ? ' accent' : ''}`}>
            {v}
            <button
              type="button"
              aria-label={`Remove ${v}`}
              onClick={() => onChange(values.filter((x) => x !== v))}
            >
              ×
            </button>
          </span>
        ))}
        {adding && !full ? (
          <input
            className="chiplist-entry"
            autoFocus
            value={draft}
            maxLength={maxChars}
            placeholder={placeholder}
            onChange={(e) => setDraft(e.target.value)}
            onBlur={commit}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                commit();
              } else if (e.key === 'Escape') {
                // Abandon the half-written phrase rather than commit it.
                setDraft('');
                setAdding(false);
              }
            }}
          />
        ) : (
          !full && (
            <button type="button" className="chiplist-add" onClick={() => setAdding(true)}>
              + add
            </button>
          )
        )}
      </div>
      {full && (
        <p className="muted small" style={{ margin: '6px 0 0' }}>
          That is the most this list holds — remove one to add another.
        </p>
      )}
    </div>
  );
}
