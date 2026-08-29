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
| 6 | ~~Permission prompts from the heredoc habit: `cat <<EOF` + pipes fall outside `Bash(obelisk:*)`~~ **RETIRED 2026-08-24** — the premise was wrong: the user runs Claude Code in bypass-all-permissions and wants every skill able to run any command, so a prompt was never a real cost. The 85 "manual approvals" were never paid | ~~Workflow mandates Write tool + bare `obelisk --query`~~ Superseded: `allowed-tools` dropped from the frontmatter, workflow is one heredoc+run Bash call per round |
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

## 2026-08-24 upstream refresh (pin `7c1b478` -> `3226391`, CLI 0.2.2 -> 0.2.5)

Upstream moved: the skill doc is now published from its own docs-only repo
`tommy0103/obelisk-skill` (built from `tommy0103/obelisk@c70c311`), and
`obelisk install` shells out to `npx skills add tommy0103/obelisk-skill`, which
writes straight into `~/.claude/skills/obelisk` -- it would overwrite the
personalized SKILL.md. Warning recorded in `.upstream/PINNED.txt`.

Re-measured from session `58f98cab-01b7-4552-8474-fb3cff1accdd` (wiki,
2026-08-24), this session excluded from its own numbers. Corpus: 1273 sessions
(824 Claude, 446 Codex, 3 Pi -- Pi is no longer zero, Kimi still is) across 387
projects. Since the 2026-08-07 personalization: 116 `obelisk --*` calls in 17
sessions.

Did the fixes hold?

| # | Verdict | Evidence since 2026-08-07 |
|---|---------|---------------------------|
| 1 schema guessing | **held** | 2 errors in 116 calls (1.7%), down from 11 in 157 (7%). Hot schema re-verified against 0.2.5; only `summaries` drifted, gaining `visibility, input_tokens, output_tokens` |
| 3 budget / 4 batching / 5 reference tax / 8 path mangling | **held** | no recurrence in the error set |
| 6 heredoc permission tax | **withdrawn** | Not a partial win -- an invalid lesson. Measured 39/116 (34%) still using heredoc, then the user corrected the premise: bypass-all-permissions is the standing mode, and skills are meant to run anything. Heredoc is now the *recommended* form, since write-then-run in one Bash call costs one tool round instead of two |
| 7 memory persist | **did not take** | still 2 live memories, and the newer one is this skill's own registration. Zero organic writes in 17 days. The round-3 offer is not firing; next iteration should make it unconditional on a durable conclusion rather than a judgement call |
| 9 host-agnostic bulk | **held, narrowing** | 3 Pi sessions now exist, so "0 Pi rows" is no longer literally true; still far below the threshold where Pi machinery earns body space |

New frictions found in this refresh:

| # | Friction | Evidence | Fix in SKILL.md |
|---|----------|----------|-----------------|
| 10 | Own live session pollutes results. 0.2.5 refreshes the index before every query, so the running conversation competes with real history as evidence | Round-1 sweeps in this session returned this session as the top 3 hits | "Your own session is in the index" block: derive the session id deterministically from the scratchpad UUID, drop self-hits, never cite them back |
| 11 | Upstream's invocation-nonce recipe does not work under our workflow. The nonce is the query file path as typed, and resolution needs that path already indexed -- a first-use path resolved 1 of 4 times here, a reused one 4 of 4. Upstream's "unique directory per query" therefore misses on nearly every Claude Code query, which is one-shot by construction | Probes `obq-verify-20260824-{a1,a2,a3,b1}`; `is_invoking` and `overview().current.session_id` both populate correctly once resolution succeeds | Query path is per-session and reused across rounds (`/tmp/obq-<session-id>.mjs`) instead of upstream's per-query `mktemp` dir. This rests on the resolution measurement alone -- the permission argument that originally co-justified it was withdrawn the same day (#6) and the recipe is unchanged without it |
| 12 | The old fixed `/tmp/q.mjs` is entrenched and now actively harmful: weeks of reuse put it outside the nonce recency window, so identity never resolves | 33/116 calls since 2026-08-07 still write `/tmp/q.mjs` | Superseded by the per-session path above |
| 13 | FTS ANDs every term, so a verbose topic string silently returns zero and reads like "no history exists". Round 1's own example encouraged long topic strings | Wiki-scoped sweep this session: 1 term 30 hits, 2 terms 26, 3 terms 9, 4 terms 0 | Query rule: two or three high-signal terms, widen with `OR`, read an empty round 1 as over-constrained first |
| 14 | Upstream's new sandbox rule is worth keeping: a permission failure on `~/.obelisk` invites falling back to direct SQLite/JSONL reads, which silently answers from a stale index | Upstream `SKILL.md` "Fresh Index and Sandbox Permissions"; no local occurrence yet | Query rule: rerun unsandboxed, never route around a failed `obelisk` call |

