// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The scrolling chat transcript: per-message bubbles (with speaker labels in a
// multi-character scene, collapsible thinking blocks, inline edit, Realism/Needs
// chips, and the per-message action toolbar) plus the live streaming bubble.
// Extracted verbatim from ChatPage to keep that page under the file-size cap;
// every action is delegated to a callback so all chat state stays in ChatPage.

import { type RefObject } from 'react';
import { MessageContent } from './MessageContent';
import { ChipsRow } from './ChipsRow';
import { MessageActions } from './MessageActions';
import { type CastMember } from './CastBar';
import { type Message } from './chatTypes';

/// Truthful generation status (desktop status-bar parity): live prompt-reading
/// counts from the managed local backend + which background pass holds the
/// single local slot. Null fields = no live data (remote backend).
export type GenStatus = {
  phase: string;
  busyWith: string | null;
  promptCur: number | null;
  promptTotal: number | null;
  genCur: number | null;
  genTotal: number | null;
};

function fmtTokens(n: number): string {
  if (n >= 10000) return `${Math.round(n / 1000)}K`;
  if (n >= 1000) return `${(n / 1000).toFixed(1)}K`;
  return `${n}`;
}

/// Mirror of the desktop status-bar wording so both surfaces tell the same
/// truth about the wait.
function genStatusLabel(s: GenStatus): { label: string; fraction: number | null } {
  const hasLive = s.promptTotal != null && s.promptTotal > 0;
  const fraction = hasLive
    ? Math.min(1, (s.promptCur ?? 0) / (s.promptTotal as number))
    : null;
  if (s.busyWith) {
    const pass = s.busyWith === 'journal' ? 'journal pass' : 'growth pass';
    if (hasLive) {
      const stage =
        (s.genTotal ?? 0) > 0
          ? `writing (${s.genCur} tokens)`
          : `reading ${fmtTokens(s.promptCur ?? 0)} / ${fmtTokens(s.promptTotal as number)} tokens (${Math.round((fraction ?? 0) * 100)}%)`;
      return { label: `Waiting — ${pass} is using the model: ${stage}`, fraction };
    }
    return { label: `Waiting — ${pass} is using the model…`, fraction: null };
  }
  if (hasLive && ((s.genTotal ?? 0) === 0 || (fraction ?? 0) < 1)) {
    return {
      label: `Reading prompt — ${fmtTokens(s.promptCur ?? 0)} / ${fmtTokens(s.promptTotal as number)} tokens (${Math.round((fraction ?? 0) * 100)}%)`,
      fraction,
    };
  }
  if (hasLive) {
    // Prompt done + decode running + no streamed token yet: on the solo path
    // that decode IS our reply warming up — only busyWith marks someone
    // else's work (desktop parity, review finding).
    return {
      label: `Starting the reply — ${s.genCur} tokens written`,
      fraction: 1,
    };
  }
  if (s.phase === 'thinking') return { label: 'Model is thinking…', fraction: null };
  return { label: 'Processing prompt…', fraction: null };
}

