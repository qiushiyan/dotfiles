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
- **A name for where the work is going**, not where it has been. Today's branch
  is merged or nearly so, so a name taken from it files the baton under work
  that is already over, and hides the one thing you would open the file to
  find — the next worktree's name. That branch plus a suffix (`-followup`,
  `-part-2`, a trailing date) does the same.
- **A review-posture baton** is named `review-<branch under review>` instead.
  It creates no branch and no worktree, so the shape above does not apply to
  it; `baton-index.sh` resolves its state by the subject after the prefix.

## Renaming one

The slug is a filename, a branch, a worktree and a lookup key at once, so a
rename is a graph edit rather than a file move — and it is only cheap while the
baton is unstarted (`baton-index.sh` says `unstarted`: no branch, no worktree).
Once someone has run `gwt`, the rename costs a branch and a worktree too.

Move the file, then sweep the handoff folder for the old slug and update every
hit: `blocked-by:` and `collides-with:` in sibling batons, any prose naming the
baton — including its own body, which often names the worktree it opens — and
`_clusters.md`. Re-run the index afterwards: those fields are printed verbatim,
so a dangling slug survives silently in the STATE column.

The sweep stops at the handoff folder. A repo's own dated records — specs,
issue records, execution records — name what the baton was called at the time,
and leaving them alone is what keeps them evidence.
