# LESSONS — receipts behind the personalized obelisk skill

> Update when: an upstream upgrade is folded in (re-check every item against
> the new version), or a new friction shows up in practice. Worth re-running
> the measurement after a month of new usage to see if the fixes held.

Distilled 2026-08-07 by querying obelisk about its own usage. Corpus at
measurement time: 877 indexed sessions (574 Claude, 303 Codex) across 261
projects; 157 `obelisk --*` CLI invocations in ~27 sessions across 12+
projects; 11 failed invocations. Method: `--query` scripts over
`tool_calls`/`tool_results` joined to `messages`/`sessions` (mode breakdown,
error harvest, per-session command arcs, helper-name frequency counts,
reference-Read counts), run from session `deae884d-72da-4daf-84bb-0ed47843918c`
(wiki, 2026-08-07).

## Friction catalog → fix

| # | Friction | Evidence | Fix in SKILL.md |
|---|----------|----------|-----------------|
| 1 | Column-name guessing is the dominant error: `tc.tool_name`, `tc.input`, `tr.tool_call_id` guessed instead of `tc.name`, `tc.input_json`, `tr.tool_use_id` | 7 of 11 all-time errors; e.g. sessions `df13c41e` (twice, 2026-08-06), `876ea721`, `b2bd7cf8`, `4a799ee7` (twice), `fa37c3ad`. Upstream `schema.md` was Read only 4× against 95 `sql()` uses — the reference tax goes unpaid until an error forces it | Hot schema inlined (pragma-verified), traps named, pragma probe as the doubt-resolver |
| 2 | Read-only guard keyword-scans SQL: scalar `replace()` rejected as write-like | This session, first query attempt; undocumented in upstream `pitfalls.md` | Query rule: trim with `substr()` |
| 3 | Unbudgeted output: stored text capped at 10k, results hitting exactly 10 000 chars repeatedly, requery churn | 39/159 `--query` and 10/10 `--search` calls defensively piped `\| head`; heavy arcs show consecutive 10k results | Budget rule (240-char snippets, LIMIT ≤ 20, <10k JSON); `--search` demoted to existence checks |
| 4 | Serial single-facet probe thrash | Worst arc: 12 rounds/3 min in `df13c41e` (q1.mjs…q12.mjs); best arc batched facets into `const out = {}` scripts (`e7126f06`) | Round 2 = one batched multi-facet script |
| 5 | Reference tax: ~700-line `query-patterns.md` re-Read every broad-synthesis session | 9 Reads across 9 sessions; 15 reference Reads total | The two patterns that get used (orient+sweep, batched detail) are inlined; references become escalation-only |
| 6 | Permission prompts from the heredoc habit: `cat <<EOF` + pipes fall outside `Bash(obelisk:*)` | 85 heredoc-style calls; every one needed manual approval where Write + `obelisk --query` is pre-approved | Workflow mandates Write tool + bare `obelisk --query` |
| 7 | Memory layer dormant: recall queried but nothing ever written | 1 memory ever (a video-download preference), 0 `--attune` runs, `memories(` in only 8 scripts | Round 3 persist step: offer with drafted summary inline |
| 8 | Project-path mangling inconsistent across versions | Same worktree appears as `-dev--worktrees-` and `-dev-.worktrees-` in different rows | Query rule: fragment `LIKE '%name%'` only |
| 9 | Host-agnostic bulk irrelevant to this machine: Pi/Kimi visibility machinery, recap intent | 0 Pi/Kimi sessions indexed; recap never genuinely invoked (only skill-text echoes; 0 `<command-args>` recap hits) | Dropped from the skill body; recap kept as a one-line reference route; Codex kept as a small rare-branch section (user request, 2026-08-07 — Claude remains primary) |

Post-distillation addendum (2026-08-07, same session): first real `--attune`
registration succeeded, but the recall round-trip showed memory FTS does no
stemming — `memories({ query: '…personalization…' })` returned `[]` against a
summary saying "Personalized"; literal terms matched. Rule added to the
SKILL.md recall bullet.

Non-findings worth remembering: the two user rejections of obelisk tool calls
(sessions `bd276406`, `f96783f7`) were prompt-editing interrupts — the user
resent the same request seconds later — not dissatisfaction with the skill.
Helper usage ranking (in-script): `sql` 95, `search` 31, `sessions` 16,
`overview` 10, `thread` 9, `memories` 8, everything else ≤ 4 — the skill's
emphasis follows this distribution.

## Provenance

- Upstream: `tommy0103/obelisk` `skill-doc/` @ `7c1b478` (2026-08-04), pinned
  byte-identical in `.upstream/` on 2026-08-07.
- CLI: `@obelisk-apps/cli` 0.2.2 at pin time (historical errors span 0.2.0 and
  0.2.2; installed via pnpm global, upgraded 2026-08-06 in session
  `d35a39e2`).
- Hot schema captured from `pragma_table_info` on 2026-08-07 against 0.2.2 —
  re-capture after every CLI upgrade.
