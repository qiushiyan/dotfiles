import { describe, expect, mock, test } from 'claude-code/testing'

import { alertText, pace, record, roomiest, span } from '../hooks/pace'

const MIN = 60_000
const T0 = Date.parse('2026-10-02T10:00:00Z')

const account = (launcher: string, session: number, weekly: number, vendor = 'claude') => ({
  vendor,
  launcher,
  usage: { limits: [{ kind: 'session', percent: session }, { kind: 'weekly_all', percent: weekly }] },
})
const BOARD = { schema: 7, accounts: [account('x-a', 91, 40), account('x-b', 12, 30), account('x-c', 3, 95), account('cx-d', 0, 0, 'codex')] }

describe('readings', () => {
  test('a window is announced once per threshold, the highest it has passed', () => {
    const first = record(undefined, 92, T0)
    expect(first.crossed).toBe(90)

    const second = record(first.window, 93, T0 + MIN)
    expect(second.crossed).toBeUndefined()
    expect(second.window.samples).toHaveLength(2)

    const climbing = record(record(undefined, 76, T0).window, 91, T0 + MIN)
    expect(climbing.crossed).toBe(90)
  })

  test('a lower reading is a new window: its history and its alerts start over', () => {
    const spent = record(undefined, 96, T0).window
    const fresh = record(spent, 4, T0 + MIN)
    expect(fresh.window).toEqual({ samples: [{ at: T0 + MIN, percent: 4 }], alerted: 0 })
    expect(record(fresh.window, 80, T0 + 2 * MIN).crossed).toBe(75)
  })

  test('a pace is given only when the window fills before it resets', () => {
    const samples = [{ at: T0, percent: 60 }, { at: T0 + 20 * MIN, percent: 80 }]
    const now = T0 + 20 * MIN
    expect(pace(samples, '2026-10-02T12:20:00Z', now)).toEqual({ outInMs: 20 * MIN, resetInMs: 120 * MIN })
    expect(pace(samples, '2026-10-02T10:30:00Z', now)).toBeUndefined()
    expect(pace([{ at: T0, percent: 60 }, { at: T0 + 2 * MIN, percent: 80 }], '2026-10-02T12:20:00Z', T0 + 2 * MIN)).toBeUndefined()
  })

  test('durations read as the board writes them', () => {
    expect([span(25 * MIN), span(80 * MIN), span(55.2 * 60 * MIN)]).toEqual(['25 min', '1h20', '2.3d'])
  })

  test('the roomiest account is a Claude one, clearly emptier, whose other window is not spent', () => {
    expect(roomiest(BOARD, 'five_hour', 91)).toEqual({ launcher: 'x-b', percent: 12 })
    expect(roomiest(BOARD, 'five_hour', 25)).toBeUndefined()
    expect(roomiest('not a board', 'five_hour', 91)).toBeUndefined()
  })

  test('an alert says the fill, the reset, the pace and the lane', () => {
    const samples = [{ at: T0, percent: 71 }, { at: T0 + 20 * MIN, percent: 91 }]
    const limit = { kind: 'five_hour', percentUsed: 91, resetsAt: '2026-10-02T11:40:00Z' }
    expect(alertText(limit, samples, T0 + 20 * MIN, { launcher: 'x-b', percent: 12 })).toBe(
      '5h quota at 91%, resets in 1h20. At this pace it runs out in about 9 min. Most room: x-b (5h 12%).',
    )
  })
})

describe('quota', () => {
  test('an urgent crossing toasts once, names the roomiest lane, and stays in the transcript', async ($, on) => {
    mock.clock(on, { now: T0 })
    const toasts: string[] = []
    const logs: string[] = []
    const ran: string[] = []
    on('command.register', ($, e) => ({ value: { command: e.name } }))
    on('session.start', ($, e) => ({ cwd: e.cwd }))
    on('session.measure', ($, e) => ({ changed: e.changed }))
    on('ui.toast', ($, e) => (toasts.push(e.text), { value: undefined }))
    on('ui.log', ($, e) => (logs.push(e.text), { value: undefined }))
    on('process.run', ($, e) => {
      ran.push(e.argv.join(' '))
      return { value: { exitCode: 0, stdout: JSON.stringify(BOARD), stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
    })

    await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
    const measure = (percentUsed: number) =>
      $.session.measure({
        context: { window: 200_000 },
        rateLimits: [{ kind: 'five_hour', percentUsed, resetsAt: '2026-10-02T12:00:00Z' }],
        changed: ['rateLimits'],
      })
    await measure(91)
    await measure(92)

    expect(toasts).toEqual(['5h quota at 91%, resets in 2h00. Most room: x-b (5h 12%).'])
    expect(logs).toEqual(toasts)
    expect(ran).toEqual(['headroom limits'])
  })
})