Also folded in, low-stakes: `subagents()` gained `after`/`before` (overlap
bounds, not start times); `--attune` neither refreshes nor reads the index, so
it works while the desktop app owns index writes, but needs an index that
already exists.

## Provenance

- Upstream: `tommy0103/obelisk-skill` `skills/obelisk/` @ `3226391`
  (2026-08-24), pinned byte-identical in `.upstream/` and copied verbatim to
  `references/`. Previous pin: `tommy0103/obelisk` `skill-doc/` @ `7c1b478`
  (2026-08-04).
- CLI: `@obelisk-apps/cli` 0.2.5 at pin time, pnpm global only (upgraded from
  0.2.2 on 2026-08-24; historical errors span 0.2.0–0.2.2). A second copy
  installed under npm/nvm that day was removed rather than kept in sync — see
  `.upstream/PINNED.txt` for that and the stale-`latest` cache trap.
- Hot schema re-captured from `pragma_table_info` on 2026-08-24 against 0.2.5 —
  re-capture after every CLI upgrade.

## 2026-08-24 addendum: the permission premise was wrong

Friction #6 was the second-biggest driver of the 2026-08-07 personalization and
it was built on a false assumption. The user runs Claude Code in
bypass-all-permissions as the standing mode and holds that any skill should be
able to run any command, so the 85 heredoc calls counted as "manual approvals"
cost nothing at all. Two consequences:

- `allowed-tools` is gone from the frontmatter. Do not reintroduce a tool
  allowlist here to make some workflow rule enforceable; if a rule needs an
  allowlist to survive, it is not carrying its own weight.
- Heredoc went from banned to recommended: `cat > $Q <<'EOF' … EOF; obelisk
  --query $Q` is one Bash call, where Write-then-run was two tool rounds. The
  quoted delimiter matters — unquoted `<<EOF` lets the shell eat `$` and
  backticks in the JS.

What survived the withdrawal, and why: the budget rule (#3) never depended on
permissions — `| head` shreds JSON into unparseable output, which is a
correctness cost, not an approval cost. The per-session query path (#11) rests
on the nonce-resolution measurement alone. Worth remembering as a general
pattern: a rule justified by two independent arguments should be re-derived
when one is withdrawn, not assumed safe because the other remains.

## 2026-08-29 — usage-analysis passes (session `2c06f903`, dotfiles)

Read from four earlier passes that mined one tool's usage (`d1a2fe7d` envoy,
`54711f30`/`e96abdd5` triage toolkit, `b5f5e59f` handoff-sweep) plus this
session's own rounds:

| Friction | Evidence | Fix |
|---|---|---|
| `?` positional params fail: `Unknown named parameter '0'` — and the skill recommended them | this session's first query; `d1a2fe7d` first query, retried with `${self}` inlined | Query rule now names the working form (`:x` + object), verified against 0.2.5 |
| Continuation summaries and Codex briefs match `role='user'` and pollute a "user corrections" facet | this session's user-voice facet: 4 of the top 4 hits were `/review` briefs or `This session is being continued…` | Query rule names both exclusions |
| Every usage pass rebuilt the same tally (calls / distinct sessions per subcommand, error class, re-roll, workaround-with-preceding-question) from scratch | 8 scripts in `d1a2fe7d`, 13 in `54711f30`, 4 in `e96abdd5` | Facet script inlined once in `improve-tool/MINE.md`; the skill points at it |

