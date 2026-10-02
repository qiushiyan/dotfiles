// steps: a record of which skills and prompt snippets ran this session.
//
// Signals are gathered as a turn runs (a skill's prompt expanded, a SKILL.md
// read, a TabType snippet pasted, a skill named in the prompt). When the main
// turn completes they become steps at once, by the signals alone, and a small
// model then judges each one against the turn: ran, started, or only named.

import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Step, StepCandidate, StepKind, StepSignal } from '../types'
import {
  assume,
  bandItems,
  describe,
  detail,
  forkPrompt,
  judgePrompt,
  matchSnippets,
  mentions,
  merge,
  parseSnippets,
  parseVerdicts,
  skillFromPath,
} from './detect'
import type { Evidence, Snippet, Verdict } from './detect'

const PANE = 'steps'
const JUDGE_MODEL = 'haiku'
const SNIPPETS_FILE = '.config/tabtype/config.toml'
const DEFAULT_PINS = ['consult', 'review', 'update-docs', 'prompt-check', 'pl-loopy-verify', 'pl-loopy-handoff']
/** A started step is looked at again for this many turns, then left as started. */
const FOLLOW_TURNS = 15
const KEPT_SESSIONS = 40
const TRAIL = 60

const log = atom({ plugin: 'steps', key: 'log' } as const, {})
const pending = atom({ plugin: 'steps', key: 'pending' } as const, {})
const pins = atom({ plugin: 'steps', key: 'pins' } as const, DEFAULT_PINS)
const known = atom({ plugin: 'steps', key: 'known' } as const, [])
const turnNow = atom({ plugin: 'steps', key: 'turn' } as const, 0)

const GLYPH = { done: '✓', started: '◐', mentioned: '·', none: '·' } as const

const bare = (name: string): string => name.split(':').at(-1) ?? name
const tail = (path: string): string => path.split('/').slice(-3).join('/')

// What a hot reload may lose: all of it is rebuilt or only shortens one turn's evidence.
let snippets: Snippet[] = []
let skills: string[] = []
let isLoaded = false
let prompts: string[] = []
let trail: string[] = []

async function refresh($: EngineInterface) {
  const home = (await $.env.get('HOME')) ?? ''
  snippets = await $.fs
    .read(`${home}/${SNIPPETS_FILE}`)
    .then(text => parseSnippets(String(text)))
    .catch(() => [])
  skills = await $.command
    .list()
    .then(all => [...new Set(all.filter(c => c.source !== 'builtin').map(c => bare(c.name)))])
    .catch(() => [])
  await update($, known, () => [...new Set([...skills, ...snippets.map(s => s.key)])])
  isLoaded = true
}

function note($: EngineInterface, name: string, kind: StepKind, signal: StepSignal) {
  return update($, pending, all => {
    const signals = all[name]?.signals ?? []
    return signals.includes(signal) ? all : { ...all, [name]: { kind, signals: [...signals, signal] } }
  })
}

function apply($: EngineInterface, before: Readonly<Record<string, Step>>, verdicts: readonly Verdict[], turn: number) {
  return update($, log, all => {
    const out = { ...all }
    for (const v of verdicts) {
      const step = merge(before[v.name], v, turn)
      if (step === undefined) delete out[v.name]
      else out[v.name] = step
    }
    return out
  })
}

async function persist($: EngineInterface) {
  const key = `log:${await $.session.id()}`
  await $.store.delete(key)
  await $.store.set(key, await read($, log))
  const kept = (await $.store.keys()).filter(k => k.startsWith('log:'))
  for (const old of kept.slice(0, Math.max(0, kept.length - KEPT_SESSIONS))) await $.store.delete(old)
}

