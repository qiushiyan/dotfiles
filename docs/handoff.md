# The handoff baton

`/handoff` writes a brief addressed to the next session's agent. Satellite of
`docs/doc-loop.md` — that doc places the handoff in the session loop; this one
is the mechanism, needed when editing the skill or `handoff-path.sh`.

## It *is* the next first prompt

Not a document about the work. The flow is: new worktree → `pbcopy <` the baton
→ paste. Everything follows from that:

- Line 1 is the `/onboarding <topic>` invocation, with no title above it.
- Paths stay repo-relative, so they survive the worktree switch.
- The text calls itself "this brief" and never tells the agent to read a file —
  the paste *is* the delivery. Onboarding skills stay neutral and never
  auto-read it.

## The gate

`/handoff` asks one question first, and the answer decides the shape:

- **Thread continues** → full handoff.
- **Stopped mid-task** → baton now; the doc pass becomes the next session's
  first move.
- **Work done, nothing queued** → doc pass only, and the spent baton that
  spawned this session gets deleted. A manufactured or stale baton is worse than
  none.

Pass the answer inline to skip the question: `/handoff next: wire the retry path`.

## The slug is the *next* session's branch

Naming a baton after today's branch files it under work that is already over,
and leaves the next worktree's name to be looked up. Named forward, one token
serves as baton name, branch, and worktree: the filename is the argument to
`gwt <slug>`.

That also closes the lifecycle — the baton that spawned the session you are in
is named for the branch you are on, so deleting a spent one is a lookup rather
than a hunt. Review posture has no next worktree, so its slug is
`review-<branch>`; cleanup checks both names.

## The path is computed, not prompted

`claude/.claude/skills/handoff/handoff-path.sh <slug>` prints the baton path and
creates its folder, so the skill carries no derivation to re-run and no
repo-layout examples to rot. `handoff-path.test.sh` pins the behavior.

Two things in it look like bugs and are not:

- An ordinary checkout (submodules included) is named by `--show-toplevel`, but
  a linked worktree by `--git-common-dir` — each query returns git's plumbing
  for the other case.
- Flattening the `~/dev` path with `-` is not injective. Accepted, because it
  removes the realistic collision — every `<project>/main` sharing one folder —
  without maintaining a special-case list.

Team-shared `pl-loopy-handoff` cannot call the helper, so it hardcodes its
project name.

## Where batons live

`~/dev/.handoffs/<repo>/<slug>.md` — central, outside every worktree, a sibling
of `~/dev/.worktrees`. It holds state, lessons and dead-ends with their *why*,
and first moves (reads, claims to verify, a no-code-first synthesis gate).

Living outside git entirely means the central folder needs no ignore rules, and
its per-project folders double as the archive: `ls -lt` orders them, and the
date lives in the baton's body rather than its name. Projects with linear
roadmaps may still archive copies in their records dir.

**Honesty floor:** a session that taught nothing transferable hands off state and
next move, and nothing else.
