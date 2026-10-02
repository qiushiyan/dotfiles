// The mod's pure half: when a window's reading earns an alert, how fast the
// window is filling, which account has the most room, and the words for it.

import type { QuotaSample, QuotaWindow } from '../types'

/** A window is announced as it passes each of these, once. */
export const THRESHOLDS = [75, 90] as const
export const URGENT = 90

const KEPT = 60
/** A pace is read from this much history, and needs this much to mean anything. */
const PACE_WINDOW_MS = 45 * 60_000
const PACE_MIN_SPAN_MS = 5 * 60_000
const PACE_MIN_RISE = 2
/** Another account is worth naming when it is this many points emptier. */
const ROOM_MARGIN = 20

/** The engine's window kinds, as shown, and as headroom names them. */
const LABEL: Record<string, string> = { five_hour: '5h', seven_day: '7d', spend_limit: 'spend' }
const HEADROOM_KIND: Record<string, string> = { five_hour: 'session', seven_day: 'weekly_all' }

export type Limit = { kind: string; percentUsed: number; resetsAt?: string }
export type Pace = { outInMs: number; resetInMs: number }
export type Lane = { launcher: string; percent: number }

export const label = (kind: string): string => LABEL[kind] ?? kind

/**
 * A window after one more reading, and the threshold the reading crossed.
 * Usage only rises inside a window, so a lower reading is a new window.
 */
export function record(before: QuotaWindow | undefined, percent: number, now: number): { window: QuotaWindow; crossed?: number } {
  const last = before?.samples.at(-1)
  const isSame = before !== undefined && last !== undefined && percent >= last.percent
  const samples: QuotaSample[] = [...(isSame ? before.samples : []), { at: now, percent }].slice(-KEPT)
  const alerted = isSame ? before.alerted : 0
  const crossed = THRESHOLDS.findLast(t => percent >= t && t > alerted)
  return crossed === undefined ? { window: { samples, alerted } } : { window: { samples, alerted: crossed }, crossed }
}

/** The pace of a window that will fill before it resets; undefined when it will not, or it is too early to say. */
export function pace(samples: readonly QuotaSample[], resetsAt: string | undefined, now: number): Pace | undefined {
  const recent = samples.filter(s => now - s.at <= PACE_WINDOW_MS)
  const first = recent[0]
  const last = recent.at(-1)
  if (first === undefined || last === undefined || resetsAt === undefined) return undefined
  const rise = last.percent - first.percent
  const span = last.at - first.at
  if (span < PACE_MIN_SPAN_MS || rise < PACE_MIN_RISE) return undefined
  const outInMs = ((100 - last.percent) / rise) * span - (now - last.at)
  const resetInMs = Date.parse(resetsAt) - now
  return Number.isFinite(resetInMs) && outInMs < resetInMs ? { outInMs: Math.max(0, outInMs), resetInMs } : undefined
}

/** A duration as the board writes one: `25 min`, `1h20`, `2.3d`. */
export function span(ms: number): string {
  const minutes = Math.max(0, Math.round(ms / 60_000))
  if (minutes < 60) return `${minutes} min`
  if (minutes < 24 * 60) return `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, '0')}`
  return `${(minutes / (24 * 60)).toFixed(1)}d`
}

type BoardLimit = { kind?: unknown; percent?: unknown }
type BoardAccount = { vendor?: unknown; launcher?: unknown; usage?: { limits?: unknown } }

const percentOf = (limits: readonly BoardLimit[], kind: string): number | undefined => {
  const percent = limits.find(l => l.kind === kind)?.percent
  return typeof percent === 'number' ? percent : undefined
}

/**
 * The Claude account with the most room in this kind of window, from
 * headroom's board JSON: named only when it is clearly emptier than here and
 * its other window is not itself nearly spent.
 */
export function roomiest(board: unknown, kind: string, ownPercent: number): Lane | undefined {
  const wanted = HEADROOM_KIND[kind]
  const accounts = (board as { accounts?: unknown } | null)?.accounts
  if (wanted === undefined || !Array.isArray(accounts)) return undefined
  const other = Object.values(HEADROOM_KIND).filter(k => k !== wanted)
  let best: Lane | undefined
  for (const account of accounts as BoardAccount[]) {
    const limits = account.usage?.limits
    if (account.vendor !== 'claude' || typeof account.launcher !== 'string' || !Array.isArray(limits)) continue
    const percent = percentOf(limits as BoardLimit[], wanted)
    const isSpentElsewhere = other.some(k => (percentOf(limits as BoardLimit[], k) ?? 0) >= URGENT)
    if (percent === undefined || isSpentElsewhere || percent > ownPercent - ROOM_MARGIN) continue
    if (best === undefined || percent < best.percent) best = { launcher: account.launcher, percent }
  }
  return best
}

/** One window in words: its fill, its reset, and its pace when it will run out first. */
export function describe(limit: Limit, samples: readonly QuotaSample[], now: number): string {
  const resetInMs = limit.resetsAt === undefined ? Number.NaN : Date.parse(limit.resetsAt) - now
  const reset = Number.isFinite(resetInMs) ? `, resets in ${span(resetInMs)}` : ''
  const found = pace(samples, limit.resetsAt, now)
  const out = found === undefined ? '' : `. At this pace it runs out in about ${span(found.outInMs)}`
  return `${label(limit.kind)} quota at ${Math.round(limit.percentUsed)}%${reset}${out}`
}

export function alertText(limit: Limit, samples: readonly QuotaSample[], now: number, lane: Lane | undefined): string {
  const room = lane === undefined ? '' : ` Most room: ${lane.launcher} (${label(limit.kind)} ${lane.percent}%).`
  return `${describe(limit, samples, now)}.${room}`
}