async function judge(
  $: EngineInterface,
  before: Readonly<Record<string, Step>>,
  fresh: Readonly<Record<string, StepCandidate>>,
  open: readonly Step[],
  evidence: Evidence,
  turn: number,
) {
  const reply = await $.model.complete({
    model: JUDGE_MODEL,
    prompt: judgePrompt(fresh, open, evidence),
    maxTokens: 600,
    effort: 'low',
    timeoutMs: 30_000,
  })
  if (!reply.isAnswered) return
  const names = [...Object.keys(fresh), ...open.map(s => s.name)]
  const judged = parseVerdicts(reply.text, names)
  const verdicts: Verdict[] = []
  for (const [name, candidate] of Object.entries(fresh)) {
    const found = judged[name]
    if (found) verdicts.push({ name, ...candidate, ...found, isJudged: true, isFollowUp: false })
  }
  for (const step of open) {
    const found = judged[step.name]
    if (found) verdicts.push({ name: step.name, kind: step.kind, signals: [], ...found, isJudged: true, isFollowUp: true })
  }
  await apply($, before, verdicts, turn)
  await persist($)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'steps',
      description: 'Show which skills and snippets ran this session',
      argumentHint: '[pin <name> | unpin <name> | clear]',
    })
    await $.command.register({
      name: 'did',
      description: 'Ask whether something was done this session, outside the conversation',
      argumentHint: '<question>',
    })
    const storedPins = await $.store.get('pins')
    if (Array.isArray(storedPins)) await update($, pins, () => storedPins.map(String))
    // A resumed session starts with no state: take back what it had recorded.
    if (Object.keys(await read($, log)).length === 0) {
      const saved = await $.store.get(`log:${await $.session.id()}`)
      if (saved !== null && typeof saved === 'object') await update($, log, () => saved as Record<string, Step>)
    }
    const turn = await $.session.turns()
    await update($, turnNow, () => turn)
    await refresh($)

    return next(e)
  })

  on('session.end', async ($, e, next) => {
    if (e.reason === 'clear') {
      await update($, log, () => ({}))
      await update($, pending, () => ({}))
    }

    return next(e)
  })

  on('prompt.submit', async ($, e, next) => {
    if (!isLoaded) await refresh($)
    prompts.push(e.text)
    for (const name of matchSnippets(e.text, snippets)) await note($, name, 'snippet', 'snippet')
    for (const name of mentions(e.text, skills)) await note($, name, 'skill', 'mention')

    return next(e)
  })

  on('skill.prompt', async ($, e, next) => {
    await note($, bare(e.skill), 'skill', 'skill')

    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    let line: string = String(e.tool)
    if (e.tool === 'Read') {
      line = `Read ${tail(e.file_path)}`
      const name = skillFromPath(e.file_path)
      if (name !== undefined) await note($, name, 'skill', 'read')
    } else if (e.tool === 'Bash') line = `Bash ${e.command.replace(/\s+/g, ' ').slice(0, 100)}`
    else if (e.tool === 'Skill') line = `Skill ${e.skill}`
    else if (e.tool === 'Edit' || e.tool === 'Write') line = `${e.tool} ${tail(e.file_path)}`
    else if (e.tool === 'Agent') line = `Agent ${e.description}`
    trail = [...trail, line].slice(-TRAIL)

    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId !== undefined) return result

    const turn = await $.session.turns()
    await update($, turnNow, () => turn)
    const fresh = await read($, pending)
    const before = await read($, log)
    const evidence: Evidence = { prompt: prompts.join('\n\n'), answer: e.answer, trail }
    prompts = []
    trail = []
    const open = Object.values(before).filter(
      s => s.status === 'started' && !(s.name in fresh) && turn - s.lastTurn <= FOLLOW_TURNS,
    )
    if (Object.keys(fresh).length === 0 && open.length === 0) return result

    await update($, pending, () => ({}))
    await apply($, before, Object.entries(fresh).map(([name, c]) => assume(name, c, e.isAborted)), turn)
    await persist($)
    // The judge runs after the dispatch, so the turn is never held for it.
    if (!e.isAborted) $.clock.after(0, () => void judge($, before, fresh, open, evidence, turn).catch(() => {}))

    return result
  })

  on('command.run', { command: 'steps' }, async ($, e) => {
    const [verb, name] = e.args.trim().split(/\s+/)
    if ((verb === 'pin' || verb === 'unpin') && name) {
      await update($, pins, all => (verb === 'pin' ? [...new Set([...all, name])] : all.filter(p => p !== name)))
      await $.store.set('pins', await read($, pins))

      return { text: `${verb === 'pin' ? 'Pinned' : 'Unpinned'} ${name}.` }
    }
    if (verb === 'clear') {
      await update($, log, () => ({}))
      await persist($)

      return { text: 'Cleared the recorded steps of this session.' }
    }
    await $.ui.open({ id: PANE, title: 'Steps this session', closeOnEscape: true })

    return { text: describe(await read($, log), await read($, turnNow)) }
  })

  on('command.run', { command: 'did' }, async ($, e) => {
    const now = await read($, turnNow)
    const ledger = describe(await read($, log), now)
    const question = e.args.trim()
    if (question === '') return { text: ledger }
    const reply = await $.model.fork({ prompt: forkPrompt(ledger, question, now) })

    return { text: reply.isAnswered ? reply.text : `No answer (${reply.reason}). Recorded steps:\n${ledger}` }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)
    const items = bandItems(await read($, log), await read($, pins), await read($, known))
    if (items.length === 0) return next(e)

    const { Box, Text } = $.ui.resolve(e)
    let room = e.props.bodyColumns - 12
    const shown = items.filter(item => (room -= item.label.length + 4) >= 0)
    const more = items.length - shown.length

    return (
      <Box>
        <Text dimColor>steps  </Text>
        {shown.map(item =>
          item.status === 'none' ? (
            <Text dimColor>
              {GLYPH.none} {item.label}{'  '}
            </Text>
          ) : (
            <Text color={item.status === 'done' ? 'green' : 'yellow'}>
              {GLYPH[item.status]} {item.label}{'  '}
            </Text>
          ),
        )}
        {more > 0 && <Text dimColor>+{more}</Text>}
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const all = await read($, log)
    const now = await read($, turnNow)
    const items = bandItems(all, await read($, pins), await read($, known))
    const named = Object.values(all).filter(s => s.status === 'mentioned' && !items.some(i => i.name === s.name))

    return (
      <Box flexDirection="column">
        {items.length === 0 && named.length === 0 && <Text dimColor>Nothing recorded yet.</Text>}
        {items.map(item => {
          const step = all[item.name]

          return (
            <Box flexDirection="column">
              <Box>
                {item.status === 'none' ? (
                  <Text dimColor>{GLYPH.none} {item.name}</Text>
                ) : (
                  <Text color={item.status === 'done' ? 'green' : 'yellow'}>
                    {GLYPH[item.status]} {item.name}
                  </Text>
                )}
                <Text dimColor>{'  '}{step === undefined ? 'not run' : detail(step, now)}</Text>
              </Box>
              {step?.note !== undefined && step.status !== 'mentioned' && (
                <Text dimColor wrap="wrap">{'    '}{step.note}</Text>
              )}
            </Box>
          )
        })}
        {named.map(step => (
          <Text dimColor>
            {GLYPH.mentioned} {step.name}{'  '}{detail(step, now)}
          </Text>
        ))}
        <Text> </Text>
        <Button key="close" label="Close" role="dismiss" onPress={() => $.ui.close({ id: PANE })} />
      </Box>
    )
  })
}
