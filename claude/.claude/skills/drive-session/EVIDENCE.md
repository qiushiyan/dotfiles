# drive-session — evidence

Usage passes over the sessions that ran this skill, newest first. Each names
its corpus, what it found, what changed, and what the next pass compares.

## 2026-10-15 — stage-aware driving (improve-tool pass)

**Ask.** Drive sessions through the user's own stage pipeline when they leave
it unsaid, mostly planlab overnight; ask up front and keep going on
recommended defaults; one home for the pipeline.

**Corpus.** Obelisk, both machines, Claude sessions.

- Invocations: `messages.skill = 'drive-session'` or the `/drive-session`
  command markup — 4, all 2026-10-12 → 10-14; one (mini `847c0c59`) ran on
  the body before this pass.
- Stage sequences: user turns since 2026-09-15, regex classifier over
  snippet openings and slash commands (`q-paths.mjs`); 64 replies around
  `/write-spec` (`q-design-replies.mjs`), rated by hand, one rater.
- Queries and outputs were kept in that session's scratchpad (`consult/data/`),
  not committed.

**Findings.**

- **No pipeline to follow.** In `847c0c59` the user added mid-drive "check
  our doc-loop … browse session history" and "claude-steps will show you the
  stages"; the driver then rebuilt `review-then-closeout`'s landing steps
  into a file and sed-edited it per session. The stages lived in snippet
  prose, the claude-steps label order and `docs/doc-loop.md`, which omitted
  verify, PR, code review and closeout.
- **The user's paths.** Planlab heavy (`/write-spec`) in about 60 sessions,
  light (`consult-then-build`) since 10-14; heavy runs onboarding → consult
  → `/write-spec <answers>` → `/compact` → `implement-spec` → review+verify
  → handoff + PR → `/pl-handle-code-review` (mini `5fe3d866`, `75b65cfd`,
  `003bf4cc`, `b2afbe75`).
- **Design-stage replies amend often.** About 60% of answers to a consult's
  decisions accept or pick; about 40% add scope, an instruction, or a
  resource only the user holds. The user chose to drive heavy sessions
  through to the PR anyway, parking only on a hard-to-undo decision with no
  recommendation or an operational step that is theirs.
- **Asking up front worked when the driver did it unprompted** (`847c0c59`,
  four questions with defaults in its first minute).
- **Damage came from the driver's own work** (mac `7513cde5`: its replay
  runner reaped four live lane databases).
- **Defects in the scripts:** `send-turn` reported a correct slash command
  as "arrived differently" (exit 1, which the skill answers with ctrl+c);
  `read-turn --user` took a queued task notification for a prompt.

**Consult.** `consult-r1` (fable) and `consult-r1-astra` (codex gpt-6-astra);
no foundational objection. Adopted: announce defaults and parks, ask only
blockers, veto window; resolve snippets as TabType does from a worktree; a
landing snippet apart from the review; read what a session was told;
authority by what an action touches; a fixed notice on the first send;
serialize closeouts into one main checkout; reconcile with the transcript
before resending; the driver opens a session for work rather than doing it.

**Changes.** `docs/session-pipeline.md` (new; `doc-loop.md` keeps the
knowledge loop; `tabtype/WORKFLOW.md` folded in). Skill body rewritten
around survey → plan → drive → report. `NOTICE.md`. Scripts: `snippet`;
`read-turn` slash commands as typed, harness records skipped, `--prompts N`;
`send-turn` ten minutes for `/compact`; `find-session` window and session
id; `wait-turn` `BG_SECS`. Snippets: global and planlab `consult-then-build`
spike clause; planlab `land-pr`; planlab `review-then-closeout` no longer
reserves the bot review. claude-steps `build` label. twin carries planlab's
`.tabtype.local.toml`.

**Validation.** `read-turn` against real transcripts cut around a `/compact`
and a queued notification; `snippet` from a planlab worktree, dotfiles,
TabType and a missing key; `find-session` on the live Rex session; the
stow-reach suite. Cold readers on three scenarios (overnight plan, a heavy
spec with an unrecommended decision and an expired AWS login, two personal
closeouts plus requested new work). Not run: a live drive on this body,
`send-turn` on a slash command, `x --resume`, the unanswered-question wake,
skill-evals cases (a drive spans several Rex sessions; the frozen decision
points below are the candidates).

**Next pass compares** drives after this commit with `847c0c59`:

- mid-drive pointers the user had to give (target none);
- sends that are a snippet verbatim vs. hand-composed prompts;
- parks the user overrode, and continues the user would have stopped;
- heavy sessions reaching the PR, and where the rest parked.

Reverse the heavy-path default if a driven heavy session's build has to be
redone over a decision the user would have amended.

Candidate eval cases: a review dispatched but not folded in (must not
land); a spec decision with no recommendation that is hard to undo (park
after the parts that do not depend on it); `closeout` from a planlab
worktree resolves to the distill line; a replay of `847c0c59`'s request
with the doc in hand.
