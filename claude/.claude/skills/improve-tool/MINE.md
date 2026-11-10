# Mining a tool's usage history

Read this before querying the session index. Take two things from it: how to
count, and the predicates that are easy to get wrong. The script further
down is a pattern for one kind of tool; write the query yours needs. Obelisk's
query rules apply in full.

## Counting rules

- **Classify before counting.** A signature hit is an actual use, a quoted
  instruction, a continuation, delegated work, or an adjacent task. Read the
  invocation and its follow-up in context; provider and role fields alone do
  not establish human authorship. Connected runs stay linked for provenance
  and are not counted as independent support.
- **Report the denominator.** Population and sample sizes, dates, exclusions,
  and missing follow-through. The examples below discover candidates: refine
  their predicates for the confirmed cohort and task window before reporting
  a rate, and keep the exact query and its constants beside the ledger so
  another pass can reproduce it.
- **Sample to the decision.** Sample across the dates, tasks and providers
  the question spans; widen when a gap or a rival explanation could change
  the decision, and stop when the action and its limits are clear. A large
  hit count does not need a large reading pass.
- **Each machine counts its own.** The result holds one object per machine,
  so every tally is one machine's. Calls add across machines; distinct
  sessions add too, except one moved between machines, which each holder
  counts:
  `jq '[.[] | .sessions[]?.id] | group_by(.) | map(select(length > 1))'`
  lists those among facet A's ten, so raise its `LIMIT` to check all. Report
  the corpus per machine and an unreached machine as a coverage gap. Keep
  constants as fragments below the home directory: the homes differ.
- **Writes and reads go through the shell too.** Count files across
  `Edit`/`Write` and Bash heredocs (`cat >`, `python3 - <<`, `sed -i`), and
  reads across `Read` and `cat`/`sed -n`/`head`/`tail`: a count over the edit
  or read tools alone undercounts.
- **The skill body's own claims are queries.** "Agents call `describe` before
  guessing a column" is a count, and the count says whether the rule works.

## Predicates that are easy to get wrong

- **A turn the user typed:** `role='user' AND content_type='text' AND
  COALESCE(is_meta,0)=0`, minus `This session is being continued%` and
  `[Request interrupted%`.
- **Corrections are scoped by session, never by whether the text names the
  tool.** The ones that decide a pass ("please revert", "go ahead") rarely do.
- **A reply's length and delay are not verdicts.** Read the report before it
  to tell approval from clarification, correction and restart.
- **A stored result of exactly 10,000 characters was cut by the index;**
  `raw()` windows the source. The harness's own output limit is a separate
  measurement.

## The measure follows the tool's kind

- **A CLI** (consumed output) is measured by drive cost: the script below.
- **A reporting engine** (lint, audit, a test suite, a review pass) is
  measured downstream: per finding class, what did the repair improve?
  Inspect the consequence of the change, not its line count; a one-line
  correction can restore a critical fact. Repeated maintenance suggests
  where to look, not that the findings were noise.
- **A document** (`CLAUDE.md`, `AGENTS.md`, a rules file, an onboarding
  skill) is measured by what happened after it was read. An always-loaded
  one has no invocation, so the population is every session in the project
  and the measure is **pointer hit-rate**: for each pointer, sessions whose
  edits fell in its branch against sessions that read its target. An invoked
  one (`/onboarding <goal>`) has a window, invocation to the next user turn,
  and three measures inside it: the docs read, the `Explore` prompts
  spawned, and whether the doc owning an edited area was read before the
  first edit there. A cluster
  of directories edited often whose docs are read rarely is a candidate
  routing gap. Check reads through other tools, already-loaded context, and
  whether the task needed that document, and pair the measure with the
  first-prompt task mix.
- **No engine** (a pure-instruction skill, a snippet): there is no Bash
  signature, and an empty `cli` matches every call, so drop the script's
  Bash facets and build `used` from the invocation rows. The failure facet
  becomes the user's turns plus the files the sessions touched. Inspect why
  a repair was needed: it can expose an instruction gap, a useful
  adaptation, or a defect elsewhere in the workflow. For an adoption or
  missing-capability question, comparable tasks done without the tool can
  reveal alternatives worth testing, within the authorized scope.
