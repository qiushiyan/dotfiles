---
name: obelisk
description: >
  Search past Claude Code and Codex session history, and persist conclusions worth keeping.
  Retrieve on request: "how did I fix X", "上次怎么修的", "find the session where".
  Retrieve unprompted: the user assumes context you lack, says "继续之前的", or you are about to edit a file with tangled history.
  Persist: "记住这个", "remember this", or a retrieval that yields a durable conclusion.
---

# obelisk — personal edition

Past sessions are a queryable index at `~/.obelisk/obelisk.sqlite` (SQLite +
FTS5), not a pile of transcripts to read. Every answer comes from a
**projection**: a small budgeted JS query whose JSON you read and synthesize.
Claude Code is the primary corpus; Codex shares the index.

Every rule here was bought by a logged failure.

## Run a query

```bash
Q=/tmp/obq-<session-id>.mjs   # <session-id> = the UUID directory in your scratchpad path
cat > $Q <<'EOF'
...query...
EOF
obelisk --query $Q
```

One path, fixed for the whole session and reused every round — that is what
lets obelisk recognize your own session. Quote the heredoc delimiter
(`<<'EOF'`) so the shell leaves the `$` and backticks in the JS alone. The
script body runs inside `(async () => { ... })()`; `return` emits JSON, and
the JS sandbox has no fs or network — everything comes back through that one
value. `obelisk --search "word"` is an existence check; anything real gets a
script.

**Budget** every script so its whole output is worth reading: snippets
`substr(...,1,240)`, `LIMIT` ≤ 20, JSON under ~10k chars. `| head` shreds JSON
into unparseable output, so a piped result is a wasted round; `jq` reshapes a
large result when budgeting genuinely cannot shrink it.

## Rounds

**1 — orient + sweep.** Skip only when handed an exact session id, message
uuid, or file path.

```js
const topic = 'English topic terms translated from the request';
const self = '<your session id — the UUID directory in your scratchpad path>';
const map = overview({ limit: 6 });
const project = map.current.project?.project;
const scoped = project ? { project } : {};
return {
  orientation: map.current_project && {
    project: map.current_project.project,
    sessions: map.current_project.sessions.map(s => ({ id: s.id, title: s.title, ended_at: s.ended_at })),
  },
  prior_memories: memories({ ...scoped, query: topic, limit: 5 })
    .map(m => ({ id: m.id, path: m.path, summary: m.summary?.slice(0, 240) })),
  evidence: search(topic.replace(/[-_]/g, ' '), { ...scoped, limit: 10 })
    .filter(h => h.session.id !== self)
    .map(h => ({ session_id: h.session.id, title: h.session.title,
                 uuid: h.message.uuid, ts: h.message.timestamp,
                 snippet: h.message.text?.slice(0, 220) })),
};
```

Done when you hold session ids worth expanding, or an empty that survives the
reading-an-empty rule below.

**2 — batched detail.** One script, `const out = {}`, 3–4 facets built from
round 1's ids and learned vocabulary, each budgeted. Serial single-facet
probing is the historical **thrash**: a dozen rounds where one batched script
answers everything. Expand a promising hit vertically with `context(uuid)`
(parent chain + session + subagent). Done when every facet you named has an
answer or a measured empty.

**3 — answer + persist.** Cite `session_id`/`uuid` compactly; prose carries the
synthesis. Close on one of two things: a drafted memory offer (below), or one
clause saying nothing durable came out of this. Skipping both is the measured
failure mode.

## Your own session

Obelisk rebuilds the index before every query, so this conversation competes
with real history as evidence. Its id is the UUID directory in your scratchpad
path — known before the first query, and the same id is the session's
`jsonl_path` basename. Filter it out of evidence (`self` above, or
`AND s.id <> '<id>'` in SQL); what remains is history.

