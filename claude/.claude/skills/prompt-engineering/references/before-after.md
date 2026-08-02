# Before → after — worked examples

Companion to the prompt-engineering rulebook (`SKILL.md`); read it with the
principles already loaded. Four worked examples of improving something that
already exists — one per pillar, plus an error. Each "why" maps back to a
principle in the rulebook; the point is the _move_, not the specific wording.

## 1. A behavioral instruction block (prompt)

**Before**

```
You are a helpful assistant. Stay responsive and always be proactive.
CRITICAL: You MUST NEVER answer technical questions yourself — that's the
worker's job. The way this works: each worker runs in its own background
session spawned over RPC, and results arrive as follow-up messages on the
event bus, so don't block waiting on them. (A worker turn can take several
minutes.)
```

**After**

```
<role>
You route work between the user and specialist workers. You don't do the
technical work yourself.
</role>

When a technical question comes up, hand it to the relevant worker instead of
answering it — your own answer would skip the user's review and shape the work
invisibly.

A worker turn takes several minutes, so send one complete, well-formed request
rather than a stream of small ones, and keep making progress elsewhere while it
runs — pick up the result when it arrives.

Ask the user only when the decision is theirs (direction, priorities) and you
can name the specific choice that depends on the answer.
```

**Why**

- **Cut vs. transform — the move worth seeing.** Developer-facing framing isn't always deletable; often it _hides_ a fact the model needs. "spawned over RPC… on the event bus" is pure plumbing — _cut_ it; the model learns that from using the tools, not from prose. But "a worker turn can take several minutes" is a real fact wearing an implementation-detail costume — _transform_ it into context the model acts on: send one complete request, and work elsewhere meanwhile (which also gives "don't block" its positive form). The skill is to tell those two apart, not to strip every line that mentions the system.
- `CRITICAL: MUST NEVER` → a plain framework _with its reason_ ("would skip the user's review and shape the work invisibly"). The model now applies the intent to cases the rule never enumerated, and the de-escalated tone stops it overtriggering.
- "stay responsive / always be proactive" → a concrete _trigger + action + skip_ — ask only when the decision is theirs _and_ you can name the choice.

## 2. A bloated window (context)

**Before**

```
System prompt (rebuilt and re-sent every turn, ~8k tokens):
  <role>…</role>
  <api_reference> …all 12 endpoint docs, in full… </api_reference>
  <style_guide> …the entire style guide… </style_guide>
  <decision_log> …every past decision… </decision_log>
  Always follow the style guide. Follow the style guide when writing copy.
```

**After**

```
System prompt (small, stable across turns):
  <role>…</role>
  Rules that apply every turn: …the three that always matter…
  Reference: API docs live in `docs/api/`, the style guide in `docs/style.md`.
  Read the one you need with read_doc(path) before you rely on it.

// plus a tool
read_doc(path) → returns the requested doc.
```

**Why**

- The 8k prompt pays for all 12 docs and the full log on _every_ call regardless of relevance, and a near-full window degrades (_context rot_). Keep the prefix small and stable so the cache hits and attention stays sharp.
- _Just-in-time_: hold lightweight references (paths) plus a tool to load the one doc the task actually needs.
- _Progressive disclosure_: an index up front, full content only on match.
- Cut the duplicated "follow the style guide" line — an accidental copy, not a deliberate echo.

## 3. A tool, end to end (tool)

**Before**

```js
{ name: "search",
  description: "Search the database.",
  parameters: { q: { type: "string" } } }

// result
[{ "id": "8f3a2c…", "mime": "text/markdown" }, …]
```

**After**

```js
{ name: "docs_search",
  description: "Full-text search over the team's design docs. Matches `query` \
    against title and body — use plain keywords, not boolean operators. \
    Returns the most relevant docs first.",
  parameters: {
    query: { type: "string", description: "Keywords to match against doc title and body." },
    limit: { type: "integer", default: 5, description: "Max docs to return." } } }

// result
{ "results": [{ "title": "Auth design", "path": "docs/auth.md", "snippet": "…JWT rotation…" }],
  "note": "5 of 23 matches shown. If none fit, narrow the query and search again \
           rather than raising the limit." }
```

**Why**

- Vague `search` → namespaced `docs_search`; `q` → `query` with a description — _unambiguous names_, and the description _surfaces the implicit_ (keywords-not-boolean, relevance order) that the model can't otherwise know.
- Added `limit` with a default — _token-efficient_ by construction.
- Opaque `id`/`mime` → _semantic returns_ (`title`, `path`, `snippet`) the model can act on directly.
- The `note` is _mini-context_: it nudges the next step (narrow and re-search, not raise the limit) with the reason, exactly when the model is deciding what to do after a thin result.

## 4. An error result (tool)

**Before**

```
Error: validation_failed (code 422)
```

**After**

```
Couldn't create the event: `start` ("2026-13-02") isn't a valid date — month
must be 01–12. Fix the month and retry; the rest of the call was fine.
```

**Why**

- An opaque code → an error that _prescribes the recovery path_: what was wrong, the specific fix, and that nothing else needs to change — so the model doesn't improvise recovery or retry the identical bad call.
- It lands in the result text the model actually reads, which is what makes self-correction possible at all.
