// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What to do when GET /api/chat/state fails. Nothing else in the app maps a
// 401 back to the sign-in form, so a revoked session (Account → "Sign out all
// devices") or the 30-day session expiry used to leave the chat page on a
// spinner that never resolves — and on an installed PWA there is no address
// bar to force a reload with. A dead session must land the user on the login
// screen; anything else must at least SAY so, with a way to retry.

import { ApiError } from '../api/client';

export interface ChatLoadFailure {
  /** The server answered "not you" — drop back to the sign-in screen. */
  signedOut: boolean;
  /** Plain-English reason, written for someone who has never seen a status code. */
  message: string;
}

export function describeChatLoadFailure(e: unknown): ChatLoadFailure {
  if (e instanceof ApiError) {
    if (e.status === 401 || e.status === 403) {
      return {
        signedOut: true,
        message: 'Your web session has ended. Please sign in again.',
      };
    }
    if (e.status >= 500) {
      return {
        signedOut: false,
        message: `Front Porch AI ran into a problem on your computer (${e.message}). Check it is still running, then tap Try again.`,
      };
    }
    return {
      signedOut: false,
      message: `Front Porch AI could not open this chat: ${e.message}`,
    };
  }
  return {
    signedOut: false,
    message:
      "Couldn't reach Front Porch AI. Check the app is still open on your computer and that this device is still on the same network, then tap Try again.",
  };
}
