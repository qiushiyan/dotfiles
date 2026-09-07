# Usage-analysis script

The facet scripts for one tool's usage history: read these for the query
shape, then write the one this engine needs — patterns, not coverage.

Pick the variant for the engine's output kind — **consumed output** (a CLI:
the script below), **findings** (lint, audit, test suite, review: the
reporting variant), or **a document** (`CLAUDE.md`, an onboarding skill: the
document variant), or **no engine** (a pure-instruction skill, a snippet:
the last section) — fill the constants, run it as one obelisk round, then
expand what it surfaces. Obelisk's query rules apply in full. Run every
round into a file and read bounded slices with `jq`, so an oversized facet
can be re-sliced without repeating the query. The acting harness's output
limit and Obelisk's stored-text limit are different measurements.

Before counting patterns, classify signature hits as actual uses, quoted
instructions, continuations, delegated work, or adjacent tasks. Read the
invocation and relevant follow-up in context; provider and role fields alone
do not establish human authorship. Keep connected runs linked for provenance,
not counted as independent support. The examples below discover candidates;
refine their predicates for the confirmed cohort and task window before
reporting rates. Report both population and sample sizes, dates, exclusions,
and missing follow-through. Preserve an exact query and its constants beside
the local ledger so another pass can reproduce the denominator.

```bash
S=<your scratchpad directory>; Q=/tmp/obq-<session-id>.mjs
obelisk --query $Q > $S/mine.json && jq -c 'to_entries[] | {(.key): (.value|length)}' $S/mine.json
jq -r '.subcommands[] | [.k,.calls,.sessions] | @tsv' $S/mine.json | head -40   # one facet per command; a slice over the cap is re-sliced, not re-run
```

