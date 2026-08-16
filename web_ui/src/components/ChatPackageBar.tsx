// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Web twin of desktop Import / Export Chat (folder menu). Conversations
// drawer on both desktop and phone — same two lanes: Full Front Porch
// (.fpchat) and Transcript (JSONL). The host decodes the file.

import { useRef, useState } from 'react';
import { api, ApiError } from '../api/client';
import { downloadBlob } from '../pages/story/storyUtil';
import {
  chatExportFilename,
  importResultMessage,
  type ImportOutcome,
} from './chatPackage';

type Mismatch = { file: File; packageName: string; activeName: string };

export function ChatPackageBar({
  title,
  canExport,
  canImport,
  onImported,
}: {
  title: string;
  canExport: boolean;
  canImport: boolean;
  onImported: (message: string) => void;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [exportOpen, setExportOpen] = useState(false);
  const [mismatch, setMismatch] = useState<Mismatch | null>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');

  const exportChat = async (lane: 'fpchat' | 'jsonl') => {
    setBusy(true);
    setErr('');
    setMsg('');
    try {
      const blob = await api.getForBlob(`/api/chat/export.${lane}`);
      downloadBlob(blob, chatExportFilename(title, lane));
      setMsg(lane === 'fpchat' ? 'Full Front Porch chat exported' : 'Transcript exported');
      setExportOpen(false);
    } catch (e) {
      setErr(e instanceof ApiError ? e.message : 'Export failed');
    } finally {
      setBusy(false);
    }
  };

  const upload = async (file: File, mismatchChoice?: 'full' | 'dialogue') => {
    setBusy(true);
    setErr('');
    setMsg('');
    // 409 then Full/Dialogue re-posts the same File (browser still has it).
    const q = mismatchChoice ? `?mismatch=${mismatchChoice}` : '';
    try {
      const r = await api.upload<ImportOutcome>(`/api/chat/import${q}`, file);
      setMismatch(null);
      onImported(importResultMessage(r));
    } catch (e) {
      if (e instanceof ApiError && e.status === 409 && e.message === 'character_mismatch') {
        setMismatch({
          file,
          packageName: String(e.payload.packageName ?? 'that character'),
          activeName: String(e.payload.activeName ?? 'this card'),
        });
      } else {
        setErr(e instanceof ApiError ? e.message : 'Import failed');
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="chat-package-bar">
      <div className="chat-package-actions">
        <button
          type="button"
          className="ghost"
          disabled={busy || !canImport}
          title={
            canImport
              ? 'Import a chat file'
              : 'Wait until the current reply finishes, then import'
          }
          onClick={() => fileRef.current?.click()}
        >
          Import
        </button>
        <button
          type="button"
          className="ghost"
          disabled={busy || !canExport}
          onClick={() => setExportOpen(true)}
        >
          Export
        </button>
      </div>
      <input
        ref={fileRef}
        type="file"
        accept=".fpchat,.json,.jsonl,application/json"
        hidden
        onChange={(e) => {
          const f = e.target.files?.[0];
          e.target.value = '';
          if (f) void upload(f);
        }}
      />
      {msg && <p className="muted small">{msg}</p>}
      {err && <p className="error">{err}</p>}

      {exportOpen && (
        <div className="drawer-backdrop center" onClick={() => !busy && setExportOpen(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h3>Export Chat</h3>
            <p>
              Full Front Porch keeps Realism, Needs, swipes, journal, Growth,
              and objectives so you can reimport and fork mid-history.
            </p>
            <p>
              Transcript is SillyTavern JSONL (dialogue only) for other apps.
            </p>
            <div className="modal-actions">
              <button type="button" className="ghost" disabled={busy} onClick={() => void exportChat('jsonl')}>
                Transcript (JSONL)
              </button>
              <button type="button" className="primary" disabled={busy} onClick={() => void exportChat('fpchat')}>
                Full Front Porch
              </button>
            </div>
          </div>
        </div>
      )}

      {mismatch && (
        <div className="drawer-backdrop center" onClick={() => !busy && setMismatch(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h3>Different character</h3>
            <p>
              This chat was exported for “{mismatch.packageName}”, but the open
              card is “{mismatch.activeName}”.
            </p>
            <p>Restore full Front Porch state anyway, or import dialogue only?</p>
            <div className="modal-actions">
              <button
                type="button"
                className="ghost"
                disabled={busy}
                onClick={() => void upload(mismatch.file, 'dialogue')}
              >
                Dialogue only
              </button>
              <button
                type="button"
                className="primary"
                disabled={busy}
                onClick={() => void upload(mismatch.file, 'full')}
              >
                Full restore
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
