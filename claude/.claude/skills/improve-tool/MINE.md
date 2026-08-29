# Usage-analysis script

The facet script for one tool's usage history — every past pass rebuilt it
by hand. Pick the variant for the engine's output kind — **consumed output**
(a CLI: the script below), **findings** (lint, audit, test suite, review: the
reporting variant), or **a document** (CLAUDE.md, an onboarding skill: the
document variant) — fill the constants, run it as one obelisk round, then
expand what it surfaces. Obelisk's query rules apply in full — one
`/tmp/obq-<session-id>.mjs` path for the whole session, `self` filtered out,
`LIKE` for anything with punctuation, named params only (`:x` with an object;
a positional array fails). Run every round into a file and slice it with
`jq`: the harness truncates Bash output at 10 k and a facet that overflows is
then a `jq` away instead of a re-run.

```bash
obelisk --query $Q > $S/mine.json && jq -c 'to_entries[] | {(.key): (.value|length)}' $S/mine.json
jq -r '.subcommands[] | [.k,.calls,.sessions] | @tsv' $S/mine.json     # one facet at a time, TSV for tables
```

```js
const self  = '<your session id — the UUID directory in your scratchpad path>';
const cli   = 'envoy ';                 // the engine's Bash signature, trailing space included
const skill = 'review';                 // messages.skill value and /name
const path  = 'skills/review/SKILL.md'; // how the user invokes it by path
const since = '2026-08-01';
const out   = {};

// A. population — who used it, how often, through which door
out.sessions = sql(`
  SELECT s.id, substr(s.title,1,50) title, substr(s.project,-30) project, substr(s.started_at,1,10) day, COUNT(*) calls
  FROM tool_calls tc JOIN sessions s ON s.id = tc.session_id
  WHERE tc.name='Bash' AND tc.input_json LIKE '%${cli}%' AND s.id <> '${self}'
  GROUP BY s.id ORDER BY s.started_at DESC LIMIT 10`);
out.invocations = sql(`
  SELECT COALESCE(m.skill, CASE WHEN m.text LIKE '%${path}%' THEN 'by-path' ELSE '/${skill}' END) door, COUNT(*) n, COUNT(DISTINCT m.session_id) sessions
  FROM messages m WHERE m.role='user' AND COALESCE(m.is_meta,0)=0 AND m.session_id <> '${self}'
    AND (m.skill = '${skill}' OR m.text LIKE '%/${skill}%' OR m.text LIKE '%${path}%')
  GROUP BY door`);

// B. usage shape — subcommand / flag counts, calls / distinct sessions
const calls = sql(`
  SELECT tc.id, tc.session_id sid, tc.input_json, tr.content, tr.is_error, m.timestamp ts
  FROM tool_calls tc JOIN messages m ON m.uuid = tc.message_uuid
  LEFT JOIN tool_results tr ON tr.tool_use_id = tc.id
  WHERE tc.name='Bash' AND tc.input_json LIKE '%${cli}%' AND tc.session_id <> '${self}' AND m.timestamp > '${since}'`);
const cmdOf = r => { try { return JSON.parse(r.input_json).command || ''; } catch { return ''; } };
const tally = (rows, keyOf) => {
  const t = {};
  for (const r of rows) { const k = keyOf(r); if (!k) continue; (t[k] ??= { calls: 0, s: new Set() }); t[k].calls++; t[k].s.add(r.sid); }
  return Object.entries(t).map(([k, v]) => ({ k, calls: v.calls, sessions: v.s.size })).sort((a, b) => b.calls - a.calls).slice(0, 15);
};
const shellNoise = t => /^(2>|&&|\|{1,2}|>|;|"|\$|`)/.test(t);
out.subcommands = tally(calls, r => { const i = cmdOf(r).indexOf(cli); if (i < 0) return '';
  return cmdOf(r).slice(i + cli.length).split(/\s+/).filter(t => t && !shellNoise(t)).slice(0, 2).join(' '); });
out.flags       = tally(calls.flatMap(r => (cmdOf(r).match(/--[a-z-]+/g) || []).map(f => ({ sid: r.sid, f }))), r => r.f);

// C. failures — error classes, re-rolls, truncated reads
out.errors = tally(calls.filter(r => r.is_error), r => (r.content || '').replace(/\s+/g, ' ').slice(0, 90));
const seen = new Map();
for (const r of calls) { const c = cmdOf(r); seen.set(c, (seen.get(c) || 0) + 1); }
out.rerolls = [...seen].filter(([, n]) => n > 1).sort((a, b) => b[1] - a[1]).slice(0, 15).map(([c, n]) => ({ n, cmd: c.slice(0, 120) }));
out.truncated_reads = sql(`
  SELECT COUNT(*) n, COUNT(DISTINCT tc.session_id) sessions FROM tool_calls tc JOIN tool_results tr ON tr.tool_use_id = tc.id
  WHERE tc.name='Read' AND tc.file_path LIKE '%<engine output dir fragment>%' AND length(tr.content) >= 10000`);

