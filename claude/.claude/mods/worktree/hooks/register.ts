// worktree: /wt puts the session in a new worktree without a turn of the main
// model. A fork of the session picks the branch (the same model over the same
// conversation, served from the prompt cache) and gwt creates it. Then, once
// the command has answered, the built-in /cd moves the session and the
// instruction typed with /wt is submitted as the person's next prompt, so
// work starts in the worktree at once.
//
// A worktree the session makes for itself is followed the same way, so nothing
// has to be typed: the shell enters it at once, and /cd makes the move last when
// the turn ends, which is what a resumed session and drive read. A shell move
// alone reopens on the launch directory while the conversation says otherwise.

import type { EngineInterface, Register } from 'claude-code'

import { followed, followText, mayCreate, parseTrees, quoted } from './follow'
import type { Tree } from './follow'
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

/** The stdout of a command in the session's directory; undefined when it fails. */
async function stdout($: EngineInterface, argv: string[]): Promise<string | undefined> {
  const ran = await $.process.run(argv).catch(() => undefined)
  return ran === undefined || ran.exitCode !== 0 ? undefined : ran.stdout
}

async function listTrees($: EngineInterface): Promise<Tree[]> {
  return parseTrees((await stdout($, ['git', 'worktree', 'list', '--porcelain'])) ?? '')
}

/**
 * A session in a linked worktree stays there: what it makes next is not its own
 * move. Absolute, since from a subdirectory the common dir prints relative.
 */
async function isInMainCheckout($: EngineInterface): Promise<boolean> {
  const [gitDir, commonDir] = ((await stdout($, ['git', 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir'])) ?? '').split('\n')
  return gitDir !== undefined && gitDir !== '' && gitDir === commonDir
}

/**
 * Whether the shell now stands in path. Only the shell can say: a directory
 * outside the session's working directories resets, and $.session.cwd() reads
 * the old directory until the call that ran the `cd` has finished.
 */
async function enterShell($: EngineInterface, path: string): Promise<boolean> {
  const shell = async (command: string, description: string) =>
    (await $.tool.call({ tool: 'Bash', command, description }).catch(() => undefined))?.text ?? ''
  await shell(`cd ${quoted(path)}`, 'Enter the new worktree')
  return (await shell('pwd -P', 'Confirm the shell is there')).trim().split('\n')[0] === path
}

async function move($: EngineInterface, path: string): Promise<string | undefined> {
  return $.command.run({ command: 'cd', args: path }).then(
    () => undefined,
    (error: unknown) => String(error),
  )
}

/**
 * Moves the session, then hands over the instruction. It runs from a timer:
 * the engine refuses a command run from inside a `command.run` hook, which
 * would wait on the turn that hook is holding.
 */
async function enter($: EngineInterface, plan: Plan, path: string, instruction: string) {
  const refusal = await move($, path)
  if (refusal !== undefined) {
    $.ui.log(`worktree: the session did not move (${refusal}). Run /cd ${path}`)
    return
  }
  if (plan.shouldContinue) await $.prompt.submit({ text: instruction, asUser: true })
}

export const register: Register = on => {
  /** A worktree this session entered, until its turn ends; `wasEntered` when the shell really went. */
  let followedTree: { path: string; wasEntered: boolean } | undefined

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    if (e.tool !== 'Bash' || e.agentId !== undefined || !mayCreate(e.command)) return next(e)
    const before = await listTrees($)
    const isMain = before.length > 0 && (await isInMainCheckout($))
    const ran = await next(e)
    if (!isMain || ran.deny !== undefined) return ran

    const after = await listTrees($)
    if (after.length <= before.length) return ran
    const root = (await stdout($, ['gwt', 'path']))?.trim()
    const tree = root === undefined || root === '' ? undefined : followed(before, after, root)
    if (tree === undefined) return ran

    const wasEntered = await enterShell($, tree.path)
    if (!wasEntered) {
      $.ui.log(`worktree: the shell could not stay in ${tree.path}, so the session moves there when this turn ends; ${root} is outside this session's working directories, or CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR is set.`)
    }
    followedTree = { path: tree.path, wasEntered }
    return { ...ran, context: [...(ran.context ?? []), followText(tree, wasEntered)] }
  })

  on('turn.complete', async ($, e, next) => {
    const answer = await next(e)
    if (e.agentId !== undefined || followedTree === undefined) return answer
    const { path, wasEntered } = followedTree
    followedTree = undefined
    if (wasEntered && (await $.session.cwd()) !== path) return answer
    $.clock.after(0, () => void move($, path).then(refusal => {
      if (refusal !== undefined) $.ui.log(`worktree: the session did not move (${refusal}). Run /cd ${path}`)
    }))
    return answer
  })

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
