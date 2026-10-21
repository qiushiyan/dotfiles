# drive-session — evidence

Usage passes over the sessions that ran this skill, newest first. Each names
its corpus, what it found, what changed, and what the next pass compares.

## 2026-10-21 — the Grok Session Driver (improve-tool pass)

**Corpus.** The Grok Bot "Session Driver" (`e1edc3cc`), which drives the
mini's sessions on this skill with a profile that adapts waiting
(`notify-driver` and a webhook) and the scratchpad (a checklist in
`~/.local/state/drive-session/`). Its local replica, read with
`grokbot-transcript "Session Driver"`, covers seq 274–494, 10-17 → 10-21,
what each side said only; 10-15 → 10-17 and the bot's tool calls stay in
Grok's store. Obelisk could not reach the mini, which holds every Claude
drive and driven session since 10-15; the mac has none.

**Findings,** by message seq in that chat:

- **A status answer came from the brief, not the session.** At #346 the
  driver reported that P's consult settled on orientation in
  `schedule_summary`; at #377 it told the user P writes "fewer, larger
  scripts", the brief's framing. The user set P's review bar on that (#378)
  and asked again four days later (#466), when the driver read the session
  and corrected it (#468, #470).
- **Needs-you items the user could not decide from.** "Whats this lab tier
  thing" (#322); "I forgot what it is" twice and "not exactly sure" for
  bare ids (QIU-279, QIU-276, fsmonitor) in #417 (#419). § Report asks for
  this already, for the final report; in a chat driver interim pings carry
  most of the decisions.
- **Held messages surfaced three times** (#351, #384, #417) until the user
  said deny (#419): a session at its finish gets no next step, so the
  deny-on-next-step rule never fires.
- **The role outgrew a drive.** The bot runs batches across days:
  onboarding, proposal, gate, drive, merge train, deploy, closeouts, recap,
  next onboarding. The user handed it merges, deploys, strategic-review
  choices and cleanup in chat (#373, #388, #399, #447).
- **Grok-mode mechanics live outside the repo:** `notify-driver` on the
  mini, and the bot's journal rules (waits run inside tmux; kill a parked
  session's wait).
- **Held up:** the veto and its re-arm on an amendment (#330–#336), the
  notice first (#337), a user-set gate with leftover "go build" suggestions
  left unsent (#346), new sessions through `x` for requested work.

**The user's approval line.** Asked afterwards, the user said the driver
stops for more than it should; it asked about cleanup (#298, #387, #445),
its own watchdog (#429), card filing (#417) and demo replays (#386). Stop
only for what reaches a customer or a person or cannot easily be undone;
in planlab, reads of production and writes to internal and personal
workspaces go ahead.

**Changes.** `grokbot-transcript` (scripts) prints a bot's local window.
`session-pipeline.md` § What stays the user's draws that line, and the
planlab finish lets the closeout follow the deploy; `NOTICE.md` matches.
SKILL.md: § What you do without asking (cleanup, own machinery, follow-ups;
authority handed over in chat holds for the batch, written in the
checklist); the report and every interim message lead with Needs you,
Done without asking, Waiting on time, each item self-explaining; a question
about a session is answered from the session; a held message to a landed
session goes with its block in the cleanup. `PLANLAB.md`: internal against customer
workspaces, what asks, and merges and releases once handed over. `BOT.md`:
waiting through `notify-driver`, the batch directory as scratchpad and
memory, one message per event. The Session Driver's own profile is the
user's to replace with a pointer to `BOT.md`.

**Validation.** Two cold readers, one a Claude driver at the end of a
planlab batch, one the bot after a reset with a merge grant. Both held the
`--as-user` replay, kept the half-typed tab, read the session before
answering and found the grant through the checklist. Their gaps were fixed:
cleanup only after work lands, one closeout rule, a dropped held message,
"drive to the end" stops at the PR, the batch directory's date, recaps
kept in it. Not run: a live drive on this body; `notify-driver` is
unverified (the mini was unreachable) and still outside the repository.

**Next pass** reads the mini: the driver's checklist, `claude-steps show
--all` on the driven sessions for snippet against hand-written sends, and
the Claude drives since 10-15, to compare the two drivers. It counts asks
the user answered with "just do it" (target none) and items the user had
to have explained (target none); revise the approval line if a driver's
action reaches a customer or cannot be restored.

## 2026-10-15 — the morning recap

The morning after the 10-14 drive the user asked two driven sessions to
repeat what they had recommended ("i forgot what you recommend", `ada7af18`;
"i forgot what it is", `08eb4785`) and a third what it was for "in plain
terms" (`ad62fa19`); `explain-diff` has no real use in the history. A
`recap` snippet, after HumanLayer's `show-me`, is now the last stage of a
driven session, and the report quotes the recaps. `show-me` is installed
unchanged for later questions; planlab PR bodies take its views (planlab
#9135). The next pass counts morning re-asks in driven sessions against
these three.

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
- sends that are a snippet verbatim vs. hand-composed prompts — claude-steps
  shows a driven snippet as `pasted <key>  in a file`, so `claude-steps show
  <sid> --all` counts them;
- parks the user overrode, and continues the user would have stopped;
- heavy sessions reaching the PR, and where the rest parked.

Reverse the heavy-path default if a driven heavy session's build has to be
redone over a decision the user would have amended.

Candidate eval cases: a review dispatched but not folded in (must not
land); a spec decision with no recommendation that is hard to undo (park
after the parts that do not depend on it); `closeout` from a planlab
worktree resolves to the distill line; a replay of `847c0c59`'s request
with the doc in hand.
