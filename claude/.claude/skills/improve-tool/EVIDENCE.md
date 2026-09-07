# improve-tool — evidence log

One entry per mining pass over sessions that ran this skill; counts are
written so the next pass can re-run them.

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
