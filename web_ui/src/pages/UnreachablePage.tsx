// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shown when the desktop app didn't answer at all. The service worker keeps
// this PWA loadable with the server fully off, which used to render a
// normal-looking login form that silently did nothing (Discord report
// 2026-08-04). Written for non-technical users: what happened, what to
// press, one retry button.

import { useState } from 'react';
import { useAuth } from '../auth/AuthContext';

export function UnreachablePage() {
  const { refresh } = useAuth();
  const [busy, setBusy] = useState(false);

  const retry = async () => {
    setBusy(true);
    try {
      await refresh();
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="auth-screen">
      <div className="card auth-card">
        <h1>Can’t reach Front Porch AI</h1>
        <p className="muted">
          This page opened from your device’s saved copy, but the computer
          that runs Front Porch AI isn’t answering right now.
        </p>
        <p className="muted">
          On that computer, make sure the Front Porch AI app is open and the
          web server switch is on (Settings → Advanced → Enable Web Server).
          If it’s a laptop, check it isn’t asleep. Then try again.
        </p>
        <button className="primary" onClick={() => void retry()} disabled={busy}>
          {busy ? 'Checking…' : 'Try again'}
        </button>
      </div>
    </div>
  );
}
