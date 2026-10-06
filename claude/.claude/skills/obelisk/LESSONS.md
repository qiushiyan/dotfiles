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


## 2026-08-29 upstream refresh (pin `3226391` -> `109b8b1`, CLI 0.2.5 -> 0.2.5)

Upstream's only change since the last pin is a new `deepseek` source (DeepSeek
Harness: `source='deepseek'`, `deepseek:`-prefixed ids, subagent logs folded
into the parent as sidechain messages) in `SKILL.md`, `api-reference.md` and
`schema.md`. `@obelisk-apps/cli` is still 0.2.5 on npm and its dist has zero
`deepseek` hits, so the docs describe a runtime that is not released yet.
Nothing in the hot schema moved (same CLI), so it was not re-verified.

Every prior LESSONS item re-checked: none touches source enumeration; #9 is
the only one affected and it widens trivially (DeepSeek joins Kimi in the
"not on this machine" list in the body's Escalation references). Pristine copy
replaced under `.upstream/` and `references/`; body otherwise untouched.

## 2026-09-09 — invocation identity review (pin 109b8b1 → 2869861)

**Keep the Claude-focused query workflow; adopt upstream changes only where
the installed runtime supports them.** The owner reaffirmed the personalized
examples and friction fixes. Upstream changes only SKILL.md: search nonces
must be literal, and query identity can fall back to script content.

The installed package is still 0.2.5. Its `dist/core/src/core.js`
`executeQuery` passes only `invocation.invocationNonce` to
`resolveInvokingSessionIdWithWait`; script content goes to the query sandbox,
not the identity resolver. The CLI passes the expanded argv path as that
nonce. The upstream fallback is therefore deferred until a runtime upgrade
implements it; reading the new docs is not evidence the feature is installed.

The installed `resolveInvokingSessionId` function was exercised unchanged
against an in-memory SQLite fixture, with no live index or session access:

- A literal search nonce in the indexed tool record resolves its session.
- A shell-generated nonce whose expanded value is absent returns null.
- A tool record with script content and only `$Q` does not resolve the path.
- Adding the literal `Q=/tmp/…` assignment resolves the session.

Adopted: a literal search-nonce example and an explanation of why the query
path assignment must appear in the tool record. Qualified: the body's claim
that round one always returns null; an already indexed literal path resolves.
Retained: per-session path reuse, explicit self-exclusion, quoted heredocs,
and bounded/batched query examples. These fixtures check resolver semantics,
not Claude transcript timing; friction #11's live measurements remain evidence
for path reuse, and #12's warning against a shared fixed path still applies.

Every earlier lesson was checked against the upstream delta. #11–12 are the
identity seam reviewed above. #1–10 and #13–14, the permission-premise correction,
and the usage-analysis addendum concern schema, budgets, query behavior,
source scope, permissions, or evidence selection; none is changed by this
nonce-only delta. References are byte-identical to the previous pin. No CLI
upgrade or live schema remeasurement was needed or performed.

## 2026-09-15 — correlation guidance (pin 2869861 → b164d90)

Upstream changes two behaviors: scope topic correlations to the same sessions,
and document OMP as a source with inactive branches. Adopted the correlation
rule; OMP stays in the pristine references, outside the Claude-focused body.
The installed 0.2.5 provider registry contains Claude, Codex, Kimi, and Pi only.
Replaced the body's old corpus-count claim with this runtime boundary.

An in-memory SQLite fixture used the installed schema and unchanged
`createQueryApi`: X selected one session; searching Y with `{ sessionId }`
returned its visible message and excluded an unrelated session, meta input,
and an inactive branch. A separate probe confirmed that `search` ignores
`{ sessions: [...] }` in 0.2.5, so the body prescribes one bounded search per
candidate in a single script and stops on an empty candidate set. All six
hot-schema column sets matched `pragma_table_info` on the installed schema.
This verifies query semantics, not live indexing or transcript timing.

Every prior lesson was reviewed. #3–5's budgets, batching, and inline examples
remain; #7's persistence workflow is unchanged; #9's host scope stays narrow.
#10–12's self-exclusion and per-session literal nonce remain, and core.js still
passes only invocationNonce to identity resolution. #1–2, #8, #13–14, the
withdrawn permission premise, and the usage-analysis addendum are unaffected
by this delta. No CLI upgrade or live schema/usage remeasurement was performed.

## 2026-09-15 — engine upgrade (0.2.5 → 0.2.6-rc.0)

The owner made engine upgrades part of upstream-skill maintenance. The skill
pin remains b164d90; npm's latest engine is 0.2.6-rc.0. Installed that exact
version with pnpm, keeping one installation. Skill hashes cannot establish
engine currency; the shared maintenance guide and pin carry this requirement.

Verified the installed `createQueryApi` against an in-memory database using
its packaged schema, plus a CLI `--query` against a temporary HOME:

- All six hot-schema column sets match the skill; a fresh index initializes
  and answers a schema/count query.
- Scalar `replace()` and literals such as `'update-docs'` succeed. The engine
  classifies database effects rather than scanning keywords. Retired friction
  #2 and the SQL-literal workaround from the usage-analysis addendum.
- Writes and multiple statements are rejected; named parameters work, while
  positional arrays still fail. Retained the named-parameter example.
- Session-scoped search excludes unrelated sessions, meta input, and inactive
  rows; `search` still ignores `sessions: [...]`.
- The memory language guard rejects CJK queries. Literal invocation nonces
  resolve in the fixture; absent nonces return null. Source inspection confirms
  executeQuery still passes only invocationNonce to identity resolution.
- The provider registry includes DeepSeek but not OMP. Updated that boundary
  without expanding the Claude-focused workflow.

Lessons #1, #3–5, #7–8, and #10–14 retain their schema, budgeting, batching,
persistence, path, self-exclusion, query, and fresh-index purposes; #6 remains
withdrawn. #9's narrow host scope stays deliberate. Runtime probes establish
mechanics, not new usage measurements or live transcript timing; the per-session
path and explicit self-exclusion remain. No live index rebuild was performed.

## 2026-09-24 — skill delta b164d90 → 3e045af (deferred)

Upstream added ZCode and GitHub Copilot to the provider list and `source`
values, and documented a `RangeError` for negative helper limits. The
engine is unchanged: npm's latest and rc tags remain 0.2.6-rc.0. Its
`dist/core/src/providers/` registers claude, codex, deepseek, kimi, and pi;
nothing in the package mentions zcode or copilot, and `query.js` has no
negative-limit check. The delta therefore describes an unreleased runtime.

Deferred every hunk. Host coverage stays Claude-focused (#9), and the escalation
section's "features ahead of the installed CLI" boundary already covers the
refreshed references. Refreshed `.upstream/` and `references/` to the new
pristine copy and advanced the pin. No engine change, so the 2026-09-15 schema
and helper probes still stand; none were rerun.

## 2026-10-06 — both machines through one wrapper (session `38499815`, dotfiles)

The laptop and the mini each index their own sessions, and the skill asked
only the machine it ran on. `scripts/obq` now runs one script on both and
returns one object keyed by machine. Pin and engine are unchanged (3e045af,
0.2.6-rc.0 on both machines).

Corpus at measurement: mac 2,775 sessions (1,722 Claude, 1,048 Codex, 4 Pi)
and 21 memories; mini 201 sessions since 2026-09-22 and no memories; 3 session
ids on both.

**Why ask both at query time, not mirror transcripts.** The engine takes one
root per provider and keys everything off `$HOME`, so a second corpus means a
second index under a second HOME plus a transport for about 6 GB that `twin`
refuses to carry (`~/.claude`, `~/.codex`), stale between syncs and at rest on
the mini. Asking live needs the other machine awake; the owner's ruling
(2026-10-06) is that an unreachable machine is a warning and the answer is
built from what was reached.

Spikes before the build, each claim with the output that decided it:

| # | Claim | Actual | Verdict |
|---|---|---|---|
| 1 | A script piped over ssh runs under plain `obelisk --query` on the other machine, both directions | mac→mini `sessions: 201`; wrapper run on the mini asking the mac returned `mini 201, mac 2775`, rc 0 | verified |
| 2 | A project fragment selects the same project on both; the cwd-derived scope gives a false empty on the other machine | mini, searching `twin`: `'%dotfiles%'` 2 hits; cwd scope resolved `-Users-qiushiyan` (the ssh shell's home) and returned 0 | verified |
| 3 | Through the wrapper the local engine still marks the invoking session | 5 of 5 runs returned the session id in 0.06–0.24 s; the mini returned `null` each time | verified |
| 4 | The other machine's 4 s is the engine's identity wait | mini `--query` 4.11–4.16 s; mini `--search` with no nonce 0.03–0.04 s; a local query at a path absent from the transcript: `null`, 4.57 s | verified |
| 5 | Simultaneous queries on one index all succeed | 20 of 20 on each machine, and 3 wrappers at once | verified; only the mini's run indexed new messages mid-test |
| 6 | Unreachable, engine error and hang are distinguishable and bounded | unresolvable name rc 255 in 0.02 s; dropped packets rc 255 in 4.01 s; throwing script rc 1 with `{error}`; `timeout` cut a hung remote command, which kept running there | verified with stand-ins for a sleeping machine |
| 7 | An id on both machines is one moved conversation | all 3 share `started_at`; the mini's copies are longer (2111→2497, 156→1622, 575→2721 messages); one sits under a different project on each machine | verified |
| 8 | `remember()` accepts a session id the local index lacks | isolated HOME: written with `project` passed and recalled by fragment; without `project` the row has `project: null` and scoped recall misses it | verified |
| 9 | One hot schema on both | the same columns in all six tables; `messages` and `tool_calls` order them differently (the laptop's index was migrated, the mini's built fresh) | verified as sets |

What the runs put in the skill and the wrapper:

| # | Finding | Evidence | Where it landed |
|---|---|---|---|
| 15 | A cwd-derived project is wrong on the other machine | spike 2 | Round 1 scopes by a fragment; the `project` rule says how to form it |
| 16 | The fragment's breadth is a choice | mac: `'%-dotfiles'` 318 sessions in 1 project, `'%dotfiles%'` 379 in 17 (scratchpad sessions); planlab checkout 267 sessions, `'%worktrees-main-%'` 1,183 in 610 projects | the `project` rule names the checkout form and the worktree form |
| 17 | A nonce the other machine cannot find costs 4 s there, error or not | spike 4; a script that threw on the mini still took 4.36 s | `obq` sends `--nonce` only to this machine, so `--search` there is 0.03 s; scripts stay at ~4.4 s and the body says to batch |
| 18 | Exit 0 with empty stdout: a script awaiting a promise that never settles | `rc=0 stdout_bytes=0` | `obq` treats exit 0 without one JSON document as an error |
| 19 | `fileHistory()` is an exact match on a path that starts with one machine's home | `query.js:419`; the mac path returned 2 rows on mac, 0 on mini | Query rule: SQL `LIKE` on the path below home |
| 20 | `context()`, `raw()`, `thread()` return `null` or `[]` for a row the machine does not hold | probes with a mac uuid and session on the mini | Round 2 keeps one script for ids from both machines |
| 21 | `forget()` of an id this index lacks fails with `memory not found` | isolated HOME | Memory layer: `--attune` writes this machine's memories only |

Corrected: the body said the installed runtime does not implement the
script-content identity fallback. It does. `obelisk.js` in 0.2.6-rc.0 passes
the script text as a second, strict nonce candidate, and a query at a path
made at run time resolved this session through it, in 6.94 s against 0.1 s
for a typed path. The 2026-09-15 entry read `executeQuery`, which still
receives one `invocationNonce` value; that value is now a list. The typed
path stays the rule because it is faster and because the fallback needs 40
characters of script.

The engine's own comment says the identity poll runs only when a recovery
build loses the writer lease; the code polls for the full 4 s whenever the
nonce does not resolve. Nothing here works around it. A flag to skip
identity, or the comment's condition, would remove the cost upstream.

Every earlier lesson was rechecked against this change. #1's hot schema holds
on both machines as column sets. #3's budget now bounds the whole object, so
the per-machine `LIMIT` is 10. #4 batching gains a reason (#17). #8's fragment
rule is extended, not replaced (#15, #16). #10–12's self-exclusion and typed
per-session path are unchanged, and the id filter also covers a moved
session's copy. #7's persist step stays local. #13–14 are unaffected.

Not settled: a laptop that is really asleep, seen from the mini (the cap in
`obq` bounds it either way); a session running on the mini (the wrapper was
run there over ssh); Codex's sandbox with the network denied. The local
identity marker is not guaranteed on the first query after a gap: one
`--on mac` round took 5.18 s where the next four took 0.07–0.34 s.

`tests/test-obq.sh` pins the wrapper's contract against stub `obelisk` and
`ssh` and the tree's twin manifest; a do-nothing wrapper fails 35 of its
checks. `improve-tool/MINE.md` runs its mining script through `obq` and reads
each tally per machine: its counts join rows in JS, which holds one machine's
rows at a time.
