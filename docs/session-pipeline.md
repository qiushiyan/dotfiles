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
5. **Review and verify.** `loopy-review-verify` in planlab,
   `itell-review-verify` in itell (its `verify` skill's lane), `review-verify`
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

After the merge and deploy (§ Who decides; in a planlab batch,
`PLANLAB.md` § After the PR says who runs them), planlab's `closeout` key runs `/pl-loopy-handoff-distill merged and
deployed`; elsewhere `/distill-handoffs` retires the spent brief.

A brief one session writes to start another lists, by the names above, every
stage from its entry to its finish, so the new session runs them all: a
planlab finish of "open the PR, then handle code review" has dropped review
and verification. A strategic review in a fresh session runs on a PR the
user names, or in a planlab batch on the driver's judgment:
`strategic-review-brief` has the build session write that session's
`/strategic-review <PR>` prompt.

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

A planlab batch that `drive-session` starts decides later: every session
runs `consult-design`, the user reviews all the designs at once, and each
then takes `/write-spec` or `implement-now`
(`claude/.claude/skills/drive-session/PLANLAB.md` § The design checkpoint).

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
  not relied on. The merge and the release follow without the user once the
  stages § Who decides lists have run,
  unless the user holds them: `merge-when-ready` runs them, and in a batch
  the driver sends it (`PLANLAB.md` § After the PR). The post-merge
  closeout follows once the deploy serves.
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

## Who decides

The one home for who decides what, whether the user drives a session by
hand or `drive-session` drives a batch; the snippets, the driver and its send
preamble (`claude/.claude/skills/drive-session/NOTICE.md`) follow it. The
user steps in at two kinds of moment. Everything else the session or the
driver does on its own judgment and reports.

**Ask the user**, holding only the work that depends on the answer:

- **Design questions, at the design checkpoint**: scope, what the product
  does for the person using it, and what a customer is told, asked together before
  the build, with every technical choice listed as the default the session
  will take. A design question that reopens later comes back the same way: a
  review finding the session judges foundational, a design objection it
  rebutted, or a decision that is hard to undo and has no recommendation.
- **Mutations of production data outside a reviewed release**: SQL, a script
  or a backfill run against a production database, a write in a customer's
  workspace or data, and changes to production infrastructure such as taking
  down or resizing a tier, and a release whose migration drops or rewrites
  customer data or installs something that writes it. Any other migration a
  release of `develop` carries is part of that release, below.

**Handled without asking**, and reported:

- **Every choice inside the change** once its design is settled:
  implementation, technical defaults, follow-up cards for work outside it.
- **Merge and release**, once the stages have run: review and verification,
  the prompt check where it applies, the PR's code review handled, a
  strategic review where the change earned one with its findings folded in,
  and required checks green. A release's migration gate is overridden with
  the acknowledgement it suggests when the release's session recommends it,
  having read what the gate flagged, and the migration only adds or reshapes
  schema; one that touches customer data is the second ask above. A personal
  tool's `closeout` merge is the same.
- **Docs passes, handoffs, closeouts and cleanup**: the doc pass when a
  session is ready for one, and removing the branches, worktrees, review
  checkouts and scratch files the sessions recommend; a spent brief is
  retired by the project's distill (planlab's `closeout` key), never by hand.
- **Reads of production, and writes to the user's own, internal or demo
  workspaces and to internal systems** such as an issue tracker or the
  handoffs repository. A project says which of its spaces are internal
  (planlab: AGENTS.md, "Size caution to who can be hurt").
- **Announcements in a channel**, by the project's own rule for who they
  notify (planlab: `pl-loopy-handoff-distill` § The announcement). A message
  addressed to a person goes as a draft the user sends.
- **A judgment the user would hand to a model**: a spec review, a blind
  comparison, whether a gate's evidence holds. A fresh session decides it.

**Out of reach for any session**, whatever the lists say:

- **What only the user can do**: creating a workspace, logging in to an AWS
  profile, credentials, money, an account beyond the ones named.
- **Shared machine state**: another checkout's database, lanes or working
  tree. Judge an action by what it touches, not by the directory it runs
  in: a cleanup inside an isolated clone has deleted other checkouts' lanes.
- **Deleting data the session did not create and cannot restore**, and
  **text the user owns**, such as a decision-ledger entry.

An ask holds the work at the step that would act on it, not before: the
session builds what does not depend on it and stops there, so the user comes
back to everything else done.

## Project snippets

A project's `.tabtype.local.toml` binds stages to its own skills, under a new
key or by replacing a global one. TabType reads it from the worktree and from
the main checkout beneath it, so a worktree sees the main checkout's file.
The file is gitignored in its project; `twin` carries planlab's and
TabType's between the machines (`twin/.config/twin/twin.toml`).

```text
a new key      → planlab's loopy-review-verify (the review with the pl-loopy-verify rig),
                 itell's itell-review-verify (the review with a verify lane),
                 land-pr (stage 7 without the review),
                 merge-when-ready (merge, release and confirm, when a driver holds the merge)
a global key   → planlab's consult-then-build (its spike toolkit), review-then-closeout
                 (ends at a ready PR) and closeout (the post-merge distill);
                 TabType's closeout and review-then-closeout (a release)
```
