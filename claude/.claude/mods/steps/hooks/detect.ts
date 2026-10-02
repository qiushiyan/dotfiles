// The mod's pure half: reading signals out of text, the judge's prompt and
// reply, and how a verdict changes a step. No `$` here, so tests call it bare.

import type { Step, StepCandidate, StepKind, StepSignal, StepStatus } from '../types'

export type Snippet = { key: string; head: string }

export type Verdict = {
  name: string
  kind: StepKind
  signals: StepSignal[]
  status: StepStatus
  note?: string
  isJudged: boolean
  /** A step an earlier turn started, looked at again; it carries no new run. */
  isFollowUp: boolean
}

export type BandItem = { name: string; label: string; status: StepStatus | 'none' }

/** A snippet shorter than this would match ordinary prose. */
const MIN_SNIPPET = 40
const HEAD = 80

/** `plugin:skill` and `dir:skill` name the same skill as `skill`. */
export const bare = (name: string): string => name.split(':').at(-1) ?? name

export const squash = (text: string): string => text.toLowerCase().replace(/\s+/g, ' ').trim()

/** The `[[snippets]]` of a TabType config: each key with the start of its text. */
export function parseSnippets(toml: string): Snippet[] {
  const found: Snippet[] = []
  for (const block of toml.split(/^\[\[snippets\]\]\s*$/m).slice(1)) {
    const key = /^key\s*=\s*"([^"]+)"/m.exec(block)?.[1]
    const expand =
      /^expand\s*=\s*'''([\s\S]*?)'''/m.exec(block)?.[1] ??
      /^expand\s*=\s*"((?:[^"\\]|\\.)*)"/m.exec(block)?.[1]
    if (key === undefined || expand === undefined) continue
    const text = squash(expand)
    if (text.length >= MIN_SNIPPET) found.push({ key, head: text.slice(0, HEAD) })
  }
  return found
}

/** Keys of the snippets whose opening text the prompt carries. */
export function matchSnippets(prompt: string, snippets: readonly Snippet[]): string[] {
  const text = squash(prompt)
  return snippets.filter(s => text.includes(s.head)).map(s => s.key)
}

/** `…/skills/<name>/SKILL.md` names the skill. */
export function skillFromPath(path: string): string | undefined {
  return /(?:^|\/)skills\/([^/]+)\/SKILL\.md$/.exec(path)?.[1]
}

const escape = (text: string): string => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

/**
 * The skills a prompt names. A hyphenated name counts bare; a one-word name
 * (`review`, `spike`) is also an English word, so it counts only as `/name`,
 * as a path under `skills/`, or as "name skill".
 */
export function mentions(prompt: string, names: readonly string[]): string[] {
  return names.filter(name => {
    const n = escape(name)
    const pattern = name.includes('-')
      ? `(?<![\\w-])${n}(?![\\w-])`
      : `(?<![\\w-])/${n}(?![\\w-])|skills/${n}/|(?<![\\w-])${n} skill\\b`
    return new RegExp(pattern, 'i').test(prompt)
  })
}

/** What the signals say with no model: an expansion or a pasted snippet is a run. */
export function assume(name: string, candidate: StepCandidate, isAborted: boolean): Verdict {
  const has = (signal: StepSignal) => candidate.signals.includes(signal)
  const isRun = has('skill') || has('snippet') || (has('read') && has('mention'))
  return {
    name,
    kind: candidate.kind,
    signals: candidate.signals,
    status: !isRun ? 'mentioned' : isAborted ? 'started' : 'done',
    isJudged: false,
    isFollowUp: false,
  }
}

/** The step after a verdict, from the step as it stood before the turn. */
export function merge(before: Step | undefined, v: Verdict, turn: number): Step | undefined {
  const signals = [...new Set([...(before?.signals ?? []), ...v.signals])]
  if (v.status === 'mentioned') {
    if (before === undefined) {
      return { name: v.name, kind: v.kind, status: 'mentioned', runs: 0, firstTurn: turn, lastTurn: turn, signals, isJudged: v.isJudged }
    }
    return before.status === 'mentioned' ? { ...before, lastTurn: turn, signals } : before
  }
  if (v.isFollowUp) {
    if (before === undefined || v.status === 'started') return before
    return { ...before, status: 'done', lastTurn: turn, note: v.note ?? before.note, isJudged: true }
  }
  const ran = before !== undefined && before.runs > 0
  return {
    name: v.name,
    kind: v.kind,
    status: v.status,
    runs: (before?.runs ?? 0) + 1,
    firstTurn: ran ? before.firstTurn : turn,
    lastTurn: turn,
    signals,
    note: v.note ?? (ran ? before.note : undefined),
    isJudged: v.isJudged,
  }
}

