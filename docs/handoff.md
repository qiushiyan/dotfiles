# The handoff loop's moving parts

`/handoff` writes a brief addressed to the next session's agent;
`/distill-handoffs` reconciles them against the repo — one landed branch's
briefs (the closeout pass, the common post-merge case), the whole folder, or
a question about what moves next. Satellite of
`docs/doc-loop.md` — that doc places both in the session loop; this one says
where the machinery lives, which is what you need before editing any of it.

## Three homes, and the split between them

The loop is split so that staleness cannot misroute a session:

- **`~/dev/brief`** (a separate repo, not stowed) — the `brief` CLI: the
  project-folder scheme, the fenced head grammar, the git/gh join, worktree
  placement, and the pickup pointer. **Read its `CLAUDE.md` before changing
  any surface this repo consumes** — it carries the mental model and consumer
  discovery rule.
- **`claude/.claude/skills/{handoff,distill-handoffs}/`** (here) — the judgment
  half: what a brief says, when one is earned, what a sweep verdict is. Prose
  only; the mechanism is the CLI (`brief closeout` is the sweep's input,
  `brief delete` its default retirement), and `handoff/SLUG-NAMING.md` is the
  slug contract.
- **`zsh/.config/zsh/git.zsh`** (here) — the `brief()` wrapper and its
  completion. It holds only what a parent shell alone can do: `brief start`
  needs its `cd` to stick, so the wrapper passes `--cd-file` and applies what
  lands there. The binary also works without the wrapper: standalone `start`
  prints a quoted `cd` command. Everything else is a straight exec of
  `~/.local/bin/brief`.

The shared worktree boundary is `gwt` on PATH (source: `~/dev/gwt`).
It owns configured paths, branch resolution, and worktree creation for the tmux popup,
`brief start`, and the `enter-worktree` skill. `make -C ~/dev/gwt install` installs it in `~/.local/bin`.

## The next session's first prompt

`brief start <slug>` places the worktree and gives the receiving agent a
pointer: invocation and goal, brief path, literal drift command, and pickup
gate last. The agent reads the brief itself. Its paths are repo-relative so
they survive the worktree switch; its prose calls itself "this brief" because
it outlives its filename.

`drift`, `show` and `check` accept the pointer's brief path from a checkout of
its project. Drift attributes PRs to At-pickup citations; `--show` includes
the touching commits' full stats. File citations count any file change.
Directories and globs scope symbol searches: attribution requires an added
or removed line containing a cited symbol. Without a symbol, those scopes
remain unscanned. Bare symbols identify occurrence files and count file changes.

`paths:` supplies fallback history when no claim citations can be scanned.
Missing references and live queries require their own checks; a no-match
result applies only to the reported scope. `check` warns when
a live claim lacks an observed result or explicit unverified explanation;
that warning leaves pickup available.

## The slug is the *next* session's branch

Naming a brief after today's branch files it under work that is already over,
and leaves the next worktree's name to be looked up. Named forward, one token
serves as brief name, branch, worktree dir and PR lookup key. That also closes
the lifecycle: the brief that spawned the session you are in is named for the
branch you are on, so retiring a spent one is a lookup rather than a hunt.
Review posture has no next worktree, so its slug is `review-<branch>`, and
cleanup checks both names. The cold-read test a slug has to pass lives in
`claude/.claude/skills/handoff/SLUG-NAMING.md`.

## Where briefs live

`~/dev/.handoffs/<project>/<slug>.md` — central, outside every worktree, a
sibling of `~/dev/.worktrees`. Living outside the project's own checkouts keeps
one brief visible from every worktree, whatever branch it is on.

A project folder takes one of two shapes, and the folder itself says which.
Flat: `<slug>.md` files and one `_clusters.md` note. With a root `README.md`:
briefs in domain folders, `<domain>/<slug>.md`, the root README holding the
order and each domain's README what its briefs are about — Planlab's domains
are its onboarding routes. A folder that is a git clone is shared across
machines and teammates (Planlab's is `planlab-ai/handoffs`, cloned at the same
path on the Mac mini): `brief start` pulls it first, and the handoff and sweep
skills end on `brief sync`. Evidence over 256 KB, nested repositories and
briefs `brief check` refuses stay on the machine that made them.

```text
work landed + durable knowledge has an owner → brief delete <slug>
live successor needs a unique passage          → brief retire <slug> --reason "kept: …"
premise died but useful work remains            → rewrite forward, then delete the old brief
```

The kept `.md.done` form is the exception, not the archive. The notes
(`_clusters.md`, or the READMEs) name live briefs and their order; retirement
removes the slug from them in the same change.

**Honesty floor:** a session that taught nothing transferable hands off state
and next move, and nothing else.
