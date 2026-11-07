import { describe, expect, mock, test } from 'claude-code/testing'

import { createdText, parsePlan, typed } from '../hooks/plan'
import { followed, mayCreate, parseTrees } from '../hooks/follow'

describe('plan', () => {
  test('a branch typed out is taken as written; an instruction is not a branch', () => {
    expect(typed('feat/answer-attachments')).toEqual({ branch: 'feat/answer-attachments', shouldContinue: false })
    expect(typed('fix/retry origin/develop')).toEqual({ branch: 'fix/retry', base: 'origin/develop', shouldContinue: false })
    expect(typed('go')).toBeUndefined()
    expect(typed('go with A')).toBeUndefined()
    expect(typed('create worktree and go fix it')).toBeUndefined()
    expect(typed('feat/../x')).toBeUndefined()
  })

  test("the fork's three lines become a plan; a reply with no usable branch is none", () => {
    expect(parsePlan('branch: `fix/claim-deadline`\nbase: none\ncontinue: yes')).toEqual({
      branch: 'fix/claim-deadline',
      shouldContinue: true,
    })
    expect(parsePlan('branch: feat/x\nbase: develop\ncontinue: no')).toEqual({ branch: 'feat/x', base: 'develop', shouldContinue: false })
    expect(parsePlan('I would call it "the retry fix".')).toBeUndefined()
    expect(parsePlan('branch: two words\nbase: none\ncontinue: no')).toBeUndefined()
  })

  test('the output says where the worktree is and what follows', () => {
    expect(createdText({ branch: 'feat/x', base: 'develop', shouldContinue: true }, '/w/feat/x')).toBe(
      'Worktree feat/x created at /w/feat/x, from develop. The session moves there now. The instruction given with /wt then follows as the next message; its worktree part is done.',
    )
    expect(createdText({ branch: 'feat/x', shouldContinue: false }, '/w/feat/x')).toBe(
      'Worktree feat/x created at /w/feat/x. The session moves there now.',
    )
  })
})

describe('wt', () => {
  const USAGE = { input_tokens: 1, output_tokens: 1, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
  const run = { origin: { kind: 'composer' as const }, presentation: { isFullscreen: false, columns: 80 } }
  const ok = (stdout: string) => ({ value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } })

  test('an instruction: the fork names the branch, gwt creates it, the session moves, the instruction follows', async ($, on) => {
    const clock = mock.clock(on)
    const ran: string[] = []
    const commands: string[] = []
    const prompts: { text: string; origin: unknown }[] = []
    let asked = ''
    on('command.register', ($, e) => ({ value: { command: e.name } }))
    on('session.start', ($, e) => ({ cwd: e.cwd }))
    on('process.run', ($, e) => {
      ran.push(e.argv.join(' '))
      return ok(e.argv[0] === 'git' ? 'fix/claim-loop\nfeat/board-view\n' : '/w/main/fix/retry-deadline\n')
    })
    on('model.fork', ($, e) => {
      asked = e.prompt
      return { value: { isAnswered: true, text: 'branch: fix/retry-deadline\nbase: none\ncontinue: yes', usage: USAGE } }
    })
    on('command.run', ($, e) => (commands.push(`/${e.command} ${e.args}`), { text: '' }))
    on('prompt.submit', ($, e) => (prompts.push({ text: e.text, origin: e.origin }), { text: e.text }))

    await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
    const answer = await $.command.run({ command: 'wt', args: 'create worktree and go fix it', ...run })
    expect(commands).toEqual([])
    await clock.settle()

    expect(asked).toContain('create worktree and go fix it')
    expect(asked).toContain('fix/claim-loop')
    expect(ran.at(-1)).toBe('gwt create --non-interactive fix/retry-deadline')
    expect(commands).toEqual(['/cd /w/main/fix/retry-deadline'])
    expect(answer.text).toContain('Worktree fix/retry-deadline created at /w/main/fix/retry-deadline. The session moves there now.')
    expect(prompts).toEqual([{ text: 'create worktree and go fix it', origin: { kind: 'plugin', name: 'worktree', asUser: true } }])
  })

  test('a typed branch asks no model, and a gwt failure moves nothing', async ($, on) => {
    mock.clock(on)
    const commands: string[] = []
    let forks = 0
    on('command.register', ($, e) => ({ value: { command: e.name } }))
    on('session.start', ($, e) => ({ cwd: e.cwd }))
    on('model.fork', () => ((forks += 1), { value: { isAnswered: false, reason: 'nothing-to-fork', usage: USAGE } }))
    on('process.run', () => ({
      value: { exitCode: 1, stdout: '', stderr: 'gwt: branch is checked out elsewhere', isStdoutTruncated: false, isStderrTruncated: false },
    }))
    on('command.run', ($, e) => (commands.push(e.command), { text: '' }))

    await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
    const answer = await $.command.run({ command: 'wt', args: 'feat/x', ...run })

    expect(forks).toBe(0)
    expect(commands).toEqual([])
    expect(answer.text).toBe('gwt could not create feat/x:\ngwt: branch is checked out elsewhere')
  })

  test('a refused move says so in the transcript and submits nothing', async ($, on) => {
    const clock = mock.clock(on)
    const logs: string[] = []
    const prompts: string[] = []
    on('command.register', ($, e) => ({ value: { command: e.name } }))
    on('session.start', ($, e) => ({ cwd: e.cwd }))
    on('process.run', () => ok('/w/main/feat/x\n'))
    on('model.fork', () => ({ value: { isAnswered: true, text: 'branch: feat/x\nbase: none\ncontinue: yes', usage: USAGE } }))
    on('command.run', () => {
      throw new Error('no such directory')
    })
    on('ui.log', ($, e) => (logs.push(e.text), { value: undefined }))
    on('prompt.submit', ($, e) => (prompts.push(e.text), { text: e.text }))

    await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
    await $.command.run({ command: 'wt', args: 'go fix it', ...run })
    await clock.settle()

    expect(logs).toHaveLength(1)
    expect(logs[0]).toContain('the session did not move')
    expect(logs[0]).toContain('Run /cd /w/main/feat/x')
    expect(prompts).toEqual([])
  })
})

