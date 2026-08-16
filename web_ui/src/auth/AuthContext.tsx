// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { api, ApiError } from '../api/client';

interface AuthState {
  loading: boolean;
  setupRequired: boolean;
  authenticated: boolean;
  /** The desktop app didn't answer at all (server off / asleep / away) — as
   *  opposed to answering "not signed in". The service worker serves this page
   *  from cache even with the server fully off, so without this flag a dead
   *  server renders as a perfectly normal-looking (but non-functional) login
   *  form. */
  unreachable: boolean;
}

interface AuthContextValue extends AuthState {
  refresh: () => Promise<void>;
  setAuthenticated: (v: boolean) => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({
    loading: true,
    setupRequired: false,
    authenticated: false,
    unreachable: false,
  });

  const refresh = useCallback(async () => {
    try {
      const s = await api.get<{ setupRequired: boolean; authenticated: boolean }>(
        '/api/auth/state',
      );
      setState({
        loading: false,
        setupRequired: s.setupRequired,
        authenticated: s.authenticated,
        unreachable: false,
      });
    } catch (err) {
      // An ApiError means the server ANSWERED (just not with a session);
      // anything else (fetch TypeError, abort) means nothing is listening.
      setState({
        loading: false,
        setupRequired: false,
        authenticated: false,
        unreachable: !(err instanceof ApiError),
      });
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const setAuthenticated = useCallback((v: boolean) => {
    setState((s) => ({ ...s, authenticated: v }));
  }, []);

  return (
    <AuthContext.Provider value={{ ...state, refresh, setAuthenticated }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