- **A pipeline** (one session writes what another consumes): pairs, in the
  last section.

## The script (a CLI)

Fill the constants and run it as one obelisk round. Run every round into a
file and read bounded slices with `jq`, so an oversized facet is re-sliced
without repeating the query.

```bash
S=<your scratchpad directory>; Q=/tmp/obq-<session-id>.mjs
~/.agents/skills/obelisk/scripts/obq $Q > $S/mine.json
jq -c 'to_entries[] | {(.key): (.value | if has("not_reached") or has("error") then . else with_entries(.value |= length) end)}' $S/mine.json
jq -r 'to_entries[] | .key as $m | .value.subcommands[]? | [$m,.k,.calls,.sessions] | @tsv' $S/mine.json | head -40   # one facet per command; a slice over the cap is re-sliced, not re-run
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

// E. user voice — explicit `friction:` markers, scoped by session; the turns themselves through facet F.
const used = [...new Set(calls.map(r => r.sid))].map(s => `'${s}'`).join(',') || "''";
out.friction_markers = sql(`
  SELECT m.session_id sid, m.uuid, substr(m.text,1,300) text FROM messages m
  WHERE m.role='user' AND m.content_type='text' AND COALESCE(m.is_meta,0)=0 AND m.source='claude'
    AND m.text LIKE '%friction:%' AND m.session_id IN (${used})
  ORDER BY m.timestamp DESC LIMIT 15`);

// F. what came next — the user's first turn after each engine call or skill invocation, read by position.
const invRows = sql(`SELECT m.session_id sid, m.timestamp ts FROM messages m WHERE m.role='user' AND COALESCE(m.is_meta,0)=0
  AND m.session_id <> '${self}' AND m.timestamp > '${since}' AND (m.skill = '${skill}' OR m.text LIKE '%/${skill}%' OR m.text LIKE '%${path}%')`);
const seenNext = new Set(); out.after = [];
for (const r of [...calls, ...invRows]) {
  const n = sql(`SELECT uuid, timestamp ts, substr(text,1,160) t FROM messages WHERE session_id=:sid AND role='user' AND content_type='text'
    AND COALESCE(is_meta,0)=0 AND timestamp > :ts AND text NOT LIKE 'This session is being continued%'
    AND text NOT LIKE '[Request interrupted%' ORDER BY timestamp LIMIT 1`, { sid: r.sid, ts: r.ts })[0];
  if (!n || seenNext.has(n.uuid)) continue; seenNext.add(n.uuid);
  out.after.push({ sid: r.sid, uuid: n.uuid, ts: n.ts, gapMin: Math.round((Date.parse(n.ts) - Date.parse(r.ts)) / 60000), len: n.t.length, t: n.t });
}
out.after_shape = tally(out.after, x => x.len <= 40 ? x.t.trim().toLowerCase() : 'long');   // length buckets select excerpts; they are not verdicts
out.after = [...out.after.filter(x => x.len <= 40).slice(0, 6),
             ...out.after.filter(x => x.len > 40).slice(0, 6)]; // retain receipts for both buckets

return out;
```

A `friction:` marker is the user's one-word tag on a correction ("friction:
review made me assemble the resume command by hand"), mined verbatim.

Drop facet F's `LIMIT 1` to read the conversation a run caused: every user
turn after it, in order, for the sessions in the sample. A few hundred turns
fit one file. Follow-up rounds expand vertically:
`messages({ around: uuid })` on a turn worth its context, the report before
it (the last assistant text in the window), `raw(uuid, { offset, limit })`
when a truncated tool result hides the error text; `obq --on <machine>`
asks only the machine that returned the hit.

## The writer/reader pair

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

The writer is looked up among the reader's machine's sessions, so a brief
written on one machine and picked up on another comes back with no
`writer`. Before counting a pair as writerless, run the writer query for its
slug with `obq --on <machine>` on each other machine, then intersect the read
sets after stripping each machine's home prefix from the paths.

Report confirmed pairs with reader tokens, overlap by stage, verified
falsifications (changed source / wrong at anchor), and unresolved claims.
Deduplicate claims before counting. Only a verified error at the anchor is
attributed to the writer; keep unknowns out of that failure count.
