# Naming a handoff slug

The slug is one token doing four jobs: the brief's filename, the git branch,
the worktree directory, and the key branch and PR state resolve through.
Named once well, all four read well.

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
change**, and it nests the brief exactly as it nests the worktree.

Take the outcome words from the goal you have already written rather than
coining a fresh phrase for the filename: you name it at your most context-rich,
which is exactly when a private shorthand feels self-evident.

## Cases

- **Spanning several subsystems** — name the one where the load-bearing change
  lands, or the capability itself in the domain's words.
- **Outside any documented tree** — take the vocabulary from whatever tree owns
  the work.
- **A name for where the work is going**, not where it has been. Today's branch
  is merged or nearly so, so a name taken from it files the brief under work
  that is already over, and hides the one thing you would open the file to
  find — the next worktree's name. That branch plus a suffix (`-followup`,
  `-part-2`, a trailing date) does the same.
- **A review-posture brief** is named `review-<branch under review>` instead.
  It creates no branch and no worktree, so the shape above does not apply to
  it; its state resolves by the subject after the prefix.

## Renaming one

The slug is a filename, a branch, a worktree and a lookup key at once, so a
rename is a graph edit rather than a file move — and it is only cheap while the
brief is unstarted (the listing says `unstarted`: no branch, no worktree).
Once a worktree exists, the rename costs a branch and a worktree too.

`brief mv <old> <new>` does the mechanical half: it moves the file, rewrites
sibling references in typed fields, and prints every remaining mention —
prose in sibling briefs, `_clusters.md`, the brief's own body — for you to
edit with judgement. Close with `brief check`: it resolves every sibling
reference, so a dangling slug fails loudly instead of surviving in prose.

The sweep stops at the handoff folder. A repo's own dated records — specs,
issue records, execution records — name what the brief was called at the time,
and leaving them alone is what keeps them evidence.
