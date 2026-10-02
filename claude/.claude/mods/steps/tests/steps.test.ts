import { describe, expect, mock, test } from 'claude-code/testing'

import {
  assume,
  backfill,
  bandItems,
  matchSnippets,
  mentions,
  merge,
  parseSnippets,
  parseVerdicts,
  skillFromPath,
} from '../hooks/detect'

const TOML = `trigger = ";;"

[[snippets]]
key = "prompt-check"
expand = '''
Review and revise the model-facing surfaces this session touched — prompts, skill bodies, CLAUDE.md — against the rulebook.

Report each finding as a named defect with its fix.'''

[[snippets]]
key = "commits-summary"
expand = "Commits summary for high-level changes, grouped by the behavior each one changes."

[[snippets]]
key = "postal"
expand = "AB1 2CD"
`

const BAND = { hasSurvey: false, isWorking: false, maxRows: 3, bodyColumns: 120, scroll: { offset: 0, bodyRows: 3 }, view: {} }
const USAGE = { input_tokens: 1, output_tokens: 1, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }

describe('signals', () => {
  test('a snippet is found by its opening text, and a short one is never tracked', () => {
    const snippets = parseSnippets(TOML)
    expect(snippets.map(s => s.key)).toEqual(['prompt-check', 'commits-summary'])

    const pasted = 'Review and revise the model-facing surfaces this session\ntouched — prompts, skill bodies, CLAUDE.md — against the rulebook. Also check the errors.'
    expect(matchSnippets(pasted, snippets)).toEqual(['prompt-check'])
    expect(matchSnippets('did we run the prompt check yet?', snippets)).toEqual([])
  })

  test('a hyphenated skill counts bare, a one-word skill only as a command, path or "x skill"', () => {
    const names = ['pl-loopy', 'pl-loopy-verify', 'review', 'spike', 'prompt-engineering']
    expect(mentions('test this with pl-loopy-verify before merging', names)).toEqual(['pl-loopy-verify'])
    expect(mentions('please review this diff and spike nothing', names)).toEqual([])
    expect(mentions('/review codex full review', names)).toEqual(['review'])
    expect(mentions('use the spike skill; read ~/x/skills/prompt-engineering/SKILL.md', names)).toEqual([
      'spike',
      'prompt-engineering',
    ])
  })

  test('a SKILL.md path names its skill', () => {
    expect(skillFromPath('/Users/me/.claude/skills/update-docs/SKILL.md')).toBe('update-docs')
    expect(skillFromPath('/Users/me/.claude/skills/update-docs/NOTES.md')).toBeUndefined()
  })
})

describe('verdicts', () => {
  test('the judge downgrading a step undoes the run the signals assumed', () => {
    const candidate = { kind: 'skill' as const, signals: ['skill' as const] }
    const assumed = merge(undefined, assume('consult', candidate, false), 4)
    expect(assumed).toMatchObject({ status: 'done', runs: 1, isJudged: false })

    const judged = merge(undefined, { name: 'consult', ...candidate, status: 'mentioned', isJudged: true, isFollowUp: false }, 4)
    expect(judged).toMatchObject({ status: 'mentioned', runs: 0 })
  })

  test('a started step finishing in a later turn is one run, not two', () => {
    const candidate = { kind: 'skill' as const, signals: ['skill' as const] }
    const started = merge(undefined, { name: 'review', ...candidate, status: 'started', note: 'codex running', isJudged: true, isFollowUp: false }, 7)
    const finished = merge(started, { name: 'review', kind: 'skill', signals: [], status: 'done', note: '3 findings applied', isJudged: true, isFollowUp: true }, 9)
    expect(finished).toMatchObject({ status: 'done', runs: 1, firstTurn: 7, lastTurn: 9, note: '3 findings applied' })
  })

  test('a name in the prompt alone is a mention, and never unseats a step that ran', () => {
    const named = assume('pl-loopy-verify', { kind: 'skill', signals: ['mention'] }, false)
    expect(named.status).toBe('mentioned')

    const ran = merge(undefined, assume('pl-loopy-verify', { kind: 'skill', signals: ['skill'] }, false), 2)
    expect(merge(ran, named, 12)).toEqual(ran)
  })

  test('the judge reply is read line by line; a line naming no candidate is dropped', () => {
    const reply = 'update-docs | done | three docs updated and committed\n- consult | Started | codex run in background\nother | done | x\nnonsense'
    expect(parseVerdicts(reply, ['update-docs', 'consult'])).toEqual({
      'update-docs': { status: 'done', note: 'three docs updated and committed' },
      consult: { status: 'started', note: 'codex run in background' },
    })
  })

  test('the band lists pinned steps that exist here, then the rest that ran', () => {
    const log = {
      spike: { name: 'spike', kind: 'skill' as const, status: 'done' as const, runs: 2, firstTurn: 1, lastTurn: 5, signals: [], isJudged: true },
      teach: { name: 'teach', kind: 'skill' as const, status: 'mentioned' as const, runs: 0, firstTurn: 3, lastTurn: 3, signals: [], isJudged: true },
    }
    expect(bandItems(log, ['review', 'pl-loopy-verify'], ['review', 'spike'])).toEqual([
      { name: 'review', label: 'review', status: 'none' },
      { name: 'spike', label: 'spike ×2', status: 'done' },
    ])
  })
})

