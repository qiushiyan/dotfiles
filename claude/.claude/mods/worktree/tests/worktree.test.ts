import { describe, expect, mock, test } from 'claude-code/testing'

import { createdText, parsePlan, typed } from '../hooks/plan'

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
