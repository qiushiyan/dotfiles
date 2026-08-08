---
name: obelisk
description: >
  Search and query past Claude Code (and Codex) session history.
  Reactive: when the user asks "how did I fix X", "what did we do last time", "find the session where", "上次怎么修的", "之前的session", "历史记录".
  Proactive: when the user references past work you lack context for, when you're about to modify a file with complex edit history, or when the user says "继续之前的" or "continue where we left off".
  Memory: when the user says "记住这个", "remember this", "写入记忆", "save this conclusion", or when a retrieval result contains a conclusion worth persisting.
allowed-tools:
  - Read
  - Bash(obelisk:*)
  - Bash(date:*)
  - Write
---

# obelisk — personal edition

Query local session history from SQLite + FTS5 at `~/.obelisk/obelisk.sqlite`.
CodeAct style: write a small budgeted JS query, run it, read the JSON, answer
with compact evidence — history stays queryable structure, answered from
projections rather than browsed session by session.

Claude Code history is the primary target; Codex rows share the index (see the
Codex sessions section). Personalized from the upstream host-agnostic skill —
every rule below was bought by a logged failure; pin and receipts under
Upstream.

## Workflow

One script per round: write it to `/tmp/q.mjs` with the **Write tool**, run
`obelisk --query /tmp/q.mjs` with Bash. Both are pre-approved by
`allowed-tools`; a `cat <<EOF` heredoc or a `| head` pipe is not, and each
costs the user a permission prompt.

**Budget** every script so nothing needs piping: snippets `substr(...,1,240)`,
`LIMIT` ≤ 20, whole-script JSON under ~10k chars. The script body runs inside
`(async () => { ... })()`; `return` emits JSON. Scripts are read-only and
sandboxed — no fs/network, and `remember()`/`forget()` exist only under
`--attune`.

**Round 1 — orient + sweep** (skip only when given an exact session id,
message uuid, or file path):

```js
const topic = 'English topic terms translated from the request';
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
  evidence: search(topic.replace(/[-_]/g, ' '), { ...scoped, limit: 8 })
    .map(h => ({ session_id: h.session.id, title: h.session.title,
                 uuid: h.message.uuid, ts: h.message.timestamp,
                 snippet: h.message.text?.slice(0, 220) })),
};
```

**Round 2 — batched detail.** One script, `const out = {}`, 3–4 facets built
from round 1's session ids and learned vocabulary, each facet budgeted. The
worst historical failure mode is serial single-facet probing, one facet per
round for a dozen rounds; batching the facets into one script is the fix.
Expand one promising hit vertically with `context(uuid)` (parent chain +
session + subagent), not by pulling threads.

**Round 3 — answer + persist.** Cite `session_id`/`uuid` compactly; prose
carries the synthesis, not raw dumps. If retrieval produced a durable
conclusion, make the memory offer (below) with the summary already drafted.

`obelisk --search "word"` is an existence check, nothing more; anything real
gets a query script.

## Hot schema

Verified against CLI 0.2.2 via `pragma_table_info` on 2026-08-07. Guessed
column names are the top historical failure class — trust this list over
instinct:

- `sessions(id, title, project, project_path, started_at, ended_at, git_branch, version, message_count, jsonl_path, source)`
- `messages(uuid, session_id, type, parent_uuid, timestamp, role, text, content_type, is_meta, model, is_sidechain, agent_id, input_tokens, output_tokens, cwd, skill, turn_duration_ms, source, visibility)`
- `tool_calls(id, message_uuid, session_id, name, input_json, file_path, presentation)` — no timestamp: join `messages m ON m.uuid = tc.message_uuid`
- `tool_results(tool_use_id, message_uuid, session_id, content, file_path, is_error)` — no timestamp and no `id`; the key is `tool_use_id` (`tr.tool_use_id = tc.id`)
- `summaries(id, session_id, timestamp, source, content)` — `source` is the summary kind, not the provider
- `memories(id, session_id, project, message_start, message_end, path, anchors, summary, created_at, deleted_at, deleted_reason)`

The three traps, each a real past error: it is `tc.name` (not `tool_name`),
`tc.input_json` (not `input`), `tr.tool_use_id` (not `tool_call_id`). When any
doubt remains, probe first — one cheap round beats a failed one:
``sql(`SELECT name FROM pragma_table_info('tool_calls')`)``.