describe('follow', () => {
  const MAIN = '/repo'
  const ROOT = '/w/repo'
  const WT = `${ROOT}/feat/x`
  const porcelain = (trees: { path: string; branch?: string }[]) =>
    trees.map(t => `worktree ${t.path}\nHEAD abc\n${t.branch === undefined ? 'detached' : `branch refs/heads/${t.branch}`}\n`).join('\n')
  const ok = (stdout: string) => ({ value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } })
  const ended = { reason: 'answer', answer: 'done' } as never

  /** A repository and shell: `made` joins the registry when a command naming it runs, and `cd` moves `here` unless the shell snaps back. */
  function world(on: Parameters<typeof mock.clock>[0], options: { made?: { path: string; branch?: string }[]; snapsBack?: boolean; gitDir?: string } = {}) {
    const state = { here: MAIN, trees: [{ path: MAIN, branch: 'main' }] as { path: string; branch?: string }[], bash: [] as string[], commands: [] as string[], git: 0 }
    on('command.register', ($, e) => ({ value: { command: e.name } }))
    on('session.start', ($, e) => ({ cwd: e.cwd }))
    on('turn.complete', () => ({ text: '' }))
    on('session.cwd', () => ({ value: state.here }))
    on('process.run', ($, e) => {
      if (e.argv[0] === 'gwt') return ok(`${ROOT}\n`)
      state.git += 1
      if (e.argv[1] !== 'rev-parse') return ok(porcelain(state.trees))
      // as git answers from a subdirectory: the common dir is relative unless asked otherwise
      const common = e.argv.includes('--path-format=absolute') ? `${MAIN}/.git` : '../../.git'
      return ok(`${options.gitDir ?? `${MAIN}/.git`}\n${common}\n`)
    })
    on('tool.call', ($, e) => {
      const { command } = e as unknown as { command: string }
      state.bash.push(command)
      if (command === 'pwd -P') return { result: {}, text: `${state.here}\n` }
      const cd = /^cd '(.+)'$/.exec(command)
      if (cd?.[1] !== undefined && options.snapsBack !== true) state.here = cd[1]
      if (cd === null) state.trees.push(...(options.made ?? []))
      return { result: {}, text: '' }
    })
    on('command.run', ($, e) => (state.commands.push(`/${e.command} ${e.args}`), { text: '' }))
    return state
  }
  const bash = (command: string, more: object = {}) => ({ tool: 'Bash', command, ...more }) as never

  test('what may create one: gwt and git worktree add, not a name that merely holds the word', () => {
    expect(mayCreate('P=$(gwt create -n feat/x 2>/dev/null); echo made')).toBe(true)
    expect(mayCreate('gwt feat/x -n')).toBe(true)
    expect(mayCreate('git -C /repo worktree add ../x')).toBe(true)
    expect(mayCreate('rex-worktree feat/x')).toBe(false)
    expect(mayCreate('git worktree list')).toBe(false)
    expect(mayCreate('pnpm test')).toBe(false)
  })

  test('the one new branch checkout under the root is followed; anything else is not', () => {
    const before = parseTrees(porcelain([{ path: MAIN, branch: 'main' }]))
    const after = (...more: { path: string; branch?: string }[]) => parseTrees(porcelain([{ path: MAIN, branch: 'main' }, ...more]))
    expect(followed(before, after({ path: WT, branch: 'feat/x' }), ROOT)?.path).toBe(WT)
    expect(followed(before, after({ path: `${ROOT}/base` }), ROOT)).toBeUndefined()
    expect(followed(before, after({ path: '/tmp/scratch', branch: 'feat/x' }), ROOT)).toBeUndefined()
    expect(followed(before, after({ path: `${ROOT}-other/x`, branch: 'x' }), ROOT)).toBeUndefined()
    expect(followed(before, after({ path: WT, branch: 'a' }, { path: `${ROOT}/b`, branch: 'b' }), ROOT)).toBeUndefined()
    expect(followed(before, after(), ROOT)).toBeUndefined()
  })

  test('a new worktree: the shell enters it at once, the model is told, and /cd lands when the turn ends', async ($, on) => {
    const clock = mock.clock(on)
    const state = world(on, { made: [{ path: WT, branch: 'feat/x' }] })
    await $.session.start({ cwd: MAIN, surface: 'terminal', isInteractive: true })

    const ran = await $.tool.call(bash('P=$(gwt create -n feat/x 2>/dev/null); echo made'))
    expect(state.bash.slice(-2)).toEqual([`cd '${WT}'`, 'pwd -P'])
    expect(ran.context?.join('\n')).toContain(WT)
    expect(ran.context?.join('\n')).toContain('run commands as they are')
    expect(state.commands).toEqual([])

    await $.turn.complete(ended)
    await clock.settle()
    expect(state.commands).toEqual([`/cd ${WT}`])

    await $.turn.complete(ended)
    await clock.settle()
    expect(state.commands).toHaveLength(1)
  })

  test('a shell that snaps back is not reported as moved, and /cd still lands', async ($, on) => {
    const clock = mock.clock(on)
    const state = world(on, { made: [{ path: WT, branch: 'feat/x' }], snapsBack: true })
    const logs: string[] = []
    on('ui.log', ($, e) => (logs.push(e.text), { value: undefined }))
    await $.session.start({ cwd: MAIN, surface: 'terminal', isInteractive: true })

    const ran = await $.tool.call(bash('gwt create -n feat/x'))
    expect(logs.join('\n')).toContain('could not stay')
    expect(ran.context?.join('\n')).toContain('when this turn ends')
    expect(ran.context?.join('\n')).not.toContain('run commands as they are')

    await $.turn.complete(ended)
    await clock.settle()
    expect(state.commands).toEqual([`/cd ${WT}`])
  })

  test('a session that left the worktree before its turn ended stays where it went', async ($, on) => {
    const clock = mock.clock(on)
    const state = world(on, { made: [{ path: WT, branch: 'feat/x' }] })
    await $.session.start({ cwd: MAIN, surface: 'terminal', isInteractive: true })
    await $.tool.call(bash('gwt create -n feat/x'))
    state.here = MAIN

    await $.turn.complete(ended)
    await clock.settle()
    expect(state.commands).toEqual([])
  })

  test('a subagent, a linked worktree, and a command that names neither tool move nothing', async ($, on) => {
    const clock = mock.clock(on)
    const state = world(on, { made: [{ path: WT, branch: 'feat/x' }] })
    await $.session.start({ cwd: MAIN, surface: 'terminal', isInteractive: true })

    await $.tool.call(bash('pnpm test'))
    expect(state.git).toBe(0)

    await $.tool.call(bash('gwt create -n feat/x', { agentId: 'a1' }))
    await $.turn.complete(ended)
    await clock.settle()
    expect(state.bash.filter(c => c.startsWith('cd '))).toEqual([])
    expect(state.commands).toEqual([])
  })

  test('a session already in a linked worktree stays there', async ($, on) => {
    const clock = mock.clock(on)
    const state = world(on, { made: [{ path: WT, branch: 'feat/x' }], gitDir: `${MAIN}/.git/worktrees/first` })
    await $.session.start({ cwd: MAIN, surface: 'terminal', isInteractive: true })

    await $.tool.call(bash('gwt create -n feat/x'))
    await $.turn.complete(ended)
    await clock.settle()
    expect(state.bash.filter(c => c.startsWith('cd '))).toEqual([])
    expect(state.commands).toEqual([])
  })
})