// D. workarounds — ad-hoc processing of engine output, and the question behind it
out.workarounds = sql(`
  SELECT tc.session_id sid, substr(tc.input_json,1,160) cmd,
    (SELECT substr(p.text,1,160) FROM messages p WHERE p.session_id=tc.session_id AND p.role='assistant' AND p.content_type='text'
       AND p.timestamp < m.timestamp ORDER BY p.timestamp DESC LIMIT 1) asked
  FROM tool_calls tc JOIN messages m ON m.uuid = tc.message_uuid
  WHERE tc.name='Bash' AND tc.session_id <> '${self}' AND m.timestamp > '${since}'
    AND (tc.input_json LIKE '%<engine output dir fragment>%')
    AND (tc.input_json LIKE '%python%' OR tc.input_json LIKE '%jq %' OR tc.input_json LIKE '%sleep %' OR tc.input_json LIKE '%until %')
  ORDER BY m.timestamp DESC LIMIT 10`);

// E. user voice — corrections in sessions that used the skill; explicit markers first
out.friction_markers = sql(`
  SELECT m.session_id sid, m.uuid, substr(m.text,1,300) text FROM messages m
  WHERE m.role='user' AND m.content_type='text' AND COALESCE(m.is_meta,0)=0 AND m.source='claude'
    AND m.text LIKE '%friction:%' AND (m.text LIKE '%${cli.trim()}%' OR m.text LIKE '%${skill}%')
  ORDER BY m.timestamp DESC LIMIT 15`);
out.user_voice = sql(`
  SELECT m.session_id sid, m.uuid, substr(m.text,1,240) text FROM messages m
  WHERE m.role='user' AND m.content_type='text' AND COALESCE(m.is_meta,0)=0 AND m.session_id <> '${self}'
    AND m.source = 'claude' AND m.text NOT LIKE 'This session is being continued%'
    AND (m.text LIKE '%${cli.trim()}%' OR m.text LIKE '%/${skill}%')
    AND (m.text LIKE '%why%' OR m.text LIKE '%stuck%' OR m.text LIKE '%wrong%' OR m.text LIKE '%didn''t%'
      OR m.text LIKE '%again%' OR m.text LIKE '%forgot%' OR m.text LIKE '%wait%' OR m.text LIKE '%不%')
  ORDER BY m.timestamp DESC LIMIT 10`);

return out;
```

The user-voice facet is the one that states intent, and it is the noisiest
to search for. A `friction:` marker in the user's own correction ("friction:
review made me assemble the resume command by hand") is mined verbatim and
costs one word to leave; the keyword sweep is the fallback for sessions
without one. Read the keyword sweep with the corpus in mind: a hit that repeats verbatim
across sessions is a standing snippet (`/review codex full review. While you
are waiting…`), not a correction — drop the term that matched it and re-run.

Follow-up rounds expand vertically: `context(uuid)` on a user-voice hit, the
full `thread(sid)` of the seed session, `raw(uuid, { offset, limit })` when a
truncated tool result hides the error text. The skill body's own claims are
also queries — "agents call `describe` before guessing a column" is a count,
and the count tells you whether the rule is working.

For a **reporting engine** — lint, audit, a test suite, a review pass — the
CLI facets collapse to "N calls, no flags, no errors". The cost is downstream:
per finding class, what did the repair change? A repair that touched only the
line the finding named (a sha, a count, a date) is bookkeeping; a class whose
repairs are mostly bookkeeping measures the world, not the tool, and is the
ledger's top line. The user's turn after the report ("处理 card drift 吧",
repeated) is that class in the user's voice, and the keyword sweep misses it.

```js
// finding classes from the engine's own output, then the repairs and user turns that followed
const runs = sql(`SELECT tc.session_id sid, m.timestamp ts, tr.content FROM tool_calls tc JOIN messages m ON m.uuid=tc.message_uuid
  LEFT JOIN tool_results tr ON tr.tool_use_id=tc.id
  WHERE tc.name='Bash' AND tc.input_json LIKE :cli AND tc.session_id <> :self`, { cli: '%lint.sh%', self });
const cls = {};
for (const r of runs) for (const l of (r.content || '').split('\n')) {
  const k = (l.match(/^([a-z ]+):/) || [])[1]; if (!k) continue;
  (cls[k] ??= { n: 0, s: new Set(), after: [] }); cls[k].n++; cls[k].s.add(r.sid);
  const nxt = sql(`SELECT substr(text,1,80) t FROM messages WHERE session_id=:sid AND role='user' AND content_type='text'
    AND COALESCE(is_meta,0)=0 AND timestamp > :ts ORDER BY timestamp LIMIT 1`, { sid: r.sid, ts: r.ts })[0];
  if (nxt) cls[k].after.push(nxt.t);
}
out.finding_classes = Object.entries(cls).map(([k, v]) => ({ k, flags: v.n, sessions: v.s.size, after: v.after.slice(0, 3) }))
  .sort((a, b) => b.flags - a.flags);
