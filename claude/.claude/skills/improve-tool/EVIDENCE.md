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
