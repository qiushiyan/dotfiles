# Session pipeline — the stages a branch goes through

A coding session takes one branch from its first prompt to a finish. Each
stage starts with a prompt the user sends — a TabType snippet, named here by
its key, or a slash command — and ends in something the next stage reads: an
analysis, a settled direction, a spec, commits, a review report, a PR. This
doc owns the order of the stages, the light and heavy paths, what finishes
each kind of project, and which steps stay the user's. The user follows it by
habit; `drive-session` (`claude/.claude/skills/drive-session/SKILL.md`)
follows it while the user is away.

Other homes:

- **Prompt text:** the global `tabtype/.config/tabtype/config.toml` and a
  project's `.tabtype.local.toml` (§ Project snippets); `tabtype/DESIGN.md`
  says why the snippets are shaped so.
- **What ran in a session:** `claude-steps show`, whose labels group each
  stage's skills and snippets (`claude-steps/.config/claude-steps/config.toml`).
- **How knowledge carries between sessions** — onboarding, docs passes,
  handoffs: `docs/doc-loop.md`.
- **Each stage's procedure:** its skill.

## The stages

In order; a stage the branch does not need is skipped, and a later fix can
send the branch back through review and docs. Where a project builds on
branches — planlab, itell, the tools under `~/dev` — a session starts on the
main checkout and moves to a worktree before it installs or builds anything:
`/enter-worktree` names it, `gwt` places it, and the session follows with its
context. Other sessions run from the main checkout, so an install there
changes what they run. `~/dotfiles` commits on `main`, and its `closeout`
then skips the merge.

1. **Onboard.** `/onboarding <goal>` (itell, duet), `/pl-loopy-onboarding
   <goal>` (planlab's Loopy), or a handoff brief's pointer. It ends in an
   analysis that asks the user its product questions. `think-holistic` asks
   for the same analysis where no onboarding skill exists;
   `elaborate-questions` re-asks questions the user could not decide from
   the words alone. A Loopy incident (an id, a window, a Bench card) enters
   at `/pl-loopy-debug` instead; its dossier recommends whether to build a
   fix, and a fix goes on with `/pl-loopy-onboarding <the dossier's route>`.
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
   of its own, whose answers are written into the spec before the build.
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
7. **Land.** By project (§ Finishes): planlab `land-pr`, whose PR body is
   the one `pl-pr`'s step 6 lays out; a personal tool `closeout`.
   `review-then-closeout` is stages 5 and 7 in one prompt, for a branch
   nothing has reviewed yet; sent after a review, it would start another.
8. **Code review on the PR** (planlab). `/pl-handle-code-review` loops over
   the bots' findings until the PR is caught up or the fixes stop
   converging. `handle-review` is its single-round form, for when the user
   runs the loop.
9. **Recap**, once a session has finished or stopped on something that is
   the user's: `recap` has it explain from its diff what it did, what was
   verified and what waits, for a user who did not watch; `/show-me`
   answers a narrower question about it later.

After the merge and deploy, which are the user's, planlab's `closeout` key
runs `/pl-loopy-handoff-distill merged and deployed`; elsewhere
`/distill-handoffs` retires the spent brief.

A brief one session writes to start another lists, by the names above, every
stage from its entry to its finish, so the new session runs them all: a
planlab finish of "open the PR, then handle code review" has dropped review
and verification. A strategic review in a fresh session runs only on a PR
the user names: `strategic-review-brief` has the build session write that
session's `/strategic-review <PR>` prompt.

Every stage that judges — a consult, a spike, a review — buys a judgment the
authoring session cannot make about itself, so an artifact's author is never
its only judge, and an outside finding is checked against the source before
it is acted on: a peer is evidence, not authority. Compact at artifact
boundaries: once a spec or a committed range carries the state, the
exploration that produced it is disposable.

## Choosing the path

The user's word decides. Without it, the onboarding analysis's account of
risk is the evidence:

- **Heavy:** infrastructure or runtime work with a large blast radius — the
  pool, the master, migrations, production data, a change across packages —
  or a problem complex or consequential enough that a written spec pays for
  itself. In planlab, `infra-runtime` worktrees usually take it.
- **Light:** a contained feature or fix; nearly every personal tool.

## Spikes

A spike is throwaway code that settles an assumption reading the code
cannot, before the build commits to it, and it may kill the approach
(`claude/.claude/skills/spike/SKILL.md`). `/write-spec` runs them on the
heavy path, `consult-then-build` after its consult round on the light one,
and `spike-check` asks for them on their own, the build waiting for the user
to read the verdicts. In planlab they run on the real stack:
`pl-loopy-verify`'s rungs where they hold the question, otherwise an
OrbStack container or EC2 on the `planlab-personal` AWS profile, cleaned up
afterwards; planlab's `consult-then-build` says so.

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
- **No PR** — a session that only onboards, triages or reports: its recap,
  with no distill, since nothing merged.
- **Any other project** (itell, a new repository): no default; the user
  names the finish.

A session's Rex tab is closed once its last step has run: the closeout, or
the recap where no PR follows.

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
  cleanup inside an isolated clone has deleted other checkouts' lanes.
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
The file is gitignored in its project; `twin` carries planlab's and
TabType's between the machines (`twin/.config/twin/twin.toml`).

```text
a new key      → planlab's loopy-review-verify (the review with the pl-loopy-verify rig),
                 land-pr (stage 7 without the review)
a global key   → planlab's consult-then-build (its spike toolkit), review-then-closeout
                 (ends at a ready PR) and closeout (the post-merge distill);
                 TabType's closeout and review-then-closeout (a release)
```
