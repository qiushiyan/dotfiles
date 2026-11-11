# drive-session — evidence

Usage passes over the sessions that ran this skill. A pass reads the two
sections below first, then the newest entry; dated entries follow, newest
first, each with its corpus, what it found and what changed. A run by a real
bot follows `DOGFOOD.md`.

## Decisions that stand

- **`drive` holds the mechanics and prints the next command; these files
  hold the judgment** (10-22). A mechanism a message states is not explained
  again here.
- **Who decides what lives in one place,** the pipeline doc's § Who decides
  (10-27); the notice and the project files follow it.
- **A step is written as the user would type it** (10-29).
- **A wake is a paid run, paced in drive** (11-02).
- **A session follows its own worktree; no slash command moves it** (11-07).
- **A question a session or the driver can settle is taken and told, not
  asked, and the engine does not sort questions into kinds** (11-10, the
  user's word: questions are hybrid, and they want to see a choice that was
  taken, with the option passed over).
- **A design question with a recommendation holds the merge, not the
  build** (11-10, an experiment the user will judge after a few batches).
  PLANLAB.md's checkpoint keeps the reason beside the rule: with it cut as
  a duplicate of the pipeline doc's, a driver parked its session at the
  design in 2 of 15 replays, and in none of 15 with it.
- **A strategic review a driver opened folds its own findings** (11-10); by
  hand it still stops at its report.
- **A strategic review a driver opens runs on Fable, at the effort the
  user's settings give** (11-10, the user's word); `--effort xhigh` only
  when they ask. Replayed (`q-open-review`, n=5): the open named `--model
  fable` in none of 5 runs on the text before and in 5 of 5 after, with no
  `--effort` in either.
