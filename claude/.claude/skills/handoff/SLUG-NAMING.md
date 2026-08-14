# Naming a handoff slug

The slug is one token doing four jobs: the baton's filename, the git branch,
the worktree directory, and the key `baton-index.sh` resolves branch and PR
state through. Named once well, all four read well.

## The cold-read test

The name is read **cold** — days later, from a branch listing, a worktree leaf
or a tmux window, with none of the prose around it. It passes when someone who
did not attend the session can say **which part of the system it touches** and
**what will be different about it**.

That is two halves:

- **a place** — the subsystem the work lands in
- **an outcome** — what changes there

Both halves use words that already exist in the tree — a doc basename, a
package, the domain's own term — so a cold reader can grep the name and land
somewhere. That is the operative property: not *no jargon*, but jargon with a
**greppable home**. `scheduler-retry-ceiling` resolves in one grep;
`retry-backoff-ceiling` names a real outcome and resolves only in its author's
head.

## Shape

`<prefix>/<place>-<outcome>`, lowercase kebab, 2–4 words after the prefix.
Where the repo uses a `feat/`-style prefix, that prefix names the **kind of
change**, and it nests the baton exactly as it nests the worktree.

Take the outcome words from the goal already written on line 1 rather than
coining a fresh phrase for the filename: you name it at your most context-rich,
which is exactly when a private shorthand feels self-evident.

## Cases

- **Spanning several subsystems** — name the one where the load-bearing change
  lands, or the capability itself in the domain's words.
- **Outside any documented tree** — take the vocabulary from whatever tree owns
  the work.
- **A name for where the work is going**, not where it has been: today's branch
  plus a suffix (`-followup`, `-part-2`, a trailing date) names the road behind.
