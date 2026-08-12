/** App-facing thinking strength (mirrors lib/services/reasoning_effort.dart). */

export const APP_REASONING_EFFORTS = ['low', 'medium', 'high'] as const
export type AppReasoningEffort = (typeof APP_REASONING_EFFORTS)[number]

const RANK: Record<string, number> = {
  none: 0,
  minimal: 1,
  low: 2,
  medium: 3,
  high: 4,
  max: 5,
}

const THINKING_HINT = new Set(['none', 'high', 'max'])

export function reasoningEffortTitle(id: string): string {
  switch (id) {
    case 'none': return 'Off'
    case 'minimal': return 'Minimal'
    case 'low': return 'Low'
    case 'medium': return 'Medium'
    case 'high': return 'High'
    case 'max': return 'Max'
    default: return id
  }
}

export function reasoningEffortBlurb(id: string): string {
  switch (id) {
    case 'low': return 'Light think — faster, cheaper'
    case 'medium': return 'Balanced — default'
    case 'high': return 'Deep think — slower, richer'
    default: return ''
  }
}

function supportedFor(model: string): Set<string> | null {
  if (!model) return null
  if (model.toLowerCase().includes(':thinking')) return THINKING_HINT
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

export function reasoningEffortMappingCaption(model: string, requested: string): string {
  if (!requested) return ''
  const supported = supportedFor(model)
  if (!supported) {
    return 'Sent as-is. If this model only accepts other levels, Front Porch maps to the closest one automatically.'
  }
  const wire = nearest(requested, supported)
  const allowed = [...supported]
    .filter((s) => s !== 'none')
    .map(reasoningEffortTitle)
    .join(' · ')
  if (wire === requested) {
    return `This model accepts: ${allowed}. Your pick matches — sent as ${reasoningEffortTitle(wire).toLowerCase()}.`
  }
  return `This model accepts: ${allowed}. ${reasoningEffortTitle(requested)} → sent as ${reasoningEffortTitle(wire).toLowerCase()}.`
}
