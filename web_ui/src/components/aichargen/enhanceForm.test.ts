// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AI Enhance payload + apply-merge logic: the request body must mirror the
// Dart EnhanceSelection JSON shape, and the apply body must include ONLY the
// accepted sections (the duplicate already carries the original for the rest)
// with user edits winning over the raw proposal.

import { describe, it, expect } from 'vitest';
import {
  DEFAULT_ENHANCE_SELECTION,
  anySelected,
  buildApplyBody,
  buildEnhancePayload,
  type EnhanceProposal,
} from './enhanceForm';

describe('buildEnhancePayload', () => {
  it('mirrors the Dart EnhanceSelection JSON contract', () => {
    const p = buildEnhancePayload('char-1', 'sess-1', DEFAULT_ENHANCE_SELECTION, true);
    expect(p).toEqual({
      characterId: 'char-1',
      sessionId: 'sess-1',
      fields: {
        description: true,
        personality: true,
        exampleDialogue: true,
        scenario: false,
        greetings: false,
        lorebook: false,
      },
      nsfwEnabled: true,
    });
  });

  it('modelId rides only when set (server treats absent as "current model")', () => {
    const none = buildEnhancePayload('c', 's', DEFAULT_ENHANCE_SELECTION, false);
    expect(none).not.toHaveProperty('modelId');
    const picked = buildEnhancePayload('c', 's', DEFAULT_ENHANCE_SELECTION, false, 'meta/llama-4');
    expect(picked.modelId).toBe('meta/llama-4');
  });

  it('defaults: persona trio on, the rest off, and counts as selected', () => {
    expect(anySelected(DEFAULT_ENHANCE_SELECTION)).toBe(true);
    expect(
      anySelected({ ...DEFAULT_ENHANCE_SELECTION, description: false, personality: false, exampleDialogue: false }),
    ).toBe(false);
  });
});

describe('buildApplyBody', () => {
  const proposal: EnhanceProposal = {
    description: 'new desc',
    personality: 'new pers',
    mesExample: 'new dialogue',
    scenario: 'new scenario',
    firstMessage: 'new greeting',
    alternateGreetings: ['alt one', 'alt two'],
    lorebook: { entries: [{ name: 'The Bar' }] },
  };
  const allOn = {
    description: true,
    personality: true,
    exampleDialogue: true,
    scenario: true,
    greetings: true,
    lorebook: true,
  };

  it('includes only accepted sections', () => {
    const body = buildApplyBody(proposal, { ...allOn, personality: false, lorebook: false });
    expect(body.description).toBe('new desc');
    expect(body).not.toHaveProperty('personality');
    expect(body).not.toHaveProperty('lorebook');
    expect(body.mesExample).toBe('new dialogue');
    expect(body.firstMessage).toBe('new greeting');
    expect(body.alternateGreetings).toEqual(['alt one', 'alt two']);
  });

  it('user edits win over the raw proposal', () => {
    const body = buildApplyBody(proposal, allOn, {
      description: 'edited desc',
      alternateGreetings: ['edited alt'],
    });
    expect(body.description).toBe('edited desc');
    expect(body.personality).toBe('new pers');
    expect(body.alternateGreetings).toEqual(['edited alt']);
  });

  it('skips keys absent from the proposal even when accepted', () => {
    const body = buildApplyBody({ description: 'only desc' }, allOn);
    expect(body).toEqual({ description: 'only desc' });
  });

  it('nothing accepted → empty body (duplicate stays pristine)', () => {
    const body = buildApplyBody(proposal, {
      description: false,
      personality: false,
      exampleDialogue: false,
      scenario: false,
      greetings: false,
      lorebook: false,
    });
    expect(body).toEqual({});
  });
});