```js
const self  = '<your session id — the UUID directory in your scratchpad path>';
const cli   = 'envoy ';                 // the engine's Bash signature, trailing space included
const skill = 'review';                 // messages.skill value and /name
const path  = 'skills/review/SKILL.md'; // how the user invokes it by path
const outdir = '.local/state/envoy/';   // the engine's state dir or output files, as a path fragment
const since = '2026-08-01';             // verified fix date for the comparison window
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
// tallied in JS on purpose: a subcommand named `delete` or `update` inside a SQL LIKE trips the read-only guard — bind it as :x
out.flags       = tally(calls.flatMap(r => (cmdOf(r).match(/--[a-z-]+/g) || []).map(f => ({ sid: r.sid, f }))), r => r.f);

// C. candidates — errors, repeated commands, index-capped reads; inspect context before classifying failures
out.errors = tally(calls.filter(r => r.is_error), r => (r.content || '').replace(/\s+/g, ' ').slice(0, 90));
const seen = new Map();
for (const r of calls) { const c = cmdOf(r); seen.set(c, (seen.get(c) || 0) + 1); }
out.rerolls = [...seen].filter(([, n]) => n > 1).sort((a, b) => b[1] - a[1]).slice(0, 15).map(([c, n]) => ({ n, cmd: c.slice(0, 120) }));
out.index_capped_reads = sql(`
  SELECT COUNT(*) n, COUNT(DISTINCT tc.session_id) sessions FROM tool_calls tc JOIN tool_results tr ON tr.tool_use_id = tc.id
  JOIN messages m ON m.uuid = tc.message_uuid
  WHERE tc.name='Read' AND tc.file_path LIKE '%${outdir}%' AND length(tr.content) >= 10000
    AND tc.session_id <> '${self}' AND m.timestamp > '${since}'`);

// D. workarounds — ad-hoc processing of engine output, and the question behind it
out.workarounds = sql(`
  SELECT tc.session_id sid, substr(tc.input_json,1,160) cmd,
    (SELECT substr(p.text,1,160) FROM messages p WHERE p.session_id=tc.session_id AND p.role='assistant' AND p.content_type='text'
       AND p.timestamp < m.timestamp ORDER BY p.timestamp DESC LIMIT 1) asked
  FROM tool_calls tc JOIN messages m ON m.uuid = tc.message_uuid
  WHERE tc.name='Bash' AND tc.session_id <> '${self}' AND m.timestamp > '${since}'
    AND (tc.input_json LIKE '%${outdir}%')
    AND (tc.input_json LIKE '%python%' OR tc.input_json LIKE '%jq %' OR tc.input_json LIKE '%sleep %' OR tc.input_json LIKE '%until %')
  ORDER BY m.timestamp DESC LIMIT 10`);

// E. user voice — corrections in the sessions that used the tool, scoped by session, never by
// whether the text names the tool: the corrections that decide a pass ("please revert", "go ahead")
// rarely do. Explicit markers first.
const used = [...new Set(calls.map(r => r.sid))].map(s => `'${s}'`).join(',') || "''";
out.friction_markers = sql(`
  SELECT m.session_id sid, m.uuid, substr(m.text,1,300) text FROM messages m
  WHERE m.role='user' AND m.content_type='text' AND COALESCE(m.is_meta,0)=0 AND m.source='claude'
    AND m.text LIKE '%friction:%' AND m.session_id IN (${used})
  ORDER BY m.timestamp DESC LIMIT 15`);
const voice = sql(`
  SELECT COUNT(*) n, COUNT(DISTINCT m.session_id) sessions, MIN(m.session_id) sid, MIN(m.uuid) uuid, substr(m.text,1,240) text FROM messages m
  WHERE m.role='user' AND m.content_type='text' AND COALESCE(m.is_meta,0)=0 AND m.session_id IN (${used})
    AND m.source = 'claude' AND m.text NOT LIKE 'This session is being continued%' AND m.text NOT LIKE '<command-%'
    AND (m.text LIKE '%why%' OR m.text LIKE '%stuck%' OR m.text LIKE '%wrong%' OR m.text LIKE '%didn''t%'
      OR m.text LIKE '%again%' OR m.text LIKE '%revert%' OR m.text LIKE '%forgot%' OR m.text LIKE '%wait%' OR m.text LIKE '%不%')
  GROUP BY substr(m.text,1,80) ORDER BY MAX(m.timestamp) DESC LIMIT 60`);
out.user_voice = voice.filter(v => v.n === 1).slice(0, 10);                          // single matching prefix; inspect whether it is a correction
out.standing   = voice.filter(v => v.n > 1).sort((a, b) => b.n - a.n).slice(0, 6);   // repeated prefix; inspect duplicates and provenance

// F. what came next — the user's first turn after each engine call or skill invocation, read by
// position: candidates for outcome analysis. Read the preceding report to distinguish approval,
// clarification, correction, and restart; message length and delay do not establish wasted work.
const invRows = sql(`SELECT m.session_id sid, m.timestamp ts FROM messages m WHERE m.role='user' AND COALESCE(m.is_meta,0)=0
  AND m.session_id <> '${self}' AND m.timestamp > '${since}' AND (m.skill = '${skill}' OR m.text LIKE '%/${skill}%' OR m.text LIKE '%${path}%')`);
const seenNext = new Set(); out.after = [];
for (const r of [...calls, ...invRows]) {
  const n = sql(`SELECT uuid, timestamp ts, substr(text,1,160) t FROM messages WHERE session_id=:sid AND role='user' AND content_type='text'
    AND COALESCE(is_meta,0)=0 AND timestamp > :ts AND text NOT LIKE 'This session is being continued%' ORDER BY timestamp LIMIT 1`, { sid: r.sid, ts: r.ts })[0];
  if (!n || seenNext.has(n.uuid)) continue; seenNext.add(n.uuid);
  out.after.push({ sid: r.sid, uuid: n.uuid, ts: n.ts, gapMin: Math.round((Date.parse(n.ts) - Date.parse(r.ts)) / 60000), len: n.t.length, t: n.t });
}
out.after_shape = tally(out.after, x => x.len <= 40 ? x.t.trim().toLowerCase() : 'long');   // length buckets select excerpts; they are not verdicts
out.after = [...out.after.filter(x => x.len <= 40).slice(0, 6),
             ...out.after.filter(x => x.len > 40).slice(0, 6)]; // retain receipts for both buckets

return out;
```

