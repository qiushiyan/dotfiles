# Session pipeline — the stages a branch goes through

A coding session takes one branch from its first prompt to a finish. Each
stage starts with a prompt the user sends — a TabType snippet, named here by
its key, or a slash command — and ends in something the next stage reads: an
analysis, a settled direction, a spec, commits, a review report, a PR. This
doc owns the order of the stages, the choice between the light and the heavy
path, what finishes each kind of project, and which steps stay the user's.
It is what the user follows by habit and what `drive-session`
(`claude/.claude/skills/drive-session/SKILL.md`) follows while the user is
away.

Other homes:

- **Prompt text:** the snippet files. The global one is
  `tabtype/.config/tabtype/config.toml`; a project's `.tabtype.local.toml`
  adds keys or replaces global ones there (§ Project snippets).
  `tabtype/DESIGN.md` says why the snippets are shaped as they are.
- **What ran in a session:** `claude-steps show`, whose labels group each
  stage's skills and snippets (`claude-steps/.config/claude-steps/config.toml`).
  It states dated facts: a review that was dispatched is not a review whose
  findings were folded in.
- **How knowledge carries between sessions** — onboarding, docs passes,
  handoffs: `docs/doc-loop.md`.
- **Each stage's procedure:** its skill.

## The stages

In order; a stage the branch does not need is skipped, and a later fix can
send the branch back through review and docs. Before anything is built, a
session still on a project's main checkout moves to a branch:
`/enter-worktree` names it, `gwt` places it, and the session follows with its
context.

