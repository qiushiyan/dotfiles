// The mod's pure half: reading a branch out of what the person typed or out of
// the fork's reply, and the prompts either side reads.

export type Plan = { branch: string; base?: string; shouldContinue: boolean }

const REF = /^[A-Za-z0-9][A-Za-z0-9._/-]*$/
const isRef = (text: string): boolean => REF.test(text) && !text.includes('..') && !text.endsWith('/')

/**
 * The plan when the arguments are a branch and at most a base, typed out. A
 * branch typed out carries a slash: one bare word is an instruction ("go").
 */
export function typed(args: string): Plan | undefined {
  const [branch, base, ...more] = args.trim().split(/\s+/)
  if (branch === undefined || more.length > 0 || !branch.includes('/') || !isRef(branch)) return undefined
  if (base !== undefined && !isRef(base)) return undefined
  return base === undefined ? { branch, shouldContinue: false } : { branch, base, shouldContinue: false }
}

export function namePrompt(instruction: string, branches: readonly string[]): string {
  return `The user ran /wt to move this session into a new git worktree for the work this conversation has settled on. Their instruction with the command:

<instruction>
${instruction === '' ? '(none)' : instruction}
</instruction>

Choose the branch. Its name describes the goal and scope of that work and follows this repository's naming conventions, which the most recent branches show:

<recent_branches>
${branches.length === 0 ? '(none)' : branches.join('\n')}
</recent_branches>

Name a base only when the conversation chose one; with none, the tool applies its configured default.

Reply with exactly these three lines and nothing else:
branch: <the branch name>
base: <a ref, or none>
continue: <yes when the instruction asks for work beyond creating or entering the worktree, else no>`
}

const field = (reply: string, name: string): string | undefined =>
  new RegExp(`^\\s*${name}:\\s*\`?([^\\s\`]+)\`?\\s*$`, 'im').exec(reply)?.[1]

/** The fork's three lines as a plan; undefined when the branch is missing or not a ref. */
export function parsePlan(reply: string): Plan | undefined {
  const branch = field(reply, 'branch')
  const base = field(reply, 'base')
  if (branch === undefined || !isRef(branch)) return undefined
  const shouldContinue = field(reply, 'continue')?.toLowerCase() === 'yes'
  return base === undefined || base.toLowerCase() === 'none' || !isRef(base)
    ? { branch, shouldContinue }
    : { branch, base, shouldContinue }
}

/** What the transcript, and so the model, reads as the command's output: the move itself comes next. */
export function createdText(plan: Plan, path: string): string {
  const from = plan.base === undefined ? '' : `, from ${plan.base}`
  const next = plan.shouldContinue
    ? ' The instruction given with /wt then follows as the next message; its worktree part is done.'
    : ''
  return `Worktree ${plan.branch} created at ${path}${from}. The session moves there now.${next}`
}
