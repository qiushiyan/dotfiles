# consult — evidence log

One entry per mining pass over the sessions that ran this skill. The review
skill's log is `../review/EVIDENCE.md`; a pass over both records itself here
and leaves a pointer there.

## Decisions that stand

Each with the entry that holds its evidence. A pass that would undo one
reads that entry first. Review decisions whose evidence is in this log are
listed here; consult decisions bought on 09-14 and 09-15 are in
`../review/EVIDENCE.md`.

- **A position that rests on a number this session measured carries the
  data block, and the voice judges the method before any conclusion**, in
  consult and in both review briefs, with `DATA-BLOCK.md` the one home
  (09-22: "methodolog" in 0 / 43 briefs after data work, and each of the 3
  sessions where the user asked for the method to be judged returned a real
  defect).
- **One consult with no modes: every voice checks the problem, then judges
  the approach** (09-25: approach rounds redefined the problem in 13/43
  results by the host's read, and 14/14 diagnosis results carried a full
  fix design).
- **The voice's read comes before the reading list and before our
  position** (09-25, the user's choice; 40/62 round-1 approach results had
  declared their sketch non-blind).
- **"What we observe" is its own section whether or not the cause is
  thought settled, the falsifying observation keeps its own output item,
  and "not carried by the evidence" is a verdict** (09-25: adopted from
  both voices of the pass's own round; 0/82 approach briefs had an observed
  section).
- **The read is asked for as the opening section of the answer, never as a
  note to write down and report verbatim**, in `BRIEF.md` and
  `../review/GOAL-BRIEF.md` (10-04: cold Claude voices were blocked on 15
  of 39 briefs carrying the phrase and 0 of 16 carrying neither).
- **"Before reading on" in the heading and "or read past this heading"
  stay** (10-04: they are the text the replay ran, where 8 of 8 voices
  opened with the read and 0 of 8 added the caveat).
- **The body stays short, and a shortening is cold-read old against new
  before it ships** (10-28: the cold read found 14 of 47 behaviors lost or
  weakened in the first cut; all were restored).
- **Every voice's standing rules ride in `VOICE.md` as
  `--instructions-file`, for consult and review; the brief carries the
  problem and the ask** (10-28: 27–35% of a median 2,770-word brief
  instructed the voice).
- **Briefs are written by hand from the template; no engine builds them**
  (10-28: 0 of 400 rounds had the user correct the brief or dispatch, and
  the median from invocation to dispatch was 2.9 min for consult).
- **A consult's decisions stay with the user** (11-05: sampled decisions
  are product calls the user often answers against the recommendation; 5
  of 94 follow-ups asked what one meant, all before the 10-28 rewrite).
- **Both skills open on the three names the user dispatches by, with opus,
  sol, efforts and brief splits in More control at the end** (11-17: since
  10-27 consult asks named astra 56, fable 48, opus 0).
- **The procedures carry only what nothing else carries**: what the brief
  templates and the user's always-loaded closing rule say is not repeated
  (11-17: consult 1,431 → 1055 words, review 2,749 → 2320; every rule
  bought by a failure stayed).
- **Review's verify-and-fix steps stay though most of them have no entry**
  (11-17: a model does not do it by default), and review keeps the
  `VOICE.md` refusal fallback (11-17: cut and restored the same day).
- **A consult round's cap is 45 minutes** (11-18: 2 of 18 Carbon dispatches
  failed, one at the 30-minute cap).
- **No voice gets its own concision or labelling instruction** (11-18,
  measured on Carbon: neither rule moved its unsourced numbers, and under
  the sharper one fully right claims fell to 15 of 30 against 22).
- **Fable is the voice when none is named, in consult and review** (11-20,
  the user's word; before a review the user named no voice 118 times since
  09-15).
- **Neon on high is the Gemini voice, and no line tells the lead to check
  its numbers** (11-24, the user's word; the 11-18 line was measured on
  Carbon).
- **A voice's reading list lives in `VOICE.md` and nowhere else: the brief
  templates name a lesson by its idea, and no custom subagent holds one**
  (11-26, the user's call on subagents; 365 Claude and 476 Codex sessions
  read a lesson since 10-01, and a real brief with no path had all three
  providers open what it named).

## Open comparisons

Each is a measurement a pass can run. The first is this log's newest.
Where an entry names no result that would reverse its change, the item
says so.

1. **Lessons named by idea, after 11-26.** In rounds whose brief names a
   lesson without its path: the share where the voice opens that lesson,
   per provider (the voice check: 3 of 3 providers, one brief; 09-27: 49
   of 195 cited files never tried), and hosts that read `VOICE.md` or
   check a lesson path before a round 1 (10-29 to 11-26: 150 and up to 128
   of 246 sessions; the replay: 0 of 6). Put a path back in a template
   bullet if a provider skips its lesson in more than a quarter of rounds;
   look for another cause if hosts still open `VOICE.md` in half.
2. **Neon, after 11-24.** Unsourced numbers per verdict in Neon answers,
   against Carbon's 2.4 (Astra 0), and Neon dispatch failures, against
   Carbon's 2 of 18 (11-18). The step-4 numbers line cut on 11-24 returns
   if Neon states unmeasured numbers as fact; no threshold recorded.
3. **Names outside the table, after 11-17.** Asks naming opus or sol, and
   rounds where the agent typed a voice or member name the table does not
   hold. Baseline since 10-27: consult opus 0, review opus 4. No reversing
   result recorded.
