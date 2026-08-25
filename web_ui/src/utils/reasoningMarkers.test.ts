import { describe, expect, it } from 'vitest'
import { canonicalizeReasoning } from './reasoningMarkers'

describe('canonicalizeReasoning', () => {
  it('leaves plain prose alone', () => {
    expect(canonicalizeReasoning('Hello there.')).toBe('Hello there.')
  })

  it('converts Gemma 4 channels to <think>', () => {
    const out = canonicalizeReasoning(
      '<|channel>thought\nessay\n<channel|>"Stay."',
    )
    expect(out).toContain('<think>')
    expect(out).toContain('</think>')
    expect(out).toContain('"Stay."')
    expect(out).not.toContain('<|channel>')
  })

  it('does not treat "I thought about it" as a think block', () => {
    expect(canonicalizeReasoning('I thought about it on the porch.')).toBe(
      'I thought about it on the porch.',
    )
  })
})
