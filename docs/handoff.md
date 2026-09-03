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
  placement, and the two-line pointer. Anything whose staleness could send a
  session to the wrong branch lives here, behind one parser. **Read its
  `CLAUDE.md` before changing any surface this repo consumes** — it carries
  the mental model and lists every consumer, these packages among them.
- **`claude/.claude/skills/{handoff,distill-handoffs}/`** (here) — the judgment
  half: what a brief says, when one is earned, what a sweep verdict is. Prose
  only; the mechanism is the CLI (`brief closeout` is the sweep's input,
  `brief delete` its default retirement), and `handoff/SLUG-NAMING.md` is the
  slug contract.
- **`zsh/.config/zsh/git.zsh`** (here) — the `brief()` wrapper and its
  completion. It holds only what a parent shell alone can do: `brief start`
  needs its `cd` to stick, so the wrapper passes `--cd-file` and applies what
  lands there. Everything else is a straight exec of `~/.local/bin/brief`.

The shared worktree boundary is `tmux/.config/tmux/scripts/worktree-core.sh`.
It owns worktree creation for `gwt`, the tmux popup, and `brief start`.

## It *is* the next first prompt

Not a document about the work. `brief start <slug>` places the worktree and
hands the session its opening pointer — the invocation and the goal on line 1,
the brief's path on line 2 — so the receiving agent reads the file itself.
Everything follows from that: paths inside a brief stay repo-relative so they
survive the worktree switch, and the text calls itself "this brief" because it
outlives its filename.

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
sibling of `~/dev/.worktrees`. Living outside git keeps one brief visible from
every worktree.

```text
work landed + durable knowledge has an owner → brief delete <slug>
live successor needs a unique passage          → brief retire <slug> --reason "kept: …"
premise died but useful work remains            → rewrite forward, then delete the old brief
```

The kept `.md.done` form is the exception, not the archive. `_clusters.md`
names live clusters and their order; retirement removes the slug from it in the
same change.

**Honesty floor:** a session that taught nothing transferable hands off state
and next move, and nothing else.
