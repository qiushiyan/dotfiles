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

Lessons that survived → usage-lessons.md ("smallest edit per signal, then
one holistic read", "a shape change is designed before it is built", the
outcome facet, the open goals-over-procedure note).