1. **Onboard.** `/onboarding <goal>` (itell, duet), `/pl-loopy-onboarding
   <goal>` (planlab's Loopy), or a handoff brief's pointer. It ends in an
   analysis that asks the user its product questions. `think-holistic` asks
   for the same analysis where no onboarding skill exists;
   `elaborate-questions` re-asks questions the user could not decide from
   the words alone.
2. **Design.** The path decides the prompt (§ Choosing the path):
   - **Light:** `consult-then-build` — one consult round with the user's
     open questions on trial, a spike where the direction rests on an
     assumption reading cannot settle, then the build, stopping only for
     what a default cannot settle. Stages 3 and 4 are inside it.
   - **Heavy:** `consult-design`, or a freeform "consult with opus/codex" —
     the round settles the high-level design and the implementation tenets
     and comes back with decisions.
3. **Spec** (heavy). `/write-spec <answers to the consult's decisions>`. It
   runs the unknowns the design turns on (thin spikes), commits the spec,
   has it read cold and validated by a consult, and ends with any decisions
   of its own. Answers to those are written into the spec before the build.
4. **Build.** Heavy: `/compact`, then `implement-spec`, which rebuilds the
   model from the committed spec. `implement-now` builds from decisions
   settled in the conversation. Commits land at milestones.
5. **Review and verify.** `loopy-review-verify` in planlab, `review-verify`
   elsewhere: a `/review` round while the session proves the intended
   behaviour on the running stack. Confirmed findings are folded in ("fold
   it in"); substantive fixes get a second round.
6. **Prompt check**, when the branch's diff touches model-facing text —
   prompts, skill bodies, snippets, tool descriptions and results, a
   `CLAUDE.md`: `loopy-prompt-check` in planlab, `prompt-check` elsewhere.
7. **Land.** By project (§ Finishes): planlab `land-pr`; a personal tool
   `closeout`. `review-then-closeout` is stages 5 and 7 in one prompt, for
   a branch nothing has reviewed yet; sent after a review, it would start
   another.
8. **Code review on the PR** (planlab). `/pl-handle-code-review` loops over
   the bots' findings until the PR is caught up or the fixes stop
   converging. `handle-review` is its single-round form, for when the user
   runs the loop.

After the merge and deploy, which are the user's, planlab's `closeout` key
runs `/pl-loopy-handoff-distill merged and deployed`; elsewhere
`/distill-handoffs` retires the spent brief.

A strategic review in a fresh session runs only on a PR the user names:
`strategic-review-brief` has the build session write that session's
`/strategic-review <PR>` prompt.

Every stage that judges — a consult, a spike, a review — buys a judgment the
authoring session cannot make about itself, so an artifact's author is never
its only judge. The session verifies an outside finding against the source
before acting on it; a peer is evidence, not authority. Compact at artifact
boundaries: once a spec or a committed range carries the state, the
exploration that produced it is disposable.

## Choosing the path

The user's word decides. Without it:

- **Heavy:** infrastructure or runtime work with a large blast radius — the
  pool, the master, migrations, production data, a change across packages —
  or a problem complex or consequential enough that a written spec pays for
  itself. In planlab, `infra-runtime` worktrees usually take it.
- **Light:** a contained feature or fix; nearly every personal tool.

The onboarding analysis's account of risk is the evidence to read.

## Spikes

A spike is throwaway code that settles an assumption before the build
commits to it (`claude/.claude/skills/spike/SKILL.md`, its design moment).
It runs where the approach rests on something reading the code cannot
settle, and it may kill the approach.

- **Heavy:** `/write-spec` runs them while settling its unknowns.
- **Light:** `consult-then-build` runs them after its consult round.
- **In planlab** they run on the real stack: `pl-loopy-verify`'s rungs where
  they hold the question, otherwise an OrbStack container or EC2 on the
  `planlab-personal` AWS profile, cleaned up afterwards. Planlab's
  `consult-then-build` says so.

`spike-check` asks for spikes on their own, with the build waiting for the
user to read the verdicts.

## Finishes

- **Planlab — a polished PR.** The stages through review and verification
  have run, the PR is open against `develop` with the required checks green,
  and at least one round of `/pl-handle-code-review` has been handled; its
  outcome, caught up or stopped on churn, is reported. The bots help but are
  not relied on. The merge, the deploy and the post-merge closeout are the
  user's.
- **Personal tools** (`~/dotfiles` and the tools under `~/dev` that `twin`
  installs): `closeout` merges to `main` locally, with no PR, installs on
  both machines with `twin sync`, and removes the branch.
- **TabType:** as a personal tool, but its `closeout` publishes a release to
  every user.
- **Any other project** (itell, a new repository): no default; the user
  names the finish.

## What stays the user's

A session ends most stages with decisions; its recommendation is the
default, and the user takes it in most sessions. These stay the user's:

- **Shared bases and releases** — a merge or deploy outside the finishes
  above.
- **Effects beyond the branch** — writes to production systems or data,
  messages to people (Slack, announcements, PR comments addressed to a
  person), and anything that reaches shared machine state: another
  checkout's database, lanes or working tree. The merge a personal tool's
  `closeout` makes in its main checkout is that finish, not such an effect.
  Judge an action by what it touches, not by the directory it runs in: a
  cleanup run inside an isolated clone has deleted other checkouts' lane
  databases.
- **What only the user can do** — creating a workspace, logging in to an AWS
  profile, credentials, money, an account beyond the ones named.
- **Deleting data the session did not create.**
- **Text the user owns**, such as a decision-ledger entry.
- **A decision that is hard to undo and comes with no recommendation**, a
  review finding the session judges foundational, or a design objection it
  rebutted.

Each of these holds the work at the step that would act on it, not before:
the session builds what does not depend on it and stops there, so the user
comes back to everything else done.

## Project snippets

A project's `.tabtype.local.toml` binds stages to its own skills, under a new
key or by replacing a global one. TabType reads it from the worktree and from
the main checkout beneath it, so a worktree sees the main checkout's file.

```text
a new key      → planlab's loopy-review-verify (the review with the pl-loopy-verify rig),
                 land-pr (stage 7 without the review)
a global key   → planlab's consult-then-build (its spike toolkit), review-then-closeout
                 (ends at a ready PR) and closeout (the post-merge distill);
                 TabType's closeout and review-then-closeout (a release)
```

The file is gitignored in its project; `twin` carries planlab's and TabType's
between the machines (`twin/.config/twin/twin.toml`).
