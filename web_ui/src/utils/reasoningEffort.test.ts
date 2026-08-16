// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import { describe, it, expect } from 'vitest'
import {
  reasoningEffortChipsFor,
  reasoningEffortDisplayedSelection,
  reasoningEffortMappingCaption,
  wireReasoningEffort,
} from './reasoningEffort'

const thinking = 'deepseek/deepseek-v4-flash:thinking'

describe('reasoningEffort', () => {
  it('still remaps low/medium to high on the wire for DeepSeek :thinking', () => {
    expect(wireReasoningEffort(thinking, 'low')).toBe('high')
    expect(wireReasoningEffort(thinking, 'medium')).toBe('high')
    expect(wireReasoningEffort(thinking, 'high')).toBe('high')
    expect(wireReasoningEffort(thinking, 'max')).toBe('max')
  })

  it('shows High and Max chips — not Low or Medium — for DeepSeek :thinking', () => {
    expect(reasoningEffortChipsFor(thinking)).toEqual(['high', 'max'])
    expect(reasoningEffortDisplayedSelection(thinking, 'medium')).toBe('high')
    expect(reasoningEffortDisplayedSelection(thinking, 'max')).toBe('max')
  })

  it('caption lists this model\'s real menu', () => {
    const cap = reasoningEffortMappingCaption(thinking, 'low')
    expect(cap).toContain('High')
    expect(cap).toContain('Max')
    expect(cap).not.toContain('Low')
  })

  it('Kimi K2.6 keeps Low even with a :thinking suffix', () => {
    expect(reasoningEffortChipsFor('moonshotai/kimi-k2.6:thinking')).toEqual([
      'low',
      'high',
      'max',
    ])
    expect(wireReasoningEffort('moonshotai/kimi-k2.6:thinking', 'low')).toBe('low')
  })

  it('a random :thinking id is not guessed as High/Max', () => {
    expect(reasoningEffortChipsFor('acme/mystery-reasoner:thinking')).toEqual([
      'low',
      'medium',
      'high',
    ])
  })

  it('uses a server-provided chip list for highlight, not the local hint', () => {
    expect(
      reasoningEffortDisplayedSelection('acme/foo', 'medium', ['high', 'max']),
    ).toBe('high')
  })

  it('plain models keep the Low / Medium / High fallback', () => {
    expect(reasoningEffortChipsFor('acme/gpt-lite')).toEqual(['low', 'medium', 'high'])
    expect(reasoningEffortDisplayedSelection('acme/gpt-lite', 'low')).toBe('low')
  })
})
