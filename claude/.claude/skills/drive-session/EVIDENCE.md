# drive-session — evidence

Usage passes over the sessions that ran this skill, newest first. Each names
its corpus, what it found, what changed, and what the next pass compares.

## 2026-10-22 — the driver's scripts become `drive` (improve-tool pass)

**Corpus.** On the mini, read-only: the 10-21/22 batch
(`~/.local/state/drive-session/2026-10-21/`: checklist, `open.sh`,
`open.log`, `send-decisions.log`, ~110 send files), the 10-15 batch's
checklist and the notes `2026-10-17/18/19/21.md`, which the brief's
analysis had not used; Claude transcripts under `~/.claude/projects/`;
`~/.claude-accounts/launches.jsonl`; the chat window the planlab session
pulled (`~/dev/.handoffs/dotfiles/drive-session-driver-hardening.evidence/`);
obelisk user turns in `a1d22ac5` and `bec61294` (mac); one `gh` run. Failure
signatures were counted with `grep -ciE` per log (session scratchpad
`consult/data/signature-counts.txt`): login 0/0/0/0/0/57, lock
206/57/39/4/10/87, deny-held 74/5/28/4/2/48, fresh-session rc=2
12/2/0/0/2/16 across 10-15, 10-17, 10-18, 10-19, 10-21.md and 10-21.

**Findings.** Verified at their sources unless marked.

- **`send-turn` failed every opening:** exit 2 on a fresh session, which has
  no transcript until its first prompt (`open.log` 8 of 8; the 10-15 and
  10-17 batches the same). The bot's `open.sh` sent with raw `rex send` and
  logged "arrived" when the prompt text appeared.
- **Rejected logins were invisible.** Claude Code 2.1.308 fires
  `StopFailure` with `error: authentication_failed` and no `Stop` (sandboxed
  spike, invalid key); `rex-agent` ignored it, so Rex read `working` and
  `wait-turn` never returned: T4 and R0 sat 53 minutes with their waits
  "alive". Headroom had placed both on `qiushi`, marked eligible with figures
  9.5 h old and no use since 10-19: least-load routing prefers a dead login.
- **Every queued slash command read "arrived differently"** (7 of 7): the
  transcript enqueues it without its text.
- **No wait died.** Of the four "dead waits", three fired and a concurrent
  run handled the wake (checklist 177/181, 244–248, 396/398); one was never
  armed (434). A successful post left no line in `notify.log`, so a
  delivered wake and a lost one looked alike.
- **Concurrent runs** (watchdog, per-session wakes, chat) acted on one
  session in all three batches; on 10-17 a race sent a recap where another
  run had chosen consult-design. The bot's `mkdir locks/` could not stop a
  decision made on an old turn.
- **Copy-forward memory.** "Prod still 394df272dc" was re-listed 05:43–07:56
  after a teammate's release (`gh` run 39679768815, 05:33 CST); the header's
  "merge + release when ready" was a note about #9259 in the previous batch.
  Three sends ordered merges before the 02:08 grant (one more announced
  one); #9495 merged at 22:59.
- **Hand-written sends** after the PR: strategic-review fold-ins restated
  the `strategic-review` skill's own procedure (6), merge and release orders
  (5+), `/strategic-review` as a file pointer (refused 3 times).
