// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Conversations slide-over drawer (past sessions + "New chat"). Extracted
// verbatim from ChatPage to keep that page under the file-size cap.

import { useState } from 'react';
import { ChatPackageBar } from './ChatPackageBar';
import { ConfirmDialog } from './library/LibraryDialogs';

export interface SessionSummary {
  id: string;
  preview: string;
  message_count: number;
  user_message_count: number;
  date: string;
  session_name?: string;
}

function formatDate(iso: string) {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? ''
    : d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export function ConversationsDrawer({
  sessions,
  loading,
  activeSessionId,
  onLoad,
  onNew,
  onDelete,
  onClose,
  exportTitle,
  canExport,
  canImport,
  onImported,
}: {
  sessions: SessionSummary[];
  loading: boolean;
  activeSessionId: string | null;
  onLoad: (id: string) => void;
  onNew: () => void;
  onDelete: (id: string) => void | Promise<void>;
  onClose: () => void;
  exportTitle: string;
  canExport: boolean;
  canImport: boolean;
  onImported: (message: string) => void;
}) {
  const [pending, setPending] = useState<SessionSummary | null>(null);

  return (
    <div
      className="drawer-backdrop"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="sessions-drawer" onClick={(e) => e.stopPropagation()}>
        <div className="drawer-head">
          <span>Conversations</span>
          <button className="link-btn" onClick={onClose}>Close</button>
        </div>
        <button className="primary new-chat" onClick={onNew}>+ New chat</button>
        <ChatPackageBar
          title={exportTitle}
          canExport={canExport}
          canImport={canImport}
          onImported={onImported}
        />
        {loading ? (
          <div className="centered"><div className="spinner" /></div>
        ) : sessions.length === 0 ? (
          <p className="muted">No past conversations yet.</p>
        ) : (
          <ul className="conv-list">
            {sessions.map((s) => (
              <li key={s.id} className="conv-row">
                <button
                  className={`conv-item${s.id === activeSessionId ? ' active' : ''}`}
                  onClick={() => onLoad(s.id)}
                >
                  <span className="conv-preview">{s.session_name || s.preview}</span>
                  <span className="conv-meta">
                    {formatDate(s.date)} · {s.message_count} msgs
                  </span>
                </button>
                <button
                  type="button"
                  className="icon-btn conv-delete"
                  aria-label="Delete chat"
                  title="Delete chat"
                  onClick={() => setPending(s)}
                >
                  🗑
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
      {pending && (
        <ConfirmDialog
          title="Delete Chat?"
          message={`This will permanently delete this chat and all its messages.\n\n"${pending.session_name || pending.preview}"`}
          confirmLabel="Delete"
          danger
          onConfirm={() => {
            const id = pending.id;
            setPending(null);
            void onDelete(id);
          }}
          onClose={() => setPending(null)}
        />
      )}
    </div>
  );
}