Helpers cover the first pass: `overview()`, `memories({ query })`,
`search(text, opts)`, `sessions()`, `summaries()`, `thread(sessionId)`,
`context(uuid)`, `fileHistory(path)`, `failures()`, `trace(uuid)`,
`raw(uuid, { offset, limit })`, `subagents()`, `workflows()`,
`workflowTree(runId)`. `search()` rows are
`{ message: { uuid, text, content_type, is_meta, role, timestamp, cwd },
session: { id, title, project }, rank, context }`, already FTS5-ranked — trust
the returned order. Common opts:
`{ limit, sessionId, project, after, before, cwd, source }`. `sql()` is the
escalation for exact joins and aggregations.

## Query rules

- The read-only guard keyword-scans the SQL: a SELECT containing `replace(...)`
  is rejected because it matches `REPLACE INTO`. Trim and clean strings with
  `substr()` (or in JS after fetching).
- Stored message text and tool content are truncated at 10k chars; a value of
  exactly 10 000 chars means truncated, not complete. `raw(uuid, { offset,
  limit })` windows the source JSONL when the full text matters.
- `project` filters are `LIKE` patterns over dash-mangled paths, and the
  mangling is inconsistent across CLI versions (`-dev--worktrees-` vs
  `-dev-.worktrees-`). Always match a fragment (`'%short-name%'`), never a
  constructed full path.
- FTS `MATCH` chokes on hyphens and punctuation: quote the tokenized phrase
  (`search('"two words"')`) or drop to SQL `LIKE '%two-words%'` for literal
  punctuation.
- Real user input is `role='user' AND content_type='text'`; `thinking` rows
  are trace material, never user-visible conclusions. Raw SQL over
  conversation evidence carries `COALESCE(m.is_meta,0)=0` (helpers already
  exclude meta).
- Counts come from SQL `COUNT`/`GROUP BY`, computed in the script — never from
  eyeballing returned rows.
- Timestamps are UTC. Check the local zone (`date +"%Z %z"`) before telling
  the user when something happened.
- A scoped empty result is an answer. Report it plainly; broaden only when
  asked.

## Codex sessions

Codex transcripts land in the same tables — `source='codex'`, session ids
prefixed `codex:` — so queries need no structural change. Source scoping runs
in both directions:

- Default searches stay unscoped. When Codex rows crowd out the Claude answer
  or provenance matters, add `source: 'claude'` (helpers) or
  `AND s.source='claude'` (SQL).
- Reach for Codex only when the user names it ("codex session", "在 codex 里").
  Scope with `source: 'codex'` and expect thinner metadata: summaries,
  subagents, and workflows may be absent for Codex rows.

## Memory layer

Recall only pays if writing happens, and historically almost nothing was
written. Close the loop:

- **Recall** rides in round 1 (`memories({ query })`). Query in English even
  when the conversation is Chinese — the runtime rejects CJK in memory queries
  and summaries. FTS does no stemming: use words that appear literally in
  summaries ("personalization" misses "personalized").
- **Persist**: when retrieval yields a durable conclusion (design decision,
  convention, abandoned alternative, repeated failure cause), end the answer
  with a concrete offer — drafted English summary inline, so approval is one
  word. On approval: Write the file (`.obelisk/memories/<slug>.md` in the
  relevant project), then register with `obelisk --attune /tmp/m.mjs`:

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
  `--query` first. `forget({ id, reason })` archives (the file stays). An
  update is forget + remember as one approved operation. The user saying a
  memory is wrong *is* the approval; ask only when several memories match.

## Escalation references

Upstream docs, still valid — skip their Pi/Kimi/visibility material (no Pi or
Kimi rows exist in this index; every row is visible):

| Read | when |
|---|---|
| `references/query-patterns.md` | a synthesis needs recipes beyond the two inline rounds |
| `references/api-reference.md` | exact helper options or return fields |
| `references/retrieval-semantics.md` | multi-step retrieval design |
| `references/pitfalls.md` | an error the Query rules above don't cover |
| `references/schema.md` | joins beyond the hot schema |
| `references/recap/overview.md` | an explicit `/obelisk recap …` request only |

## Upstream

`.upstream/` is the pristine host-agnostic skill-doc pinned at the commit in
`.upstream/PINNED.txt`; `LESSONS.md` holds the friction analysis behind every
rule above, with session-id receipts. The upgrade procedure lives in
`PINNED.txt`; after any upgrade, re-verify the hot schema with
`pragma_table_info` and re-check each `LESSONS.md` item against the new
version before folding changes in here.