4. **What the trims could have lost (11-17, 10-28).** After 11-17: briefs
   that put the session's own analysis under the goal's constraints,
   syntheses that misname a one-voice consult, review rounds that skip a
   step-4 pin. After 10-28: the brief's observed/inferred marking and the
   synthesis leading with decisions, rounds after against rounds before.
   No baseline recorded; these are where a behavior lost to a trim would
   show.
5. **Briefs since `VOICE.md` (10-28).** Brief size against the median 2,770
   words (expected: about two thirds), and whether voices still return the
   asked-for output sections with the design bar applied where shape was at
   stake. No round had run end to end when the entry was written. No
   reversing result recorded.
6. **The opening read's wording, after 10-04.** `provider_refusal` records
   among cold Claude voices on the new wording: two or more in the next 15
   removes the section for Claude voices, with the two-turn withhold where
   independence matters (September: 15 of 39 on the old wording). And
   self-declared non-blind reads on real rounds, against the replay's 0/8
   new and 6/8 old: revise the wording if the opening read stops appearing
   or arrives after the first tool call. `GOAL-BRIEF.md`'s wording has not
   been run, and `../write-spec/COLD-READ.md` still asks its reader to
   write down a reconstruction: look there first if a cold reader is
   refused.
7. **Cited files the voice never opens (09-27).** The share of cited
   outside files a fresh round never tries, against 49/195, and whether a
   round that skipped a lesson still used its vocabulary; one that did not
   is the case for a brief change. Since 10-28 the design-bar lessons are
   cited from `VOICE.md`, not the brief.
8. **Problem verdicts under one brief (09-25).** Verdicts other than
   "confirmed", against about 27 % of approach rounds and about 5/14
   diagnosis rounds: revise if they collapse toward "matches your framing".
   Rounds on a believed cause that carry "What we observe" and get a
   falsifier back (14/14 diagnosis rounds named one; 0/82 approach briefs
   had the section). Hosts improvising hybrid sections and users naming a
   mode: both should reach 0.
9. **The data block in use (09-22).** Rounds after data work whose brief
   carries the section (0 / 43 by the word, 6 / 43 by a predicate named),
   method items returned and what they found (sound, limit named, count
   overturned), and sessions where the user still types a methodology ask
   (3 in five weeks). No reversing result recorded.