- **Asks.** The overnight waits were a known remedy (login), a duplicate
  (R0's DB writes, answered at 20:27), moot (#9448, shipped by a teammate)
  or handed to a fresh Fable (F2 spec, T1 gate pages; also #9251 on 10-17).
  The design checkpoint's 23 minutes produced scope amendments in 4 of 10
  sessions, 3 of them on items that read as technical.

**Decisions.** The user chose merges and releases as the driver's default
in a planlab batch (asked in this pass) and a Go tool in its own repository
(`~/dev/drive`) over scripts in the skill, after a consult
(`consult-r1b`, codex gpt-6-astra, no foundational objection). Adopted from
it: a view token on every action, persist-before-act with reconciliation,
idempotent open by label, holds for shared resources, respond as a
command, wake posted versus handled, asks with their source. Rejected: a
supervised worker with SQLite; a send takes seconds and the bot can hold a
command for minutes, so recording before typing closes the crash gap
without a daemon. Kept: the design checkpoint's hold (the user's 10-21
choice); the report asks scope, product and people questions and lists
technical choices as defaults. Deferred: timed defaults on silence; no
overnight ask in the data needed one.

**Changes.** `~/dev/drive` (new): `drive` replaces `find-session`,
`read-turn`, `send-turn`, `wait-turn`, `snippet` and `notify-driver`
(removed). `rex-agent` maps `StopFailure` to `blocked`/`auth` or `error`;
settings register it. `grokbot-transcript --archive/--since/--tz`. The skill
now carries intent and policy and points at `drive --help` for the tool;
BOT.md: batch setup, waits armed by sends, a watchdog that sends nothing,
memory as the batch record. PLANLAB.md: the merge default, strategic
reviews on the driver's judgment, `fold these in`, `merge-when-ready`
(new planlab snippet, `~/dev/planlab/main/.tabtype.local.toml`), release
gates rechecked before asking. `session-pipeline.md`: the two sentences that
contradicted the merge default and the strategic-review rule. Handoff:
`~/dev/.handoffs/headroom/launch-avoids-rejected-login.md`.

**Validation.** `drive`'s suite under `-race` (a fake world whose sessions
write real transcripts; the Rex adapter against a private Rex server). Live
on the mini, in the `work` Rex session with state in a scratch directory:
`open` on a fresh session (notice first, then the typed step, confirmed in
12 s), `read`, `wait`, a send on a view, the same view refused (exit 1),
`close`; a webhook batch whose open armed its own watch and whose turn wake
and a timer wake reached a local listener (http 204) with the view, and
`status` read "woken 18:54 (nothing sent since)". The first watch run
exposed tmux dropping the caller's environment (a silent wait), fixed and
rerun. Not run: a rejected login on a real account (the spike and the fake
cover it), a queued slash command on a real session (its transcript shape is
from a real one), a hold across two live releases, the bot itself on this
body. Cold readers took three routes — a chat driver's wake on a ready PR,
a Claude driver at the design checkpoint with a rejected login, a watchdog
run — and a reread took the watchdog and hold routes again. What they could
not do changed the tool: the relaunch names `--dir`; a hold refusal routes
back through the holder's wake, which names each waiter and its refused
step; a stuck watch is flagged and restarted; `status` spells its columns
out. And the text: the watchdog only re-arms, since its "sends nothing"
contradicted handling an unhandled wake; the review session folds in and
merges; a checkpoint session is parked, its design reply standing in for
the recap; an open ask is rechecked and recorded moot when it stops
holding. `skill-sync --check` on the skill: no metadata drift.

**Next pass compares** the bot's first batches on `drive` with 10-21/22,
from `drive metrics` and `drive log` rather than a hand-coded chat: sends
that reach a session decided on a stale view (target none, now refusals);
openings and logins that fail unseen (target none); wakes posted with no
action before the next (the measure of the lost-wake suspicion); owner wait
per merged change and asks answered "delegated" or "moot" (both should
fall); refusals by kind, to see whether the bot routes around them with raw
`rex`. Reverse the merge default if a driven merge or release reaches a
customer in a way the user would have stopped.

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

**The design checkpoint.** The user then asked that a planlab batch stop
once every session's design is in, for one review, with the spec decided
per session after the consult. The 10-17 batch ran it on the user's word
(#339 → #346, calls in #348 and #353). `PLANLAB.md` § The design checkpoint
makes it the default: `consult-design` for every session, `spike-check`
where needed, one report, then `/write-spec` → `/compact` →
`implement-spec` or `implement-now` on the user's word. The user chose to
have the checkpoint wait for them rather than build on recommendations
after a timeout; a batch that reaches it overnight idles until they answer.
`notify-driver` came into the repository unchanged from the mini.

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
