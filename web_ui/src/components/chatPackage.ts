// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import { safeDownloadStem } from '../pages/story/storyUtil';

/** Safe download stem — the browser names the file (`<a download>`). */
export function chatExportStem(title: string): string {
  return safeDownloadStem(title, 'chat');
}

export function chatExportFilename(title: string, ext: 'fpchat' | 'jsonl'): string {
  const stamp = new Date().toISOString().replace(/:/g, '-').split('.')[0];
  return `${chatExportStem(title)}_${stamp}.${ext}`;
}

export type ImportOutcome = {
  fullRestore: boolean;
  warning?: string;
};

export function importResultMessage(r: ImportOutcome): string {
  if (r.fullRestore) {
    return r.warning
      ? `Chat imported (with note: ${r.warning})`
      : 'Chat imported with full Front Porch state';
  }
  return r.warning
    ? `Chat imported as dialogue only (${r.warning})`
    : 'Chat imported (dialogue only)';
}