// repairs: edits to the flagged file inside the session; `git log --numstat -- <file>` outside obelisk says +1/-1 or content
out.repairs = sql(`SELECT tc.file_path f, COUNT(*) n, COUNT(DISTINCT tc.session_id) sessions FROM tool_calls tc
  WHERE tc.name IN ('Edit','Write') AND tc.input_json LIKE :marker AND tc.session_id <> :self GROUP BY tc.file_path ORDER BY n DESC LIMIT 10`,
  { marker: '%verified-against%', self });
```

For a **document** — `CLAUDE.md`, `AGENTS.md`, a rules file, an onboarding
skill — the instrument is what happened after it was read. An always-loaded
document has no invocation, so the population is every session in the
project and the measure is **pointer hit-rate**: for each pointer, sessions
whose edits fell in its branch against sessions that read its target. An
invoked document (`/onboarding <goal>`) has a window — invocation to the next
user turn — and three measures inside it: the docs read, the `Explore`
prompts spawned (each one a question the document did not answer), and
whether the doc owning an edited area was read before the first edit there.

```js
// pointer hit-rate: edits under a package vs reads of the doc its pointer names
const P = { 'zsh/': 'docs/zsh.md', 'tmux/': 'tmux/.config/tmux/workflow.md' };
const ed = sql(`SELECT DISTINCT session_id sid, file_path f FROM tool_calls tc JOIN sessions s ON s.id=tc.session_id
  WHERE s.project LIKE :p AND tc.name IN ('Edit','Write') AND tc.file_path LIKE :root`, { p: '%dotfiles', root: '/Users/qiushi/dotfiles/%' });
const rd = sql(`SELECT DISTINCT session_id sid, file_path f FROM tool_calls tc JOIN sessions s ON s.id=tc.session_id
  WHERE s.project LIKE :p AND tc.name='Read'`, { p: '%dotfiles' });
out.pointer_hits = Object.entries(P).map(([pkg, doc]) => {
  const inBranch = new Set(ed.filter(r => r.f.includes('/dotfiles/' + pkg)).map(r => r.sid));
  const readDoc  = new Set(rd.filter(r => r.f.endsWith(doc)).map(r => r.sid));
  return { pkg, doc, branch_sessions: inBranch.size, read_in_branch: [...inBranch].filter(s => readDoc.has(s)).length, read_anywhere: readDoc.size };
});

// invocation window for an invoked document: /onboarding … up to the next user turn
const inv = sql(`SELECT m.session_id sid, m.timestamp ts, m.text FROM messages m JOIN sessions s ON s.id=m.session_id
  WHERE m.role='user' AND COALESCE(m.is_meta,0)=0 AND m.session_id <> :self AND s.project LIKE :p
    AND m.text LIKE '%<command-name>/onboarding</command-name>%' ORDER BY m.timestamp`, { self, p: '%itell%' });
const argOf = t => (t.match(/<command-args>([\s\S]*?)<\/command-args>/) || [, ''])[1].trim();
out.args_shape = { total: inv.length, empty: inv.filter(r => !argOf(r.text)).length, carries_goal: inv.filter(r => argOf(r.text).length > 60).length };
out.windows = inv.map(r => {
  const end = (sql(`SELECT timestamp ts FROM messages WHERE session_id=:sid AND role='user' AND content_type='text' AND COALESCE(is_meta,0)=0
    AND timestamp > :ts AND text NOT LIKE '%<command-%' ORDER BY timestamp LIMIT 1`, { sid: r.sid, ts: r.ts })[0] || { ts: '9999' }).ts;
  const w = { sid: r.sid, ts: r.ts, end };
  const reads = sql(`SELECT tc.file_path f FROM tool_calls tc JOIN messages m ON m.uuid=tc.message_uuid WHERE tc.session_id=:sid AND tc.name='Read'
    AND m.timestamp > :ts AND m.timestamp < :end AND COALESCE(m.is_sidechain,0)=0`, w).map(x => x.f.replace(/^.*?platform\//, ''));
  const explore = sql(`SELECT substr(tc.input_json,1,140) p FROM tool_calls tc JOIN messages m ON m.uuid=tc.message_uuid
    WHERE tc.session_id=:sid AND tc.name IN ('Agent','Task') AND m.timestamp > :ts AND m.timestamp < :end`, w).map(x => x.p);
  return { sid: r.sid.slice(0, 8), arg: argOf(r.text).slice(0, 40), docs: reads.filter(f => f.startsWith('docs/')).length, src: reads.filter(f => f.startsWith('src/')).length, explore };
});
```

`read_before_edit` extends the window facet: for each doc cluster (`{ dirs:
[...], docs: [...] }`), sessions that edited under `dirs` against sessions
that read one of `docs` before the first such edit. A cluster edited often
and read rarely is a route the document does not route to. Pair either
measure with the first-prompt task mix (`MIN(timestamp)` user text per
session) to see which tasks the document says nothing about.

For a tool with no CLI engine (a pure-instruction skill, a doc, a snippet),
the Bash signature is the script path or nothing, and B collapses to A; the
failure facet becomes the user-voice facet plus the `Edit`/`Write` targets
the sessions touched — what the agent had to fix by hand is what the skill
did not teach.
