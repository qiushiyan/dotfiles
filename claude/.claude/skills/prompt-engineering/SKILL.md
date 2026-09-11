---
name: prompt-engineering
description: The one rulebook for model-facing text — prompts, skill and agent bodies, CLAUDE.md, snippets, tool descriptions and results, and the context window. Use when writing or revising any of them. Skill frontmatter and invocation are writing-for-agents' SKILL-MECHANICS.md.
requires:
  - user:writing-for-agents/SKILL-MECHANICS.md
  - lessons:agent-tooling/usage-lessons.md
---

# Writing for the model

The rulebook for anything a model reads: a system prompt, a skill or agent
body, a `CLAUDE.md`, a snippet, a tool's description, result, or error, and
the shape of the window they land in. Read it before writing one, or as the
revision pass over the surfaces a session touched. **The reader of every
word you write is the model**; optimize for how a model reads.

## The philosophy

A capable model does its best work from a clear description of the goal,
the constraints that bound it, and the conventions of the place — not from
a procedure for reaching it. A procedure spends attention every turn,
fights the model's own plan, and breaks on the case it did not foresee. So
name the goal and what done looks like; state each constraint with the
reason behind it, because a reason generalizes where a bare rule invites
creative violation; and leave the method to the model. A surface improved
this way usually comes out shorter — by keeping what changes the reader's
next action and leaving out the rest, never by compressing sentences into
fragments, arrow chains, or labels.

## The shape

What a cold reader needs, in the order they need it. Most instruction
surfaces settle into three layers. That is the usual result of asking what
the reader needs first, not a template: a surface may collapse to one layer
or grow one.