Retired: 09-25's non-blind reads under the commit-first order (the 10-04
replay answered it, 0 of 8 against 6 of 8, and 6 carries the live count);
09-25's single outcome to follow (one case, reverses nothing); 09-25's
steward brief (the user's change in planlab, not a measure of this skill);
09-22's queries saved beside the brief and method findings that moved the
position (secondary to 9); 11-18's syntheses adopting a Carbon number and
Carbon members at the cap (Carbon was replaced by Neon on 11-24 and the
numbers line cut; 2 carries both for Neon).

## 2026-09-22 — the data behind a position goes on trial before the conclusion

**Question**, the user's: when a session has done data analysis before a
consult or review, make judging that analysis — the right data pulled, data
missing, the approach — a built-in part of the round rather than something
typed into the ask. Session `527fd55a`, the same session whose own two-voice
consult (`consult-r1+4`) found the pass's counts wrong upstream of its
conclusions: a sweep over every turn where the instruction governed a window,
an overturn predicate scoped to the session's end, one rater's soft boundary,
an example that read differently at its source.

**Corpus.** Obelisk, `source='claude'`, self excluded, 2026-08-15 → 09-22.
Invocations by `skill IN ('consult','review')`, the `<command-name>` tag, or
the skill path in a user turn (330 matches, most of them quoted paths; 65
dispatched a round by `envoy run`). Data work before the round: a Bash call in
the same session, before the invocation, containing `planlab backstage db`,
`aws logs`/`start-query`/`cloudwatch`, `obelisk --query`, `loopy evidence`,
`loopy tools`, `psql` or a bare `SELECT` (the last is weak and never alone in
the rows below). The brief: the last `# Consult`/`# Review` file written
between the invocation and the dispatch. The voice: the `envoy collect`
result text after it.

**Counts.** 43 dispatched rounds after data work (45 rows, two duplicated
invocations). Briefs: "methodolog" 0 / 43, "predicate" 6, a population or
denominator 7, a query or SQL 16, an exclusion or coverage gap 0. The user
asked for the method to be judged in 3 sessions (`ef1fb9a4` 08-20 "give them
the raw logs, I'm not convinced"; `40965715` 08-26 "review the integrity of
your data analysis approaches before I judge"; `aa026e62` 09-22 "our analysis
methodology"), and each returned a real defect: `40965715`'s Codex found a
duration field that included tool execution so a 91 % decomposition
double-counted tools, and a wall-share denominator taken from the wrong
population. Unasked, voices mention missing or unmeasured data in 24 / 44
collects and a sample or denominator in 16 (keyword, loose). This session's
own round is the strongest receipt: both voices re-ran the index and
overturned three load-bearing counts (`.agents/skills/pl-loopy-handoff/EVIDENCE.md`
in planlab, the 2026-09-22 entry).

**Changed.** `DATA-BLOCK.md`, the one home: the trigger (a count, rate or
measurement this session produced; a number measured elsewhere is a premise),
the section's shape in the observed register (source and window, population
and denominator, queries and raw outputs by path, classification and rater,
coverage gaps, not measured, receipts), the output item the voice fills before
any conclusion, and the author's duties before dispatch. `consult/SKILL.md`
step 2 and `review/SKILL.md` step 2 carry the trigger; all four brief
templates carry the section slot (deleted when it does not apply) and the
method item first in the output — item 0 in approach, diagnosis and full,
item 2 after the verbatim expectation in goal. Diagnosis places the block
inside "What we observe", above the blind read.

**Validation.** Two cold readers, read-only, one per skill: a consult on a
71 % correlation from unsaved production and log queries with "be critical
about how I got the 71 %"; a full review of a report, a spec threshold and
code built from 21 days of saved production rows with "check whether the
sample is the right population before the code", plus the goal variant.
Both produced the section in the right place and the method item first, and
both stalled on the same thing: whether the voice can re-run a production
query at all — fixed by a slot for what the voice can run and a method item
that says what it would run otherwise. Also fixed from them: results that
exist only as tool output are re-run into files; the diagnosis brief takes
the bullets without a second heading; the goal item's position and the
template heading stated correctly in the block; step 3's slot list in the
review skill named the data and standards sections; two pre-existing consult
defects the scenario tripped — words-versus-substance mode precedence and the
first dispatch recipe showing an unnamed second voice. Read-only simulations;
no round has yet run on a brief that carries the block. A same-day reread
against the rulebook replaced the block's explanatory prose with a filled
section and a filled method verdict from this pass, and cut the four
templates' author-facing slot to three lines each.

**Next pass measures.** Rounds after data work whose brief carries the
section (baseline 0 / 43 by the word, 6 / 43 by a predicate named); method
items returned and what they found, classified sound · limit named · count
overturned; sessions where the user still types a methodology ask (3 in five
weeks); queries saved beside the brief; and whether a method finding changed
the position before the user saw it.

## 2026-09-25 — one consult: the voice defines the problem, then the approach

**Question**, the user's (session `3a8e018c`): collapse the diagnosis and
approach modes into one consult whose voice always does both jobs, stressing
whichever the case needs — agree with our problem and spend the effort on the
shape, or say we defined the wrong problem and design from its own.

**Corpus.** Obelisk, self excluded, 2026-07-04 → 09-25. Invocations as in the
09-22 entry: 290 rows / 248 sessions (claude 266, codex 24). Brief kind: a
Write/Bash call containing `# Diagnosis` or `# Consult` plus a template
phrase (`blind read`, `Your sketch`, `What we propose`, `What we concluded`):
diagnosis 15 real sessions (3 steward test-fixture hits removed), approach
161 — all after the 08-19 split, so not comparable with `e94b8bb`'s "63 %
diagnosis-shaped". Envoy store: 146 consult prompts, 141 results, 09-10 →
09-25 only. Queries, raw outputs and the one-rater classification are in the
session scratchpad `consult-mode/` (not durable; the predicates above rebuild
them).

**Counts.**
- The diagnosis template already asks for two jobs: 14/14 returned diagnosis
  results carry a full fix design (836–3,691 chars). Both voices pointed out
  that this measures template compliance rather than redundancy. 0/14
  refuted the cause; about 5 re-scoped the problem while confirming it
  (`e612d36c`, `ea926edf`, `89db4c19`, `450d5bbb`, `1d98c199`).
- Approach rounds redefine the problem in a quarter to a third of results:
  13/43 by the host, and 4–5 of about 22 in Fable's read of the rest, ≈27 %.
  26/66 contest a causal claim (loose regex). Clean case: `ask-hard-timeout`,
  routed to approach on a believed cause, which the voice refuted unprompted.
- Hosts improvise evidence sections inside approach briefs:
  `capacity-coordinator-offload` r1 "Production evidence (observed,
  reproducible)"; `f1f58cf6` "The incident evidence (observed…)". A hybrid
  ask was answered by an improvised hybrid brief (`0cb71579`); the user
  built on its "reframing from Codex".
- Self-declared non-blind sketches: 40/62 round-1 approach results; 0/4
  diagnosis results.
- Diagnosis's rarity is partly the product of `08a2322`, which sent every
  traced bug to approach.

**Consult round.** One brief (`consult-mode/brief.md`) to two voices:
`main-ca6ae1ca/consult-r1+6` (codex gpt-6-astra) and
`main-ca6ae1ca/consult-r1b` (claude fable-5-1). Both agreed to merge, with no
foundational objection. Adopted from them:
- The evidence section no longer depends on the host judging the cause
  settled.
- "Not carried by the evidence" survives as a verdict.
- The problem is stated once, and agreement takes one line.
- The falsifier keeps its own numbered item.
- The synthesis still leads with decisions.
- The goal section carries the outcome and the symptom as seen, never a
  cause.
- A voice with one job has the other job's items deleted.
- Four callers were missed: `envoy/DESIGN.md`, the description,
  `DATA-BLOCK.md`, and the steward.

The user chose Fable's commit-first order: the voice's read comes before the
reading list and before our position.

**Changed.** `BRIEF.md` replaces `APPROACH-BRIEF.md` and
`DIAGNOSIS-BRIEF.md`:
- The section order is goal → what we observe → your read (the problem, then
  the shape) → posture, design bar, reading list → what we believe (the
  problem, with observed and inferred links and what we never checked; then
  the proposal) → where we doubt it.
- The output is method · read · problem verdict · falsifier · approach ·
  where ours breaks · tenets · objections.

