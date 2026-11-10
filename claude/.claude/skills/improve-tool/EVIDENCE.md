# improve-tool — evidence log

A pass reads the two sections below first, then the newest entry. Dated
entries follow, oldest first, one per pass, with counts written so a later
pass can re-run them.

## Decisions that stand

- **A shape change is designed to the user before it is built** (09-01; no
  full revert in the 54 runs since, against 1 of the first 6).
- **No fixed session budget, review window or scheduled re-measurement**
  (09-07): scope follows the question.
- **No mandatory interview and no automatic closing review** (09-07). The
  closing prompt pass is the one exception this log keeps reopening; see the
  first open comparison.
- **Three independent sessions is a reporting floor,** not proof and not a
  bar to fixing one verified defect (09-07).
- **A reproducible finding gets its case before the edit** (10-09, 10-28).
- **Silence in the history is no reason to cut a guardrail** (10-28); a
  cut needs its case run without the line, or a baseline interview (11-05).
- **The closing prompt pass goes to a fresh reader** (11-09). Told to run it
  themselves, authors did in 1 of 13 replayed builds; handed to a subagent
  it ran in 33 of 33.
- **The build rules stay in the main file** (11-09). Moved to a companion
  that every run opened, the case-before-edit rule held in 6 of 9 replays
  against 9 of 9 in place. A companion is routed from the opening with the
  moment it is read; one named only mid-file was opened in 0 of 3.

## Open comparisons

Each is a measurement the next pass can run. Answer or retire them before
adding more.

1. **Does the user still send `prompt-check` after a run?** Predicate: a
   user turn after the invocation `LIKE '%Review and revise the model-facing
   surfaces%'`, in runs that edited model-facing text. Baseline: 19 of 54
   runs (09-15 → 11-07), and the pass it asked for found defects in at least
   13 of the 15 replies read. The replay shows the fresh reader's pass
   running; only live runs show whether it leaves the snippet nothing to
   find. After the rewrite ships: the next five such runs. Reverse: still
   sent and still finding defects in three of five means the reader's pass
   is weaker than the user's, and its brief is what to look at.
2. **Does the report still leave the user to ask what changed for them?**
   Predicate: a follow-up asking what they now type, how an agent comes to
   know the change, or "what do you mean by" a label the report coined.
   Baseline: 7 and 12 of 54 runs. After the rewrite: the next five runs.
   Reverse: no drop means the report list is not what the reader acts on.

## 2026-08-29 — first two runs

Corpus: 2 sessions, `c37919b5` (~/wiki, `scripts/lint.sh`, user live) and
`1780f1fe` (itell platform, `/onboarding` skill, user absent until the end).
Both reached step 8: ledger, cold readers (2 and 3), evidence log or memory.

| friction | count | reading | verdict |
|---|---|---|---|
| mining output over the harness's 10 k Bash cap | 2/2 — wiki round 1 persisted at 45 KB and was re-read from the tool-results file 4×; itell 3 of 5 rounds truncated, then redirected to scratchpad + `jq` | observed | fix the cause: MINE.md runs every round into `$S/mine.json` and slices with `jq` |
| CLI facets collapse on a reporting engine ("271 calls, no flags, no errors") | 1/2 — wiki agent's own answer; it invented finding-class → repair → user-turn | observed | promote: reporting variant in MINE.md |
| document variant too thin; agent invented the invocation window, `read_before_edit`, Explore prompts, `args_shape` | 1/2 — itell, 5 rounds | observed | promote: folded into the document variant |
| step 4 blocks when the user is not live | 1/2 blocked (itell: substituted assume-and-flag); 1/2 worked live (wiki: verdicts in one turn) | observed | fix the cause: request read for verdicts first; `assumed:` verdicts; hard stop only for contract changes |
| `/review full` skipped | 1/2 (wiki, docs-only pass) | inferred: cold readers judged sufficient | left; user's call |
| `/consult` never ran | 2/2 | observed: neither pass changed an engine contract the user had not already decided | left; the trigger held |

