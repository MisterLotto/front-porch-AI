// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Per-message action toolbar (swipe / regenerate / continue / edit / delete /
// speak). Extracted verbatim from ChatPage to keep that page under the file-size
// cap.

import { useState } from 'react';
import { api } from '../api/client';
import { type Message } from './chatTypes';
import { SpeakButton } from './VoiceControls';
import { VariantPickerModal } from './VariantPickerModal';

export function MessageActions({
  m,
  isLast,
  busy,
  canSpeak,
  greetCount = 1,
  greetingIndex = 0,
  onSwipe,
  onRegenerate,
  onContinue,
  onEdit,
  onDelete,
  onVariantPicked,
}: {
  m: Message;
  isLast: boolean;
  busy: boolean;
  canSpeak: boolean;
  greetCount?: number;
  greetingIndex?: number;
  onSwipe: (index: number, direction: number) => void;
  onRegenerate: () => void;
  onContinue: () => void;
  onEdit: () => void;
  onDelete: () => void;
  onVariantPicked?: () => void;
}) {
  const count = m.swipeCount ?? 1;
  const idx = (m.swipeIndex ?? 0) + 1;
  const [picker, setPicker] = useState(false);
  // Generated-image messages carry no regenerable text — hide the text-gen
  // actions for them (desktop bubble parity).
  const isImage = !!m.image;
  const isGreet = !m.isUser && m.index === 0 && greetCount > 1;
  const hasSwipeVariants = !m.isUser && !isImage && count > 1;
  const canSwipe =
    !m.isUser &&
    !isImage &&
    (hasSwipeVariants || isGreet || (isLast && m.index !== 0));
  const showPicker = isGreet || hasSwipeVariants;
  const cycleGreet = (dir: number) => {
    const next = (greetingIndex + dir + greetCount) % greetCount;
    void api
      .post('/api/chat/select-variant', { messageIndex: 0, variantIndex: next })
      .then(() => onVariantPicked?.());
  };
  return (
    <div className={`msg-actions${m.isUser ? ' user' : ''}`}>
      {canSwipe && (
        <span className="swipe">
          <button className="icon-btn" title="Previous" disabled={busy}
            onClick={() => isGreet ? cycleGreet(-1) : onSwipe(m.index, -1)}>◀</button>
          <span className="swipe-count">
            {isGreet ? `${greetingIndex + 1}/${greetCount}` : `${idx}/${Math.max(count, idx)}`}
          </span>
          <button className="icon-btn" title={isGreet ? 'Next greet' : 'Next / new swipe'} disabled={busy}
            onClick={() => isGreet ? cycleGreet(1) : onSwipe(m.index, 1)}>▶</button>
        </span>
      )}
      {showPicker && (
        <button
          className="icon-btn"
          title={isGreet ? 'Select greet' : 'Select variant'}
          disabled={busy}
          onClick={() => setPicker(true)}
        >
          ☰
        </button>
      )}
      {!m.isUser && !isImage && isLast && m.index !== 0 && (
        <>
          <button className="icon-btn" title="Regenerate" disabled={busy} onClick={onRegenerate}>⟳</button>
          <button className="icon-btn" title="Continue" disabled={busy} onClick={onContinue}>⏩</button>
        </>
      )}
      {!m.isUser && !isImage && isLast && m.index === 0 && (
        <button className="icon-btn" title="Continue" disabled={busy} onClick={onContinue}>⏩</button>
      )}
      {/* When the last message is the user's (e.g. the AI reply was deleted),
          offer a Generate-reply button — same backend regenerate() call, which
          now generates a fresh response from the trailing prompt. Desktop parity
          for #85. */}
      {m.isUser && isLast && (
        <button className="icon-btn" title="Generate reply" disabled={busy} onClick={onRegenerate}>⟳</button>
      )}
      {canSpeak && !m.isUser && m.text.trim() !== '' && <SpeakButton text={m.text} />}
      <button className="icon-btn" title="Edit" disabled={busy} onClick={onEdit}>✎</button>
      <button className="icon-btn" title="Delete" disabled={busy} onClick={onDelete}>🗑</button>
      {picker && (
        <VariantPickerModal
          messageIndex={m.index}
          onClose={() => setPicker(false)}
          onPicked={() => {
            setPicker(false);
            onVariantPicked?.();
          }}
        />
      )}
    </div>
  );
}