The query path doubles as an invocation nonce, so obelisk marks the session
itself: `is_invoking: true` on `search()` hits and `sessions()` rows, and
`overview().current.session_id`. It resolves only once that path is indexed —
round 1 returns `null`, later rounds with the same path resolve — so read it as
a bonus and rely on the scratchpad id.

## Hot schema

Re-verified against CLI 0.2.5 via `pragma_table_info` on 2026-08-24. Guessed
column names are the top historical failure class — trust this list over
instinct:

- `sessions(id, title, project, project_path, started_at, ended_at, git_branch, version, message_count, jsonl_path, source)`
- `messages(uuid, session_id, type, parent_uuid, timestamp, role, text, content_type, is_meta, model, is_sidechain, agent_id, input_tokens, output_tokens, cwd, skill, turn_duration_ms, source, visibility)`
- `tool_calls(id, message_uuid, session_id, name, input_json, file_path, presentation)` — no timestamp: join `messages m ON m.uuid = tc.message_uuid`
- `tool_results(tool_use_id, message_uuid, session_id, content, file_path, is_error)` — no timestamp and no `id`; the key is `tool_use_id` (`tr.tool_use_id = tc.id`)
- `summaries(id, session_id, timestamp, source, content, visibility, input_tokens, output_tokens)` — `source` is the summary kind, not the provider
- `memories(id, session_id, project, message_start, message_end, path, anchors, summary, created_at, deleted_at, deleted_reason)`

The three traps: it is `tc.name` (not `tool_name`), `tc.input_json` (not
`input`), `tr.tool_use_id` (not `tool_call_id`). On any doubt, probe first —
one cheap round beats a failed one:
``sql(`SELECT name FROM pragma_table_info('tool_calls')`)``.

Helpers cover the first pass: `overview()`, `memories({ query })`,
`search(text, opts)`, `sessions()`, `summaries()`, `thread(sessionId)`,
`context(uuid)`, `fileHistory(path)`, `failures()`, `trace(uuid)`,
`raw(uuid, { offset, limit })`, `subagents()`, `workflows()`,
`workflowTree(runId)`. `search()` rows are
`{ message: { uuid, text, content_type, is_meta, role, timestamp, cwd },
session: { id, title, project, is_invoking? }, rank, context }`, already
FTS5-ranked — trust the returned order. Common opts:
`{ limit, sessionId, project, after, before, cwd, source }`; on `subagents()`
the `after`/`before` pair bounds overlap (still-active / already-started), not
start time. `sql()` is the escalation for exact joins and aggregations.

## Query rules

- The read-only guard keyword-scans the SQL: a SELECT containing `replace(...)`
  is rejected because it matches `REPLACE INTO`. Trim and clean strings with
  `substr()`, or in JS after fetching.
- Stored message text and tool content are truncated at 10k chars; a value of
  exactly 10 000 chars means truncated, not complete. `raw(uuid, { offset,
  limit })` windows the source JSONL when the full text matters.
- `project` filters are `LIKE` patterns over dash-mangled paths, and the
  mangling is inconsistent across CLI versions (`-dev--worktrees-` vs
  `-dev-.worktrees-`). Match a fragment (`'%short-name%'`), never a constructed
  full path.
- `sql()`'s read-only guard scans the whole statement text, string literals
  included: `'update-docs'` or `'insert-mode'` inside quotes is rejected as a
  write. Bind such values with `?` params (or build the literal in JS) instead
  of inlining them.
- FTS `MATCH` chokes on hyphens and punctuation: quote the tokenized phrase
  (`search('"two words"')`) or drop to SQL `LIKE '%two-words%'` for literal
  punctuation.
- **Reading an empty:** FTS ANDs every term, so a long topic string is a
  conjunction that quietly returns nothing (one measured sweep: 1 term 30 hits,
  4 terms 0). Sweep with two or three high-signal terms and widen with `OR`.
  Once the terms are that lean, a scoped empty is an answer — report it plainly
  and broaden only when asked.