Lessons that survived → `~/.config/lessons/agent-tooling/usage-lessons.md`
("facets follow the engine's output kind", "the request is the first
interview").

## 2026-09-01 — bootstrap: the skill run on its own six runs

Corpus: 6 runs since 08-29 — `c37919b5` (wiki lint), `1780f1fe` (itell
/onboarding), `03b5e91a` (wiki skill + CLAUDE.md), `39f2bf85` (write-spec
snippet → skill), `af44333d` (spike), `c699709b` (distill-handoffs + brief);
4 of them after the 08-29 fixes. Doors: slash 5/6, by-path 1/6. Session
`3167ab18`; ledger `improve-tool-frictions.md` in its scratchpad.

Measurement: runs = sessions with `messages.skill='improve-tool'` or
`<command-name>/improve-tool` or `skills/improve-tool` in user text, `self`
excluded; per run, Bash rows after the invocation (`obelisk --query` calls,
`is_error`, `length(content) >= 10000`), `Agent` rows whose input contains
"cold reader", user turns after the invocation (`role='user' AND
content_type='text'`, continuation summaries excluded) read by position.
The holistic-pass count is those user turns naming writing-for-agents or
prompt-engineering. Next window: runs after 2026-09-01.

Re-measure of 08-29: the file+jq mining fix held (raw obelisk overflow 0/4,
was 2/2; one residual jq slice in `c699709b`); the reporting and document
variants were not stalled on (0/4); step 4 no longer blocks (0/4) but
over-fired once (below); `/review full` ran as written 0/4.

| friction | count | reading | verdict |
|---|---|---|---|
| user asks for a holistic writing-for-agents + prompt-engineering read after the pass | 6/6 — `5ab02359`, `3dea2c2f`, `67a5e2ff`, `b88db121`, `93337ade`, `66b92dd6` | observed | promote: step 6 ends with the holistic pass as its own commit |
| shape change built before the user heard the design; full revert | 1/6 — `39f2bf85` `5a286e98` ×2, user live 5 min earlier | observed | fix the cause: `shape:` field per ledger fix; a shape fix is designed to the user first, never `assumed:`; a user who replied this session is live |
| outcome facet (user's next turn after the tool) invented per run; user-voice facet keyed on the tool's name | 3/6 invented — `1780f1fe`, `39f2bf85`, `c699709b`; the deciding corrections never named the tool | observed | promote: MINE.md facet F (`after`, gap-minutes, short-turn tally); E scoped by session |
| recap did not land, user asked for a refresher | 1/6 — `c699709b` `d07dade3` | observed | fix: one report table (friction · count · verdict · landed where) replaces "assumed first" + "frictions by rank" |
| `/review full` ran 0/6 as written; goal 2/6, skipped-and-said-so 1/6 | 6/6 | observed; reading inferred | assumed: step 7 says `/review goal`, skip allowed when said |
| /consult brief lacked the mining context; user pointed codex at obelisk + MINE.md by hand | 1/6 — `39f2bf85` `d745ffbb` | inferred | assumed: the brief carries the signatures and MINE.md |
| ledger/evidence writes via Bash heredoc invisible to `Edit`/`Write` counts | 2/6 ledgers | observed | MINE.md: count heredocs too |
| evidence log beside the skill questioned as consumer-facing | 1/6 — `39f2bf85` `93016511`; 2/6 runs used the repo's own log | open | no change; the user's call |
| vision: goals over procedure for smart models | user voice `2ea19d5a` + write-spec research | open | not built (shape change, "future direction"); recorded in usage-lessons |

Hypotheses from the pre-mining read: outcome/counterfactual facets —
confirmed by the corpus; replay of the seed scenario over cold-reading —
unmeasured (cold readers preceded edits in 5/6 runs, no run replayed), left
as a proposal.

Cold readers (2: a CLI + skill run with the user live for an hour; a
rarely-invoked skill with the user asleep) stalled on: no named variant for a
no-engine tool (the answer was tail prose in MINE.md); no rule for a candidate
fix a mined correction already rejects; the not-live branch silent on what
happens to a shape design; `$S` and the output-dir fragment never filled in
MINE.md; facet F for skill invocations as a comment, not code; no re-measure
branch when the seed is already in the log; no route from doc-loop.md. All
fixed (`3fbeccc`). Both readers cut the same restated lessons; cut. Goal
review: one cold codex voice, out-dir `20260901-220410-review`.

Lessons that survived → usage-lessons.md ("smallest edit per signal, then
one holistic read", "a shape change is designed before it is built", the
outcome facet, the open goals-over-procedure note).

## 2026-09-07 — bootstrap: evidence discipline and outcome preservation

Purpose: improve model-facing workflows without mistaking fewer calls,
shorter prompts, or repeated activity for better work. The user's supplied
screenshot motivated this pass; its principles are design input, not mined
proof. Source image: https://pbs.twimg.com/media/HRe1Lx9aIAALrNj.jpg

**Coverage.** Obelisk broad discovery returned 23 matching user-role rows
across 20 sessions, 2026-08-29–2026-09-05 (16 Claude, 4 Codex). Classified by
entry message: 12 explicit invocations, 5 delegated consult/review sessions
(4 Codex, 1 Claude), 1 continuation-led bootstrap history, and 2 adjacent
analysis/follow-through sessions. Delegated work and continuations are not
independent uses. All 20 candidate entries were inspected; relevant user
turns were projected at up to 20 per session, then seven selected corrections
expanded with adjacent assistant text. This is targeted sampling, not a
complete outcome audit. The current session was excluded.

**Reproduction.** Discovery predicate: `role='user'`,
`COALESCE(is_meta,0)=0`, `COALESCE(is_sidechain,0)=0`, current session excluded,
and `skill='improve-tool' OR text LIKE '%/improve-tool%' OR text LIKE
'%skills/improve-tool%'`; group by session. Confirmed invocation predicate:
`text LIKE '%<command-name>/improve-tool</command-name>%'` with those filters;
count distinct sessions, inspect entries rather than treating every matching
body as another invocation. Exact queries and bounded output remain local at
`/tmp/improve-tool-01a07c80/`; this entry preserves the predicates and receipts
because scratch output is temporary.

**Previous-fix check.** Cutoff is commit `9567cda`,
`2026-09-01T21:15:54Z`, not midnight on the evidence-entry date. Five later
explicit invocations: `d8d04a4f`, `eae57373`, `f198f15b`, `07144497`,
`abd24d95`. Their loaded skill bodies all include the holistic-pass rule.
After each invocation, Bash calls whose `input_json LIKE '%obelisk%--query%'`
number 41 across 5 sessions. One error is a downstream jq null-iteration
failure (`eae57373`, `toolu_01Pkm259SJC1s5LueQmLSsE5`), not evidence that
Obelisk failed. Four stored results reach 10,000 characters across 2 sessions
(`07144497`, `abd24d95`); this measures index-capped records, not original
harness overflow. The older overflow count is not directly comparable.
Three sessions contain an explicit later prompting-pass request
(`d8d04a4f/5fc12a08`, `eae57373/4f7bf022`, `f198f15b/51bfdfcb`);
requests alone do not establish omission, so no stronger mandate was added.

| finding | evidence and limits | verdict / layer |
|---|---|---|
| broad signature counts mix independent uses with other material | 8 of 20 candidates are not explicit invocations; review briefs occur in both providers. This is one reproduced query defect, not eight workflow failures. | User-authorized consolidation: classify the cohort before counting, retain exact predicates and full follow-up receipts. Instructions: MINE.md and skill sampling guidance. |
| observed cost does not establish its cause or value | One of five newer runs: `d8d04a4f/1121896f` (09-02) states the disabled tool was accidental and rejects fallback machinery. `f198f15b/0d42e94d` (09-03) says theme removal is not costly enough to need extra machinery. `abd24d95/c8421c93` (09-04) explicitly protects useful verification while questioning the proposed owner of its cost. These are different decisions, not one repeated defect. | Preserve engine-first reasoning, add alternative explanations and successful counterexamples, and rank by outcome with a quality guardrail. Instructions; shared lesson introduction now calls history partial. |
| a follow-up is evidence to interpret, not a verdict encoded by length or timing | Requests for decision explanations in `d8d04a4f/a8abefec` (09-02) and `eae57373/9a3541b0` (09-03); theme-run acceptance `f198f15b/0d42e94d` is a counterexample to treating all approvals as pointless stops. Two clarification cases do not establish recurrence. | Explain consequential choices plainly, ask only unresolved questions, reuse authorization, preserve short-message receipts. Instructions. |

The latest adjacent follow-through, `402389c4`, was inspected separately:
`f72e3788` (09-06) asks whether optional reading would harm output quality;
`b35d0c4c` challenges an explanation connecting permission settings to
truncation. The following assistant defends that explanation. This pass
neither verifies nor calls it false; an assistant's explanation is a claim,
not a mechanism test. This distinction is now explicit in the skill.

**Validation and deliberate keeps.** Two independent cold readers exercised
a sparse documentation case and a CLI case with a rejected design. Both
classified silence as unknown and clipped index text as insufficient evidence
of agent-visible overflow. Their findings corrected the no-engine branch,
mtime-as-version overclaim, discarded follow-up receipts, automatic expansion
from rare uses, and reopening authorized choices. Existing engine-before-docs
ordering, stage ownership, rejected-design receipts, and holistic review stay.
The three-session threshold applies to recurrence claims, not a verified
single defect. The 45-session and 30-day bounds are starting budgets and
review windows, not required sample sizes or an automatic scheduled job.

**Next comparison.** First action: apply the revised instructions in the next
improve-tool run. Review up to five independent uses by 2026-10-07, extending
the window if needed. Check three outcomes: (1) all reported rates have a
classified cohort and recoverable receipts; (2) each recommended change names
an observable benefit and preserved quality; (3) questions identify a real
unresolved decision. Baseline defects are the discovery query and instruction
examples above, not a historical failure-rate estimate. Revise if the new
wording causes redundant permission gates, forced findings, unjustified
history expansion, or removal of useful verification. Runtime improvement is
unproven until those uses exist; no 30-day savings estimate is claimed.

Final independent goal review of `fa6dfca`: substantially landed, with a
remaining contradiction in specialized examples. Confirmed and corrected:
one-line repairs and low read counts now prompt investigation rather than
verdicts; assistant falsification mentions retain receipts and require source
verification; reader overlap is bounded to the declared window instead of the
entire session. The holistic pass also removed an unsupported fixed claim
about shell reads halving counts. All four JavaScript examples pass syntax
checks and the skill's relative links resolve. Mining queries ran against
Obelisk; specialized example changes were syntax- and read-verified, not
replayed against a new pipeline corpus. No runtime benefit is inferred.

### Same-day structural revision — goals and constraints

The user then authorized a broader improvement against the general prompting
guide, with judgment where its defaults do not fit. This revision reuses the
bootstrap evidence above; it is not another mining pass or evidence that the
first revision improved runtime outcomes.

Replaced the eight-stage checklist with purpose, evidence standards, owning
layer, and delivery criteria. The entrypoint shrank from 2,111 to 1,245 words.
The cold-reader prompt now asks the reader to exercise judgment in a concrete
scenario; it requests exact commands only for executable recipes and accepts
no findings. Query mechanics remain in MINE.md. The shared usage lessons and
doc-loop pointer were aligned with the resulting workflow.

Deliberate changes from the previous shape:

- No fixed 45-session budget or 30-day default: scope follows the question,
  unresolved alternatives, and enough comparable uses. The specific next
  comparison proposed above remains a valid plan for this pass.
- No mandatory interview, separate holistic-read commit, or automatic closing
  review: each needs a decision, coherent change, or unresolved verification
  question to justify it. The holistic read itself stays because its six-run
  history supports it.
- Reorganization is allowed when accumulated rules obscure the purpose;
  smallest-edit doctrine should not preserve a bad structure indefinitely.
- The three-independent-session floor remains a conservative reporting rule,
  not proof of causality or a barrier to fixing one verified defect.
- Engine verification before dependent instructions, archived content as data,
  source checks for falsifications, rejected-design decisions, and unknown
  outcomes remain constraints. Query examples stay because they supply
  non-obvious joins and evidence-selection patterns rather than a judgment
  procedure the model must imitate.

Two independent readers first exercised the revised files, then compared the
previous entrypoint for lost behavior. Sparse documentation use: distinguished
two actual uses from a review and continuation, fixed a verified local route
without a new permission gate, and left the silent outcome unknown. CLI and
handoff workflow: preserved the existing uninstalled handoff, required source
verification before blaming the writer, kept a rejected surface rejected,
and left dependent instructions pending. Neither found lost behavior in its
scenario. The pipeline reader found a conflicting approval rule in the shared
lesson; the lesson now uses the same scope-based authorization boundary.

This is a read-only scenario comparison, not an end-to-end outcome A/B test.
Relative links and unchanged frontmatter were checked; runtime improvement
remains for the comparable-use measurement above. The prompting guide itself
needed no new rule: the structural problem was in this skill's application
of its existing principles.

## 2026-10-06 — mining reads both machines (a procedure change, not a mining pass)

The obelisk skill gained `scripts/obq` (its `LESSONS.md`, same date): one
script runs against the laptop's sessions and the mini's and returns one
result per machine. `MINE.md` ran plain `obelisk --query`, so a pass counted
only the machine it ran on.

- **Run block:** goes through `obq`; the slices carry the machine as their
  first column. Verified by running the CLI variant with only its constants
  changed (`cli = 'twin '`, since 2026-09-22) on both machines: every facet
  came back from each (10 sessions sampled on the laptop, 6 on the mini), and
  no session id appeared on both.
- **Writer/reader pairs:** the writer lookup sees one machine. Handoff briefs
  touched since 2026-09-22: 28 read and 41 written on the laptop, 34 and 49 on
  the mini; 5 were read on one machine and written only on the other (2 read
  on the mini, 3 on the laptop). `MINE.md` now sends a writerless pair to the
  other machine before it is counted.
- **Removed:** the comment that a `delete` or `update` literal inside a SQL
  `LIKE` trips the read-only guard. On engine 0.2.6-rc.0 both ran (1 and 3
  rows on the laptop).

Not verified: no cross-machine pair was built end to end, and no mining pass
has run through the new block. The next pass compares whether its report
states the corpus per machine, and whether a writerless pair was checked on
the other machine before being counted.

## 2026-10-09 — runtime replay through skill-evals (a procedure change, not a mining pass)

Every pass since 2026-09-01 ended its runtime claims with "unproven until
future uses" or a read-only cold-reader comparison; replay of the seed
scenario was proposed on 09-01 and never run. `~/dev/skill-evals` (a private
repo, registered in twin with its fixtures carried) now replays a skill headless: each case is a prose file (request,
source session, what passes and fails), each rollout a `claude -p` session
with the skill at one revision in a throwaway HOME, under a write sandbox,
billed to OpenRouter, graded by `openai/gpt-6-sol` against the case. SKILL.md's
verification section now routes reproducible findings through it.

Calibrated on obelisk's own lessons before trusting it (obelisk
`LESSONS.md`, same date, has the table): two of nine lessons still separate
the revision before the fix from the fix (positional params 0/3 → 3/3;
per-session query path 0/9 → 5/9 at the fix → 9/9 today), so the harness can
see an instruction change land. Six are saturated: Opus 5.5 avoids the
mistake under the old text too, which is the second use this gives a pass,
finding rules the current model no longer needs. The judge agreed with a
regex on 44 of 48 checkable runs and was right on the four disagreements.

Case-design lessons from the pilot, now in the skill-evals README or this
skill:

- **A check on process passes wrong outcomes.** A memory-offer case passed a
  run that never found the session holding the answer, because "says nothing
  durable came out" was an acceptable ending. The case now names the answer
  session; SKILL.md asks for the outcome in every case.
- **Stopping before the outcome makes the verdict a coin flip.** Self-exclusion
  stopped after two obelisk calls read 1/2 then 4/2/3 for the old revision;
  run to the answer it read 5/0. A case runs at least as far as the step its
  criteria judge.
- **The judge is not told what its verdict decides** (prompt-engineering's
  judge case study): the first judge prompt said a wrong pass "hides a
  regression"; it was removed and the pilot regraded.

Cost of the whole pilot: about $25 on OpenRouter for 134 rollouts and their
regrades, a 2-call obelisk rollout costing $0.10–0.25.

One cold reader walked the new section with a concrete obelisk finding
(descriptive query file names). Adopted from it: "earlier revision passes too"
now says the harness did not reproduce the mistake at that run count, not that
the model no longer makes it, since a failure seen a few times a week may not
show in three runs; a case that already covers the behaviour is tightened, not
duplicated; every case runs at both the earlier sha and `WORKTREE` so each has
a baseline; `red` is a sha recorded before editing; and the disclosure names
OpenRouter. In the harness, a case without `green` now admits against
`WORKTREE` instead of crashing the run.

Not verified: no improve-tool pass has used the new step yet; that one cold
reader is the only check of the route. Next pass on a tool
with cases: did it write the case before editing, run red and `WORKTREE`, and
report per-case counts; and did it name a saturated rule rather than claim it
as an improvement.

## 2026-10-28 — under budget, cut on evidence, and the case before the edit (first eval cases)

The tstack case study (`../prompt-engineering/EVIDENCE.md`, same date) set a
1,500-word body budget; this skill was recorded at 1,938. The same pass
learned that a skill's length is mostly behavior (rewrites for length lost
14 of 47 behaviors in consult and 12 rules in the rulebook until a cold read
caught them), so cutting has to run on evidence.