export function ChatMessageList({
  messages,
  castById,
  multiCast,
  lastIndex,
  busy,
  streaming,
  genStatus,
  scrollRef,
  canSpeak,
  editIndex,
  editDraft,
  onEditDraftChange,
  onCancelEdit,
  onSaveEdit,
  onBeginEdit,
  onSwipe,
  onRegenerate,
  onContinue,
  onDelete,
  onReprocess,
  onRevert,
}: {
  messages: Message[];
  castById: Map<string, CastMember>;
  multiCast: boolean;
  lastIndex: number;
  busy: boolean;
  streaming: string;
  genStatus: GenStatus | null;
  scrollRef: RefObject<HTMLDivElement>;
  canSpeak: boolean;
  editIndex: number | null;
  editDraft: string;
  onEditDraftChange: (v: string) => void;
  onCancelEdit: () => void;
  onSaveEdit: () => void;
  onBeginEdit: (m: Message) => void;
  onSwipe: (index: number, direction: number) => void;
  onRegenerate: () => void;
  onContinue: () => void;
  onDelete: (index: number) => void;
  onReprocess: (index: number) => void;
  onRevert: (index: number) => void;
}) {
  return (
    <div className="chat-messages" ref={scrollRef}>
      {messages.map((m) => {
        const speaker = !m.isUser && m.characterId ? castById.get(m.characterId) : undefined;
        return (
          <div key={m.index} className="msg-row">
            {multiCast && speaker && <span className="msg-speaker">{speaker.name}</span>}
            {m.hasThinking && m.thinkingContent && (
              <details className="thinking">
                <summary>💭 Thoughts</summary>
                <div className="thinking-body">{m.thinkingContent}</div>
              </details>
            )}
            {editIndex === m.index ? (
              <div className="msg-edit">
                <textarea
                  value={editDraft}
                  onChange={(e) => onEditDraftChange(e.target.value)}
                  rows={4}
                  autoFocus
                />
                <div className="msg-edit-actions">
                  <button onClick={onCancelEdit}>Cancel</button>
                  <button className="primary" onClick={onSaveEdit}>Save</button>
                </div>
              </div>
            ) : (
              <>
                <div className={m.isUser ? 'bubble user' : 'bubble ai'}>
                  {m.image && (
                    // Generated image (from /image or the Image Studio) —
                    // native right-click gives "Save image as…" in a browser.
                    <img
                      className="chat-image"
                      src={`/api/image/saved/${encodeURIComponent(m.image)}`}
                      alt={m.imagePrompt || 'generated image'}
                      title={m.imagePrompt}
                      loading="lazy"
                    />
                  )}
                  {m.text && <MessageContent text={m.text} />}
                </div>
                {!m.isUser && m.chips && (
                  <ChipsRow
                    chips={m.chips}
                    isLast={m.index === lastIndex}
                    busy={busy}
                    onReprocess={() => onReprocess(m.index)}
                    onRevert={() => onRevert(m.index)}
                  />
                )}
                <MessageActions
                  m={m}
                  isLast={m.index === lastIndex}
                  busy={busy}
                  canSpeak={canSpeak}
                  onSwipe={onSwipe}
                  onRegenerate={onRegenerate}
                  onContinue={onContinue}
                  onEdit={() => onBeginEdit(m)}
                  onDelete={() => onDelete(m.index)}
                />
              </>
            )}
          </div>
        );
      })}
      {streaming && (() => {
        // Separate a (possibly still-open) <think> block so reasoning streams
        // into a muted "thinking…" area and the reply shows below — mirrors how
        // the finished message renders its collapsible thinking block.
        const open = streaming.indexOf('<think>');
        let thinking = '';
        let rest = streaming;
        if (open !== -1) {
          const after = streaming.slice(open + 7);
          const close = after.indexOf('</think>');
          thinking = close === -1 ? after : after.slice(0, close);
          rest = streaming.slice(0, open) + (close === -1 ? '' : after.slice(close + 8));
        }
        return (
          <div className="bubble ai streaming" aria-live="polite">
            {thinking.trim() && (
              <div className="streaming-think">
                <span className="muted small">💭 thinking…</span>
                <div className="streaming-think-body">{thinking}</div>
              </div>
            )}
            {rest && <MessageContent text={rest} />}
          </div>
        );
      })()}
      {!streaming && genStatus && (() => {
        // Before the first token arrives, name the wait truthfully instead of
        // showing nothing: real prompt-reading progress from the local
        // backend, or which background pass is holding the slot.
        const { label, fraction } = genStatusLabel(genStatus);
        return (
          <div className="bubble ai streaming gen-status" aria-live="polite">
            <span className="muted small">{label}</span>
            {fraction != null && (
              <div className="gen-status-track">
                <div
                  className="gen-status-fill"
                  style={{ width: `${Math.round(fraction * 100)}%` }}
                />
              </div>
            )}
          </div>
        );
      })()}
    </div>
  );
}
