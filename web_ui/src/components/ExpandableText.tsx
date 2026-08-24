// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Sidebar body text: fixed line-clamp, tap to expand. Matches the desktop
// ExpandableSidebarText so Journal / recap / RAG receipts are not truncated
// to a single ellipsis line when the panel has room.

import { useState } from 'react';

export function ExpandableText({
  text,
  lines = 4,
  className,
}: {
  text: string;
  lines?: number;
  className?: string;
}) {
  const [open, setOpen] = useState(false);
  if (!text) return null;
  return (
    <div
      className={`expandable-text${open ? ' open' : ''}${className ? ` ${className}` : ''}`}
      style={open ? undefined : { WebkitLineClamp: lines, lineClamp: lines }}
      onClick={() => setOpen((v) => !v)}
      title={open ? 'Tap to collapse' : 'Tap to expand'}
    >
      {text}
    </div>
  );
}
