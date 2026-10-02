// worktree: /wt puts the session in a new worktree without a turn of the main
// model. A fork of the session picks the branch (the same model over the same
// conversation, served from the prompt cache) and gwt creates it. Then, once
// the command has answered, the built-in /cd moves the session and the
// instruction typed with /wt is submitted as the person's next prompt, so
// work starts in the worktree at once.
//
// The enter-worktree skill does the same through a full turn and cannot go on
// in that turn, since its move lands when the turn ends; it stays for Codex.

import type { EngineInterface, Register } from 'claude-code'

import { createdText, namePrompt, parsePlan, typed } from './plan'
import type { Plan } from './plan'

async function recentBranches($: EngineInterface): Promise<string[]> {
  const ran = await $.process
    .run(['git', 'for-each-ref', '--sort=-committerdate', '--count=20', '--format=%(refname:short)', 'refs/heads'])
    .catch(() => undefined)
  return ran === undefined || ran.exitCode !== 0 ? [] : ran.stdout.split('\n').filter(line => line !== '')
}

async function choose($: EngineInterface, instruction: string): Promise<Plan | string> {
  const reply = await $.model.fork({ prompt: namePrompt(instruction, await recentBranches($)) })
  if (!reply.isAnswered) {
    return reply.reason === 'nothing-to-fork'
      ? 'There is no conversation yet to name a branch from. Name one: /wt <branch> [base].'
      : `No branch name came back (${reply.reason}). Name one: /wt <branch> [base].`
  }
  return parsePlan(reply.text) ?? `The reply named no usable branch:\n${reply.text.trim()}\nName one: /wt <branch> [base].`
}

/**
 * Moves the session, then hands over the instruction. It runs from a timer:
 * the engine refuses a command run from inside a `command.run` hook, which
 * would wait on the turn that hook is holding.
 */
async function enter($: EngineInterface, plan: Plan, path: string, instruction: string) {
  const refusal = await $.command.run({ command: 'cd', args: path }).then(
    () => undefined,
    (error: unknown) => String(error),
  )
  if (refusal !== undefined) {
    $.ui.log(`worktree: the session did not move (${refusal}). Run /cd ${path}`)
    return
  }
  if (plan.shouldContinue) await $.prompt.submit({ text: instruction, asUser: true })
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'wt',
      description: 'Create a worktree for the work under discussion and move the session into it',
      argumentHint: '[<branch> [base] | what to do once there]',
    })

    return next(e)
  })

  on('command.run', { command: 'wt' }, async ($, e) => {
    const instruction = e.args.trim()
    const plan = typed(instruction) ?? (await choose($, instruction))
    if (typeof plan === 'string') return { text: plan }

    const argv = ['gwt', 'create', '--non-interactive', plan.branch, ...(plan.base === undefined ? [] : [plan.base])]
    const made = await $.process.run(argv, { timeoutMs: 120_000 }).catch((error: unknown) => String(error))
    if (typeof made === 'string') return { text: `gwt did not run: ${made}` }
    const path = made.stdout.trim().split('\n').at(-1) ?? ''
    if (made.exitCode !== 0 || path === '') {
      return { text: `gwt could not create ${plan.branch}:\n${made.stderr.trim()}` }
    }

    $.clock.after(0, () => void enter($, plan, path, instruction))

    return { text: createdText(plan, path) }
  })
}