- Real user input is `role='user' AND content_type='text'`; `thinking` rows are
  trace material, never user-visible conclusions. Raw SQL over conversation
  evidence carries `COALESCE(m.is_meta,0)=0` (helpers already exclude meta).
- Counts come from SQL `COUNT`/`GROUP BY` computed in the script, never from
  eyeballing returned rows.
- Timestamps are UTC. Check the local zone (`date +"%Z %z"`) before telling the
  user when something happened.
- A failed `obelisk` call is answered by fixing the call, never by reading the
  SQLite file or the JSONL directly — the CLI refreshes the index before
  answering, so a manual fallback silently drops the newest sessions.
  `SQLITE_READONLY`, `EACCES`, or "attempt to write a readonly database"
  against `~/.obelisk` means the shell was sandboxed: rerun the same command
  unsandboxed. If write access stays unavailable, stop and report the blocker.

## Codex sessions

Codex transcripts land in the same tables — `source='codex'`, session ids
prefixed `codex:` — so queries need no structural change.

- Default searches stay unscoped. When Codex rows crowd out the Claude answer
  or provenance matters, add `source: 'claude'` (helpers) or
  `AND s.source='claude'` (SQL).
- Reach for Codex when the user names it ("codex session", "在 codex 里").
  Scope with `source: 'codex'` and expect thinner metadata: summaries,
  subagents, and workflows may be absent.

## Memory layer

Recall only pays if writing happens, and historically almost nothing was
written. Close the loop:

- **Recall** rides in round 1 (`memories({ query })`). Query in English even
  when the conversation is Chinese — the runtime rejects CJK in memory queries
  and summaries. FTS does no stemming here either: use words that appear
  literally in summaries ("personalization" misses "personalized").
- **Persist** when retrieval yields a durable conclusion — a design decision, a
  convention, an abandoned alternative, a repeated failure cause. End the
  answer with the drafted English summary inline, as a finished artifact
  awaiting a yes, so approval is one word. On approval: write
  `.obelisk/memories/<slug>.md` in the relevant project, then register it with
  `obelisk --attune /tmp/oba-<session-id>.mjs`:

```js
return remember({
  path: '.obelisk/memories/<slug>.md',
  session_id: '<source session id>',
  message_start: '<first relevant uuid>',
  message_end: '<last relevant uuid>',
  anchors: [{ kind: 'file', path: '<related file>' }], // optional
  summary: 'English. Decision + reasoning + constraints — judgeable from memories() output alone.',
});
```

- `--attune` exposes only `remember()`/`forget()`; gather ids with a normal
  `--query` first. It neither refreshes nor reads the index, so it works while
  the desktop app owns index writes, but it does need an index that already
  exists — any `--query` guarantees that. `forget({ id, reason })` archives and
  the file stays; an update is forget + remember as one approved operation. The
  user saying a memory is wrong *is* the approval; ask only when several
  memories match.

## Escalation references

Upstream docs, still valid. Their Kimi and visibility material does not apply
here (no Kimi rows; every row visible), and Pi is 3 sessions out of 1273.

| Read | when |
|---|---|
| `references/query-patterns.md` | a synthesis needs recipes beyond the three rounds |
| `references/api-reference.md` | exact helper options or return fields |
| `references/retrieval-semantics.md` | multi-step retrieval design |
| `references/pitfalls.md` | an error the Query rules don't cover |
| `references/schema.md` | joins beyond the hot schema |
| `references/recap/overview.md` | an explicit `/obelisk recap …` request |

## Upstream

`.upstream/` is the pristine host-agnostic skill doc pinned at the commit in
`.upstream/PINNED.txt`, and `references/` is a verbatim copy of its references.
`LESSONS.md` holds the friction analysis behind every rule above, with
session-id receipts.

Upgrade by the procedure in `PINNED.txt` — by hand, since `obelisk install`
would overwrite this file. Every upgrade re-verifies the hot schema with
`pragma_table_info` and re-checks each `LESSONS.md` item against the new
version before anything is folded in here.
