# drive-session — evidence

Usage passes over the sessions that ran this skill, newest first. Each names
its corpus, what it found, what changed, and what the next pass compares. A
run by a real bot follows `DOGFOOD.md`.

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
(`~/dotfiles/docs/rex-restart.md`). SKILL.md lets the driver reopen without
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