**Changes.**
- Body 1,938 → 1,362 words, about 15-word sentences. The skill-evals detail
  moved to `EVALS.md`, routed from the opening.
- New **Size is behavior**: an over-budget tool is cut where its cases and
  the live history both show a rule unneeded; silence in the history alone is
  no reason, since a working guardrail leaves no failures. A finding is
  folded in by rewriting the sentence it corrects.
- A finding one headless session reproduces becomes a case before any edit,
  stated in the body rather than only behind the pointer.
- `COLD-READER.md` gains the parity read for a wholesale rewrite.
- `EVALS.md` names the `codex:<model>` judge route (skill-evals 9e166fb):
  OpenRouter refused every OpenAI and Gemini model on the key this day.

**Parity read** of the first cut: 63 old behaviors, 11 lost and 14 weakened
(the trace-the-cause guard, fixing what verification reveals, how to ask,
the maintenance bar for new mechanisms, hand replays, among them), and two
additions that would have misled (history silence as a deletion basis; "the
budget fails growth", true only for skills recorded over it). All restored
or corrected before the eval runs.

**Eval** (`~/dev/skill-evals/cases/improve-tool`, fixture
`improve-tool-seeds`; red f59feda; judge `codex:gpt-6.1-terra`; agent Opus
5.5). Runs `it-1028`, `it-1028-b`, `it-1028-c`.

- **finding-to-case** (the 64cf9ef `path` finding): with the seed ending at
  the user's question, both revisions failed 3/3; 1 of 6 runs found the zsh
  cause, so the case measured diagnosis, not the method. Moving the case
  ordering into the body did not change that (0/3, `it-1028-b`). With the
  seed carrying the session's diagnosis: red 0/3, this revision 3/3. Case
  written before the edit 0/3 → 3/3; cause, engine fix, instruction fix,
  and an honest report equal at 3/3. The case discriminates.
- **over-budget** (obelisk, 2,638 words): saturated, red 2/3 and this
  revision 2/3. Both kept the still-needed rules 3/3, ran a parity check 3/3
  and reached the budget 3/3; cuts justified by evidence 1/3 → 2/3, noise at
  n=3. Red's passing runs reached the budget by moving text into side files.

**Next pass compares:** live passes after this commit on whether a
reproducible finding gets its case before the edit, and whether an
over-budget pass cites the cases or history for each cut. The over-budget
case wants more runs (n≥6) before its cut-on-evidence difference means
anything.

## 2026-11-05 — the baseline interview (a procedure change, not a mining pass)

**Source.** The agent-prose gist (mbriggs, a fork of `writing-for-agents`),
judged in this session as an outside writing guide; its verdicts are in
`../prompt-engineering/EVIDENCE.md`, same date. Its one method this skill
lacked: ask fresh subagents, with no tools and no draft, what they would do,
and sort each line by whether every subject already does it.

**Calibration against known answers.** Obelisk's nine replayed lessons
(`../obelisk/LESSONS.md`, 2026-10-09) were the answer key. A blind Opus
agent, holding the gist and the nine lines but not the replay results, wrote
one interview prompt and pre-registered the "already does it" answer per
line; two Opus and one Sonnet subagent answered it; the sort used those
criteria. Prompt and answers: this session's scratchpad `interview/`.

| line | interview | sort | replay at red |
|---|---|---|---|
| named params | 3/3 wrote `?` + array | keep | 0/3, still needed |
| query path | scratchpad paths, 2/3 a new file each round | keep | 0/9, still needed |
| user voice | Sonnet `role='user'` only | keep | 1/2, weak |
| memory offer | 1/3 offered | keep | 3/3, saturated |
| own session, output budget | 3/3 did it | task run (pressure) | saturated |
| correlation, lean FTS | 3/3 did it | cut | saturated |
| inline schema | 3/3 probed first | cut | saturated; the ablation costs a round |

No needed line was marked for cutting; one unneeded line was kept; the
round the schema saves is invisible to an interview. The two baselines
differ: the interview has no text, the replay's red has the text before the
fix, which for the two still-needed rules taught the wrong form. Side
finding for obelisk's next pass: unprompted, Opus put query files in the
scratchpad, whose path carries the session id, so the path rule may shrink
to "reuse one path". Cost: four subagents, about five minutes.

**Changed.** `BASELINE.md` (new companion); § Every line earns its place
restructured into bold-led rules, the interview as the screen for a line
with no case; `revise-prompt`'s fix list and `write-prompt` step 2 point at
it.

**Next pass compares:** cuts made in improve-tool and revise-prompt passes
after this commit. Does a cut of a caseless rule cite an interview or a run?
Does an interview-cut rule come back (a failure in later use that the cut
line guarded)? Reversal: a cut made on an interview alone that later use
shows was needed, or interviews skipped in favour of opinion.

## 2026-11-09 — the skill on its own 54 runs: a stance and a toolkit

Purpose: the user asked what would make the skill "more flexible and more
powerful", by "a helpful philosophy" or "the toolkit they would likely need",
without a longer prompt. Session `93a3dd6a` (mac); ledger
`improve-tool-frictions.md` in its scratchpad.

**Corpus.** Discovery (user role, `is_meta=0`, `is_sidechain=0`, self
excluded, `skill='improve-tool' OR text LIKE '%improve-tool%'`): 138 sessions
(mac 88, mini 38, mini2 12), 08-29 → 11-09. Confirmed invocations
(`text LIKE '%<command-name>/improve-tool</command-name>%'`, continuations
excluded): 72 rows in 66 sessions (mac 50/45, mini 13/12, mini2 9/9); five
sessions hold the same request re-sent after an interrupt. Window: the 54
sessions invoked after 09-07 (mac 33, mini 12, mini2 9), which no pass had
read. Read: every user turn after each invocation (576), the head and tail
of each first report with its reply, six steering turns with the whole
report they answered, and per-run tool facts. Not read: the work between
reports, each pass's diff, sidechains. Bash-heredoc edits are invisible to
the edit counts, and "claimed a pass" is a LIKE match on assistant text.

**Comparisons answered.**

| promised | result |
|---|---|
| 09-01 shape change designed first | held: 0 full reverts in 54 |
| 09-01 holistic prompt pass inside the skill | not held: open comparison 1 |
| 09-07 rates carry a classified cohort | held in the reports since 10-28 that count anything |
| 09-07 questions name a real open decision | not held: go-ahead asks for work in scope in at least 8 runs ("Should I make these three changes?", "Whether to record this pass in the evidence log") |
| 10-06 corpus stated per machine | held where sampled (`2c257532`, `c7ba697e`, `1c432277`, `f6f07667`) |
| 10-09, 10-28 case before the edit | skill-eval in 12 of 33 runs since 10-09; of 6 since 10-28, 4 ran red or wrote the case first, 2 edited first (`4404a72d`, `60bd494a` by hand) |
| 10-28 over-budget cuts cite cases; n≥6 on the over-budget case | not measured; retired as a promise, kept as a deletion to watch below |
| 11-05 a caseless cut cites an interview | pending: 6 runs since, 1 interview-like (`0a262f3d`) |

**Findings.**

| finding | evidence and limits | disposition |
|---|---|---|
| The skill is asked more than its body describes | hand-tagged requests: a named tool's usage 20, an open design or placement question 12, "is X effective" by experiment 7, an outside idea to judge 8, a retyped prompt to turn into a tool 7 | opening rewritten |
| The pass runs inside the session pipeline and the body claimed the later stages as its own | after the first report the user started a consult or review in about 25 of 54, sent `prompt-check` in 19, typed a landing nudge in at least 14; `docs/session-pipeline.md` names no entry for this skill | § Deciding and asking; the pipeline line is the user's docs pass |
| The closing prompt pass does not run | open comparison 1; the assistant had claimed a pass before the ask in 3 of 15; the build comes turns after the skill was read | "A build is not done at the last edit", named in the report's closing line |
| The report leaves the user to ask | what changes for me, and how an agent learns it: 7 runs; "what do you mean by" a coined label: 12; a recap after hours away: 5 | the report list; questions answerable alone |
| A rule per finding, and the smaller fix first | `75e316e5` (eight spec rules; "address the root problem rather than just applying a patch", then "I don't want to overfit"), `be35ec01`, `71bdb6e3`, `8ae01ce4`, `a5cdd6e5`, `527fd55a`; the body's "smallest coherent change" against the global scoping rule's "propose the proper fix first". None seen in the 14 first reports since the 10-28 size ratchet, so size has a mechanism and reasoning had none | § The stance |
| "Among others you find" retyped in the arguments | at least 11 of 54 requests; sampled runs do report unasked findings, so a preference, not a measured failure | stance, first paragraph |
| Promised comparisons mostly never happen | a subagent's read of 11 evidence logs: 103 promises, 88 with a later entry, 36 followed, 17 in full; followed where the next entry opens on the last measures (strategic-review 5 of 6, write-spec 9 of 11), not where they trail (review 1 of 7, consult 1 of 6, tabtype 2 of 9, envoy 2 of 10); this log's five lists since 09-07 first compared today | the log's top section; promise one or two |
| MINE.md is read and not reused | read in about 45 of 54 first windows; its run block in 1, the voice sweep 0, the document and reporting variants 0, pairs 7 and next-turn 8 (all September); name matches undercount adapted copies. Two defects: `context()` and `thread()` called bounded, and the next-turn query returning `[Request interrupted…` as a reply (231 such rows in 197 sessions since 09-07) | both defects fixed; slimming is the user's decision |
| skill-eval is driven by hand around its edges | 450 calls in 28 sessions since 10-09, 8 errors; 132 through `ssh mini`; one rollout inspected with jq or python over `row.json` and `transcript.jsonl` in at least 7 sessions, 11-04 and 11-05 included | proposal for skill-evals: a `show` command; not built |
| Offers nobody takes | an Obelisk memory offered in at least 16 of 54 runs, written in 5, none after 10-02 | the offer is cut |

**Changed.** `SKILL.md` rewritten from the goal: what a good pass is, the
companions routed from the opening with the moment each is read, five stance
paragraphs, a short toolkit, then changing, deciding, proving and recording.
Body 1,464 → 1,458 words; with its companions 5,386 → 4,825. `MINE.md`
3,225 → 2,561: the counting rules and predicates first, then the measure per
kind of tool, then the script; it loses the keyword sweep and the reporting
and document query variants, and gains the read this pass turned on, every
user turn after a run. `EVALS.md` 697 → 806: its steps in order, where
rollouts run, what `WORKTREE` means, and what to do when a judge cannot log
in. This log: the two sections at its top.

**Changed on purpose.**
- *The right fix over the smallest,* where the body said "smallest coherent
  change" against the global scoping rule.
- *Questions asked together, each with its default,* where the body said one
  neutral question at a time; the pipeline's § Who decides asks them so.
- *The closing pass by a fresh reader,* and *a build ends with it, the check
  and the evidence entry.*
- *One or two open comparisons at the head of the log,* where each change
  had a success measure nobody ran.
- *A trace may follow a symptom into the sessions it leads to; ask before a
  wider sweep.* The fresh reader found "ask before reaching into history the
  request does not cover" in conflict with tracing a cause into another
  tool. A default taken here; the boundary is the owner's.

**Cut, to watch.**
- *The Obelisk memory offer.* Bring back if a later session asks for a
  conclusion that lives only in an evidence log it had no reason to open.
- *"Most of a long skill's length is behavior".* The `over-budget` case
  passed 9 of 9 without it. Bring back if an over-budget pass reaches its
  budget by rewording and its parity read finds behavior lost.
- *The pointer to `SKILL-MECHANICS.md`.* Reached through revise-prompt and
  `AGENT-DOCS.md`. Bring back if a pass changes a skill's frontmatter without
  reading it.
- *`MINE.md`'s keyword sweep for corrections,* reused in 0 of 54 runs, and
  its reporting and document query variants, 0 of 54. Bring back if a pass
  over a corpus too large to read turn by turn misses a correction the
  sweep's words would have caught.
- *"Add a broader review when a material question remains",* the ledger's
  per-change fields, the compact table in the report, "the user remembers
  the moments that hurt", "a finding is a symptom", "never adopted on
  reputation", and the parity read "as a risk check, not a list to
  restore" (COLD-READER.md holds it).

**Restored after the checks caught their loss.** Checking help and results
against the installed build, "or explicit correction" beside the verified
defect, a cut logged with what it guarded, and the contract-change rule as it
stood (parity read). The case before any edit: a rewording that offered an
engine test in its place wrote the case late or not at all in 3 of 3 replays.
The rule naming the baseline interview: turned into a pointer through
revise-prompt, `BASELINE.md` was opened in 0 of 3 over-budget replays
against 3 of 3 for the live text. "An addition pays with a cut": cut on the
fresh reader's advice, and the design case's check that a proposal says what
it makes room with fell to 2 of 3; back in, 3 of 3.

**Verified by reading.** One parity read against `main` (30 of the old
file's 52 action-changing instructions kept, several through `MINE.md` and
revise-prompt). Three cold readers on scenarios from real runs (`2c257532`,
`9f01709a`, `71bdb6e3`); each reached a determinate first report. One fresh
reader ran revise-prompt's pass over the three files after the replays and
found, beyond wording: `MINE.md`'s script matching every Bash call when a
tool has no CLI, its moved-session check reading a list capped at ten,
`EVALS.md` telling the reader to run before calibrating, and the two
conflicting instructions above. All fixed.

**Verified by replay** (`~/dev/skill-evals`, tool `improve-tool`, arms under
`skills/`; rollouts on Opus 5.5 on the subscriptions, the model the 14 runs
since 10-28 used; judge Sonnet 5.5, three passes, graded on the laptop
because the mini's judge login had expired; runs `it-1109b` to `it-1109g`). "Final single file" sums the text before
and after the fresh reader's pass.
Cells are runs that passed the named check.

| case and check | live | first rewrite | final single file | split |
|---|---|---|---|---|
| design-then-go: closing pass | 1 of 3 | 0 of 3 | 6 of 6 | 3 of 3 |
| design-then-go: all checks | 1 of 3 | 0 of 3 | 6 of 6 | 3 of 3 |
| finding-to-case: case before the edit | about 4 of 5 judge passes, n=3 | 0 of 3 | 12 of 12 | 6 of 9 |
| finding-to-case: closing pass | 0 of 3 | 0 of 3 | 12 of 12 | 9 of 9 |
| over-budget: all checks | 3 of 3 | 3 of 3 | 6 of 6 | 3 of 3 |
| root-not-rules: all six checks | groups in 1 of 3 | 3 of 3 | 3 of 3 | not run |

- *The closing pass.* "First rewrite" told the author to run it, with a
  sharper sentence than the live text; a variant differing only in handing it
  to a fresh reader passed 3 of 3. In 5 of 6 final builds the session edited
  the target again after the reader returned.
- *The split* put the build rules in a `BUILD.md` routed from the opening.
  It was opened in each of the nine runs checked, at the start, not at the
  first edit. At nine runs each the case-first gap could be chance (about
  one in five); it points the way `AGENT-DOCS.md` § Where text sits predicts.
- *root-not-rules* is the 09-21 write-spec case: the control arm, told the
  owner's answer, passed all six checks.
- *Cost.* A build with the reader's pass ran about twice as long as the live
  text's: 7 to 11 minutes against 4 on design-then-go. About $135 across
  all runs, at Claude Code's API-price estimate.
- *Limits.* Three runs a cell except where nine is said. `go-says-what`, the
  design reply naming what a go-ahead does, was read from transcripts by a
  script, since the judge sees that reply clipped: the final text did in 3
  of 3.

**An outside skill judged: mattpocock's `retro`** (`skills/engineering/retro`
at a7d038f, 2026-09-24; the user asked for "Ritual", and that repository has
no skill of the name). It reads one session, the current one by default,
from the raw logs, and proposes changes to the agent's environment in seven
categories; nothing changes until the user picks one.

- *Replayed as an arm,* its body verbatim. On the one-session defect
  (`finding-to-case`) it found the cause and fixed both layers in 3 of 3, in
  2 minutes and $0.67 against the live skill's 4 and $1.15, and wrote no case
  and ran no pass. On `root-not-rules`, outside the one session it is built
  for, it scored below the live skill: groups in about 1 of 5 judge passes,
  what to leave alone in about half.
- *Graduated, each on our own evidence.* A check that fails when the mistake
  is made now heads the stance's list of fixes: retro gives a mechanical
  violation "a deterministic check, full stop", and here the 10-28 size
  ratchet stopped skill growth where prose had not. A rule goes where there
  is room to apply it: retro hands standards to the reviewer, who gets a
  diff, and keeps them from the implementer, who is under the most context
  pressure; here the build drops the closing prompt pass and a separate pass
  finds defects, while the one-PR rule shows the other half, a default that
  must change from the first reply. Twelve of the 54 requests were placement
  questions.
- *Covered already.* Every candidate traces to a moment in the record; a
  line that changes nothing is cut; an existing check that sits unwired is
  the finding; wider access to information.
- *Rejected.* Its fixed categories: its own doc quotes a user for whom the
  model "invents generic advice to satisfy the retro categories". Proposing
  only: in review about 33 of 37 replies to an offered idea said build. One
  session as the unit: its doc says it "cannot tell you that a rule now
  fires too often".

**Proposed outside this skill, not built.**
- *skill-evals.* A `show` command for one rollout. Leave `EVIDENCE.md` and
  `LESSONS.md` out of the skill a rollout installs, since a log can name a
  case's answer. Keep the reply a scripted answer responds to whole for the
  judge; it arrives clipped at 4,000 characters, so a two-turn case cannot
  judge its first reply. A judge route that works on the mini over ssh (its Claude
  login had expired, on 11-05 as well).
  The read policy let one rollout read `editorMode` from the owner's real
  `~/.claude.json`.
- *`docs/session-pipeline.md`.* A line naming this skill as an entry, as
  `go-cli-maintain` has, for the user's docs pass.
