# consult — evidence log

One entry per mining pass over the sessions that ran this skill. The review
skill's log is `../review/EVIDENCE.md`; a pass over both records itself here
and leaves a pointer there.

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