const SIGNAL_TEXT: Record<StepSignal, string> = {
  skill: 'its skill prompt was loaded this turn',
  read: 'its SKILL.md was read this turn',
  snippet: 'the user pasted this prompt snippet',
  mention: 'the user prompt names it',
}

const clip = (text: string, max: number, from: 'start' | 'end'): string =>
  text.length <= max ? text : from === 'start' ? `${text.slice(0, max)} […]` : `[…] ${text.slice(-max)}`

export type Evidence = { prompt: string; answer: string; trail: readonly string[] }

export function judgePrompt(
  fresh: Readonly<Record<string, StepCandidate>>,
  open: readonly Step[],
  evidence: Evidence,
): string {
  const lines = [
    ...Object.entries(fresh).map(
      ([name, c]) => `- ${name} (${c.kind}): ${c.signals.map(s => SIGNAL_TEXT[s]).join('; ')}`,
    ),
    ...open.map(
      s => `- ${s.name} (${s.kind}): started in an earlier turn${s.note ? ` (${s.note})` : ''}; did it finish in this turn?`,
    ),
  ]
  return `You label workflow steps in one turn of a coding-agent session. A step is a skill (a named procedure the agent follows) or a prompt snippet (a canned instruction the user pasted). Naming a step is not running it: the user may only be asking whether it ran, and the agent may decline or defer it.

<user_prompt>
${clip(evidence.prompt, 2000, 'start')}
</user_prompt>

<tool_calls>
${evidence.trail.join('\n') || '(none)'}
</tool_calls>

<final_answer>
${clip(evidence.answer, 3000, 'end')}
</final_answer>

<candidates>
${lines.join('\n')}
</candidates>

Label each candidate:
- done: the agent carried the step out in this turn and it finished.
- started: the agent launched it and its result is still pending, such as a background run it is waiting on.
- mentioned: it was only discussed, asked about, declined or deferred.

Reply with one line per candidate and nothing else, in this form:
name | status | what came of it, in at most 12 words`
}

const STATUSES: readonly StepStatus[] = ['done', 'started', 'mentioned']

/** The judge's lines, as `name → status and note`; a line that names no candidate is dropped. */
export function parseVerdicts(
  reply: string,
  names: readonly string[],
): Record<string, { status: StepStatus; note?: string }> {
  const out: Record<string, { status: StepStatus; note?: string }> = {}
  for (const line of reply.split('\n')) {
    const [name, status, ...rest] = line.replace(/^[-*\s]+/, '').split('|').map(part => part.trim())
    const found = STATUSES.find(s => s === status?.toLowerCase())
    if (name === undefined || found === undefined || !names.includes(name)) continue
    const note = rest.join(' | ')
    out[name] = note === '' ? { status: found } : { status: found, note }
  }
  return out
}

/** The band's items: pinned steps available here first, then the rest that ran, newest first. */
export function bandItems(
  log: Readonly<Record<string, Step>>,
  pins: readonly string[],
  known: readonly string[],
): BandItem[] {
  const item = (name: string): BandItem => {
    const step = log[name]
    const ran = step !== undefined && step.status !== 'mentioned'
    return {
      name,
      label: ran && step.runs > 1 ? `${name} ×${step.runs}` : name,
      status: ran ? step.status : 'none',
    }
  }
  const pinned = pins.filter(name => known.includes(name) || log[name] !== undefined)
  const rest = Object.values(log)
    .filter(step => step.status !== 'mentioned' && !pins.includes(step.name))
    .sort((a, b) => b.lastTurn - a.lastTurn)
    .map(step => step.name)
  return [...pinned, ...rest].map(item)
}

