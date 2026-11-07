// Following a worktree the session made: the pure half. Git's own registry says
// what was made, so the spelling of the command that made it does not matter.

export type Tree = { path: string; branch?: string }

/** A Bash command worth listing worktrees around. `rex-worktree` opens one for another session. */
export const mayCreate = (command: string): boolean => /(^|[^\w-])gwt\b|\bworktree\s+add\b/.test(command)

export function parseTrees(porcelain: string): Tree[] {
  return porcelain.split(/\n\n+/).flatMap(block => {
    const path = /^worktree (.+)$/m.exec(block)?.[1]
    const branch = /^branch refs\/heads\/(.+)$/m.exec(block)?.[1]
    if (path === undefined) return []
    return branch === undefined ? [{ path }] : [{ path, branch }]
  })
}

/**
 * The checkout to follow: the one new tree on a branch under this repository's
 * worktree root. A detached or scratch checkout is a look at other code, not
 * the session's new home, and two new ones leave nothing to choose by.
 */
export function followed(before: readonly Tree[], after: readonly Tree[], root: string): Tree | undefined {
  const known = new Set(before.map(tree => tree.path))
  const fresh = after.filter(tree => !known.has(tree.path) && tree.branch !== undefined && tree.path.startsWith(`${root}/`))
  return fresh.length === 1 ? fresh[0] : undefined
}

export const quoted = (path: string): string => `'${path.replaceAll("'", `'\\''`)}'`

/** What the model reads beside the command that made the worktree. */
export function followText(tree: Tree, isThere: boolean): string {
  return isThere
    ? `This session moved into the new worktree ${tree.path} (branch ${tree.branch}). Bash and relative paths resolve there from now on, so run each command from here.`
    : `This session moves into the new worktree ${tree.path} (branch ${tree.branch}) when this turn ends. Until then, name that path in each command.`
}