`SKILL.md`:
- The mode routing is gone.
- Step 1's position is the problem, then the approach.
- Step 2 covers what the observed section carries, and per-voice briefs.
- Step 5 reads the problem verdict first.
- Step 6's triggers no longer name modes.
- Step 7 treats a replaced or unsupported problem as a decision.

Callers updated: `DATA-BLOCK.md`, `handoff/pickup/design.md` and `build.md`,
`write-spec/SKILL.md`, and `envoy/DESIGN.md`.

**Not changed — the steward.** planlab's `services/steward` Diagnose step
reads `consult/DIAGNOSIS-BRIEF.md` (`diagnose/job.ts:73`, `build/skills.ts:35`,
`skills.test.ts:45`) from dotfiles at a pinned commit. It uses only the
observations and the blind read, and its own prompt and JSON contract enforce
both. The user owns the steward change: at the next pin bump it needs its
own observations-only brief (recommended: a steward-owned file) or a
migration to `BRIEF.md`.

**Validation.** Three read-only cold readers ran on the merged files, each
with its own scenario:
- a believed incident cause: code 134 plus a 3 MB script, "pin the root
  cause with astra, and tell me if the cap is the right fix";
- a feature with no incident: a weekly digest, "agree with the general
  direction, settle the final approach and the implementation tenets for
  the two PRs, with astra and opus";
- a mixed ask with a measured count: "fable on the root cause only, astra
  on both".

In all three, the reader kept facts and explanations on the right sides of
the voice's read without guessing, and needed no mode.

Fixed from the readers:
- Step 7 had no done condition (all three readers).
- "astra" is now a spoken voice word (two readers).
- The cause-only cut is named by item number.
- The method item is judged first in step 5.
- The withhold decision moved to the start of step 2.
- Observed and inferred are defined for a need a user reported. The feature
  reader's first guess was here: the vocabulary fit only bugs.
- A measurement that cannot be repeated is saved verbatim (DATA-BLOCK).
- The garbled resume sentence is fixed.

Declined:
- Scope-only readings of the per-voice rule: it fires only when the user
  splits jobs.
- A fence for user-named scope: the fence rule already covers a user
  decision.
- A mandatory round 2 after the falsifier: left to judgment.
- A regression-workflow route for fix traps: project-specific.
- DATA-BLOCK's voice-credential line and "sweep window" check: they predate
  this change and are left for the next DATA-BLOCK pass.

All of this is read-only simulation. No real round has yet run on
`BRIEF.md`. Word count: 3,773 across `SKILL.md` and `BRIEF.md` before the
reader fixes, against 4,974 for the old skill and its two templates.

**Next pass measures**, on rounds dispatched from `BRIEF.md`:
- Rounds on a believed cause that carry "What we observe" and get a
  falsifier back. Baseline: 14/14 diagnosis rounds named one; 0/82 approach
  briefs had an observed section.
- Problem verdicts other than "confirmed". Baseline: about 27 % of approach
  rounds and about 5/14 diagnosis rounds. Revise if they collapse toward
  "matches your framing", the ceremony the 09-14 pass removed.
- Self-declared non-blind reads under the commit-first order. Baseline:
  40/62. Revert the order if it does not drop.
- Hosts improvising hybrid sections, and users naming a mode: both should
  reach 0.
- One outcome: whether a problem redefinition changed what was built,
  followed to the user's next decision.

## 2026-09-27 — cited files the voice never opens

**Question**, the user's: do voices fail to read documents outside the
project, such as the prompt-engineering guide? A tabtype round had every
such read refused; that was envoy's permission mode, fixed there (envoy
`EVIDENCE.md`, 2026-09-27). This pass covers review rounds too and records
itself here only.

**Corpus.** The envoy job store: every claude turn, 2026-09-14 → 09-27,
matching each brief's cited paths outside the cwd against the voice's
Read/Bash/Grep/Glob calls. Everywhere but tabtype nothing was refused.

**Finding.** Across 33 fresh, successful rounds whose briefs cited outside
files, the voice opened 146 and never tried 49 (about 25 %); 4 rounds opened
none, 18 opened all. The skipped files are the brief's required reading, not
optional pointers: the codebase-design lessons from "The design bar"
(`deep-modules.md` 16, `composition.md` 15, `design-it-twice.md` 11,
`deepening.md` 10), `tenets.md` 10, and the prompt-engineering `SKILL.md` 5
of its 11 citations. No brief or template change came from this pass.

**Next pass measures:** the share of cited outside files a fresh round never
opens. Baseline: 49/195. Pull a skipped round's result and check whether its
critique used the skipped file's vocabulary — a round that skipped
`deep-modules.md` and still judges depth and seams read it in some other
form; one that does not is the case for a brief change.

## 2026-10-04 — the pre-read wording and the provider's refusals

**Question**, the user's: Claude voices on consult and review keep failing
on a safety filter although the briefs are plain engineering; find when and
why, and which layer to change. This pass covers review too.

**Corpus.** The envoy job store, 502 `meta.json`, 2026-09-14 → 10-04; a
block is a record whose error says "safeguards flagged". Cohort: provider
claude, not a continuation, `prompt.md` over 3,000 bytes (61 turns). Wording
predicate on `prompt.md`: `write (this|it|them) down|write down` and
`verbatim`, case-insensitive. Obelisk for the wider window: assistant rows
`text LIKE 'API Error:%safeguards flagged%'`, this session excluded.

