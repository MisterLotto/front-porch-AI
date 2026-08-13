// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AI Enhance review (web twin of the desktop enhance_review_page): old vs new
// per rewritten field — side-by-side on wide layouts, stacked on phones — with
// per-section "use this" toggles and editable new text. Apply creates the
// "<Name> (Enhanced)" duplicate via the existing duplicate endpoint, then
// writes the accepted fields with the existing partial-update endpoint.
// Discard closes without any request.

import { useEffect, useState } from 'react';
import { api, ApiError } from '../../api/client';
import { useLayout } from '../../hooks/useBreakpoint';
import {
  buildApplyBody,
  type EnhanceAccepted,
  type EnhanceEdits,
  type EnhanceProposal,
  type EnhanceSelection,
} from './enhanceForm';

interface CharDetail {
  description?: string;
  personality?: string;
  mesExample?: string;
  scenario?: string;
  firstMessage?: string;
}

export function EnhanceReviewModal({
  characterId,
  characterName,
  proposal,
  selection,
  onApplied,
  onClose,
}: {
  characterId: string;
  characterName: string;
  proposal: EnhanceProposal;
  selection: EnhanceSelection;
  onApplied: (newId: string) => void;
  onClose: () => void;
}) {
  const { wide } = useLayout();
  const [old, setOld] = useState<CharDetail | null>(null);
  const [accepted, setAccepted] = useState<EnhanceAccepted>({ ...selection });
  const [edits, setEdits] = useState<EnhanceEdits>({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    api
      .get<CharDetail>(`/api/characters/${characterId}/detail`)
      .then(setOld)
      .catch(() => setOld({}));
  }, [characterId]);

  const apply = async () => {
    if (busy) return;
    setBusy(true);
    setError('');
    try {
      const dup = await api.post<{ id: string; name: string }>(
        `/api/characters/${characterId}/duplicate`,
        { newName: `${characterName} (Enhanced)` },
      );
      await api.post(`/api/characters/${dup.id}`, buildApplyBody(proposal, accepted, edits));
      onApplied(dup.id);
    } catch (e) {
      setBusy(false);
      setError(e instanceof ApiError ? e.message : 'Could not save the enhanced character');
    }
  };

  const section = (
    key: keyof EnhanceAccepted,
    title: string,
    oldText: string | undefined,
    newText: string | undefined,
    editKey?: keyof EnhanceEdits,
  ) => {
    if (newText === undefined) return null;
    const use = accepted[key];
    return (
      <div className="enh-section" key={`${key}-${title}`}>
        <div className="enh-section-head">
          <strong>{title}</strong>
          <label className="cg-field cg-toggle enh-use">
            <input
              type="checkbox"
              checked={use}
              onChange={(e) => setAccepted({ ...accepted, [key]: e.target.checked })}
            />
            <span>Use this</span>
          </label>
        </div>
        <div className={`enh-compare${wide ? ' wide' : ''}`}>
          <div>
            <small className="muted">Before</small>
            <div className="enh-old">{oldText?.trim() ? oldText : '(empty)'}</div>
          </div>
          <div>
            <small className="muted">After (editable)</small>
            <textarea
              className="enh-new"
              disabled={!use || editKey === undefined}
              value={
                editKey !== undefined
                  ? ((edits[editKey] as string | undefined) ?? newText)
                  : newText
              }
              onChange={(e) =>
                editKey !== undefined && setEdits({ ...edits, [editKey]: e.target.value })
              }
            />
          </div>
        </div>
      </div>
    );
  };

  const loreCount = Array.isArray((proposal.lorebook as { entries?: unknown[] })?.entries)
    ? (proposal.lorebook as { entries: unknown[] }).entries.length
    : 0;

  return (
    <div className="drawer-backdrop center" onClick={busy ? undefined : onClose}>
      <div className="modal enh-modal enh-review" onClick={(e) => e.stopPropagation()}>
        <div className="drawer-head">
          <span>✨ Review: {characterName} (Enhanced)</span>
          <button className="link-btn" onClick={onClose}>
            Close
          </button>
        </div>
        <p className="muted">
          Nothing is saved yet. Untick what you don't want, tweak the text, then Save to add
          the enhanced copy to your library. Your original {characterName} stays exactly
          as-is either way.
        </p>

        {old === null && <p className="muted">Loading current card…</p>}
        {old !== null && (
          <div className="enh-sections">
            {section('description', 'Description', old.description, proposal.description, 'description')}
            {section('personality', 'Personality', old.personality, proposal.personality, 'personality')}
            {section('exampleDialogue', 'Example dialogue', old.mesExample, proposal.mesExample, 'mesExample')}
            {section('scenario', 'Scenario', old.scenario, proposal.scenario, 'scenario')}
            {section('greetings', 'First message', old.firstMessage, proposal.firstMessage, 'firstMessage')}
            {proposal.alternateGreetings?.map((g, i) => (
              <div className="enh-section" key={`alt${i}`}>
                <div className="enh-section-head">
                  <strong>Alternate greeting {i + 1}</strong>
                </div>
                <textarea
                  className="enh-new"
                  disabled={!accepted.greetings}
                  value={edits.alternateGreetings?.[i] ?? g}
                  onChange={(e) => {
                    const alts = [...(edits.alternateGreetings ?? proposal.alternateGreetings ?? [])];
                    alts[i] = e.target.value;
                    setEdits({ ...edits, alternateGreetings: alts });
                  }}
                />
              </div>
            ))}
            {selection.lorebook && loreCount > 0 && (
              <div className="enh-section">
                <div className="enh-section-head">
                  <strong>New lorebook ({loreCount} entries)</strong>
                  <label className="cg-field cg-toggle enh-use">
                    <input
                      type="checkbox"
                      checked={accepted.lorebook}
                      onChange={(e) => setAccepted({ ...accepted, lorebook: e.target.checked })}
                    />
                    <span>Use this</span>
                  </label>
                </div>
              </div>
            )}
          </div>
        )}

        {error && <p className="error">{error}</p>}
        <div className="modal-actions">
          <button className="ghost" disabled={busy} onClick={onClose}>
            Discard
          </button>
          <button className="primary" disabled={busy || old === null} onClick={apply}>
            {busy ? 'Saving…' : 'Save as New Character'}
          </button>
        </div>
      </div>
    </div>
  );
}
