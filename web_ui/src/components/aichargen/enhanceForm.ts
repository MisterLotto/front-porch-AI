// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Pure payload/merge logic for AI Enhance (grow an existing character from a
// real chat). Kept out of the components so vitest can pin it — the same rule
// chargenForm.ts follows. The server contract:
//   POST /api/chargen/enhance  {characterId, sessionId, fields, nsfwEnabled}
//   → ws `chargen_enhance_done` {characterId, proposal}
// Apply then rides the EXISTING endpoints: POST /api/characters/<id>/duplicate
// {newName} followed by POST /api/characters/<newId> with the accepted fields.

/** Mirrors the Dart EnhanceSelection JSON shape (chat_grounding.dart). */
export interface EnhanceSelection {
  description: boolean;
  personality: boolean;
  exampleDialogue: boolean;
  scenario: boolean;
  greetings: boolean;
  lorebook: boolean;
}

export const DEFAULT_ENHANCE_SELECTION: EnhanceSelection = {
  description: true,
  personality: true,
  exampleDialogue: true,
  scenario: false,
  greetings: false,
  lorebook: false,
};

export function anySelected(s: EnhanceSelection): boolean {
  return (
    s.description || s.personality || s.exampleDialogue || s.scenario || s.greetings || s.lorebook
  );
}

/** What `chargen_enhance_done` carries — only the selected keys are present. */
export interface EnhanceProposal {
  description?: string;
  personality?: string;
  mesExample?: string;
  scenario?: string;
  firstMessage?: string;
  alternateGreetings?: string[];
  lorebook?: unknown;
}

/** Per-section "use this" toggles in the review step. */
export interface EnhanceAccepted {
  description: boolean;
  personality: boolean;
  exampleDialogue: boolean;
  scenario: boolean;
  greetings: boolean;
  lorebook: boolean;
}

/** Review-step edits (text the user tweaked before applying). */
export interface EnhanceEdits {
  description?: string;
  personality?: string;
  mesExample?: string;
  scenario?: string;
  firstMessage?: string;
  alternateGreetings?: string[];
}

export function buildEnhancePayload(
  characterId: string,
  sessionId: string,
  selection: EnhanceSelection,
  nsfwEnabled: boolean,
  modelId = '',
) {
  return {
    characterId,
    sessionId,
    fields: selection,
    nsfwEnabled,
    // Remote backends only: which model runs THIS enhance (the server resolves
    // it ad-hoc; the app's active model is never switched). '' = active model.
    ...(modelId ? { modelId } : {}),
  };
}

/**
 * The partial-update body for `POST /api/characters/<newId>`: only accepted
 * sections are included (the duplicate already carries the original for the
 * rest), and a user edit wins over the raw proposal.
 */
export function buildApplyBody(
  proposal: EnhanceProposal,
  accepted: EnhanceAccepted,
  edits: EnhanceEdits = {},
): Record<string, unknown> {
  const body: Record<string, unknown> = {};
  if (accepted.description && proposal.description !== undefined) {
    body.description = edits.description ?? proposal.description;
  }
  if (accepted.personality && proposal.personality !== undefined) {
    body.personality = edits.personality ?? proposal.personality;
  }
  if (accepted.exampleDialogue && proposal.mesExample !== undefined) {
    body.mesExample = edits.mesExample ?? proposal.mesExample;
  }
  if (accepted.scenario && proposal.scenario !== undefined) {
    body.scenario = edits.scenario ?? proposal.scenario;
  }
  if (accepted.greetings) {
    if (proposal.firstMessage !== undefined) {
      body.firstMessage = edits.firstMessage ?? proposal.firstMessage;
    }
    if (proposal.alternateGreetings !== undefined) {
      body.alternateGreetings = edits.alternateGreetings ?? proposal.alternateGreetings;
    }
  }
  if (accepted.lorebook && proposal.lorebook != null) {
    body.lorebook = proposal.lorebook;
  }
  return body;
}