- **What planlab's next batch holds is worked out by sessions that change
  no code, and the user picks once** (11-10, `PLANLAB-NEXT-BATCH.md`): two
  gather by source, a fresh third reviews both for a large batch, start
  notes live in the handoffs clone, and a claim older than today is a lead
  until it is measured. The session-facing words are planlab snippets, which
  a driver may adapt (the user's word).
- **A critical design question holds the work that depends on it and is
  asked at once, on its own** (11-11, the user's choice between the two
  forms). Critical is a principle the session judges, with examples: an
  answer people or later work will come to rely on, so that changing it
  after it ships makes someone adapt. Landed unreplayed on the user's word;
  see open comparison 7.
- **A larger UI or UX change shows its design as a prototype** (11-11, the
  user's word): `emil-prototype`, the user's pick, `emil-finish`, in planlab
  and itell.

## Open comparisons

Each is a measurement the next pass can run. Answer or retire them before
adding more.

1. **Questions that were not the user's.** Predicate: each `ask` event
   classed by hand against § Who decides (design, production, only the
   user, a message to a person or an announcement; everything else was
   already handed over). Baseline: 41 of 127 across batches 11-02, 11-06
   and 11-09 (10 of 39, 17 of 54, 14 of 34). After the 11-10 text: the next
   two batches. Revise toward an engine check if the share stays above a
   fifth; reverse if the user undoes a choice taken without asking more
   than once a batch.
2. **The design checkpoint experiment.** Hours a session sat parked at its
   design (baseline about 50 over the four heavy PRs of 11-02), and design
   answers that amended a build already made, with the rework each cost
   (baseline before the change: 3 of 38 design questions not taken as
   recommended). The user judges it after a few batches.
3. **A pull request opened with no review round.** Baseline: 4 of 15 driven
   building sessions (11-06: 3 of 4; 11-09: 1 of 4), 6 of 11 hand-driven
   light-path runs. After `pr-stage-check.py`: its denials, and what each
   session did next (ran the review, or went on and said why).
4. **A stop the user could not decide from.** Baseline: at least 9 answers
   in three batches needed a question first. After `rules/stops.md` reaches
   the sessions: the next two batches.
5. **Third-person steps.** 26 of 49 own-words sends in 11-09 name the user
   in the third person, 16 carry an ask id (11-06: 3 and 6 of 27). The rule
   is broken and no harm is on record; left alone. Act if a session
   misreads such a step.

6. **What deciding a batch costs the user.** Predicate: the user's typed
   messages in the driver's chat from asking what the next batch should be
   to its sessions opening, and the asks put to them for the pick.
   Baseline, 11-10: six messages, five of them adding instructions, and
   three asks (A37, A38, A39). After `PLANLAB-NEXT-BATCH.md`: the next two
   planned batches. Also count start notes a session found wrong at pickup.
   Drop the third session if its report changes nothing the user notices
   twice running.
7. **Critical questions.** Owed first: replay `q-critical-question` and its
   counter-case `q-checkpoint-mixed` on the `critical-holds` arm
   (`skill-evals`), which the mini's accounts had no room for on 11-11. An
   earlier wording that held the build parked the core of a fix in the
   counter-case (0 of 3, from 3 of 3). Then, per batch: asks marked
   critical against all design asks, hours each held its session, and how
   many the user took as recommended. Revise the wording if more than about
   a fifth of design asks are marked critical; reconsider the hold if
   nearly all are taken as recommended.

Retired, answered here: wakes that drew no action (12 of 76 in 11-09,
against 14 of 124 and the 70% the engine pass began from); strategic reviews
per PR (7 of 8 sampled, one skipped on a grant); "holds typed text" refusals
(none in three batches). Retired, not reached: the iTELL comparisons of
10-30 (no iTELL batch on mini2 since); a Rex restart's reopen; the 11-07
worktree counts, which need a pass of their own.

## 2026-11-11 — a critical question holds its work; UI changes show a prototype (same pass, mini2 `50c232d4`)

**Ask.** The user chose the hold over ask-and-build-on, asked what should
count as critical, then: the four kinds hold, add workflows people rely
on, state one principle with examples and leave the judging to the model;
and name the design skill for larger UI and UX work in planlab and itell.

**Corpus.** The 131 answers recorded in batches 11-02, 11-06 and 11-09
(`events.jsonl`, `took`): 40 amended or delegated, classed by hand. About
half were who hears what, six production or credentials, seven fix-here-or-
follow-up, and a handful design: what Loopy may do unasked (plugin
approvals, subagents and the wiki), what every user sees (streaming), a
definition a gate rests on (a planner rule, the pause threshold), standing
machinery (a repository variable). Not critical by the user's own answers:
how a fix repairs a failing case ("build the fix right now"), and
reversing a teammate's written position ("do what it thinks is correct
instead of waiting for him"). Design-skill use: user turns naming
`emil-design/SKILL.md`, 13 sessions since 11-04 on mini2 and mac; variants
then a pick in the permissions card, the Taodesk ticket page and the
tool-language card, "no need to prototype this time" for a small one, a
preview link that returned 404 in two, and streaming, which ran consult and
spec and was shown only when the user asked mid-batch.

**Changed.** The pipeline doc's § Who decides (the principle, its examples
and counter-examples) and its design stage (the three `emil-` keys);
NOTICE.md; PLANLAB.md's and ITELL.md's checkpoints.

**Not verified.** No replay: see open comparison 7. No driven session has
been sent an `emil-` key.

## 2026-11-10 — deciding the next batch, and critical design questions (improve-tool pass, mini2 `50c232d4`)

**Ask.** Formalize how the next batch is decided, which the user had been
typing by hand and through the bot; then, mid-pass: a really critical
design question should still be flagged for their agreement, recommendation
or not.

**Corpus.** The Session Driver's transcript, 11-02 20:49 to 11-10 20:52 GMT
(archive from seq 1, read with `grokbot-transcript`); the session index on
mac, mini and mini2, all reached; the 11-09 batch's `sends/` and event log.
Predicate for a run that decided a batch: a user turn in a planlab session
containing `next batch` or `parallel sessions` (or the Slack triage's
opening), read in context. Seven before 11-10: `mini:74869f39` (10-13),
`mini:fec0d58b` (10-15), `mini:3d3bb977` (10-17), `mini:49eba4bf` (10-27),
`mini:4b3e8b77` (10-30), `mini2:dc974e02` (11-02, the bot's O1),
`mini2:da19e9fb` (11-06). Not read: the three 11-10 planning sessions' full
reports, drive's code beyond the park and carry-over paths. None of the
five open comparisons was reached: the batch they wait for opened at 20:58.

**Found.**
- **The user retyped the procedure each run.** On 11-10 they sent six
  messages from the ask (14:52) to the start notes (17:09), five adding
  instructions. Earlier runs carry the same ones: measure in production
  before judging (3 of 7), a Fable and Astra review of the batch notes (3
  of 7), start notes or briefs per session (4 of 7).
- **A fresh review of the two reports paid, once.** `batch-coordinator`
  (`mini2:6189b211`) corrected five facts in them, one a storage deadline
  already stale by a teammate's PR, and turned 13 proposals into 11.
- **Three asks for one decision.** A37 and A38 were answered before the
  review reshaped both.
- **The driver closed the two gathering sessions at 16:09 and 16:22,**
  while the review of their reports ran until 16:44.
- **All eleven worker sessions opened from start notes in a session's
  scratchpad under `/tmp`,** with a copy in `/tmp/b1110`.
- **The planning sessions ran in the old batch,** because a new one would
  have stopped a parked session's 09:00 wake; the driver then carried that
  wake by a timer in the new batch.
- **No file showed `drive open --snippet`,** and none of 98 open events on
  mini2 used one (pattern not checked against the log's schema).
- **A single session would not hold both sources:** the two 11-10 sessions
  peaked near 455k tokens each and the one of 11-06 at 771k, by the index's
  figure, unchecked against cache accounting.

**Changed.**
- New `PLANLAB-NEXT-BATCH.md`, routed from PLANLAB.md's opening and the
  pipeline doc's stage 1; the four snippets are in planlab's
  `.tabtype.local.toml` (`tabtype/EVIDENCE.md`, same date).
- `brief` skips a folder whose name starts with an underscore (brief
  `22534aa`), so `_batches/<date>/` travels in the shared handoffs clone
  without reading as a route.
- A critical question: the pipeline doc's § Who decides, NOTICE.md,
  PLANLAB.md's checkpoint and a clause in ITELL.md.
- **Cut:** PLANLAB.md's "Next-batch priorities go to onboarding as your
  suggestion; onboarding decides the order and what runs in parallel." It
  kept a driver from fixing the batch's order itself. The new file's step 1
  sends the last batch's follow-ups after the key and its step 2 decides the
  order. Bring it back if a driver picks a batch's contents with no
  planning session when the user asked what it should be.
- The size record rose by the new file, raised by hand.

**Verified by replay** (`skill-evals` `cases/drive-step`, the files inlined
as arms `fable-default` for the text before and `next-batch-2` after; Opus
5.5, three judge passes, n=5 unless said):
- `q-next-batch`: 0 of 5 before, 5 of 5 after. Before, the driver opened one
  planning session with a prompt of its own in every run.
- `q-critical-question`: 0 of 5 before (asked, but no message until the
  combined report), 5 of 5 after.
- `q-checkpoint-mixed` 5 of 5 both; `q-open-review` 3 of 3 after.
- `q-inside-change` 4 of 5 before, 2 of 5 after, and `q-docs-pr` 3 and 2 of
  5: the `told` check is lower after in both (1.00 to 0.73, 0.60 to 0.40),
  each interval reaching 0. One run after asked a choice the case wants
  told. Not distinguishable from noise at this count; open comparison 1
  watches it.
- Two cases were reshaped after a first run, both disclosed in the case
  files: `q-next-batch`'s `notes` check asked for a mention the driver has
  no reason to make when it sends the snippet by key, and
  `q-critical-question` first required the build to wait.
- The first baseline run (`runs/next-batch-1110`) installed the skill
  without inlining it and is void: the driver had no instructions.

**Verified by reading.** A fresh reader ran revise-prompt's pass over the
new file, the four snippets and the pipeline sentence, with drive's and
brief's help: about 35 findings, folded in except two the user had decided
(a driver may adapt a snippet; a start note gives an early view on
strategic review). It verified by running that every command example
matches its help, that the four keys resolve, and two defects in the
existing triage snippet.

**Not verified.** The route from PLANLAB.md to the new file as a bot follows
it from disk, since the replay inlines both; any session started from the
three new snippets; `brief sync` publishing a `_batches/` folder; `drive
--batch <old> close` after a new batch beyond the one close on record
(11-10 20:56); a parked session joining a new batch by `--as`, which
drive's `TestASessionAnotherDriverDrivesIsTheirs` covers for a send.

## 2026-11-10 — what three driven batches cost the user (improve-tool pass, mini2 `427f5995`)

**Ask.** Make the pipeline and the drive procedure easier and more robust
to carry: fix the obvious bugs and find the high-leverage changes, from the
real sessions. Then, on the proposal: sessions and reviews should not be
overcautious; no question kinds in the engine; a session with a
recommendation carries on overnight.

**Corpus.** The Session Driver's transcript, 11-02 20:49 → 11-10 12:28 GMT
(113 user messages, 381 bot messages); mini2's batches 2026-11-02, -06 and
-09 (events, `sends/`, `watches.log`, `drive metrics`); 8 of the 25 PRs
those batches merged, chosen for coverage, each traced through its
sessions' reports and commits; hand-driven planlab sessions 10-25 → 11-10
on all three machines. The mini's older batches and the bot's command lines
before 11-09 22:00 are not covered. Ledgers in that session's scratchpad:
`ledger-A.md`, `ledger-C1.md`, `ledger-C2.md`, `ledger-M.md`.

**Observed.**
- **Where 220 hours went** (8 PRs, first prompt to merge): sessions working
  17%, waits inside a turn 22% (CI is about an hour a push), waiting on the
  user 58%, holds and driver delay 3%. The overnight design checkpoint is
  about 50 of those hours, one churn-stop ask 41.7, one hold 23.
- **A third of the asks were already handed over:** 41 of 127, by hand
  class against § Who decides. In 11-09, 14 of 34, of which 12 were answered
  as recommended; A24 held #11027's merge and release from 02:59 to 09:31.
  Design questions were taken as recommended 35 of 38 times. The user's
  amendments went to messages to people (9 of 16), announcements (5 of 11)
  and production access (5 of 18). Their words: "A22, I don't really care",
  "no need to ask me".
- **The ask is the bot's only shape for a choice.** It records a session's
  question as an ask even when nothing waits (A22: "Both stay as Search left
  them"), because § Report's examples of things done without asking were all
  actions, none a choice between options.
- **The review round was skipped in 4 of 15 building sessions** (11-06: S2,
  S3, S4; 11-09: S3). Each got its build step in the bot's words with the PR
  named ("Build … as one PR now"), took the team's `pl-pr` → `pl-land`
  path, and ran `pl-local-bugbot-cycle` (2, 12 and 8 cycles in the three
  sampled). In those three the strategic review then found behaviour
  defects by probe. On #10800, 12 cycles made 1,637 review-fix lines
  against 1,074 feature lines, hit the churn stop, and the ask to lift it
  waited 41.7 hours though the session's own report said the refactor
  belonged to the strategic review.
- **The strategic review earns most:** a behaviour defect in 5 of 7 runs, a
  reshape in 7 of 7, a median 23% of the PR's line changes. PR bots: a
  median 78 minutes, mostly idle, for at most 1.1%. Four of seven review
  reports say earlier rounds patched one premise.
- **Escapes** (15 feature PRs): no revert and no regression fix; one
  adjacent gap fixed by a teammate after the PR that skipped its strategic
  review; one residual found by an owed read. Four owed reads are pending.
- **A hold outlived its work.** A step sent with `--hold release` also
  started a nine-hour eval; drive keeps a hold while a job its holder
  started runs. Nine of 19 refusals in 11-09, a second hold name invented
  under two grants, and "why did you not get notified".
- **A wait on an outside event became a question.** `park`'s refusal lists
  "ask" first; A12 ("Is Glen's #11015 on develop yet?") was recorded one
  second after it, when the PR had merged seven minutes earlier.
- **The closeout example always refused:** `--snippet closeout "<text>"`
  expands to a body whose first line is a typed-only command. Ten refusals
  in three batches, each recovered by retyping.
- **Riders written by hand:** "Fold these in" was extended in 15 sends
  across 12 sessions (an independent review of substantive fixes, the
  prompt check, a docs pass, do not merge); a docs pass was written into 8
  merge steps.
- **Stops:** at least 9 answers needed a question first ("can you repeat
  A21 and A22"); 20 of 113 user messages asked for status, 4 of the replies
  carried the page link.
- **Left alone:** third-person steps (comparison 5); labels `S1`…`S8` in all
  three batches, which drive's help stopped showing on 11-09; 106 of 381
  bot messages opening as progress notes; `left by` lines for three unmerged
  branches on every status.

**Changed.**
- SKILL § Acting and asking: a choice a session or the driver settled is
  told with the option passed over, by a note on the session and a line
  under Done without asking; § Report's example and bullet show one.
- SKILL § Each step: a wait on something outside the batch is a park
  `--until` the driver checks itself.
- PLANLAB and ITELL § The design checkpoint, the pipeline doc's § Who
  decides and NOTICE: a design question with a recommendation is recorded
  as an ask whose unanswered outcome is "builds as recommended; the merge
  waits", and the session goes on. A question with no recommendation still
  holds the build. A merge waits while a design question is open.
- PLANLAB § After the PR: the review folds its own findings; a churn stop
  before the strategic review goes to that review.
- The pipeline doc: stage 7 names `pr-stage-check.py`; stage 8 is the
  team's `pl-land`; a fact that can be looked up is looked up.
- `strategic-review`: a driven review folds after its report; the fold is
  read (a `/review` round over substantive fixes, the prompt check, the
  docs pass) and settled before its own merge step.
- `claude/.claude/hooks/pr-stage-check.py`: the first `gh pr create` in a
  PlanLab session with no review round is refused once, with what to run.
- drive (`usage-fixes`, merged as `2185870` and installed on mini2 at 16:17
  the same day by a drive session): a keyed typed-only snippet with trailing
  text is typed with the rest attached; the park refusal and the wake's
  default lead with the outside wait, and the ask reads as a decision only
  the owner can make; `drive free` hands back a hold that only a background
  job of its holder keeps; a waiter refused before it joined the batch is
  cleared; git finds its repository from the directory it runs in.

**Cuts, with what each guarded.**
- "so a run after a compaction or reset reads it" (the plan note): the
  reason, which § How a drive runs step 3 states.
- "and the report names what ran on a default": § Report's last bullet
  asks for the defaults taken.
- "Nothing goes past the checkpoint without the user's word; this outranks
  SKILL.md's Continue": a design built on a recommendation the user would
  have amended. Bring back at comparison 2's signal, or on the user's word.
- The stop before a driven strategic review's fold: a finding the user
  wanted to sort first. Bring back if folds land work the user reverses.

**Verified.**
- *Replayed* (`~/dev/skill-evals` `drive-step`, three cases built from the
  batches before any edit: A31's docs PR, A18's choice inside a change,
  and 11-06 S1's checkpoint with a customer write in it). Arms carry the
  driver's files whole, at `6a3a845` and as revised; Opus 5.5 stands in for
  the bot; Sonnet 5.5 judges, three passes; n=5 an arm.

  | case | at 6a3a845 | after the reader's pass | as shipped |
  |---|---|---|---|
  | checkpoint with a customer write | 0 of 5 | 5 of 5 | 5 of 5 |
  | a choice inside the change | 2 of 5 | 5 of 5 | 5 of 5 |
  | a docs PR the session recommends | 1 of 5 | 3 of 5 | 5 of 5 |

  Checks passed per run, of 11: 6.27 at `6a3a845` against 10.60 (90%
  interval of the difference +3.07 to +5.47; run `drive-asks-1110c`), and
  10.80 for the text as shipped (`drive-asks-1110d`). The middle column
  lost the docs PR's telling in two runs: a restructure had dropped the
  words that name the note, and they went back. The two guards, no write
  in a customer's workspace and no message to a customer without the
  user's word, held in every run of every arm. Limits: the old text also
  sent the docs PR without asking (5 of 5), so the replay did not reproduce
  the bot's ask there and shows only the telling (0.13 → 0.87); three
  checks were loosened after the first grading, where they failed what the
  rule intends (a park once the work is done, going on to the spec, the
  recorded asks as the telling), and every arm was graded on them.
- *drive:* each fix has a test that was red first; `make check` was green
  at the branch's tip. Installed since, but no batch step has yet taken the
  new paths.
- *The hook:* 159 cases on synthetic payloads with a stub `claude-steps`,
  under both Pythons; no live session has met it.
- *By reading:* a fresh reader ran revise-prompt's pass over every touched
  surface with none of this pass's reasoning, and found 16 things, all
  handled. The ones that changed these files: the rule's edges differed
  between files (a question with no recommendation held "the build" in
  three places and "the work that depends on it" in two; "before the merge"
  read as every merge); BOT.md's model stop still ended "stays parked"; two
  SKILL examples still showed a decision holding a build; an amending
  answer goes to the session that holds the change, which after the review
  opens is `sr-`; the emergency-merge bullet contradicted `pl-land`.
- *At the landing:* a second reading by revise-prompt's pass cut what
  drive's own help says (the command for an outside wait, how long a hold
  lasts) and one of the two statements of the checkpoint's reason. Side by
  side at ten runs a case the text before and after were level (10.90
  against 10.80 checks a run, interval −0.40 to +0.20; `drive-asks-landed2`),
  but both checkpoint failures were the driver parking the session at its
  design, and only without the reason (2 of 15 with `drive-asks-landed`;
  0 of 15 before). The reason went back as a clause: 0 of 15
  (`drive-asks-landed3`). The choice told and not asked misses about one
  run in fifteen in either text. The hook's suite and two drive tests from
  this pass asserted message wording; they now assert what a refusal names
  and the order of its ways.
- *Not verified:* a real bot on the revised files; the design-checkpoint
  experiment; anything on iTELL.

**Found on the way.** A worker ran drive's suite under `git rebase --exec`.
Git exported `GIT_DIR`, and the suite's fixture commits and `core.bare`
landed in `~/dev/drive`. The checkout was restored (config reset, a stale
worktree entry pruned, a stray branch deleted, `main` equal to
`origin/main`), and `internal/gitenv` closes the gap with a test that was
red first.

## 2026-11-07 — sessions follow their own worktrees; `/enter-worktree` goes (improve-tool pass, dogfood)

**Ask.** An agent that makes a worktree should end up working in it, driven or
not, with no slash command; `EnterWorktree` binned, the skill too if a dogfood
says so.

**Corpus.** Obelisk, all three machines, from 2026-09-15: 81 sessions that ran
`gwt create`, with 20,780 later Bash calls, 7,879 of them (38%) `cd <worktree>
&& …`. 559 "session is isolated" refusals in 33 sessions, against about 35 that
entered through `EnterWorktree`. Dogfood: batch `wt-dogfood-1107`, 7 real
sessions on the laptop under `drive`, run from a Claude Code session rather
than a bot, Sonnet and Opus, two scratch repositories.

**Observed.**
- `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1` in `.zshrc` silently reset every
  `cd`, so prefixing was the agent's working answer to a false system prompt.
- `EnterWorktree` isolates the session: `git add`, heredocs, `sed` and `pnpm`
  refused, and every Bash call after the worktree's removal. 23 of its 44
  sessions came through the skill, 14 of them after `session-cd`, which needs
  tmux and so fails in Rex.
- No rule, no gwt in the repository (P1): raw `git worktree add` into
  `~/dev/.worktrees/add-mul`, a slot gwt would not choose, so nothing followed
  it and no `/cd` landed.
- With the rule (R1, R2, O1, D1, D2, D3): all six ran `gwt create`, moved, and
  their transcripts moved with them. Bash calls that carried a path after the
  move: 0 in five, 1 in O1. R2 and D3 stopped first and were told in plain
  words to build, which was the skill's one job under drive. D2 launched in a
  subdirectory with a stray empty `.git`, the itell shape.
- R1's closeout from inside its worktree merged, removed and ended on main.
- A killed session (D3) came back on its worktree by the `next:` drive printed.

**Changed.** The env var left `.zshrc`; `~/dev/.worktrees` joined
`additionalDirectories`; `EnterWorktree` is denied; the worktree mod follows a
new branch checkout under gwt's root (shell at once, `/cd` when the turn ends);
`rules/worktrees.md` names gwt without promising a move, since none comes from
a linked worktree or for a second one; drive's `reopen` reads the transcript for where
a session last worked; `enter-worktree` and `session-cd` are gone, and the
step line above says to ask for a worktree in the text.

**Deletion to watch.** `enter-worktree` named the branch from the conversation
and carried the move. Bring a skill back if sessions told to build in a
worktree stop reaching for gwt, or name branches badly with no conversation to
go on.

**Limits.** Seven sessions on toy tasks, on the laptop, with no bot: wakes and
real work are unmeasured, and the 38% is not yet re-measured. Throwaway
checkouts also went through gwt in a headless check (2 of 2), and cleaned up.

**Next pass compares.** The share of post-create Bash calls with a `cd` prefix
(38%), "session is isolated" refusals (none should come from `EnterWorktree`),
any coordinator moved by the mod (must stay 0), failures from `cd` now
persisting, and how often the main-checkout guard and the `worktree add -b`
refusal fire (a session that then reached for gwt, or one that worked around
the refusal).

## 2026-11-05 — the first batch after the engine pass (drive maintenance pass)

**Ask.** A maintenance pass over drive (`go-cli/MAINTAIN.md`), starting from
how the bots used it.

**Corpus.** mini2's batch 2026-11-02 (1,262 events, 2 Nov 20:56 → 5 Nov),
its `watches.log` and `drive metrics`, the Session Driver's transcript from
2 Nov, and the mini's batches 2026-10-24, 2026-10-28 and itell-2026-10-28 for
refusal counts. The bot's command lines are still unreadable (cursor
wrappers), so usage errors (exit 2) are uncounted.

**Observed.**
- 14 of 124 session wakes were followed by no action, against 70% of the
  engine pass's corpus (other batches, so no measure of its saving); 21 rode
  another session's post.
- All 10 `job-running` wakes (a job running, a reply that neither asks nor
  says it waits, ten minutes on) drew no action, and each session moved on
  with none, its next wake 4 minutes to 7 hours later; the log does not say
  its job's end was what moved it.
- A weekly usage limit on 3 Nov failed five sessions' steps and left three on
  its menu. drive's next: was `timer 900 'retry …'` for a limit lifting 45
  hours later, so the bot asked the owner, who said to exit and resume on
  another account; the bot did it outside drive, leaving two copies of
  sr-10450 (N46, N48). S8's gone wake then reopened it on the limited
  account. Picking Stop on the menu writes nothing to the transcript (S5's).
- `record answer` given the owner's words as its last argument typed them
  into O1 as the step three times (A14, A17, A18, one a production
  breakglass turn on the quote alone). A refused answer-with-step lost the
  answer twice (A21, A24; the owner answered A24 again the next day).
- The batch logs hold 30 refusals of two kinds across four batches, each
  fixed by hand the same way: a typed line over 500 bytes (15) and a
  typed-only skill heading a file (15, 13 of them
  `/pl-loopy-handoff-distill`).
- "another driver is sending" three times, each the bot's own overlapping
  run.

**Changed.** In drive: a usage limit's next: relaunches on another account
(Stop on its menu, close, `open --resume` with the step), or says to tell
the owner and park until the reset, and the limited account is never offered
again; `record answer` needs `--source`; a line too long to type goes as a
file, and a `--file` step headed by a typed-only skill is typed as that line
with the rest attached; a refused answer-with-step says the answer is not
recorded and how to record it; a lock held by the bot's own run says so. A
turn whose own job runs now wakes when the job's end resumes it, or at two
hours, unless its reply asks: the engine pass kept ten minutes for the two
reports in its replay that ended with a job left running, and such a report
now reaches the bot up to two hours later. Here, relaunching for a usage
limit joins what is done without asking.

**Next pass compares** wakes followed by no action against 14 of 124 here;
the `job-running` and `job-wait` wakes at two hours that carried a finished
report the bot then acted on, which is what the hold costs; usage-limit
relaunches and whether any needed the owner; refusals by kind against the
30 typed-step refusals here.

## 2026-11-02 — what a driver's wakes cost (engine pass)

**Ask.** Make the Session Driver cheaper and calmer, starting in drive. Each
webhook post is a model run. Worked from the owner's reading of the chat, 15 Oct
to 1 Nov, and checked against the record.

**Corpus.** The mini's batch logs 2026-10-24, 2026-10-28 and itell-2026-10-28
(1,012 posted wakes over 9.2 days) and the 42 transcripts of their sessions. A
wake's cause is not recorded, so one posted 9.5 minutes or more after both its
reply and its arming is taken as the ten-minute cap on a turn with a job running.

**Observed.**
- 679 of the 995 turn-ended wakes came from that cap, and 666 of those drew no
  action: 258 distinct replies, up to 28 wakes each. Median gap between wakes
  no action followed: 10.3 minutes.
- Of the 13 capped wakes followed by an action, 7 were real endings with a job
  left running (reports or decisions, all 1,425 characters or more), 4 were the
  bot noticing a job that should have ended or a CI result the session had not
  picked up, and 2 were steps the owner sent that the wake had nothing to do with.
- The 1 Nov outage is invisible to the webhook: the post at 12:53 answered 200
  and no run followed, so nothing that reads HTTP status can see it.
- A run's actions land 33 seconds after its wake at the median, the last of them
  within two minutes at the 90th percentile.

**Changed.** A turn whose job runs wakes no one while its reply says it waits; a
reply that asks wakes in a minute, any other in ten, once per view, and the watch
stays armed. Endings share a post at most every three minutes. Wakes no trace
followed back off to one try every two hours. `drive watch --due-all` is the
machine's watchdog, with no model run when nothing is due. One command for an
answer and its step (`record answer … 'step'`) and for what closed sessions left
(`cleanup`). After-wake commands run hourly at most.

**Replayed** through the classifier as reviewed: 1,012 wakes become 389 posts and
11 ask rechecks, a 60% cut, with 45 endings carried by another's post. Letting no
reply stay silent on its words gives 547 posts and 11 rechecks, a 45% cut. Of the
266 distinct capped replies, 168 read as waiting, 64 as ended, 34 as asking; the
patterns were written on these same replies, so there is no held-out measure of
what they miss. The replay holds the bot's actions at their real times and infers
the capped wakes from elapsed time, so it models posts, not runs. In it the seven
real endings all still wake: the five that ask nine minutes sooner, the two reports
from as soon to under three minutes later once pacing is counted. Three of the four
cases of the bot catching a stuck job or a CI result now reach it at two hours, not
ten minutes, unless the job ends first; that is the price paid. Varying the hold
from one hour to four moved the total by about 5%.

**Next pass compares** `drive metrics`' wakes, carried, wakes by cause and
"followed by no action" for a batch after this, the causes now recorded rather
than inferred from elapsed time, against 70% of wakes (706) followed by none here;
whether any turn sat parked behind a job with a question in it (grep a batch's
`done` wakes for a job listed, and read those replies); and how often the two-hour
backstop was what caught a stuck job.

## 2026-10-30 — how the drivers read the pipeline (improve-tool pass)

**Ask.** After the tstack-style rewrites and the prompt-engineering overhaul,
learn from the bots' use how well they understand the session pipeline, and
make it clearer. Laptop session `2bb79cc3`; ledger, scripts and both chat
readers' findings in its scratchpad (`drive-session-frictions.md`,
`itell-chat-findings.md`, `sd-chat-findings.md`).

**Corpus.** `grokbot-transcript` for ITELL (10-28 → 10-29 23:47, both
machines) and the Session Driver (10-26 → 10-29 23:49); batch records
2026-10-28 and itell-2026-10-28 (mini), itell-2026-10-29, -29b, -29c (mac);
266 send and open intents with their step files; 29 driven sessions, 30
found in obelisk across the two machines. The bots' shell commands are not
readable (every `$` line is a cursor wrapper), so which files a run read is
unknown. Steps after the 10-29 voice change are those from 11:45, when the
mini's drive first typed an `@` step.

**Observed.**
- **Stage order holds** for both bots: onboarding → design → spec or build →
  review and verify → prompt check → land → code review → strategic review
  → fold-in → merge → recap → closeout, with iTELL's verdict checked by the
  bot every time and every merge on `--hold itell-main`.
- **Asks beyond § Who decides' two kinds** (both bots, recurrent): the
  Session Driver asked about a gate's evidence (A14), opening a strategic
  review (A18) and branch cleanup; ITELL about retiring a brief (three
  times), opening a fix session, closing a session, and a migration (P3, P4,
  A), which `apps/platform/CLAUDE.md:28` ("never self-apply a migration")
  made the sessions hold though it rode the merge unasked.
- **Standing rules kept in the bots' memory** (both, 4 instances): "from
  now on…" grants (ITELL 11:56, 18:30, 18:31; the Session Driver's
  emergency-label rule carried from batch 2026-10-24 into 2026-10-28). One
  `drive record grant` in five batches.
- **Stops without the user-facing effect:** after the 10-27 fix the user
  still asked "whats a direct user impact?" or for "a straightforwarad
  explainaation" of three Session Driver stops (10-29 14:39, 20:13, 20:58);
  each plain rewrite was answered within minutes.
- **Post-PR mechanics:** three planlab merges went as hand-written file
  steps without `--hold release`; builders were closed without recap once
  their strategic review opened, on a rule the bot made after the user's
  17:37 correction; ITELL opened no strategic review until asked (23:47),
  its profile saying "Ignore PLANLAB.md" while ITELL.md pointed into it.
- **Step voice** after the 10-29 change: Session Driver 8 of 51 own-text
  steps in the third person, all relays of the user's answer ("A16 from
  Qiushi: …"; 23 of 30 before); ITELL 3 ("Qiushi answered A1", "Owner
  answers…"). ITELL typed `/onboarding Read /tmp/p4.md and do what it says.`
  for both openings of batch -29b instead of `@`.
- **Chat:** "On it" / "checking" messages remain, 19 of 66 (Session Driver)
  and about 44 of 162 (ITELL), against BOT.md's rule; most answer a user
  message seconds before the result.
- **b0fa861** (ITELL's own edit, user-approved, unpushed) failed `skill-sync
  --check` (+38 body, +370 total), left the pipeline doc saying only the user
  can sign in to staging, wrote a deploy route through
  `deploy-platform.yml --ref main` an hour after `release.yml` (#419) made
  that the escape hatch, and added "a planning session's numbered PRs can
  skip a number" from a misread: NB's plan had a PR 5.
- Two typed `/strategic-review` openings arrived as "i/strategic-review"
  (2026-10-28 log 15:55, 21:09): 76d0f53's revise condition.
- Late 10-29 the Session Driver's wakes went unanswered while Grok's own
  command safety check errored; outside this skill.

**Changed.**
- SKILL.md: § Asking opens on the two kinds, with the 10-29 asks as its
  cost; a "from now on" rule is recorded for the batch and sent to the user
  as a line for these files; the report's Needs you says who using the
  product would notice each option.
- BOT.md: a stop says what each option changes for the people using the
  product; a stop opens on its goal, the target example says what happens
  unanswered; the project file read is PLANLAB.md or ITELL.md.
- PLANLAB.md: the builder is recapped and closed once its review session
  runs; a merge uses the key with its context after it, with the cost.
- ITELL.md: which PLANLAB sections hold; a migration is no ask of its own;
  strategic reviews on the bot's judgment; the production deploy runs from
  the merging session, through `release.yml`; a new table is classified
  before its merge.
- `docs/session-pipeline.md`: iTELL's finish, strategic reviews in itell
  batches, a reversed answer reopens a design question (and NOTICE.md); the
  PR-numbering line removed.
- Handoff: `~/dev/.handoffs/drive/stray-i-on-open.md`.
- Deletions to watch: "On the mac, batch.json's `after_wake` is a list"
  (bring back if a bot edits batch.json by hand); "every action names the
  view … refused once moved past" (drive's help opens on it; bring back if a
  bot sends on a stale view without reading again); how drive handles a
  held peer message (bring back if a bot delivers one); "`DEPLOYMENT.md` is
  at the repository root".
- Size record raised by hand (skill-budget.yaml), with the reason.

**Validation.** A Sonnet cold reader on six scenarios over the changed
files: eight defects; the stale deploy route and the late table check were
verified against `learlab/itell` origin/main and fixed, as were the PLANLAB
scope, the reversed answer, the hold sentence that read as permission, and
the message opening. Not fixed: who deletes a merged PR's remote branches
(minor). Not run: an eval replay. The bots run Grok, the 10-29 Grok route was
stopped, and an Opus writer tied on these behaviours before, so no runtime
claim is made.

**Outside this skill** (for the user): each bot's profile is where a chat
reply's rules land, since a run woken by a chat message need not reread
BOT.md, so the "On it" messages want a line there; ITELL's profile should
read PLANLAB.md where ITELL.md points; Browser Test asked for the user's own
words four times after a standing grant.

**Next pass compares:** asks outside the two kinds per batch (target none);
"from now on" rules recorded and proposed as lines; plain-terms re-asks of
a stop (target none); merges sent through `merge-when-ready` with `--hold
release` (target all); iTELL migration holds (target none) and strategic
reviews opened unasked; deploys run by a session through `release.yml`;
third-person answer relays. Revise if a migration rides to production
in a way the user would have stopped, or a deploy from a session ships
something the bot's report misses.

### Same day — a cold read for length

**Ask.** Read the whole skill and the pipeline doc again: shorter, still
expressive, by the rulebook. A Sonnet cold reader (scratchpad
`coldread-brevity.md`) found the split right and the cost in repeats.

**Changed.** SKILL.md's authority text is one § Who decides (it was four
places, the two kinds stated twice); the two `drive open --goal` examples
are one; the per-session report bullet is three sub-bullets. BOT.md reads
four pipeline sections and no NOTICE.md (drive attaches it); § Your memory
folds into § Waiting; a choice card holds one decision; the target stop
example names what each option changes for people using Loopy (the trimmed
pair the reader drafted waits for a `relay` replay). PLANLAB.md keeps only
what is planlab's own; its `/write-spec Read /path…` example, the form the
Session Driver typed six times on 10-29, is now an `@` attachment. ITELL.md
carries its own design checkpoint and strategic-review commands instead of
pointing into PLANLAB.md. The pipeline doc: one "hold only the step"
statement, "when unsure" split between a reversible step (do it) and
whether it reaches a customer (ask), and the checkpoint for any batch with
unsettled designs. Words: SKILL 2825 → 2597, BOT 1971 → 1749, PLANLAB 1207
→ 990, ITELL 1398 → 1483 (inlined), read per run about 8,600 → 6,600.

**Parity read** (a second Sonnet reader, old f38d409 against the rewrite, two
scenarios): fixed what it found. A merge step again names its release hold
with its reason; SKILL's section is § Acting and asking, so "§ Who decides"
means only the pipeline doc's; ITELL's checkpoint got back `spike-check`,
"a session past its design goes straight on", "message only for a decision
that holds a session" and the spec call; the "when unsure" ask narrowed to a
write in a customer's workspace or data; ITELL's merge block names the review
session where one ran; `watches.log`'s location and a personal tool's merge
came back.

**Deletions to watch**, each with the sign that brings it back:
- "drive keeps two runs off one session…" (BOT): a bot resends on a stale
  view.
- "nothing in your shell tells drive which bot is asking" and the
  `--after-wake` reason (BOT): a bot drops `--driver` or `--after-wake`.
- "a new batch starts with no grants" as a comment (SKILL): a grant carried
  across batches.
- "These records are how the batch is measured" and the `--took` values
  comment (SKILL): asks left unrecorded, or an invented `--took`.
- "drive refuses a second send naming it… says what frees it" (SKILL): a
  bot routes around a hold refusal.
- "The user did not watch the night" and the recap's rationale (SKILL): a
  bot writes a session's summary itself instead of a recap.
- The goal's "they read it on their page" (SKILL): a bot rewrites the goal
  at every stage.
- PLANLAB's restated spec criteria, steering areas, docs-pass and
  foundational-finding lines, and BOT's "a message to a person goes as a
  draft" (all owned by the pipeline doc): a bot misses one of them.
- NOTICE.md off the bot's reads: a bot sends a session a step the notice
  already covers.

### Same day — the user's direction: fewer asks, strategic review by default, no dates

**Ask.** Make the bots and sessions more powerful rather than more limited:
the user stays in the overall design and the major product forks, and the
rest, down to the test account accepting the terms of service on staging,
is the driver's. A planlab PR gets a strategic review by default; a session
opts out when the change is contained and isolated, touches no production
path, and is a simple fix its in-session review has settled. Instructions
state what to do, never a dated incident.

**Changed.**
- `docs/session-pipeline.md`: stage 9 is the strategic review (planlab by
  default, with the opt-out; elsewhere on a named PR or an itell driver's
  judgment), recap is stage 10, the planlab finish and the merge conditions
  name it; § Who decides hands over anything reversible that reaches no
  customer ("when unsure whether to ask, do it and report it"). The
  "reverses an answer the user gave" ask this pass had added is removed from
  it and NOTICE.md: it widened the asks, and the user took every
  recommendation of the A19 it came from.
- PLANLAB.md: every PR gets a strategic review once its code review is
  handled, skipped only on the build session's stated opt-out.
- planlab's `land-pr` and `review-then-closeout` (`.tabtype.local.toml`,
  carried by `twin files sync planlab`): the session says in its report
  whether its change can skip the review.
- SKILL.md § Asking names what is the driver's instead of the 10-29 asks.
- Every dated clause left the model-facing files (SKILL, BOT, PLANLAB,
  ITELL): the 10-21/22 acknowledgement count, the 10-22 fast-forward, the
  10-23 first-turn merges, and this pass's own. This reverses 10-22's "kept:
  the two rules with their cited cost"; the reasons stay as what goes
  wrong. The prompt-engineering rulebook's fold-in rule now says so.

**Validation.** A Sonnet cold reader on five scenarios (an opt-out that
holds, one with no word, a review reversing a technical default, the
staging terms, an opt-out whose diff touches production billing) routed all
five without an ask; fixed from it: NOTICE.md lacked the reversible-step
category, § Asking now keeps asks for what only the user can do, an opt-out
is checked against the diff, and "installs something that writes it"
belongs to the migration. Not run: a live batch on these files.

**Next pass compares** strategic reviews opened per planlab PR and the
opt-outs given (each meeting all three conditions), and asks per batch.
Revise if a skipped review lets through a defect a review would have
caught, or a reversible step the driver took is one the user would have
stopped.

## 2026-10-29 — a Rex restart (drive `f847a7b`)

**Observed.** The mini's Rex server restarted three times for an app update.
Every watch woke its bot "gone" at 10:41; the Session Driver wrote notes
N20–N27 ("drive has no resume command", "asked Qiushi whether to relaunch
them") and parked, and the iTELL bot's own reopen of P1F failed on the
batch's missing Rex session. A watch's poll had started the new server with
the bot's `NO_COLOR=1`, so no pane drew dim text: P1F's unexplained typed
line (§ input boxes below) was its suggestion, read as typed until the
server ran clean.

**Changed.** drive never starts a server, and every report of a gone
session names the open that brings it back, which keeps the label's park
and starts the Rex session; a resumed cut-short turn wakes `interrupted`;
`drive watch --stop-all` stops the wakes before a planned restart
(`~/dotfiles/docs/rex.md` § Restarting). SKILL.md lets the driver reopen without
asking and says what the reopened session's step carries; BOT.md has the
watchdog reopen a gone session `--due` names, since a parked one gets no
wake.

**Next pass compares** the next restart's gone sessions: reopened by the
driver without asking (target all), and interrupted ones sent the
restart line rather than a bare continue.

## 2026-10-29 — steps as the user would type them (improve-tool pass)

**Ask.** The user saw the bots write each step to a file and send "read
<path> and do what it asks"; Claude Code's `@path` attaches a file, and they
want a driven session's prompts closer to what they would type themselves,
the notice aside. Mini session `9fb41991`; ledger and receipts in its
scratchpad (`drive-session-frictions.md`, `chat-findings.md`).

**Corpus.** Batches 2026-10-24, 2026-10-27, 2026-10-28 (Session Driver)
and itell-2026-10-28 (ITELL): 34 driven sessions and their transcripts; both
chats from 10-27 on, read in full by a delegated reader.

**Observed.**
- 157 of 157 bare pointers were read by the session's first tool call (141
  `cat`, 16 Read): the pointer worked and cost a tool call each.
- All 13 notice-only turns, ahead of a typed first step, ended "the step
  isn't here"; in 12 the session listed `sends/` or read `batch.json` or
  `events.jsonl`, and sr-9786 found its queued line there. A Sonnet replay
  in a bare repository did not dig (0 of 6) but wasted the turn (6 of 6).
- Claude Code 2.1.312: `@/abs/path` attaches the file, outside the project
  too, after a typed skill's arguments too, with no tool call. Typed through
  Rex, Enter on a line ending in a mention takes the file completion and
  sends nothing; a space after the path closes it. A mention queued mid-turn
  is not attached: the model Reads it, and on one account met a "read
  outside the working directories?" prompt.
- Bot voice: 23 of the Session Driver's 30 self-written steps open "Qiushi
  …" or "From Qiushi", five name ask ids the session never saw, all nine
  start files say "the driver then sends", and the six `/write-spec` lines
  type "for my answers" over files saying "he agrees". ITELL's add-ons are in
  the user's voice; 4 of its 5 briefs say "the owner".
- Chats (fewer than three each, recorded, not acted on): a stray `?25h` kept
  an ITELL session parked 16.4 h because `respond clear` fails in vim
  insert mode; a "you can send the note to Max" grant became a draft;
  plain-terms re-asks on 3 of the Session Driver's 11 stops (the 10-27
  revise trigger), and its 6 multi-question cards all skipped.

**Changed.**
- drive `7485faa`: a file step is typed as `@<copy>` with a trailing space;
  a queued one keeps "Read <copy> and do what it asks."; the notice rides a
  typed first step as an `@` mention, keeping its own turn only for a
  command no skill file backs, a queued send, or a line past 500 bytes;
  typed lines ending in a mention get the space; help and the typed-only
  refusal teach `@<file>`.
- claude-steps `5dcaec6`: a prompt that is one `@/path` mention is a
  pointer, answered by its file attachment.
- SKILL.md § Sending: write the rest as the user would type it, first
  person, their words and nothing they did not say, nothing of the driver,
  chat or record; typed skills take their brief as `@path` (PLANLAB.md too).
- Deletions to watch, each a mechanism drive's own messages state: "a
  refusal did nothing, read again"; how a prompt's `next:` shows the call;
  `close`'s refusal causes; the exit-4 message's details; "sessions drive
  opens have these nudges off". Bring one back if a bot misreads that
  message.

**Validation.**
- drive and claude-steps `make check`; a fake that takes Enter as the
  completion on a trailing mention; a live batch through real Rex and Claude
  Code (Haiku): `/echo-args 9786 @brief` arrived in one turn with the brief
  and the notice attached, a file step as `@copy`, zero tool calls.
- `~/dev/skill-evals` case `drive-step` (s4-amend, s2-agree, s1-followup:
  the 10-28/29 answers), Opus writer, Sonnet judge, subscription route, n=3
  per arm (`runs/drive-step-1029`, `-r2`). Voice and no-driver checks per
  run: current 1.67 of 6, revised 6.00, revised2 6.00. Faithful, after
  correcting the check to allow a hold the skill requires: current 2.00 of
  3, revised 0.67 (first person invited views the user never gave), revised2
  2.33. revised2 ("nothing they did not say") shipped. Not run: Grok as the
  writer, which is what the bots run; a calibration's s1-followup rollouts
  reached OpenRouter (Grok, kimi) before the user stopped that route.

**Next pass compares** the next batches' step files against these counts:
third-person openings, record ids and driver talk in steps; notice-only
turns (expected none outside built-ins and queued sends); `unknown` sends on
a line ending in a mention; claude-steps' file-pointer misses (59 of 261
before). Revise if a bot's first-person step states a view the user did not
give, or a queued `@` step stalls on a read prompt.

### Same day — prompt-engineering revision pass

- § Sending's opening now shows one avoid/target step pair (S2's real
  answer) and folds in "your own words only answer the session's
  question"; replayed as the `shipped` arm: voice and no-driver 12 of 12
  on s1-followup and s4-amend, faithful 5 of 6 once "nothing they did not
  say" came back (3 of 6 without it). s2-agree is the example's own source,
  so its 3 of 3 does not count.
- Cut, as drive's own message states them: "drive refuses one inside a
  file and prints the line to type". "A deny ends the turn" now says the
  next step is the driver's to send.
- NOTICE.md ends "The step is in this message or my next.": the old "The
  step follows" was false once the notice rides after a typed line.
- drive `--help` says an @PATH queued mid-turn stays a path and a queued
  file step is a line asking for the read; the typed-only refusal says
  "a file it attaches".

### Same day — input boxes drive could not clear

**Observed.** Three sessions over 10-28/29 held text in the box: ITELL's
P2 a `?25h` (16.4 h parked, two clears "failed"), ITELL's P1F "redeploy
staging from main and confirm the build" (refused twice, cleared by
nothing, the step never sent), the Session Driver's S1 "a stale typed line
naming nonexistent sends/S1-5.md". Every account runs vim editor mode.
Reproduced live (Haiku, Rex, 2.1.312): `ESC[` and `?25h` arriving apart
leave `?25h` typed; ctrl+u deletes only before the cursor, so with the
cursor at the line's start the installed drive's clear failed exactly as
P2's did; in NORMAL mode (after any Escape on an idle box) ctrl+u leaves
part of the line and a typed step loses its head up to the first letter
that inserts ("Reply with the word ok." → "th the word ok."). Claude
Code's suggestions copy the pointer form, "Read …/sends/S8-5.md and…" on a
live S8, so S1's "stale line" was most likely a suggestion the bot read
off the screen; drive reads those as suggestions. P1F's line, most likely
a suggestion that drive read as typed, did not reproduce: focus-in and an
attached client left the dim attribute in place.

**Changed.** drive `76d0f53`: on a vim account a box not showing `--
INSERT --` gets `i` before a step is typed or cleared; every clear presses
End before ctrl+u. The fake models vim mode and the cursor. Verified live:
the fixed clear empties the `?25h` the installed one could not, and a step
typed into NORMAL mode arrives whole.

**Next pass compares** "holds typed text" refusals and failed clears;
revise if a box reads typed text drive cannot clear again (capture its
`--format vt` screen: that is the evidence P1F lacked), or a step arrives
with a stray leading `i`.

## 2026-10-27 — who decides, in one place, and how a stop reaches the phone (improve-tool pass)

**Ask.** Borrow from tstack and pstack where it helps the pipeline; run the
experiments on the subscriptions (laptop session `f136bb24`). Receipts and
every run: that session's scratchpad (`experiments.md`,
`pipeline-borrow-ledger.md`, `pipeline-frictions.md`) and `~/dev/skill-evals`
runs on the mini (`relay-*`, `sizing-1026`, `cue-1026`, `recog-1026`).

**Observed.**
- The Session Driver's chat (10-21 → 10-26): the user asked for a status
  outline at least six times; 6 of 19 question cards were skipped, all
  jargon or housekeeping; the migration-gate override was asked three times
  and granted each time; standing grants (doc pass, merge after a clean
  strategic review, cleanup) were re-given per batch.
- On 10-25 the six design-checkpoint reports reached the user as one-line
  labels; the user asked for plain rewrites. A cold reader recovered the
  decisions from the originals, which were heavier (more "unclear", technical
  approvals mixed in), not undecidable.
- `relay` replays (7 real stops): Grok as the writer, judged by kimi,
  today's guidance 23.4 checks per message; a shown avoid/target pair 39.9
  (jargon explained 1.00 against 0.07, faithful 0.95); a field contract 39.6
  but faithful 0.67, since its fields make the writer supply missing
  recommendations. Opus ties the two forms; Haiku needs the contract.
- `checkpoint-sizing` (four 10-24 sessions forked at their reports): a
  sizing pass, a first-principles pass and the user's own earlier
  preferences each reached none of the user's 10-25 steering (0.00-0.67
  checks per run against the control's 7.00). The checkpoint stays a human
  stop.

**Changed.**
- `docs/session-pipeline.md` § Who decides replaces § What stays the user's:
  ask the user for design questions at the checkpoint and for mutations of
  production data; merge and release, a schema-only migration gate, docs
  passes, cleanup, internal channel posts and judgments handed to a fresh
  model go ahead; logins, shared machine state, unrecoverable deletes and
  the user's own text stay out of reach. The user asked for one place.
- `NOTICE.md`, `SKILL.md` and `PLANLAB.md` follow it instead of keeping
  lists of their own; `merge-when-ready` (planlab's `.tabtype.local.toml`)
  overrides a schema-only gate.
- `BOT.md`: a stop that needs the user is written for the user's state, with
  a real avoid/target pair (the 10-25 S1 card and the plain version the
  user asked for).

**Validation.** One cold reader, five files, ten scenarios: 15 defects, all
fixed (a destructive migration inside a release fell through both asks;
"who is told what" clashed with channel posts; PLANLAB's merge conditions
differed from the pipeline's; the example asked about a gate now handed to
the bot).

**Prompt-engineering revision pass** (same session, after the commit).
Fixed: a real customer's name in the grant example (now Acme; the public
history still holds it at `caf36e5`); the second ask's heading said "outside
a reviewed release" while its body named a release's destructive migration;
the migration gate defined twice in different words, and NOTICE.md and
`merge-when-ready` missing "installs something that writes it"; a double
negative in the prompt rule; an eval-score line in BOT.md (the reason is the
user's state, the score lives here); "S2's save receipts" in the example the
bot copies; `land-pr` and `review-then-closeout` still saying the merge is the
user's to start. Kept, on purpose: the example pair inline in BOT.md (the
lever the replays measured; the bot reads this file every run, a pointer
might go unread); A22/A23 and "1B and 2B" in the target, the user's own card
labels shown beside plain words; the lane-deletion clause in § Who decides,
the reason a rule about what an action touches overrides where it runs; the
stage list echoed in the merge condition, the gate it states; "never by
hand" for briefs, paired with what to do.

**Next pass compares** the next batch's chat against this one: status
asks, skipped cards, re-asks of a relayed stop, and any override the user
reverses. Revise if a schema-only override breaks a running release or a
relayed stop draws a plain-terms re-ask.

## 2026-10-24 — third dogfood (drive-session-test, dogfood-3-2026-10-24)

**Corpus.** The batch's record and notes, the three sessions' transcripts
and `claude-steps`, read as `DOGFOOD.md` says; the bot's chat after the
brief had not synced. It first finished dogfood-2 as asked (A1 moot, T3
closed).

**Findings.** Holds took turns: three closeouts into one main checkout, T2
refused while T3 held it, parked, sent once T3 closed. Wakes: 8 for sessions
and the veto timer, none failed. A wake that came while a job ran (T2's 11
minutes) said to watch again, and the session went on. Every first step
stopped where it should and asked for its worktree. Real: metrics counted
no merge, since each closeout removed its own branch before the close that
judged it; the unanswered-wake test never saw its repost, because `--due`
waits ten minutes and said nothing of it at eight; a parked waiter's line
kept naming its holder after the hold was free; the cleanup list assumed
the driver removes the branch. Rejected: freeing a hold at the merge, before
the holder's recap turn ends (a later step may still be closeout work, and
the cost is one recap turn); disarming the veto timer (second time). Outside
this skill: envoy names jobs per repository, so two sessions there that both
call a job `review-r1` collect each other's review (`~/dev/envoy`).

**Changes.** `drive` 7dcf4d9: a change merged without a pull request is
judged by the session's newest commit, by id; status and `--due` say when
an unanswered wake comes again, and the repost says it is one; a parked
waiter's line says its hold is free. This body: the cleanup is what the
last step left; BOT's veto timer brings nothing once the user answered.
`DOGFOOD.md`: the chat's sync, and timing in a pattern.

**Next pass compares** a run with the Session Driver itself once this branch
merges: the repost seen and acted on, metrics' merged changes against the
closeouts' reports, a report built from closed sessions' reads.

## 2026-10-24 — second dogfood (drive-session-test, dogfood-2-2026-10-23)

**Corpus.** The batch's record (`drive log`, `drive metrics`, its 16
friction notes), the three Sonnet sessions' transcripts, and `claude-steps`
on each. The bot's chat after the brief had not synced to the mini.

**Findings.** Wakes reached the bot: 7 for sessions and 1 timer posted, none
failed, none unhandled. A turn that ended on its own background job (T1's
`sleep 90 && pytest`) went on when the job ended, and one watch waited
through both. Not reached: closeouts taking turns on a hold, since all three
sessions merged themselves in their first turn after a step that named the
finish; `--due` re-arming anything. Real: `--batch` after the command was
refused on every watchdog run; a closed session could not be read for the
report; a stale-view refusal did not say a parallel run had sent the step;
metrics counted no local merge. The step-named-finish and the worktree
timing ("setup goes once it reaches the build", which a small task does in
its first turn) were the body's. Rejected: disarming the veto timer on a
grant (the run read the record, as designed). Test setup: after-wake
`grokbot-transcript --archive` exists only in this branch's script.
**Blind spot, kept:** a job a session detaches itself (`nohup … &`) is
invisible to Claude Code's registry and to `drive`: no terminal, its group's
leader gone, its environment unreadable. The bot wrote the stop step by
hand, as the job rule wants.

**Changes.** `drive` ea3ab20: read a closed or gone session from its
transcript; `--batch` anywhere; a stale view names the step drive sent;
a branch merged with no pull request counts, recorded at close. This body:
the first step says where it stops and asks for its worktree when it builds
at once (`/enter-worktree` alone only after a stop); a finish whose cleanup
follows closes instead of parking; the report trims what the driver has
since done from a recap.

**Next pass compares** a third run: two closeouts that take turns on one
hold, each told after its snippet key to stop at the local merge; a session
`--due` re-arms; after-wake on this branch's script.

## 2026-10-23 — dogfood by a test bot (drive-session-test)

**Corpus.** The Grok bot "drive-session-test" drove four Sonnet sessions in a
scratch repository through the personal-tool path by this branch's body
(`grokbot-transcript drive-session-test`), its report checked against the
batch's `drive log` and `drive metrics`.

**Findings.** Plan and veto, a file first step, `/compact`, two closeouts
taking turns on one hold, a park with an ask, recap, close and the report
went as written. Every one of the 14 wakes failed: the machine's one webhook
was the live bot's, `drive` armed watches it could not post, and metrics
counted the failed posts as watched turns. A background job (`find ~ -name
twin.toml`, from a closeout in a repository `twin` does not know) kept a hold
behind a turn `drive` read as done; no command stopped it, so the bot killed
it from its own shell. The bot sent `/enter-worktree` as a first step, and
the session waited for a task. Its proposals were mostly rules working
around `drive`: the fixes went where each wrong fact starts. The one it
made on holds (a send without `--hold` frees one) would have let a second
closeout land on a first one's follow-up, so the rule stands and its wording
changed.

**Changes.** `drive` 7191bd5 and 361964c: a batch names its own webhook and
refuses to start or arm a wake or timer without one; `batch new` starts its Rex session; a background
job is shown, says it keeps a hold, and is stopped through its session; a
compaction's output is its answer; a failed post leaves its turn unwatched.
This body: the first step carries the task, a job is the session's to stop,
the hold wording, BOT's `--webhook` and its premise (a command holds for
minutes, not a turn's hour).

**Revision pass (10-23, prompt-engineering).** drive 323fd10: a hold's
`next:` says what frees it from where the holder stands (answer its prompt,
or its job ends), and a wake or read with a job gives the stop step this
body points at; `--webhook` alone starts a webhook batch, so BOT's example
lost `--wake webhook`. This body: the hold bullet points at the refusal
instead of restating how long a hold lasts, a wording that had already
drifted once; the cleanup's `drive close` comment follows `next:` instead of
"leave it", which contradicted stopping a stale job; the first-step rule
holds the timing once. A Sonnet cold reader on the new hold and wake texts
routed them as meant. Kept: BOT's example names the Session Driver (its
reader); a test bot's owner gives it its own name.

**Next pass compares** a rerun with the test bot's webhook on its batch and a
task whose closeout is a local merge: wakes posted, wakes re-posted by
`--due`, a session that continued on its own, work the bot ran from its own
shell (target none).

## 2026-10-22 — strategic review of `drive` and this body (fold-in)

**Corpus.** `~/dev/drive` 05bbfd4..973e787 and this branch, read by area;
728 transcripts under `~/.claude/projects` (denies, `/compact`, queued input,
expired logins, resumes, held peer messages); the Session Driver's chat
10-21 11:04 → 10-22 15:58 (`grokbot-transcript`); three probe sessions on
Claude Code 2.1.308 (Haiku, isolated tmux, scratch directory, no Rex) with
every hook logged and the registry polled; read-only `drive read`/`status`
on the live blocks; two Sonnet cold readers playing the bot.

**Findings.**
- **Rex misses what drives need.** No hook reports a held peer message (Rex
  blocked, the session idle: live on e8fec0 since 15:46, every send
  refused), a permission prompt's first six seconds, an approved command
  until its PostToolUse, a queued turn, a `/compact`, a deny or an
  interrupt, or an API error (a0c02b read `working` after a weekly rate
  limit ended its turn). Claude Code's registry (`sessions/<pid>.json`
  `status`) says where the session itself stands and changed within 160 ms
  of each transition in the probes: `drive` now reads it first.
- **Wakes went missing:** `respond` armed none and status read the old wake
  as handled; the watchdog rule keyed on status words could not see it.
- **A first step with the notice** shared the step's intent, so a hold went
  free in the gap and a run killed mid-notice lost the step silently.
- **Text that did not run as written:** `drive wait` told to a bot, a
  literal `approve|deny` and `VIEW`, a relaunch on a view already moved and
  with `'<the step>'`.
- **Chat:** about a third of the bot's 148 messages were "I'll tell you
  once…"/"Checking…"; on 10-22 10:33 it fast-forwarded the mini's main
  checkout and reinstalled packages to run a CLI itself. Both rules were
  already in the body as bare rules.

**Changes.** `drive`: 30 commits (`git log 973e787..c5f2385`), each fix
pinned by a test that goes red with the line put back. This body: rewritten
shorter around command examples; the watchdog is `drive watch --due`; a
refused command arms nothing, so the bot parks; a window joins with `send
--as`; the plan is recorded for the veto run; recap before park; a cut-short
command is settled from the transcript; the two failed rules carry their
cited cost.

**Validation.** `make check`; installed. A cold reader on the new body with
real message texts generated from the fake. Not run: a live batch on this
`drive`, the bot itself on this body, metrics on a real night.

**Revision pass (10-23, prompt-engineering).** The body and drive's text now
divide the work: drive's `next:` carries the command for the session as it
stands, `--help` the words, this body the judgment; mechanics a message
states were cut here. A Sonnet cold reader on four routes that lean on
`next:` routed them all; the five lines it guessed at were fixed in drive.
Kept on purpose: the plan and report examples (patterns), the two rules with
their cited cost (no mechanism can stop a chat message or a shell command
the bot runs itself), PLANLAB unchanged (already example-led, its checkpoint
states its own precedence), NOTICE unchanged (the owner's voice to the
driven session, matching drive's notice-first delivery).

**Next pass compares** the first bot batches on this body against 10-21/22:
turns left unwatched (`drive metrics`, target none), wakes re-posted by
`--due`, acknowledgement messages in the chat (target none), work the
driver ran from its own shell (target none).

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
