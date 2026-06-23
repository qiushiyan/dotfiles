---
name: prompt-engineering
description: Reference for designing and improving prompts, agent context, and tool surfaces — written for how a model reads, not how a human documents.
---

# Prompt engineering

Distilled, provider-agnostic guidance for two jobs that share one rulebook:

1. **Writing** a new prompt, instruction block, or tool definition.
2. **Improving** an existing one.

The principles are the same either way. When writing, use them as a design guide. When improving, use them as a defect lens — read the target against the principles and the [Common defects](#common-defects-the-improvement-lens) list, then propose each change _with the reason it helps_. The [Before → after](#before--after) section shows the move on concrete examples. There is no hard line between the two jobs; improving is just writing with a draft already in front of you.

**The reader of every word you write is the model.** Optimize for how a model reads, not for how a human documents a system.

This guide is organized around the three things you shape when you build with a model — and you rarely touch one without the others:

- **Prompt design** — how the model should _behave_.
- **Context engineering** — what the model _knows_ this turn.
- **Tool design** — what the model can _do_.

> **A note on delimiters.** Examples below use XML-style tags (`<context>…</context>`); Markdown headings and fenced blocks work just as well. What matters is that you delimit content clearly and stay consistent — not which characters you use.

---

## First principles

These five carry the rest. Most specific rules are a corollary of one of them.

- **Write for the model, not the developer.** The most common defect is developer-facing framing leaking into model-facing text — architecture commentary, mechanism explanations, implementation rationale, and the quieter one: internal names, product concepts, and domain terms that mean something to _you_ but nothing to the model. It needs to know neither _how the system works_ nor _what you call its parts_ — only _what to do_. Read each line and ask: does this help the model act, or does it only land because I built this? Cut plumbing outright; for a term that carries meaning only for you, swap in the plain thing it stands for. (The per-term form of this is the familiar-term test under the cold-reader principle below.)
- **Explain the why.** A model generalizes from a reason far better than from a bare rule — it will apply the intent to cases you never anticipated. A constraint stated as a bare prohibition invites creative violation; the same constraint stated as a framework _with its motivation_ becomes part of how the model reasons.
- **Minimal but complete.** Aim for the smallest set of information that fully specifies the behavior you want — nothing redundant, nothing missing. Minimal does not mean short; it means no padding. Over-specification breeds brittleness and overtriggering; under-specification yields generic output.
- **Everything is prompt surface.** Tool names, parameter names, descriptions, result text, and error messages all consume the model's attention and steer its behavior. Treat them with the same care as the system prompt.
- **The cold-reader test.** The artifact you write is read _standalone_ — by a model that has none of your conversation: not the problem you've been solving, the system you've been building, or the code tour you just took. That context is yours, not the file's, and it skews you two ways at once. You _under-supply_ the basics — what this thing is, the system it's part of — because they're obvious to you. And you _over-supply_ your own vocabulary — internal names, product concepts, domain terms that read as precise to you and as noise to a reader who's never seen them, _because_ they carry so much meaning for you. Both are the curse of knowledge, sharpest exactly when your context is richest — i.e. while authoring. Run a check for each direction. _Under-supply:_ anchor the basics, then read it cold — if a fresh reader saw _only_ this, would they know what it is and what to do? _Over-supply:_ the **familiar-term test** — for every internal name, product concept, or domain term, ask _does this help the model do the task, or understand the problem it's on — or is it here only because I know what it means?_ Familiarity is not value. Make this a deliberate test, not a recognition rule, because your own jargon never _feels_ like jargon — it feels necessary; the test catches it precisely by interrogating the comfortable terms too. When a term fails, replace it with the plain thing it stands for: name the work, not the label you filed it under.

---

## Prompt design

How the model should behave.

### Structure and placement

- **Long content first, the task last.** Put documents, templates, and other longform context at the _top_; put the instruction/question in a block at the _end_. Models attend most reliably to the beginning and end of a context and degrade on material buried in the middle, so a load-bearing instruction must not live mid-context. On long multi-document inputs this ordering measurably improves quality.
- **Delimit content types** so data is unambiguous from instructions. Use descriptive tags; nest when the content is hierarchical.
- A reliable order for a system prompt: **role/context → task → detailed instructions → output format.**

### Be specific and concrete

- **State the output contract** — format, length, style, what "done" looks like. The less the model has to guess, the more likely you get what you want. If you want it to go above and beyond, say so explicitly; it won't infer ambition.
- **For behavioral instructions, specify trigger + action + skip condition** — _when_ it should fire, _what_ to do, and _when not to_. The skip condition is what prevents overtriggering, and is the part people forget.
- **Cut generic directives.** "Be helpful," "be proactive," "ask good questions" are noise — the model already tries to do these. If you can't name the trigger, the action, and the skip condition, the instruction isn't ready to add.

### Framework over prohibition; positive over negative

- **Prefer the positive path.** Tell the model what _to do_, not what to avoid. Negation forces the model to first surface the very concept it's meant to suppress (the "pink elephant" problem), and larger models can actually do _worse_ on negated instructions. Reframe "don't ask generic questions" as "ask only when you can name the concrete decision that hinges on the answer."
- **Reserve `never`/`do not` for hard safety boundaries** — destructive commands, data loss — where a positive rephrase would be vaguer and the cost of violation is severe. Negation as the _primary_ steering mechanism is fragile; a prompt full of "do not" reads like a list of things the model now knows it _could_ do.

### Calibrate emphasis

Dial back `CRITICAL:`, `you MUST`, ALL-CAPS, "exactly once." Modern models are highly instruction-responsive and _overtrigger_ on aggressive emphasis — language meant to fix undertriggering on older models now backfires. Write normal imperatives. Reserve strong language for a genuine hard constraint backed by a real, observed failure mode — not as precaution.

### Right altitude

- Write **strong heuristics, not brittle if-else logic, and not vague platitudes.** Encode the expert _strategy_; leave the model judgment room where you don't actually care about the specifics. "Think carefully about whether the loop has converged before continuing" beats a hand-authored decision tree — and survives cases the tree didn't foresee.
- **Prefer general instructions over prescriptive step lists.** Use numbered steps only when order or completeness genuinely matters.

### Examples (few-shot)

Examples are the highest-leverage tool for tone, format, and judgment that rules alone struggle to pin down — the pictures worth a thousand words.

- Wrap them in `<example>` / `<examples>` tags so the model distinguishes them from instructions.
- Make them **relevant** (mirror the real use case) and **diverse** (cover edge cases; vary enough that the model doesn't overfit to one surface pattern).
- A handful is the sweet spot — enough to show the pattern, not so many they dominate the prompt or cause overfitting.
- **Include at least one anti-example** (`type="avoid"`). Without it, the model often reproduces the generic default you're trying to displace.

> Reasoning models frequently need few or no examples — reach for them when rules aren't landing the judgment, not by default.

### Roles

A role/persona line focuses **tone, voice, audience, and output style** — use it for that, and one line is often enough. Don't rely on "you are an expert…" to improve factual accuracy or reasoning; that doesn't reliably help and can pull the model into style-following mode.

### Reasoning models and long-horizon behavior

This guide targets modern reasoning models, and many prompts drive an agent across many turns.

- **Let the model reason; don't script its thinking.** Give a clear goal, strong constraints, and an explicit output contract, then let it work — don't hand-author step-by-step "think first" scaffolding or over-specify intermediate steps (it wastes reasoning budget and can fight the model's own plan). Ask it to **verify its answer against the success criteria** before finishing — and for high-stakes work, have a fresh-context evaluator that never saw the work being built grade it against a rubric, since agents reliably over-rate their own output. (Hand-written chain-of-thought is mainly a crutch for older non-reasoning models, where it does help — add it back if you target those.)
- **Counter premature termination.** Tell long-running agents to keep going until the task is genuinely resolved, and to research or decide on the most reasonable path rather than handing back at the first sign of uncertainty. Declaring victory on partial progress is the cardinal long-horizon failure.
- **Make action defaults steerable.** Scale eagerness to the cost of being wrong: act-then-report for reversible actions, ask-first for consequential or irreversible ones. Set explicit tool-call budgets and stop conditions, and give an escape hatch ("if you can't determine X, proceed with your best assumption and note it").

---

## Context engineering

What the model knows this turn. Instructions tell it how to behave and tools say what it can do; context is the information you place in — and keep out of — its window. **The window is a finite budget, not free space**, and the most common agent failure is not clumsy wording but the right information missing, or buried under noise.

- **Treat the window as a finite budget.** Aim for the smallest set of high-signal tokens that does the job. Model quality degrades as the window fills — measurably, and often well before the advertised limit (_context rot_) — so padding "just in case" actively hurts. More context is not safer context.
- **Load just-in-time.** Hold lightweight references — file paths, IDs, queries — and pull full content at runtime via tools, instead of pre-loading everything you might need. Metadata (names, directory structure, timestamps) is high-signal navigation in its own right.
- **Disclose progressively.** Load in tiers: a lightweight menu or index first, full detail only when the task matches it. (Same shape as a phase-scoped tool menu, or the `note` in a tool result — show what's relevant now, keep identifiers for the rest.)
- **Place for attention; keep the prefix stable.** Put high-signal material and the live task where the model attends best — the edges, not the middle (see [Structure and placement](#structure-and-placement)). Keep the prompt _prefix_ stable and let variable, per-request content ride at the end, so the cache hits the static portion and you don't pay to re-read it every turn.
- **Externalize state; compact at the boundary.** For work that spans many turns or survives compaction, keep state in durable artifacts _outside_ the window — a plan/todo file, structured JSON for status, git for checkpoints — and read enough back on a fresh window to continue. As the window fills, summarize and reinitialize: preserve decisions, open problems, and load-bearing detail; drop redundant tool output. Tell the agent its context is managed automatically so it doesn't wrap up early to save budget.

---

## Steer at the right surface

The system prompt is not the only — or always the best — place to steer behavior. It's read once, early; by the time the model is on its fifth tool call, the system prompt is far away in context. A behavior that must happen _at a specific moment_ is more reliably driven by a nudge that lands at that moment.

Use each surface for what it does best, and **keep one source of truth per behavior** — if the same rule appears in the system prompt, a tool description, and a result, the model reads all three, may overtrigger, and the copies drift when one is updated.

| Surface                | Best for                                        | The question it answers                                 |
| ---------------------- | ----------------------------------------------- | ------------------------------------------------------- |
| System prompt          | General principles, posture, durable policy     | "How should I approach this in general?"                |
| Tool description       | That tool's mechanics, when/when-not to call it | "How do I use this specific tool?"                      |
| Tool result text       | Moment-specific nudges (see below)              | "What should I do right now, given what just happened?" |
| Subagent output format | What the parent gets to act on                  | "What structured result should I hand back?"            |

Tool result text is the **most underused, highest-signal** surface — it's read at the exact moment the model decides its next action. When system-prompt guidance isn't landing, the first question is: "is there a tool result that fires at the right moment where a nudge would be more effective?"

---

## Tool design

What the model can do. The through-line: **everything the agent sees through a tool is prompt** — name, description, parameters, results, errors. Engineer it like prompt text, because it is.

### Few thoughtful tools, not API wrappers

- Build a few tools targeting whole **workflows**, consolidating multiple operations behind one call — `schedule_event` instead of `list_users` + `list_events` + `create_event`. More tools don't yield better outcomes, and ambiguous overlap between tools actively hurts selection.
- The test: **if a human engineer can't say which tool applies in a situation, the model can't either.** Keep the active set small and the boundaries clean; namespace related tools by service/resource (`calendar_search`, `calendar_create`) when there are many.

### Descriptions surface the implicit

- Write the description **as if onboarding a new teammate.** Make explicit what the model cannot discover on its own: query formats, niche terminology, how resources relate, lifecycle facts.
- **Unambiguous parameter names** (`user_id`, not `user`). **Strict, typed schemas**; use **enums to teach usage patterns** — a `mode: steer | follow_up` parameter teaches the two patterns through the schema itself, no prose rule needed.
- _What_ the tool is belongs in the description; _when_ to call it (and when not to, among overlapping tools) belongs in the system prompt.

### Return meaningful context

- Prefer **semantic, human-legible fields** over opaque identifiers — `name`, `file_type`, not `uuid`, `mime_type`. Semantic content informs the model's next action; opaque IDs don't, and resolving IDs to names measurably reduces hallucination.
- **Be token-efficient.** Pagination, filtering, truncation, sensible defaults. Return what the model needs to act on, not everything the backend has. Route bulky data the model needn't read around the model, not through it.
- **Progressive disclosure.** Offer a verbosity control (`concise | detailed`), or return identifiers and load full bodies on demand — so the result surface stays focused.
- **No universal best format.** JSON, XML, or Markdown — pick per task and verify by trying it.

### Errors prescribe the recovery path

An error result is a steering opportunity, not a stack trace. **Name the failure layer, say what it implies, and prescribe the next action**, so the agent doesn't improvise recovery:

> The {service} call failed at the infrastructure layer ({detail}); your input was never processed, so this is not a content problem. Retry the identical call once; if it fails again, stop and report to the user rather than continuing.

Validation errors should communicate the **specific fix** ("expected `role` to be `implementer` or `reviewer`"), never opaque codes. And the error must reach the _model_ (in the result it reads), or it can't self-correct and will retry the same mistake blindly.

### Results nudge the next step (mini-context)

The highest-leverage tool-design pattern. When a result changes what the agent should do next, **the result text says so explicitly, with the reason** — a "mini-context" that steers the model down the intended path at exactly the moment it matters:

> The user is away, so your question is queued and the run is pausing. End your turn with a one-line status — anything you do past this point happens without the answer you just asked for. The run resumes when they reply.

Two specialized variants:

- **Warn-once-then-allow** — for an action that's _usually but not always_ wrong. The first attempt returns a steering error naming the why and the alternatives; an identical repeat call passes. Judgment keeps the override; the harness just makes it deliberate. Prefer this over a hard block whenever the rule has legitimate exceptions — a hard block tries to replace judgment with a mechanism.
- **Reactive state-triggered nudge** — fire _once at a threshold_ (not on every call), on the existing result surface, and give the _reason_ the threshold matters, not just a count. (This is how a harness "system reminder" works.)

### Tool design is eval-driven

Tool ergonomics can't be fully predicted up front because agents are non-deterministic. Iterate: prototype, run **realistic multi-call scenarios**, read the transcripts — _what the agent omits or fumbles is as informative as what it does_ — then refine. Small description changes can shift behavior a lot, so don't bikeshed naming or response format in the abstract; decide it with an eval.

---

## Common defects (the improvement lens)

When improving an existing prompt or tool, scan for these. Each maps to a principle above; the fix is in parentheses.

- **Developer-facing framing** — explains how the system works rather than what to do. (Cut, or rewrite as an action.)
- **Assumed conversational context** — the artifact opens mid-stream: specifics, options, or sub-rules without first naming what the thing _is_ and the system it belongs to, because the author held that in-session and a cold reader won't. The inverse of developer-facing framing — too little identity, not too much mechanism. (Add a one- or two-line "what this is" anchor up front, then go specific.)
- **Mechanism narration** — "this works by…", "the system will…", "the result arrives as…". (Replace with the action and its trigger.)
- **Familiar-term leak** — an internal name, product concept, or domain term that's load-bearing in your head but inert to the model; it slips past the developer-facing scan because it's neither _mechanism_ nor _missing identity_ — it's over-supplied vocabulary, a third axis. The recognition rule can't catch it (your own jargon never feels like jargon). (Run the familiar-term test: does it help the model act, or only signal to you? Replace with the plain thing it stands for.)
- **Generic directives** — "be helpful," "stay responsive." (Replace with trigger + action + skip, or cut.)
- **Negation as the main lever** — a pile of "do not" rules. (Reframe as the positive path; keep "never" only for hard safety.)
- **Aggressive emphasis** — CRITICAL/MUST/ALL-CAPS not backed by an observed failure. (Normalize to a plain imperative.)
- **Defensive over-prompting** — rules guarding against problems never actually seen. (Cut; add rules when a failure recurs, not preemptively.)
- **Buried instructions** — a load-bearing instruction in the middle of long content. (Move it to the end, or repeat it there.)
- **Context bloat / pre-loading everything** — stuffing all possibly-relevant material into the window up front. (Hold references and load just-in-time; keep the prefix small and stable.)
- **Everything in the system prompt** — moment-specific behavior crammed into the always-on prompt. (Move it to a tool-result nudge that fires at the moment.)
- **Duplication across surfaces** — the same rule in the system prompt, a tool description, and a result. (One source of truth.)
- **Opaque tool returns and errors** — UUIDs, raw blobs, stack traces, bare error codes. (Semantic fields; recovery-prescribing errors.)

---

## Before → after

Four worked examples of improving something that already exists — one per pillar, plus an error. Each "why" maps back to a principle above; the point is the _move_, not the specific wording.

### 1. A behavioral instruction block (prompt)

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

### 2. A bloated window (context)

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
- Cut the duplicated "follow the style guide" line — _one source of truth_.

### 3. A tool, end to end (tool)

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

### 4. An error result (tool)

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
