/** App-facing thinking strength (mirrors lib/services/reasoning_effort.dart). */

export const APP_REASONING_EFFORTS = ['low', 'medium', 'high'] as const
export type AppReasoningEffort = (typeof APP_REASONING_EFFORTS)[number]

const RANK: Record<string, number> = {
  none: 0,
  minimal: 1,
  low: 2,
  medium: 3,
  high: 4,
  xhigh: 5,
  max: 6,
}

const HIGH_MAX = new Set(['none', 'high', 'max'])
const LOW_HIGH_MAX = new Set(['none', 'low', 'high', 'max'])

export function reasoningEffortTitle(id: string): string {
  switch (id) {
    case 'none': return 'Off'
    case 'minimal': return 'Minimal'
    case 'low': return 'Low'
    case 'medium': return 'Medium'
    case 'high': return 'High'
    case 'xhigh': return 'Extra high'
    case 'max': return 'Max'
    default: return id
  }
}

export function reasoningEffortBlurb(id: string): string {
  switch (id) {
    case 'low': return 'Light think — faster, cheaper'
    case 'medium': return 'Balanced — default'
    case 'high': return 'Deep think — slower, richer'
    case 'xhigh': return 'Heavier than high'
    case 'max': return 'Full thinking budget'
    case 'minimal': return 'Bare-minimum thinking'
    default: return ''
  }
}

function supportedFor(model: string): Set<string> | null {
  if (!model) return null
  const id = model.toLowerCase()
  // `:thinking` is Nano's "use the thinking variant" tag, not a ladder.
  if (id.includes('deepseek') && id.includes(':thinking')) return HIGH_MAX
  if (id.includes('glm-5.2') || id.includes('glm5.2')) return HIGH_MAX
  if (id.includes('kimi-k2.6') || id.includes('kimi-k2-6')) return LOW_HIGH_MAX
  return null
}

function nearest(requested: string, supported: Set<string>): string {
  if (supported.has(requested)) return requested
  const req = RANK[requested] ?? RANK.medium
  const thinking = [...supported].filter((s) => s !== 'none')
  const pool = (thinking.length ? thinking : [...supported]).filter((s) => s in RANK)
  if (!pool.length) return requested
  return pool.reduce((a, b) => {
    const da = Math.abs(RANK[a]! - req)
    const db = Math.abs(RANK[b]! - req)
    if (da !== db) return da < db ? a : b
    return RANK[a]! < RANK[b]! ? a : b
  })
}

export function wireReasoningEffort(model: string, requested: string): string {
  const supported = supportedFor(model)
  if (!supported) return requested
  return nearest(requested, supported)
}

export function reasoningEffortChipsFor(model: string): string[] {
  const supported = supportedFor(model)
  if (!supported) return [...APP_REASONING_EFFORTS]
  const chips = [...supported]
    .filter((s) => s !== 'none' && s in RANK)
    .sort((a, b) => RANK[a]! - RANK[b]!)
  return chips.length ? chips : [...APP_REASONING_EFFORTS]
}

export function reasoningEffortDisplayedSelection(
  model: string,
  requested: string,
  chips?: string[],
): string {
  const row = chips?.length ? chips : reasoningEffortChipsFor(model)
  if (row.includes(requested)) return requested
  return nearest(requested || 'medium', new Set(row))
}

export function reasoningEffortMappingCaption(
  model: string,
  requested: string,
  chips?: string[],
  mandatory?: boolean,
): string {
  if (!model) return ''
  const row = chips?.length ? chips : reasoningEffortChipsFor(model)
  const allowed = row.map(reasoningEffortTitle).join(' · ')
  if (mandatory) return `This model always thinks. Strengths: ${allowed}.`
  if (chips?.length) return `This model's thinking levels: ${allowed}.`
  const supported = supportedFor(model)
  if (!supported) {
    if (!requested) return ''
    return `Sent as ${reasoningEffortTitle(requested).toLowerCase()}. When we know this model's levels, the chips match them.`
  }
  return `This model's thinking levels: ${allowed}.`
}