The user-voice facet is the one that states intent. A `friction:` marker —
the user's one-word tag on a correction ("friction: review made me assemble
the resume command by hand") — is mined verbatim; the keyword sweep is the
fallback, grouped by text prefix so a hit arrives with its count:
`user_voice` and `standing` are candidate buckets by prefix frequency, not
proof of unique corrections or standing preferences.

Follow-up rounds expand vertically: `context(uuid)` on a user-voice hit, the
bounded `thread(sid)` projection of the seed session, `raw(uuid, { offset, limit })` when a
truncated tool result hides the error text. The skill body's own claims are
also queries — "agents call `describe` before guessing a column" is a count,
and the count tells you whether the rule is working.

For a **reporting engine** — lint, audit, a test suite, a review pass — the
CLI facets can miss the downstream outcome: per finding class, what did the
repair improve? Inspect the consequence of the change, not its line count;
a one-line correction can restore a critical fact. Repeated maintenance and
the user's response to it suggest priorities to investigate, not automatic
proof that the findings were noise.

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
prompts spawned (questions whose need for exploration should be assessed), and
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
and read rarely is a candidate routing gap. Check reads through other tools,
already-loaded context, and whether the task needed that document. Pair the
measure with the first-prompt task mix to assess actual coverage.

For a tool with **no engine** (a pure-instruction skill, a doc, a snippet),
the Bash signature is the script path or nothing, and B collapses to A; the
failure facet becomes the user-voice facet plus the files the sessions
touched. Inspect why the repair was needed: it can expose an instruction
gap, useful adaptation, or a defect elsewhere in the workflow. Count files
across `Edit`/`Write` *and* Bash heredocs
(`cat >`, `python3 - <<`, `sed -i`): with permissions bypassed, writes go
through Bash, and a count over the edit tools alone undercounts. For an
adoption or missing-capability question, comparable tasks done without the
tool can reveal alternatives worth testing, within the authorized scope.
Sparse usage can still justify a verified local repair; it does not itself
require a wider search or make every workaround a requirement.

## The pipeline variant — the writer/reader pair

For a tool whose output one session writes and another consumes (a handoff
brief, a spec, a status page), the population is pairs, not sessions. Build
each pair, then measure what the reader paid that the writer had already
paid:

