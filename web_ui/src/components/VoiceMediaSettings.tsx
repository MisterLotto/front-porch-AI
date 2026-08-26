// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Voice & Media enable toggles for the web Settings page. Desktop Voice &
// Media lives on the host; a phone/remote user still needs to turn TTS and
// STT on (audit P2.12). Engine pick / voice download stay on desktop.

import { useEffect, useState } from 'react';
import { api } from '../api/client';

interface VoiceStatus {
  ttsEnabled: boolean;
  sttEnabled?: boolean;
  sttAvailable: boolean;
  ttsEngine?: string;
  globalVoice?: string;
}

export function VoiceMediaSettings() {
  const [v, setV] = useState<VoiceStatus | null>(null);
  const [saving, setSaving] = useState(false);

  const load = () =>
    api.get<VoiceStatus>('/api/voice/status').then(setV).catch(() => {});

  useEffect(() => {
    void load();
  }, []);

  if (!v) return null;

  const patch = async (p: Partial<VoiceStatus>) => {
    setSaving(true);
    try {
      const next = await api.post<VoiceStatus>('/api/voice/settings', p);
      setV(next);
    } catch {
      /* keep last known */
    } finally {
      setSaving(false);
    }
  };

  return (
    <section className="card">
      <h3>Voice &amp; Media</h3>
      <p className="muted small">
        Turn spoken replies and the microphone on for this computer. Pick the
        engine and voice on the desktop app — this page only enables them.
      </p>
      <label className="row-label">
        <span>Enable text-to-speech</span>
        <input
          type="checkbox"
          checked={v.ttsEnabled}
          disabled={saving}
          onChange={(e) => void patch({ ttsEnabled: e.target.checked })}
        />
      </label>
      <label className="row-label">
        <span>Enable speech-to-text</span>
        <input
          type="checkbox"
          checked={!!v.sttEnabled}
          disabled={saving}
          onChange={(e) => void patch({ sttEnabled: e.target.checked })}
        />
      </label>
      {!v.sttAvailable && v.sttEnabled && (
        <p className="muted small">
          Speech-to-text is on, but the host has not finished loading a
          recogniser yet. Try the mic again in a moment.
        </p>
      )}
    </section>
  );
}