const ago = (turn: number, now: number): string => {
  const n = Math.max(0, now - turn)
  return n === 0 ? 'this turn' : n === 1 ? '1 turn ago' : `${n} turns ago`
}

/** One step's detail line, as the pane and `/steps` show it. */
export function detail(step: Step, now: number): string {
  if (step.status === 'mentioned') return `named only, ${ago(step.lastTurn, now)}`
  const state = step.status === 'started' ? 'started, result pending' : 'ran'
  const count = step.runs > 1 ? ` ×${step.runs}` : ''
  const guess = step.isJudged ? '' : ', unjudged'
  return `${state}${count}, turn ${step.lastTurn} (${ago(step.lastTurn, now)}) via ${step.signals.join('+')}${guess}`
}

/** The whole log as text: what `/steps` prints and `/did` hands the fork. */
export function describe(log: Readonly<Record<string, Step>>, now: number): string {
  const steps = Object.values(log).sort((a, b) => b.lastTurn - a.lastTurn)
  if (steps.length === 0) return 'No skill or snippet has been recorded this session.'
  return steps
    .map(s => `${s.name} (${s.kind}): ${detail(s, now)}${s.note ? `. ${s.note}` : ''}`)
    .join('\n')
}

export function forkPrompt(ledger: string, question: string, now: number): string {
  return `Answer the question below about this conversation in at most four sentences: what was done, roughly when, and what is still open.

The harness recorded the workflow steps of this session as they happened. The record is reliable where earlier turns have been compacted out of your view; if it disagrees with what you can see, say so. The session is at turn ${now}.

<recorded_steps>
${ledger}
</recorded_steps>

<question>
${question}
</question>`
}

/** A transcript row as `$.session.messages()` returns it, as far as this reads it. */
export type PastMessage = {
  role: 'user' | 'assistant'
  text: string
  toolUses: readonly { tool: string; input: Readonly<Record<string, unknown>> }[]
}

const EXPANDED = /Base directory for this skill: \S*\/skills\/([^/\s]+)/g
const COMMAND = /<command-name>\/([\w:-]+)<\/command-name>/g

/**
 * The steps a transcript shows, for a session that was under way before the
 * mod loaded. Signals alone decide, so every step is unjudged, and a name that
 * was only mentioned is left out: the rows the engine injects name every skill.
 */
export function backfill(
  messages: readonly PastMessage[],
  snippets: readonly Snippet[],
  skills: readonly string[],
): { log: Record<string, Step>; turns: number } {
  const log: Record<string, Step> = {}
  let turns = 0
  let fresh: Record<string, StepCandidate> = {}
  const add = (name: string, kind: StepKind, signal: StepSignal) => {
    const signals = fresh[name]?.signals ?? []
    if (!signals.includes(signal)) fresh[name] = { kind, signals: [...signals, signal] }
  }
  const close = () => {
    for (const [name, candidate] of Object.entries(fresh)) {
      const verdict = assume(name, candidate, false)
      const step = verdict.status === 'mentioned' ? undefined : merge(log[name], verdict, turns)
      if (step !== undefined) log[name] = step
    }
    fresh = {}
  }
  for (const message of messages) {
    if (message.role === 'assistant') {
      for (const use of message.toolUses) {
        const { skill, file_path: path } = use.input
        if (use.tool === 'Skill' && typeof skill === 'string') add(bare(skill), 'skill', 'skill')
        const read = use.tool === 'Read' && typeof path === 'string' ? skillFromPath(path) : undefined
        if (read !== undefined) add(read, 'skill', 'read')
      }
      continue
    }
    // A skill's expanded body rides a user row of the turn that loaded it.
    const expanded = [...message.text.matchAll(EXPANDED)].flatMap(found => found[1] ?? [])
    for (const name of expanded) add(name, 'skill', 'skill')
    if (expanded.length > 0 || message.text.trim() === '') continue
    close()
    turns += 1
    for (const found of message.text.matchAll(COMMAND)) add(bare(found[1] ?? ''), 'skill', 'skill')
    for (const name of matchSnippets(message.text, snippets)) add(name, 'snippet', 'snippet')
    for (const name of mentions(message.text, skills)) add(name, 'skill', 'mention')
  }
  close()
  return { log, turns }
}