**Finding.** Every block is one category, `reasoning_extraction` (16/16 in
the store; 35/35 indexed rows in 24 sessions, 08-20 → 09-28). The stream
shows the provider stopping the voice's response, Claude Code retrying once,
and the turn ending as a refusal. Among cold Claude voices, briefs carrying
"Write this down now … Report it verbatim" were blocked 15 of 39; briefs
with neither phrase 0 of 16, with "verbatim" alone 0 of 5. Fable 5.1 took 9
of the blocks, Opus 5.5 6. Ten blocked briefs were re-sent by their hosts
with only that section rewritten: 9 passed, and the tenth — which still
asked for "a working note of your own" to "include unchanged" — passed once
the section was removed. The same bytes re-sent passed once and were blocked
once. The vendor guide already names the cause
(`references/fable-prompting-guide.md`: instructions to echo or transcribe
reasoning as response text trigger this category). All 20 blocked voice
sessions since September are consult briefs; goal reviews carrying the same
construct passed 3 of 3, and no full review was blocked.

**Limits.** The reasoning text and the withheld output are not in the logs,
so what the classifier matched is inferred from the association and the
pairs. A base rate exists apart from our wording: on 08-20, 13 blocks in 4
sessions, 3 of them interactive sessions with no brief at all. Four blocked
voice sessions are indexed but gone from the store. The mini's store was not
read.

**Changed.** `BRIEF.md` and `../review/GOAL-BRIEF.md` ask for the read as
the opening section of the answer, "as first written"; "write this down
now", "verbatim" and "unrecoverable once you have read on" are gone, and
each template's comment tells the host to keep it that way when adapting the
section. envoy 0.12.0 records a refusal as its own cause with the category
(envoy `EVIDENCE.md`, 2026-10-04).

**Replay, and what it could not show.** The brief blocked on Opus 5.5 under
both the original and a softened wording (`main` `consult-r1+8`), 8 turns
per wording on Opus 5.5, Claude Code 2.1.289, six-minute cap (every recorded
block had landed within 226 s): 0 of 8 blocked on the original wording and 0
of 8 on the new one (`replay-ctl-1..8`, `replay-new-1..8` in the `main`
store). With the three organic turns since 09-28 the original wording is 0
of 11 where September's rate was 15 of 39, so something on the provider or
Claude Code side moved, and the replay says nothing about whether the
rewording lowers the rate. What it did show: under the new wording 8 of 8
voices opened with the read before any tool call, and 0 of 8 prefaced it
with a caveat that the whole brief was already in view, against 6 of 8 on
the original — the 09-25 entry's "self-declared non-blind reads" measure. A
missing caveat is not a blind read; the brief is still one file.

**Next pass measures:**
- `provider_refusal` records among cold Claude voices on the new wording.
  Two or more in the next 15: remove the section for Claude voices and use
  step 6's two-turn withhold where independence matters.
- Self-declared non-blind reads on real rounds; replay baseline 0/8 new,
  6/8 old. If the opening read stops appearing, or arrives after the first
  tool call, the wording lost the instrument: revise it.
- `../write-spec/COLD-READ.md` asks its reader to "write down" a
  reconstruction and return it. No block is on record for it and it was left
  as is; look there first if a cold reader is refused.

