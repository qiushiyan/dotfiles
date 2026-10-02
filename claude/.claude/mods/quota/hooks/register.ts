// quota: what the tmux context chip cannot say. The chip shows each window's
// fill; this mod keeps the readings of a session, so it can announce a window
// crossing a threshold once, say when it will run out at the current pace, and
// name the account with the most room. /quota prints the same and the board.
//
// Readings arrive pushed (`session.measure`, when a window moves a whole
// point); headroom is asked only on an urgent crossing and for /quota.

import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import { alertText, describe, record, roomiest, URGENT } from './pace'
import type { Lane, Limit } from './pace'

const windows = atom({ plugin: 'quota', key: 'windows' } as const, {})

/** `headroom limits` reads its cache from disk alone: no network, no request spent. */
async function lane($: EngineInterface, limit: Limit): Promise<Lane | undefined> {
  const ran = await $.process.run(['headroom', 'limits'], { timeoutMs: 5000 }).catch(() => undefined)
  if (ran === undefined || ran.exitCode !== 0) return undefined
  try {
    return roomiest(JSON.parse(ran.stdout), limit.kind, limit.percentUsed)
  } catch {
    return undefined
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'quota',
      description: "This session's rate-limit windows and pace, and every account's usage",
    })

    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    if (!e.changed.includes('rateLimits')) return next(e)

    const now = await $.clock.now()
    const before = await read($, windows)
    const after = { ...before }
    const crossings: { limit: Limit; crossed: number }[] = []
    for (const limit of e.rateLimits) {
      const { window, crossed } = record(before[limit.kind], limit.percentUsed, now)
      after[limit.kind] = window
      if (crossed !== undefined) crossings.push({ limit, crossed })
    }
    await update($, windows, () => after)

    for (const { limit, crossed } of crossings) {
      const isUrgent = crossed >= URGENT
      const text = alertText(limit, after[limit.kind]?.samples ?? [], now, isUrgent ? await lane($, limit) : undefined)
      $.ui.toast(text, { timeoutMs: isUrgent ? 20_000 : 10_000 })
      // A toast is gone in seconds; the urgent one also stays as a transcript line.
      if (isUrgent) $.ui.log(text)
    }

    return next(e)
  })

  on('command.run', { command: 'quota' }, async $ => {
    const now = await $.clock.now()
    const usage = await $.session.usage()
    const seen = await read($, windows)
    const own = usage.rateLimits.map(limit => describe(limit, seen[limit.kind]?.samples ?? [], now))
    const board = await $.process.run(['headroom', 'accounts', '--compact'], { timeoutMs: 20_000 }).catch(() => undefined)
    const accounts = board === undefined || board.exitCode !== 0 ? 'headroom did not answer.' : board.stdout.trim()

    return { text: [own.length === 0 ? 'No rate-limit reading yet this session.' : own.join('\n'), accounts].join('\n\n') }
  })
}
