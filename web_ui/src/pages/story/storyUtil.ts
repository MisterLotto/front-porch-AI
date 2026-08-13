// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared Porch Stories client helpers: library-card status derivation, file
// downloads, and text/binary export. Reused by the library list and the bible
// dashboard so the logic lives in one place.

import { api } from '../../api/client';
import type { StoryListItem } from '../../storyTypes';

export interface CardStatus {
  label: string;
  tone: string; // CSS var token name suffix → var(--story-status-<tone>)
  icon: string;
}

/** Granular library-card status (mirrors the desktop home card). */
export function cardStatus(s: StoryListItem): CardStatus {
  if (s.proseCount > 0) {
    return { label: `${s.proseCount} beats written`, tone: 'prose', icon: '✍️' };
  }
  if (s.sceneCount > 0) {
    return { label: `${s.sceneCount} scenes planned`, tone: 'scenes', icon: '🎬' };
  }
  if (s.actCount > 0) {
    return { label: `${s.actCount} acts structured`, tone: 'acts', icon: '🌳' };
  }
  if (s.hasConcept) {
    return { label: 'Bible created', tone: 'bible', icon: '📖' };
  }
  return { label: 'New — needs concept', tone: 'new', icon: '💡' };
}

/** Trigger a browser download for a blob. */
export function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

/** One sanitiser for every `<a download>` name (chat export + story files). */
export function safeDownloadStem(name: string, fallback: string): string {
  const cleaned = (name || fallback).replace(/[^\w.-]+/g, '_').replace(/^_+|_+$/g, '');
  return cleaned.length === 0 ? fallback : cleaned;
}

const safe = (name: string) => safeDownloadStem(name, 'story');

/** Download the assembled prose as plain text or markdown. */
export async function exportText(id: string, format: 'text' | 'markdown', title: string) {
  const r = await api.get<{ text: string }>(`/api/stories/${id}/export?format=${format}`);
  const blob = new Blob([r.text], { type: 'text/plain' });
  downloadBlob(blob, `${safe(title)}.${format === 'markdown' ? 'md' : 'txt'}`);
}

/** Download the EPUB (synthesized server-side). */
export async function exportEpub(id: string, title: string) {
  const blob = await api.getForBlob(`/api/stories/${id}/ebook`);
  downloadBlob(blob, `${safe(title)}.epub`);
}