**Revision pass, same day** (prompt-engineering rulebook, over the brief
sections, both template comments and envoy's refusal wording). Fixed: the
comments claimed the provider "refuses" where it can refuse, called
Anthropic "a Claude voice's provider" against the skills' own use of
provider, and pointed at this log instead of the rule's home, the
rulebook's Right altitude rule; `BRIEF.md` said "the later sections say
where the code moved you", which no output item asks for. Keeps, so the next
pass leaves them: "or read past this heading" and the "before reading on"
heading ask for what a one-message brief cannot give, but they are the text
the replay ran (8 of 8 opened with the read, 0 of 8 with the caveat), and a
phrase is a no-op only when a run says so; the two comments are echoes of
the rulebook rule on purpose, since a host adapting a template reads the
template; `../write-spec/COLD-READ.md` untouched as above. The final text of
`BRIEF.md` differs from the replayed text by the one cut clause;
`GOAL-BRIEF.md`'s wording has not been run.

## 2026-10-28 — rewritten under "Write short"

The tstack case study (`../prompt-engineering/EVIDENCE.md`, same date) made
consult the measured test of the new style: the most invoked model-reached
workflow (182 typed, 229 from a sentence naming it).

- Body 2,309 → 1,498 words, 29.6 → about 21-word sentences, 51 em-dashes →
  none. Description 35 → 26 words, now the "user names its job" shape.
- A cold read (fresh subagent, old against new) listed 47 behaviors and
  found 14 lost or weakened in the first cut. One was a bug the rewrite
  introduced: the cause-only brief kept the read's "The shape" item. Also:
  the design bar's default had flipped to opt-in, `--prompt-file` beside
  per-voice files, a changed count revising the position, escalating with
  both positions, adding *or sharpening* a planned case, tenets revised in
  place and recorded beside the test-plan edits, the tenet trigger words,
  naming the latest round. All restored, paid for with cuts elsewhere.
- What did not shrink: the voice table, the three envoy commands, the done
  criteria, and the brief's per-voice exclusions are behavior, which is why
  the cut stopped at a third rather than tstack's size.

No eval case covers consult yet: a round needs a worked conversation and a
dispatched voice. The next pass compares rounds after this commit with
earlier ones on the brief's observed/inferred marking and the synthesis
leading with decisions, which is where a lost behavior would show.

## 2026-10-28 — the voice's standing rules ride as instructions, the brief carries the problem

**Question**, the user's: the agent asking for a consult or review should
spend its effort passing the problem, with a straightforward, flexible way
to ask. Is preparation a real cost?

**Measured** (obelisk, both machines, 2026-09-14 → 10-28, every round: 190
consult and 210 review, Session Driver rounds excluded; scripts and
per-round data were scratch): invocation to dispatch, median 2.9 min
(consult) and 1.9 (review); 2 template reads; one write of the brief; 17 and
6 rounds edited the brief after writing it; 0 of 400 had the user correct
the brief or dispatch; no template-surgery mistakes found in any sent
brief. Briefs median 2,770 words, of which 27–35% instructed the voice and
19–28% was copied verbatim from a template. 44% of rounds checked that the
lesson paths exist; the user judged that cheap enough to keep. Preparation
is not a real cost; building briefs in code was not worth an engine.

**Changed:** `VOICE.md` holds the rules every voice works by (role,
read-only, grounding, stance, the design bar, how to offer ideas), sent as
`--instructions-file`, which envoy delivers as system-level text (codex
`developer_instructions`) and keeps for the conversation's life. consult and
review both start voices with it, so a consult voice seated warm in review
carries the same text and envoy accepts the flag again. `BRIEF.md` lost its
posture and design-bar sections and its author notes shrank; review's two
templates lost the review-lens paragraph and the ideas boilerplate.
Body+companions: consult 3,908 → 3,905 (with `VOICE.md` counted), review
8,128 → 7,954. A warm voice that started before this change makes envoy
refuse the flag; the round then goes without it and the brief opens with
the path.

**Verified:** a two-voice dispatch (codex `gpt-6.1-sol`, Claude Opus 5.5)
with the flag: both answered from the file (read-only; `deep-modules.md`
for a shape at stake), codex citing its developer instructions. envoy's
roster code refuses a differing or added instructions file on a continued
conversation (`internal/dispatch/roster.go` shareRoster).

**Not verified:** no consult or review round has run end to end since; the
next pass compares briefs after this commit for size (expect about two
thirds of today's) and for voices still producing the asked-for output
sections with the design bar applied where shape was at stake.

## 2026-11-05 — decisions checked, no change

See `../review/EVIDENCE.md`, same date. Consult's follow-ups since 10-06:
94 direct user turns, 5 asked what a decision meant (all 10-07 → 10-15,
before the 10-28 rewrite); sampled decisions are product calls the user
often answers against the recommendation, so they stay with the user.
`VOICE.md`'s small now excludes a new command.

## 2026-11-17 — the voice section becomes the three names the user dispatches by

**Question**, the user's: make consult and review thinner and tailored to how
they are actually called — the word "consult" or "review" plus a model name,
typed or carried by a tabtype snippet (`consult-then-build`,
`consult-design`, `review-verify`, `review-then-closeout`, all of which name
fable or astra) — with Fable, Astra and the new Carbon up front and finer
controls below.

**Corpus.** Obelisk on mac, mini and mini2, self excluded. Skill calls with
`skill IN ('consult','review')` since 09-01: 665 (354 consult, 311 review).
The user's last text before each call since 09-15, matched on whole words;
the voices in `envoy run --with` commands over the same window.

- Named before a consult: astra 133, fable 81, codex 69, claude 56, opus 46,
  sol 1. Before a review: none named 118, codex 87, claude 31, astra 26,
  fable 23, opus 11, sol 1.
- Since 10-27: consult astra 56, fable 48, opus 0; review fable 21, astra 15,
  opus 4.
- Dispatched, every skill's runs together: astra 459, fable 240, opus 212,
  sol 114.

**Change.** Both skills open on a **Voices** table — astra (also "codex",
and the default), fable (also "claude"), carbon (also "gemini") — with the
exact `--with`, the member name a warm seat types, and the command; opus,
sol, efforts, spelled-out ids and brief splits move to a **More control**
table at the end. Carbon joins review too: the user now names three models
for both. Cut as caches of envoy's own output or rules: `envoy pending`, a
warm voice keeping its model, and the decision-question format the user's
always-loaded rules already give. The VOICE.md refusal fallback, cut too,
came back to review the same day: a warm voice whose consult ran before a
VOICE.md edit is refused the current file, and leaving the flag off as envoy
says leaves the cold voice without the rules.

**Read-checked.** A fresh agent given only the two skills typed the intended
command for eight asks shaped like the corpus's, member names and the
family rule included; the four ambiguities it named (a Carbon effort note
that read as "a lone Carbon", a goal cap shown only as 60, "asks for one
voice" against "review with carbon", two home paths for one folder) were
fixed before commit. **Next pass compares:** asks naming a model outside the
table (opus, sol) since this commit, and rounds where the agent typed a
voice or member name that is not in the table.

## 2026-11-17 — the procedures trimmed to what nothing else carries

**Question**, the user's: after the voice reshape, make the procedures
thinner too, cutting by evidence rather than by feel.

**Method.** Each rule in both procedures was mapped to the entries in this
log and `../review/EVIDENCE.md` that bought it: consult 34 rows, 1 bought by
a failure seen in real sessions (the measured-number rule, 09-22), the rest
by a decision or measurement or by nothing; review 64 rows, 11 by a failure,
26 by a decision or measurement, 27 by nothing. Every failure-bought rule
stayed. Cut: what `BRIEF.md` and `../review/GOAL-BRIEF.md` already say
(observations only, fences, the data block, the facts block, what goes in
"already judged", the standards, the two goal slots that leak), what the
user's always-loaded closing rule says, and no-ops (the background task as
the signal, following `next:`, done-whens that repeat their step). Review's
brief step folded into its mode step. The verify-and-fix discipline of
review's steps 4 and 5 stayed, compressed, though most of it has no entry:
a model does not do it by default. Consult 1,431 → 1055 words, review
2,749 → 2320.

**Read-checked.** A fresh agent walked a consult and a review through the
trimmed skills. Of what it found unclear, two came from this trim and were
fixed: the synthesis lost "for a fan-out" before the member address, and
`BRIEF.md` lacked the clause that this session's analysis stays open "even
when the user agreed with it". The rest predate it: a user's "one round,
build without waiting" against a disputed count, the warm reviewer having
no brief slot for follow-through, and whether a new metric is a product
decision.

**Next pass compares:** briefs written after this commit that put the
session's own analysis under the goal's constraints, synthesis messages
that misname a one-voice consult, and review rounds that skip a step-4 pin.

## 2026-11-18 — Carbon's numbers are the lead's to check, and a round's cap is 45 minutes

**Question**, the user's: after one design round, replay more past rounds on
Astra and Carbon across kinds, and try a Carbon-only instruction ("Be
extremely concise. Sacrifice grammar for the sake of concision.", and label
numbers it did not measure).

**Method.** Six past rounds from mini2's job store, two per kind: design
(Bench context search, the streaming-frame instrument), refactor (twin's
restructure, envoy's state machines), bug (drive's forgotten parked session,
the slow first model call). Each brief and `VOICE.md` ran unchanged against
a standalone clone holding only the history up to the commit the round
read, under a `sandbox-exec` profile denying the live checkouts, the session
stores and `~/.ssh`. A first wave in plain worktrees was discarded: Astra
read past the frozen commit on its own (`git rev-list 4b1b268..main`, the
installed CLI from a newer checkout). Arms: Astra, Carbon, Carbon with the
user's rule appended to `VOICE.md`, and on three cases a sharper rule (a
2,000-word cap, a path:line beside every number). Two blind judges per case
(Opus 5.5, Sol on xhigh) checked five central claims per answer in the code,
counted unsourced numbers and ranked.

| per answer | Astra | Carbon | Carbon + rule |
|---|---|---|---|
| minutes | 5 (4–7) | 20 (14–29) | 19 (18–23) |
| words; words per sentence | 2,190; 16 | 3,580; 33 | 3,000; 30 |
| central claims fully right | 54/55 | 40/55 | 37/55 |
| unsourced numbers per verdict | 0 | 2.4 | 2.75 |

Sol ranked Astra first in all six. Opus split three and three: Carbon where
the round was a defect hunt in code (drive, envoy, Bench), Astra where it
turned on measurement or proof. Fresh judges reproduced every
Astra-versus-Carbon order on three cases. Neither rule moved the unsourced
numbers. The sharper one overran its cap on every answer (2,500–2,900
words), and its fully right claims fell to 15 of 30 against plain Carbon's
22 on the same cases: terseness cost qualifiers, not guesses. 2 of 18
Carbon dispatches failed (a stream error at 28 minutes, the 30-minute cap),
none of 8 Astra.

**Changed.** Step 4 carries the Carbon numbers line in place of a Carbon
instruction; agy's global rules file (`~/.gemini/GEMINI.md`) would also load
into every round. The cap is 45 minutes. `consult-design` asks all three
voices, and planlab's batch-notes snippet asks fable and astra, since
checking notes for what would mislead is a precision job.

**Next pass compares:** syntheses that adopt a Carbon number unchecked, and
Carbon members capped at 45 minutes.

## 2026-11-20 — fable is the voice when none is named (consult and review)

On the user's word (session `mini2:5b25b85e`): both skills' Voices sections
now say so, and their tables and first command put fable first. In review a
full round after a fable consult still seats astra cold, by the other-family
rule. Before a review the user named no voice 118 times since 09-15 (the
2026-11-04 entry above), so the default decides most rounds.

## 2026-11-24 — Neon replaces Carbon as the Gemini voice (consult and review)

On the user's word: Gemini 4 Neon on high is their agy model and the
"gemini" voice. Both skills' Voices rows and More control lines now name
`agy:gemini-4-neon:high`, member `agy-gemini-4-neon`; the `consult-design`
snippet asks fable, astra and neon; agy's tracked settings render
`Gemini 4 Neon (High)`. Neon also offers XHigh, which Carbon did not; the
user chose High. A smoke run of `agy --model gemini-4-neon --effort high`
answered. The Carbon numbers line in step 4 is cut: the 2026-11-18 entry
measured it on Carbon, and nothing yet says Neon states unmeasured numbers
as fact. **Next pass compares:** unsourced numbers per verdict in Neon
answers against that entry's Carbon 2.4, and Neon dispatch failures.

## 2026-11-26 — a voice's reading list lives in VOICE.md; the briefs name no lesson path (consult and review)

Session `mini2:7639db7f` (an `/improve-tool` pass). A Gemini session beside
it (`mini2:76d99d5a`) had answered the same question; the two agreed one
plan, each built half, and each read the other's half cold. The
strategic-review half is in `../strategic-review/EVIDENCE.md`, same date.

**Asked** by the user: should the lessons move behind Claude Code custom
subagents, so that a skill says "launch a code reviewer" and knows no lesson
path? Their observation: hosts list and read dependencies they do not need.

**Corpus.** Obelisk, `mac`, `mini` and `mini2`, all reached, self excluded.
A read is `Read`, or a Bash or Codex `exec` call using cat, sed -n, head or
tail, on a path under `config/lessons/`. Readers since 10-01 are classed by
the session's first user turn (a `# Consult` or `# Review` heading is a
voice), a `/strategic-review` invocation, or an `envoy run` call (a host).
Host behaviour is counted since 10-29 over sessions whose main thread ran
`envoy run consult-r1` or `review-r1`. Scripts and results were scratch.

