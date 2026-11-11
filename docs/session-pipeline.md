# Session pipeline — the stages a branch goes through

A coding session takes one branch from its first prompt to a finish. Each
stage starts with a prompt the user sends — a TabType snippet, named here by
its key, or a slash command — and ends in something the next stage reads: an
analysis, a settled direction, a spec, commits, a review report, a PR. This
doc owns the order of the stages, the light and heavy paths, what finishes
each kind of project, and who decides what. The user follows it by
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
`gwt` places it and the session follows with its context
(`docs/claude-mods.md` § worktree). Other sessions run from the main checkout, so an install there
changes what they run. `~/dotfiles` commits on `main`, and its `closeout`
then skips the merge.

1. **Onboard.** `/onboarding <goal>` (itell, duet), `/pl-loopy-onboarding
   <goal>` (planlab's Loopy), or a handoff brief's pointer. It ends in an
   analysis that asks the user its product questions. `think-holistic` asks
   for the same analysis where no onboarding skill exists;
   `elaborate-questions` re-asks questions the user could not decide from
   the words alone. A routine pass over a personal Go tool, with no request
   behind it, enters at `go-cli-maintain`
   (`claude/.claude/skills/go-cli/MAINTAIN.md`). Its report holds fixes it
   already verified, so the branch goes straight to `review-then-closeout`
   unless a decision reshapes the design, which takes `consult-then-build`.
   A Loopy incident (an id, a window, a Bench card) enters at
   `/pl-loopy-debug` instead; its dossier recommends whether to build a
   fix, and a fix goes on with `/pl-loopy-onboarding <the dossier's route>`.
   An iTELL learner's bug report enters at `/bug-report-triage <reportId>`,
   and a fix it recommends goes on with `/onboarding`.
   In planlab, when the user has not said what the next batch holds,
   sessions that change no code decide it before any of its sessions
   onboards: `loopy-slack-triage` for what arrived,
   `loopy-initiatives-review` for what was planned, `loopy-batch-review`
   for a fresh review of both, and `loopy-batch-notes` for the start note
   each session opens from: its `opens:` line names the brief that carries
   the work or the line to type, and the note sets up the work and leaves
   its stages to be sent. A driver's procedure is `PLANLAB-NEXT-BATCH.md` beside its
   skill.
2. **Design.** The path decides the prompt (§ Choosing the path):
   - **Light:** `consult-then-build` — one consult round with the user's
     open questions on trial, a spike where the direction rests on an
     assumption reading cannot settle, then the build, stopping only for
     what a default cannot settle. Stages 3 and 4 are inside it.
   - **Heavy:** `consult-design`, or a freeform "consult with opus/codex" —
     the round settles the high-level design and the implementation tenets
     and comes back with decisions.
   - **A larger change to how the product looks or feels** shows its design,
     since that is decided by eye: `emil-prototype` builds variants and
     stops at them for the user's pick, in planlab on the `pl-prototype-bar`
     harness, and `emil-finish` builds the pick. `emil-improve` is for a
     change the user already knows, with no prototype. All three follow
     `claude/.claude/skills/emil-design/SKILL.md`.
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
   the one `pl-pr`'s step 6 lays out; itell `land-pr`, against `main`, its
   verdicts in the PR body; a personal tool `closeout`.
   `review-then-closeout` is stages 5 and 7 in one prompt, for a branch
   nothing has reviewed yet; sent after a review, it would start another.
   In planlab a session's first `gh pr create` is refused when stage 5 has
   not run in it, with what to run
   (`claude/.claude/hooks/pr-stage-check.py`), so a build step that names
   the PR does not skip the review.
8. **Settle the PR** (planlab). `land-pr` hands the PR to the team's
   `pl-land`, which asks for CI by label, handles red CI and what reviewers
   post, and ends at ready to merge or at a churn stop. It merges only on
   the user's approval, which `merge-when-ready` carries.
   `handle-review` is one round of the review handling alone, for when the
   user runs the loop.
9. **Strategic review** (planlab, by default). `strategic-review-brief` has
   the build session write the reviewer's prompt, and a fresh session, on
   Fable when a driver opens it, runs `/strategic-review <PR>`, folds its
   findings in and merges. A change
   skips it when it is contained and isolated, touches no production path,
   and is a simple fix its own review round has settled; the build session
   says so in its report. Elsewhere it runs on a PR the user names, or in an
   itell batch on the driver's judgment.
10. **Recap**, once a session has finished or stopped on something that is
   the user's: `recap` has it explain from its diff what it did, what was
   verified and what waits, for a user who did not watch; `/show-me`
   answers a narrower question about it later.

After the merge and deploy (§ Who decides; in a planlab batch, `PLANLAB.md`
§ After the PR says who runs them, in an itell one `ITELL.md` § After the
PR), planlab's `closeout` key runs `/pl-loopy-handoff-distill merged and
deployed`; elsewhere, itell's `closeout` key included, `/distill-handoffs`
retires the spent brief.

A brief one session writes to start another lists, by the names above, every
stage from its entry to its finish, so the new session runs them all: a
planlab finish of "open the PR, then handle code review" drops review and
verification.

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

A batch that `drive-session` starts with unsettled designs decides later:
every session runs `consult-design`, each then takes `/write-spec` or
`implement-now` on its own recommendations, and the user sees all the
designs at once; a merge waits only for a design question still open
(`PLANLAB.md` § The design checkpoint, and its iTELL form in `ITELL.md`).

## Spikes

A spike is throwaway code that settles an assumption reading the code
cannot, before the build commits to it, and it may kill the approach
(`claude/.claude/skills/spike/SKILL.md`). `/write-spec` runs them on the
heavy path, `consult-then-build` after its consult round on the light one,
`go-cli-maintain` throughout its pass, and `spike-check` asks for them on
their own and ends at their verdicts: by hand the build waits for the user
to read them, and in a driven batch the next step sends it on. In planlab they run on the real stack:
`pl-loopy-verify`'s rungs where they hold the question, otherwise an
OrbStack container or EC2 on the `planlab-personal` AWS profile, cleaned up
afterwards; planlab's `consult-then-build` says so. In itell they run in the
worktree's verification lane (`pnpm verify`) where it holds the question, as
itell's `consult-then-build` says.

## Finishes

- **Planlab — a polished PR, merged and released.** The stages through
  review and verification have run, the PR is open against `develop` with
  the required checks green, and `pl-land` has settled it, its outcome
  (ready to merge, or stopped on churn) reported; the bots help but are
  not relied on. Then
  stage 9's review session merges and releases without the user unless they
  hold them (`PLANLAB.md` § After the PR), and the closeout follows once the
  deploy serves.
- **Personal tools** (`~/dotfiles` and the tools under `~/dev` that `twin`
  installs): `closeout` merges to `main` locally, with no PR, installs on
  both machines with `twin sync`, and removes the branch.
- **TabType:** as a personal tool, but its `closeout` publishes a release to
  every user.
- **No PR** — a session that only onboards, triages or reports: its recap,
  with no distill, since nothing merged.
- **iTELL — a merged PR on staging.** The stages through review and
  verification have run, the latter with a verdict that passed at the PR
  head, and the PR is open against `main` with its checks green; there are
  no review bots, so stage 8 is a person's comments when there are any.
  `merge-when-ready` merges it and follows it to staging. The production
  deploy waits for the user's grant, after a signed-in check of staging
  (`ITELL.md` § After the PR).
- **Any other project** (a new repository): no default; the user names the
  finish.

A session's Rex tab is closed once its last step has run: the closeout, or
the recap where no PR follows.

## Who decides

The one home for who decides what, whether the user drives a session by
hand or `drive-session` drives a batch; the snippets, the driver and its send
preamble (`claude/.claude/skills/drive-session/NOTICE.md`) follow it. The
user steps in at two kinds of moment. Everything else the session or the
driver does on its own judgment and reports.

**Ask the user**, holding the work only at the step that would act on the
answer: the session builds what does not depend on it and stops there, so
the user comes back to everything else done.

- **Design questions**: scope, what the product does for the person using
  it, and what a customer is told, asked together once the design is in,
  with every technical choice listed as the default the session will take.
  The step that acts on the answer is the merge. A session that recommends
  an answer builds on it, since the user nearly always takes it and a
  rebuild costs less than a night parked; a question with no recommendation
  holds the work that depends on it. A design question that reopens later
  comes back the same way: a review finding the session judges
  foundational, or a design objection it rebutted.

  **A critical question** is marked as one and asked at once, on its own.
  The session still builds on its recommendation, and the merge waits for
  the user's agreement. It is a question someone will have built on the
  answer to by the time it could be changed: customers who form a habit or
  a workflow around it, data stored in its shape, later work that assumes
  it. The test: if the answer changed a month after it ships, who would
  have to adapt? When that is nobody, or only the team editing code, it is
  a default to take and tell.

  - **Critical, for example:** whether subagents may edit the wiki, or what
    else the product does without asking its user; how a reply looks as it
    streams; how table rows are stored for every PDF read from now on; how
    a planner's "from now on" rule is saved; what counts as a planner rule
    in a release gate; a variable every release must then set.
  - **Not critical, for example:** making a schedule that refused to save
    work again; which queue tells search, how often a slow page is retried,
    how long deleted rows are kept; the wording of a notice or a report
    line; one pull request or two, and which carries a fix; a known limit
    accepted and recorded; behaviour on a path no customer takes yet.

  These are examples to reason from, on both sides: the session judges
  each case, and one or two critical questions in a batch is usual.
- **Mutations of production data**: SQL, a script or a backfill run against
  a production database; a write in a customer's workspace or data; a change
  to production infrastructure, such as taking down or resizing a tier; and a
  release whose migration drops or rewrites customer data, or whose
  migration installs something that writes it. Any other migration rides its release, below.

**Handled without asking**, and reported: anything reversible that reaches
no customer, such as the test account accepting the terms of service on
staging. A fact that can be looked up, such as whether a pull request
merged, is looked up. When unsure whether a reversible step needs the user,
do it and report it; when unsure whether a write lands in a customer's workspace or
data, ask. Beyond that:

- **Every choice inside the change** once its design is settled:
  implementation, technical defaults, follow-up cards for work outside it.
- **Merge and release**, once the stages have run and no design question
  about the change is open: review and verification, the prompt check where
  it applies, the PR settled, the strategic review with its findings folded
  in (planlab's default; elsewhere where the change earned one), and
  required checks green. The strategic review's fold is change the user
  asked for, so the code review's churn stop after it is no reason to hold:
  the merge goes on with `--churn-ok`. A churn stop before that review goes
  to the review, which reads the whole change.
  A release's migration gate is overridden with the acknowledgement it
  suggests once the release's session has read what it flagged and
  recommends it, unless the migration is one the second ask names. A
  personal tool's `closeout` merge is the same.
- **Docs passes, handoffs, closeouts and cleanup**: the doc pass when a
  session is ready for one, and removing the branches, worktrees, review
  checkouts and scratch files the sessions recommend; a branch that is not
  merged stays, stated plainly and not asked about; a spent brief is
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

## Project snippets

A project's `.tabtype.local.toml` binds stages to its own skills, under a new
key or by replacing a global one. TabType reads it from the worktree and from
the main checkout beneath it, so a worktree sees the main checkout's file.
The file is gitignored in its project; `twin` carries planlab's, itell's and
TabType's between the machines (`twin/.config/twin/twin.toml`).

```text
a new key      → planlab's loopy-review-verify (the review with the pl-loopy-verify rig),
                 itell's itell-review-verify (the review with a verify lane);
                 in both, land-pr (stage 7 without the review) and merge-when-ready
                 (planlab: merge, release and confirm; itell: merge and follow it to staging)
a global key   → planlab's and itell's consult-then-build (each one's spike rig),
                 review-then-closeout (ends at a ready PR) and closeout (the post-merge distill);
                 TabType's closeout and review-then-closeout (a release)
```