describe('backfill', () => {
  const user = (text: string) => ({ role: 'user' as const, text, toolUses: [] })
  const uses = (tool: string, input: Record<string, unknown>) => ({ role: 'assistant' as const, text: '', toolUses: [{ tool, input }] })

  test('a transcript yields the steps that ran, by turn, and leaves out names only mentioned', () => {
    const snippets = parseSnippets(TOML)
    const { log, turns } = backfill(
      [
        user('available skills: update-docs, pl-loopy-verify, consult'),
        user('<command-message>update-docs</command-message> <command-name>/update-docs</command-name>'),
        user('Base directory for this skill: /Users/me/.claude/skills/update-docs\n\n# Update docs'),
        uses('Edit', { file_path: 'docs/zsh.md' }),
        user('now run a consult round with codex'),
        uses('Skill', { skill: 'claude:consult' }),
        user(''),
        user('Review and revise the model-facing surfaces this session touched — prompts, skill bodies, CLAUDE.md — against the rulebook.'),
        user('did we run pl-loopy-verify yet?'),
      ],
      snippets,
      ['update-docs', 'pl-loopy-verify', 'consult'],
    )

    expect(turns).toBe(5)
    expect(Object.keys(log).sort()).toEqual(['consult', 'prompt-check', 'update-docs'])
    expect(log['update-docs']).toMatchObject({ status: 'done', runs: 1, lastTurn: 2, isJudged: false })
    expect(log['consult']).toMatchObject({ status: 'done', lastTurn: 3 })
    expect(log['prompt-check']).toMatchObject({ kind: 'snippet', lastTurn: 4 })
  })
})

describe('steps', () => {
  test('a skill expanded in a turn shows in the band, and the judge decides how', async ($, on) => {
    mock.store(on)
    mock.env(on, { HOME: '/home/me' })
    const clock = mock.clock(on)
    on('fs.read', () => ({ value: TOML }))
    on('command.list', () => ({ value: [] }))
    on('session.turns', () => ({ value: 3 }))
    on('session.id', () => ({ value: 's1' }))
    on('session.messages', () => ({ value: [] }))
    on('command.register', ($, e) => ({ value: { command: e.name } }))
    on('session.start', ($, e) => ({ cwd: e.cwd }))
    on('skill.prompt', ($, e) => ({ text: e.text }))
    on('turn.complete', ($, e) => ({ text: e.answer }))
    on('model.complete', () => ({
      value: { isAnswered: true, text: 'consult | started | codex consult running in background', usage: USAGE },
    }))

    await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
    await $.skill.prompt({ skill: 'consult', text: 'the skill body' })
    await $.turn.complete({ answer: 'Launched the consult.', durationMs: 5, isAborted: false, turnId: 't1', reason: 'answer' })

    for (const surface of ['terminal', 'desktop'] as const) {
      const ui = await $.ui.mount({ plugin: 'steps', surface, component: 'AbovePrompt', props: BAND })
      expect((await ui.find({ type: 'Text', text: /consult/ }))?.text).toContain('✓ consult')
      await ui.unmount()
    }

    await clock.settle()

    const ui = await $.ui.mount({ plugin: 'steps', surface: 'terminal', component: 'AbovePrompt', props: BAND })
    expect((await ui.find({ type: 'Text', text: /consult/ }))?.text).toContain('◐ consult')
    await ui.unmount()
  })
})