1. **What this is, and what done looks like.** The task, the system it
   belongs to, the reader's role, and what marks the work complete — the
   output contract, when the deliverable is a document — in the first
   lines, before any rule or fact. This is the reader's mental model; a
   capable model generalizes from intent and cannot infer it. A document
   that opens on a mechanism, a trap, or a count of things ("two producers
   feed…") has seated a lower layer in the anchor's place.
2. **What shapes the judgment.** The constraints with their reasons, and
   the expert's heuristics. Steps appear only where order or completeness
   genuinely matters — a fragile sequence, an irreversible operation, where
   one wrong order costs more than the model's judgment saves — and then
   as a numbered list, so the reader can see which part is the narrow
   bridge and which is open field. This is the one home of that rule.
3. **What the environment will not confess.** The traps, the unwritten
   convention, the thing that looks right and is wrong. A trap that belongs
   to one concept lives under that concept; the tail carries the
   cross-cutting ones, where attention is strong again.

A snippet, a tool description, or an error line is one layer; a prompt
built around large source material keeps its opening and places the
material between it and the request (under Instructions). Formatting
exists so the reader can see the layers: a header per layer or stage, a
sectioned list for parallel items and lookups (a bold label, then the
entry), a table only where the reader compares cells across rows, prose
for one argument, and no more structure than the content has — one
paragraph hides a hierarchy, a header every three sentences invents one,
and a grid of independent entries hides a list. Prompt style shapes output style, so a
surface formatted the way you want the output to look teaches by example.

<example type="avoid">
Two producers feed **#bug_reports**: `LoopyReport` rows (the row exists even when the Slack post failed) and `LoopyConversationAnalysis` rows. **Check `.source` before quoting `.problemStatement` as the user's words.** …
</example>

<example>
You are triaging a production incident of **Loopy**, planlab's multi-turn tool-use agent. A signal has arrived from one of two producers — a person pressed *report a bug* in a thread, or the judge that scores every settled run flagged one — and you hold an id from either. The job is to say what happened and why, with receipts, and to leave one working dossier per root cause that the verify skill can reproduce from; it stops there.
</example>

The first opens on a mechanism, then a trap; the second names the task, the
system, the input, and done, and the two producers become a fact inside it.

## The bar — rules that hold on every surface

### Who reads it

- **Cold reader.** The artifact is read standalone by a model with none of
  your conversation. Authoring skews you both ways: you under-supply the
  basics because they are obvious to you, and over-supply your own
  vocabulary. Run the **familiar-term test** on every internal name — does
  it help the model act, or is it here because you know what it means? A
  failing term becomes the field's own word, or plain language; the
  domain's standard terms stay, since they are what the user says.
- **Give the reason.** The model performs better when it knows what the
  request is for and who it serves. "I'm working on X for Y; they need Z;
  with that in mind: the request" beats the request alone, and a rule with
  its why is applied to cases the rule never named.
- **Right altitude.** Encode the expert's strategy as strong heuristics,
  not a decision tree, and leave room to work; an exact sequence belongs
  only to the narrow bridge named in the shape. Ask for conclusions with
  their evidence. A written intermediate the workflow needs — a plan
  before the build — is output and fine to ask for; "show your thinking"
  can trigger a reasoning-extraction refusal on the Fable generation.
- **Completion criteria.** End every step, and every set of instructions
  the reader executes, on a condition the model can tell done from
  not-done by — "every modified model accounted for", not "understanding
  reached". Clarity resists premature completion; demand drives the legwork.

### What it says

- **Positive path; trigger, action, skip.** Say what to do. Negation drags
  the forbidden behaviour into context and half-reads as a suggestion; keep
  `never` for hard safety boundaries. A behavioural rule carries when it
  fires, what it does, and when not to — the skip condition is what stops
  over-triggering, and a mandated output section carries its skip ("if
  none, say none") so nothing gets invented to fill it.
- **Earned emphasis.** `CRITICAL`, `MUST`, all-caps, and "exactly once"
  make modern models over-trigger. Write plain imperatives; reserve strong
  language for a hard constraint behind an observed failure you can cite.
- **One home per behaviour.** Give each rule one authoritative place and
  echo it only on purpose, naming the home the echo serves — accidental
  copies drift apart and over-trigger. The environment is a home too: a
  `--help`, a config file, a listing; a document that restates it is a
  cache that goes stale, so cache only what the model cannot find by
  looking. When a prompt is assembled from modes or flags, branch in the
  composer, never in the prose: the model reads one world.
- **Shown beats said.** A model imitates what it is shown more strongly
  than it follows what it is told, so every example is an instruction and
  an unvetted one is an instruction you never meant. Wrap examples in
  `<example>` tags, hold them to the standard you want reproduced, and vet
  them first when output ignores a rule. Reasoning models need few for
  judgment: reach for one where rules are not landing or the output is
  style-bound, and add an avoid-case only where the model would otherwise
  reproduce the default you are displacing. What retrieval returns is an
  example too.
- **No-ops and sediment.** An instruction the model already obeys by
  default pays load to say nothing; delete the sentence rather than trim
  it. Whether a line is a no-op is model-relative and settled by running
  the document — a cold reader, or the surface's own tests — never by
  intuition: a terse line that looks redundant may be the one holding a
  behaviour. Layers settle because adding feels safe and removing feels
  risky; check every line against what the document does today.

### What it proves

- **Solve it in code first.** An instruction is a probabilistic lever paid
  for every turn; a mechanism executes every time and costs the window
  nothing. Before writing or strengthening a rule: **eliminate** the
  possibility (a hook, a schema, a formatter on save); failing that,
  **inform** — place what the system already knows at the decision point;
  only then **instruct**. Prose is for judgment, and hard-blocking a
  genuine judgment call is the same mistake inverted.
- **Prove what you prescribe.** A success line or an error asserts only
  what its layer observed — "accepted", "written", never "all inputs
  validated" from a layer that cannot see validation; an overclaim
  licenses the model to skip verification it still needs or retry an
  operation that half-completed. A **truth claim** is any line asserting
  what a mechanism does — a command's behaviour, a path, a result's
  wording. Verify each at its source, and where the surface has a harness
  pin the load-bearing ones with a test, since an unpinned truth drifts
  back.

## What differs by surface

### Instructions — a prompt, a skill body, a doc

- A prompt built around large source material — documents, transcripts,
  data running to thousands of tokens — opens on the task, places the
  material next, and puts the question last: attention is strongest at the
  edges of context and weakest in the middle. Delimit content types so data
  is never mistaken for instruction.
- A role line sets voice and audience, not competence.
- Inline what every run needs, push what only some runs reach behind a
  pointer one level deep, and keep a concept's definition, rules, and
  caveats under one heading.
- Every document spends **context load** if always in the window or
  **cognitive load** on the human who must remember it exists, so a
  **context pointer** (a skill description, a `CLAUDE.md` line naming a
  doc) is front-loaded on its trigger word, carries one trigger per
  genuinely distinct branch, and stops there.
- Repeat a **leading word** — a compact concept the model already holds
  (*lesson*, *tight*, *red*) — as a token, never a sentence; a coined word
  buys no prior.
- Split a document only when the cut earns it: by sequence when later
  steps tempt the model to rush the current one, and only across a real
  context boundary.

Two policies belong in any instruction for an agent that acts or reports
across turns, and nowhere else (both are from the Fable prompting guide
under Pointers, echoed here because every such instruction needs them).
**Re-ground the human:** a final message, a packet, a report is the
reader's first look at work they did not watch — lead with the outcome,
then the one or two things you need from them, each explained as if new,
leaving behind the vocabulary built while working; before reporting
progress, audit each claim against a tool result from the session and say
plainly what is verified and what is not. **Pause only where the work
needs the user:** a destructive or irreversible action, a real scope
change, or input only they hold; when the user is describing a problem or
thinking aloud, the deliverable is the assessment; otherwise act, and end
the turn only when the work is complete or blocked.

### Context — what the model holds this turn

- The window is a finite budget and quality degrades as it fills, well
  before the advertised limit; the most common agent failure is the right
  information missing or buried, not clumsy wording.
- Hold lightweight references — paths, ids, queries — and load full
  content just in time; disclose in tiers, an index first and the detail
  when the task matches.
- Keep the prefix stable so the cache hits the static portion, and let
  per-request content ride at the end.
- For work that outlives a window, keep state in durable artifacts outside
  it and tell the agent its context is managed, so it does not wrap up
  early to save budget.

### Tools — what the model acts through

- Everything the agent sees through a tool is prompt: name, parameters,
  description, result, error. Build a few tools around whole workflows
  rather than wrapping an API; if an engineer cannot say which tool
  applies, the model cannot either.
- The description onboards a new teammate — query formats, terminology,
  how resources relate — and *when* to call it lives in the system prompt.
  Unambiguous parameter names; enums that teach usage through the schema.
- Return semantic, human-legible fields over opaque ids, meet the model's
  vocabulary in retrieval, and route bulky data the model need not read
  around it.
- An error names the failure layer, what it implies, and the next action
  — written against the condition that fires it, prescribing only what
  that path can prove, with the reason line and never the dump.
- A result is read at the moment the model decides its next action: when
  it changes what should happen next it says so with the reason; an action
  usually but not always wrong gets warn-once-then-allow, not a hard
  block; a threshold nudge fires once, with why the threshold matters.
- Ergonomics are settled by running realistic multi-call scenarios and
  reading what the agent fumbles.

## The revision pass

The standing pass over the model-facing surfaces a session touched — or,
when pointed at files, every line of them — run before shipping. In order:

1. **Inventory by reader.** Tag every touched surface: the model acting, a
   model grading against a rubric, or a human. Human-facing text is
   ordinary writing and stays out. Test task instructions with a concrete
   input already in the executor's hands: what next action or judgment
   does each sentence change? Translate requests to the artifact's author
   into the executing reader's goal or constraints. Mark templates — a hedge
   covering many instances is load-bearing, and "fixing" it to one instance breaks the
   others — and text quoted from a vendor guide, kept as tested rather
   than restyled.
2. **Sweep for stale text.** Diff the touched surfaces. Grep the repo for
   every name the diff removed or renamed and for every file that points
   at a touched surface; read each hit for text describing the old
   behaviour. After a behaviour change that is where the highest-yield
   defect usually is, not in the text you were pointed at.
3. **Cut before you add.** Remove plumbing and mechanism narration ("this
   works by…"), incident narration (the ticket, the session, the user who
   hit it — the model needs the general reason), procedure the model would
   derive from the goal, verification and re-check scaffolding the current
   model performs unprompted, accidental duplicates, generic directives,
   rules guarding failures never seen, unearned emphasis, and no-ops — a
   doubtful no-op is marked, and step 5's cold read settles it. Then
   **transform** rather than cut where a fact is wearing a plumbing
   costume:

   <example type="avoid">
   The way this works: each worker runs in its own background session spawned over RPC, and results arrive as follow-up messages on the event bus, so don't block waiting on them. (A worker turn can take several minutes.)
   </example>

   <example>
   A worker turn takes several minutes, so send one complete, well-formed request rather than a stream of small ones, and keep making progress elsewhere while it runs.
   </example>

   The RPC and the event bus were plumbing and went; "several minutes" was
   a fact the model acts on and became the instruction, which also gave
   "don't block" its positive form.
4. **Then the defect lens** on what remains — each rule seen from its
   failure side, named so a finding is checkable; the remedy is the bar
   rule behind it:
   - *hook before anchor* — opens on a mechanism, a trap, or a count of
     things, or has no first layer at all;
   - *flat hierarchy* — layers rendered as one paragraph, or bullets that
     run to paragraphs;
   - *a lookup rendered as a grid* — a table whose rows are independent
     entries the reader looks up one at a time; a sectioned list reads
     whole in source;
   - *stale cache* — restates a `--help`, a config, a listing;
   - *familiar-term leak* — an internal name where the field has a word;
   - *negation as the lever* — the rule is carried by what not to do;
   - *rule–example conflict* — the example wins, so fix it first;
   - *conflicting rules with no precedence* — state the rule once with
     its exception folded in;
   - *config-conditional prose* — a mode or flag branched in the text;
   - *unearned certainty* — a claim its layer could not observe;
   - *volatile facts in a durable prompt* — derive at render time or
     point at a source;
   - *buried instruction* — move it to the end, or repeat it there on
     purpose;
   - *opaque returns and errors* — ids without meaning, failures without
     a next action.
5. **Verify and record.** Check each truth claim against its source now;
   pin it with a test where a harness exists, otherwise say in the commit
   what you verified and how. Read every touched file once more as one
   whole, cold — a cold reader with a concrete scenario where a no-op or a
   route is in doubt. Name the deliberate keeps — a sanctioned echo, a
   load-bearing hedge, an earned `never` — with their reasons, so the next
   pass does not undo them.

Done when a cold reader would know from the first lines what each surface
is and what to do, the layers are visible on the page, every keep carries
its reason, every truth claim was verified or pinned, and the surface is
usually shorter than before — longer only where a named gap was filled.

## Pointers

- Frontmatter lives in `../writing-for-agents/SKILL-MECHANICS.md`
  (`disable-model-invocation`, the description's two shapes, router
  skills), with two house exceptions: `argument-hint` names the argument
  shape in one bracketed line, and `allowed-tools` is left out (why: the
  usage lessons below). House shape, `skillOverrides`, and the install
  recipe: `docs/agent-skills.md` in the dotfiles repo — read one sibling
  skill for its frontmatter and header order, not its method.
- Tools whose instructions are shaped by usage history — what to teach,
  what to move into the engine, cold readers:
  `~/.config/lessons/agent-tooling/usage-lessons.md`.
- The Fable prompting guide — behaviours of the current Claude generation:
  long turns, effort, refusal classes, memory, and which instructions a
  prior model needed that this one performs unprompted:
  `~/dotfiles/references/fable-prompting-guide.md`.
- A project's own prompting guide, when its `CLAUDE.md` names one (planlab:
  `docs/loopy/prompting-guide.md`), answers that repo's calibrations: which
  terms pass the familiar-term test there, which emphasis is earned, where
  its surfaces live. General lessons graduate up into this file; the house
  layer keeps the instance and its evidence.
