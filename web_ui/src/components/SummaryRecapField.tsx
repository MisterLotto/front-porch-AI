// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// "Where we are" recap: 4-line clamp, tap to expand; Edit opens the field.
// Desktop twin: lib/ui/chat_components/sidebar/journal_memory/summary_recap_field.dart
//
// TextField keeps a half-typed draft across a tools-snapshot refetch (the
// sidebar reloads wholesale on every chat refresh). Syncing on the primitive
// text — not the object identity — means an identical refetch is a no-op.

import { useEffect, useState } from 'react';
import { ExpandableText } from './ExpandableText';

/** Free-text field that commits on blur, keeping the half-typed draft alive
 *  across a refetch. */
export function TextField({
  value,
  rows,
  placeholder,
  onCommit,
}: {
  value: string;
  rows: number;
  placeholder?: string;
  onCommit: (v: string) => void;
}) {
  const [draft, setDraft] = useState(value);
  useEffect(() => setDraft(value), [value]);
  return (
    <textarea
      className="note-input"
      rows={rows}
      value={draft}
      onChange={(e) => setDraft(e.target.value)}
      onBlur={() => draft !== value && onCommit(draft)}
      placeholder={placeholder}
    />
  );
}

/** Formatted recap view (4-line clamp) with an editor that opens on Edit.
 *  Empty recap stays in the editor so the placeholder is visible. */
export function SummaryRecapField({
  value,
  editing,
  onCommit,
  onStartEditing,
  onStopEditing,
}: {
  value: string;
  editing: boolean;
  onCommit: (text: string) => void;
  onStartEditing: () => void;
  onStopEditing: () => void;
}) {
  const showEditor = editing || !value.trim();
  if (showEditor) {
    return (
      <TextField
        value={value}
        rows={4}
        placeholder="The character's recap of where things stand…"
        onCommit={(text) => {
          onCommit(text);
          if (text.trim()) onStopEditing();
        }}
      />
    );
  }
  return (
    <div
      className="summary-recap-view"
      onDoubleClick={onStartEditing}
      title="Double-click to edit"
    >
      <ExpandableText text={value} lines={4} />
    </div>
  );
}