- **the reader's window** — from the user message that carries the pointer
  (the brief's path, or `/<onboarding-skill>`) to the first user turn after
  it; `messages.input_tokens` on the window's last assistant row is the
  recorded input count; check provider and cache accounting before comparing it.
- **the writer** — the session whose `tool_calls` wrote the brief's path
  (`name IN ('Write','Edit') AND input_json LIKE '%<slug>.md%'`).
- **reads, both sides** — `Read` calls by path, plus the paths inside Bash
  `cat` / `sed -n` / `head` / `tail` commands; a `Read`-only count misses
  shell reads,
  each classified by stage: core doc, route, brief, gate, other doc, code.
- **overlap** — the reader's read paths ∩ the writer's, by stage. Check
  whether the same fact was rebuilt unnecessarily or usefully reverified.
- **claimed falsifications** — assistant text containing `falsif%` locates
  claims to inspect. Verify each against the cited source at the writer's
  anchor and the pickup revision. An empty `git log <anchor>..<pickup> --
  <cited paths>` establishes no committed change in those paths, not that
  the reader's accusation is true; runtime or external facts may also drift.

A pair-discovery sketch (one round, sliced with `jq`); confirm the exact
artifact and writer before promoting a candidate pair into the ledger:

```js
const briefDir = '.handoffs/<project>/';          // the writer's output, as a path fragment
const pointer  = '/<onboarding-skill>';           // what the reader's first message carries
const stage = f => /README\.md$|agent\.md$/.test(f) ? 'core' : /routes\//.test(f) ? 'route'
  : f.includes(briefDir) ? 'brief' : /pickup\//.test(f) ? 'gate' : /docs\//.test(f) ? 'doc' : 'code';
const pathsOf = tc => { const j = JSON.parse(tc.input_json);            // Read → file_path; Bash → the paths in cat/sed -n/head/tail
  return tc.name === 'Read' ? [j.file_path] : (j.command || '').match(/\S+\.(md|ts|go|sh)\b/g) || []; };
// G. pairs — a reader window per pointer message; the writer is whoever wrote that brief's file
const readers = sql(`SELECT m.session_id sid, m.uuid, m.timestamp ts, m.text FROM messages m
  WHERE m.role='user' AND COALESCE(m.is_meta,0)=0 AND COALESCE(m.is_sidechain,0)=0
    AND m.session_id <> '${self}' AND m.text NOT LIKE 'This session is being continued%'
    AND m.text LIKE '%${briefDir}%' AND m.text LIKE '%${pointer}%' AND m.timestamp > '${since}'`);
out.pairs = readers.map(r => {
  const slug = (r.text.match(new RegExp(briefDir + '([\\w/-]+)\\.md')) || [])[1];
  if (!slug) return { reader: r.sid, uuid: r.uuid, unclassified: 'No artifact path extracted' };
  const writer = sql(`SELECT tc.session_id sid, m.timestamp ts FROM tool_calls tc
    JOIN messages m ON m.uuid=tc.message_uuid
    WHERE tc.name IN ('Write','Edit') AND tc.input_json LIKE :artifact AND m.timestamp < :pickup
    ORDER BY m.timestamp DESC LIMIT 1`, { artifact: `%${slug}.md%`, pickup: r.ts })[0];
  const next = sql(`SELECT timestamp ts FROM messages WHERE session_id=:sid AND role='user'
    AND content_type='text' AND COALESCE(is_meta,0)=0 AND COALESCE(is_sidechain,0)=0
    AND timestamp > :ts AND text NOT LIKE 'This session is being continued%'
    AND text NOT LIKE '<command-%' AND text NOT LIKE 'Base directory for this skill:%'
    ORDER BY timestamp LIMIT 1`, { sid: r.sid, ts: r.ts })[0];
  const end = next?.ts || '9999'; // no follow-up: end of available evidence, outcome unknown
  const reads = (sid, start, end) => new Set(sql(`SELECT tc.name, tc.input_json
    FROM tool_calls tc JOIN messages m ON m.uuid = tc.message_uuid
    WHERE tc.session_id=:sid AND tc.name IN ('Read','Bash')
      AND m.timestamp >= :start AND m.timestamp < :end`, { sid, start, end }).flatMap(pathsOf));
  const rd = reads(r.sid, r.ts, end), wr = writer ? reads(writer.sid, '', writer.ts) : new Set();
  const overlap = {}; for (const f of rd) if (wr.has(f)) overlap[stage(f)] = (overlap[stage(f)] || 0) + 1;
  const mentions = sql(`SELECT uuid, timestamp, substr(text,1,240) text FROM messages
    WHERE session_id=:sid AND role='assistant' AND content_type='text' AND COALESCE(is_meta,0)=0
      AND timestamp >= :start AND timestamp < :end AND text LIKE '%falsif%' LIMIT 10`,
    { sid: r.sid, start: r.ts, end });
  return { slug, reader: r.sid, uuid: r.uuid, writer: writer?.sid, overlap,
           followup_observed: !!next, falsification_candidates: mentions };
});
```

Report confirmed pairs with reader tokens, overlap by stage, verified
falsifications (changed source / wrong at anchor), and unresolved claims.
Deduplicate claims before counting. Only a verified error at the anchor is
attributed to the writer; keep unknowns out of that failure count.