**Found.**
- **Most lesson reading is done by sessions a custom subagent cannot be.**
  Since 10-01: 365 Claude voice sessions and 476 Codex sessions (1,957
  reads) read a lesson; Gemini voices are not indexed. No session has
  spawned a custom subagent type.
- **The host's extra work is real and small.** Since 10-29, of 246 sessions
  that started a round 1, 150 read `VOICE.md` and up to 128 ran `ls` or
  `test` on a lesson path (loose: any such command naming the tree). The
  Gemini session's per-run count over the same window, not re-run here: of
  405 fresh round-1 runs, 227 briefs carried lesson paths, 155 hosts read
  `VOICE.md`, 115 checked paths and 84 read a lesson. Of 921 briefs since
  10-01, 505 named no lesson; the lines that did were 38 to 54 of about
  1,250 words.
- **The cause was in the templates.** `review/BRIEF-TEMPLATE.md` and
  `GOAL-BRIEF.md` repeated `deep-modules`, `deepening` and `composition`,
  which `VOICE.md` has sent since 10-28, and carried `finding-classes`,
  `tenets` and revise-prompt, which it lacked. Step 2 here linked
  `VOICE.md`.
- **`requires:` never reached a session.** 0 of 446 Skill-tool loads of
  consult, review and strategic-review carried frontmatter. Its one reader
  is Planlab's steward (`services/steward/src/kernel/skills.ts`), dormant.

