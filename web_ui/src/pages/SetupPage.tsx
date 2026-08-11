// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import { useEffect, useState } from 'react';
import { api, ApiError } from '../api/client';
import { useAuth } from '../auth/AuthContext';

export function SetupPage() {
  const { refresh } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [setupToken, setSetupToken] = useState('');
  const [tokenRequired, setTokenRequired] = useState(false);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void api
      .get<{ setupTokenRequired?: boolean }>('/api/auth/state')
      .then((s) => setTokenRequired(!!s.setupTokenRequired))
      .catch(() => {});
  }, []);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (password.length < 8) return setError('Password must be at least 8 characters.');
    if (password !== confirm) return setError('Passwords do not match.');
    if (tokenRequired && !setupToken.trim()) {
      return setError(
        'Enter the one-time setup code from the desktop app (Settings → Web Server).',
      );
    }
    setBusy(true);
    try {
      await api.post('/api/auth/setup', {
        username,
        password,
        ...(setupToken.trim() ? { setupToken: setupToken.trim() } : {}),
      });
      await refresh();
    } catch (err) {
      if (err instanceof ApiError && err.payload.setupTokenRequired === true) {
        setTokenRequired(true);
      }
      setError(err instanceof ApiError ? err.message : 'Setup failed.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="auth-screen">
      <form className="card auth-card" onSubmit={submit}>
        <h1>Welcome</h1>
        <p className="muted">Create the account that secures remote access to Front Porch AI.</p>
        <label>
          Username
          <input value={username} onChange={(e) => setUsername(e.target.value)} autoFocus required />
        </label>
        <label>
          Password
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </label>
        <label>
          Confirm password
          <input type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} required />
        </label>
        {tokenRequired && (
          <label>
            Setup code
            <span className="muted"> from desktop Settings → Web Server</span>
            <input
              value={setupToken}
              onChange={(e) => setSetupToken(e.target.value)}
              autoComplete="one-time-code"
              required
            />
          </label>
        )}
        {error && <p className="error">{error}</p>}
        <button className="primary" disabled={busy}>
          {busy ? 'Creating…' : 'Create account'}
        </button>
      </form>
    </div>
  );
}
