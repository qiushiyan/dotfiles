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