**Decided** by the user: no custom subagents, lessons stay plain files, and
`requires:` goes, a break in the steward accepted.

**Changed** (`c33824e7`).
- `VOICE.md` lists every lesson a voice reads: it gains the class tag
  (gated on the brief asking for one), the tenets form and revise-prompt.
- The three brief templates name no lesson path. Each bullet keeps its task
  and its keep-or-delete gate, which only the host can settle, and names
  the lesson by its idea ("the trace the composition lesson defines").
  Both review templates and `BRIEF.md` say in their header that the lessons
  ride in `VOICE.md`.
- Step 2 no longer links `VOICE.md`; step 4 cites `tenets.md`, which the
  host applies.
- `review/SKILL.md`'s fallback for a refused `--instructions-file` hands
  every voice in the job the current `VOICE.md`: a warm voice keeps the
  copy it started with, which can predate a lesson the brief names.
- `requires:` removed from consult, review, write-spec, delegate and
  test-audit. `prompt-engineering` keeps its block, because that file is
  copied into the Planlab repository and removing it is a change there.
- Sizes: consult 1,020 body and 3,478 total to 1,006 and 3,473; review
  total 6,344 to 6,336.

**Cut, with what each guarded and the sign that brings it back.**
- The lesson paths in the templates guarded the voice finding the file.
  Back if comparison 1 shows voices not opening a lesson a brief names by
  idea.
- "read … for the bar" in the structural bullets was the imperative to
  open `deep-modules.md`; `VOICE.md` says to judge in its vocabulary. Back
  on the same sign.
- The tenets rules restated in `BRIEF.md` item 6 and review's milestone
  bullet (a stand with its reason, no file names, seven at most) guarded a
  voice that skipped `tenets.md`. Back inline if file-level tenets return
  (`../review/EVIDENCE.md`, comparison 5).
- Step 2's "which says what each section holds" and the `VOICE.md` clause:
  `BRIEF.md`'s header says both.

**Verified.**
- **A case written first.** `brief-names-no-lesson` (skill-evals, red
  `ce0d1674`, n=3, kept briefs read with grep): at the old text the brief
  carried 3 lesson paths and the host touched lesson files in 3 of 3; at
  the first candidate and at the final text, 0 paths, the trace and the
  class tag kept, and the host touched no lesson file, in 6 of 6. Time to
  dispatch fell from 124 s to about 60 s.
- **The cases that passed before still pass.** `warm-beside-cold` 3 of 3
  at both, `goal-withholds` 3 of 3 at both, on the first candidate. Both
  cases expected the default voices from before 11-20 and failed on current
  text until corrected in this pass.
- **Real voices.** One brief the candidate host wrote, with a milestone
  bullet added, went to fable, astra and neon with the candidate
  `VOICE.md`. All three opened `review-lens`, `deep-modules`, `composition`,
  `finding-classes` and `tenets`; every answer carried the trace, class
  tags from the lesson and tenets in its form. The host had dropped "the
  composition lesson defines" from its bullet, so "the trace" alone found
  the file. Baseline: 09-27, 49 of 195 cited files never tried.
- **Cold reads.** The Gemini session found four gaps, all folded (the goal
  template's header, the tenets path in step 4, the class-tag gate, and the
  cuts that kept both skills inside their budgets). A fresh subagent's
  revise-prompt pass found the warm-voice fallback.
- **Not run:** `judge-fix-report`, whose fix-and-report half this change
  does not touch; a consult round end to end; a goal brief with a real
  voice.
