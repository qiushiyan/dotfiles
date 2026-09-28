---
name: prompt-engineering
description: The one rulebook for model-facing text — prompts, skill and agent bodies, CLAUDE.md, snippets, tool descriptions and results, and the context window. Use when writing or revising any of them. Skill frontmatter and invocation are writing-for-agents' SKILL-MECHANICS.md.
requires:
  - user:writing-for-agents/SKILL-MECHANICS.md
  - lessons:agent-tooling/usage-lessons.md
---

# Writing for the model

The rulebook for anything a model reads: a system prompt, a skill or agent
body, a `CLAUDE.md`, a snippet, a tool's description, result, or error, a
judge's question, and the shape of the window they land in. Read it
before writing one, or as the revision pass over the surfaces a session
touched. **The reader of every word you write is the model**; optimize for
how a model reads. It follows the order of the work — what belongs in text
at all, the layers, every sentence, the surface — and the revision pass
walks the same map.

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

## Before any prose: does this belong in text?

**Solve it in code first.** An instruction is a probabilistic lever paid
for every turn; a mechanism executes every time and costs the window
nothing. Before writing or strengthening a rule: **eliminate** the
possibility (a hook, a schema, a formatter on save); failing that,
**inform** — place what the system already knows at the decision point;
only then **instruct**. Prose is for judgment, and hard-blocking a genuine
judgment call is the same mistake inverted. When the mechanism lies outside
what you were asked to write — a global hook for one skill — write the
instruction and offer the mechanism; inside a skill, a bundled script is
the in-scope form.

## Write in layers

What a cold reader needs, in the order they need it. Most instruction
surfaces settle into three layers. That is the usual result of asking what
the reader needs first, not a template: a surface may collapse to one layer
or grow one. A snippet, a tool description, or an error line is one layer
that carries what it can of the three; **Every sentence** and its surface's
section hold for it in full.

### 1. What this is, and what done looks like

The task, the situation it arrives in as the reader meets it, the reader's
role, and what marks the work complete, in the first lines, before any rule
or fact. This is the reader's mental model; a capable model generalizes
from intent and cannot infer it. A document that opens on a mechanism, a
trap, or a count of things ("two producers feed…") has seated a lower
layer in the anchor's place.

<example type="avoid">
Two producers feed **#bug_reports**: `LoopyReport` rows (the row exists even when the Slack post failed) and `LoopyConversationAnalysis` rows. **Check `.source` before quoting `.problemStatement` as the user's words.** …
</example>

<example>
You are triaging a production incident of **Loopy**, planlab's multi-turn tool-use agent. A signal has arrived from one of two producers — a person pressed *report a bug* in a thread, or the judge that scores every settled run flagged one — and you hold an id from either. The job is to say what happened and why, with receipts, and to leave one working dossier per root cause that the verify skill can reproduce from; it stops there.
</example>

The first opens on a mechanism, then a trap; the second names the task, the
situation, the input, and done, and the two producers become a fact inside
it.

- **The reader's world.** Describe the situation the reader works in, not
  the system you built around it. The reader decides from its input
  alone, so pose each task, question, and criterion as something a careful
  person holding only that input could settle, in the terms of its world.
  Where your decision needs more — what the host knows, what happens next
  — split it: the reader answers what its input shows, and code joins that
  answer with the rest. The frame may simplify or stylise the system, as
  long as the right answer under it is the right answer in fact; a reader
  that acts on the real system gets a frame that leaves things out and
  never invents them.

  <example type="avoid">
  You are the `verify-review` operation in the steward's drain, stage 4 of 7. Your reply is stored as a `turn_reply` row; when your turn ends the drain moves the task to `review.owed` unless a `hold` row exists.
  </example>

  <example>
  You are checking a web app build against its acceptance criteria before it goes to code review. The engineer who supervises this task reads your final message. Review starts as soon as your turn ends, unless you run `steward hold --reason "<why>"` to wait for them.
  </example>

  The first describes the session from the builder's seat: the
  operation's name, its place in a state machine, the table its reply
  lands in. The second gives the same facts as the session meets them —
  what it is doing, who reads what it writes, and the one lever it holds
  over what happens next.
- **Done the reader can check.** Give the surface, and every step the
  reader executes, a condition the model can tell done from not-done by —
  "every modified model accounted for", not "understanding reached".
  Clarity resists premature completion; demand drives the legwork. A
  document's done includes its output contract, and an output code parses
  gets an exact one: path, shape, allowed values.

### 2. What shapes the judgment

The constraints that bound the work and the heuristics an expert brings to
it.

- **Give the reason.** The model performs better when it knows what the
  request is for, and a rule with its why is applied to cases the rule
  never named. For a collaborator on open work, "I'm working on X for Y;
  they need Z; with that in mind: the request" beats the request alone.
  For a reader executing one job, the reason that lands is a consequence
  inside its world: "the next step starts as soon as this turn ends, so a
  choice left open is made by that step without anyone saying so."
- **Right altitude.** Encode the expert's strategy as strong heuristics,
  not a decision tree, and leave room to work. Steps appear only where
  order or completeness genuinely matters — a fragile sequence, an
  irreversible operation, where one wrong order costs more than the
  model's judgment saves — and then as a numbered list, so the reader can
  see which part is the narrow bridge and which is open field. Ask for
  conclusions with their evidence. A written intermediate the workflow
  needs — a plan before the build — is output and fine to ask for; "show
  your thinking" can trigger a reasoning-extraction refusal on the Fable
  generation.
- **Trigger, action, skip.** A behavioural rule carries when it fires,
  what it does, and when not to — the skip condition is what stops
  over-triggering, and a mandated output section carries its skip ("if
  none, say none") so nothing gets invented to fill it.
- **Earned emphasis.** `CRITICAL`, `MUST`, all-caps, and "exactly once"
  make modern models over-trigger. Write plain imperatives; reserve strong
  language for a hard boundary (**Say what to do**) or a constraint behind
  an observed failure you can cite.

### 3. What the environment will not confess

The traps, the unwritten convention, the thing that looks right and is
wrong. A trap lives under the concept it belongs to, beside that concept's
definition and rules; the tail carries the cross-cutting ones, where
attention is strong again.

### Formatting shows the layers

A header per layer or stage, a sectioned list for parallel items and
lookups (a bold label, then the entry), a table only where the reader
compares cells across rows, prose for one argument, and no more structure
than the content has — one paragraph hides a hierarchy, a header every
three sentences invents one, and a grid of independent entries hides a
list. Prompt style shapes output style, so a surface formatted the way you
want the output to look teaches by example.

## Every sentence, on any surface

These hold wherever a model reads, in a layered skill and a one-line error
alike.

- **Cold reader.** The artifact is read standalone by a model with none of
  your conversation. Authoring skews you both ways: you under-supply the
  basics because they are obvious to you, and over-supply your own
  vocabulary. Run the **familiar-term test** on every internal name — does
  it help the model act, or is it here because you know what it means? A
  failing term becomes the field's own word, or plain language; the
  domain's standard terms stay, since they are what the user says.
- **Say what to do.** Negation drags the forbidden behaviour into context
  and half-reads as a suggestion. Keep `never` for a hard boundary — an
  irreversible action, a safety line, a line the user drew — and pair it
  with what to do instead.
- **Shown beats said.** A model imitates what it is shown more strongly
  than it follows what it is told, so every example is an instruction and
  an unvetted one is an instruction you never meant. Wrap examples in
  `<example>` tags, hold them to the standard you want reproduced, and vet
  them first when output ignores a rule. Reasoning models need few for
  judgment: reach for one where rules are not landing or the output is
  style-bound, and add an avoid-case only where the model would otherwise
  reproduce the default you are displacing. What retrieval returns is an
  example too.
- **One home per behaviour.** Give each rule one authoritative place and
  echo it only on purpose, naming the home the echo serves — accidental
  copies drift apart and over-trigger. The environment is a home too: a
  `--help`, a config file, a listing; a document that restates it is a
  cache that goes stale, so cache only what the model cannot find by
  looking. When a prompt is assembled from modes or flags, branch in the
  composer, never in the prose: the model reads one world.
- **No-ops and sediment.** An instruction the model already obeys by
  default pays load to say nothing; delete the sentence rather than trim
  it. Whether a line is a no-op is model-relative and settled by running
  the document — a cold reader, or the surface's own tests — never by
  intuition: a terse line that looks redundant may be the one holding a
  behaviour. Layers settle because adding feels safe and removing feels
  risky; check every line against what the document does today.
- **Prove what you prescribe.** A success line or an error asserts only
  what its layer observed — "accepted", "written", never "all inputs
  validated" from a layer that cannot see validation; an overclaim
  licenses the model to skip verification it still needs or retry an
  operation that half-completed. A **truth claim** is any line asserting
  what a mechanism does — a command's behaviour, a path, a result's
  wording. Verify each at its source, and where the surface has a harness
  pin the load-bearing ones with a test, since an unpinned truth drifts
  back. A claim you cannot check where you are becomes a pointer to where
  the reader checks it, or ships marked unverified to the user.

## What differs by surface

### Instructions — a prompt, a skill body, a doc

- A prompt built around large source material — documents, transcripts,
  data running to thousands of tokens — opens on the task, places the
  material next, and puts the question last: attention is strongest at the
  edges of context and weakest in the middle. Delimit content types so data
  is never mistaken for instruction.
- A role line sets voice and audience, not competence.
- Inline what every run needs, and push what only some runs reach behind
  a pointer one level deep.
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

Two policies belong in any instruction for an agent that acts over many
steps or reports to someone who did not watch it work, and nowhere else
(both are from the Fable prompting guide under Pointers, echoed here
because every such instruction needs them). Carry the clauses the surface's
situation calls for, in its own terms.
**Re-ground the human:** a final message, a packet, a report is the
reader's first look at work they did not watch — lead with the outcome,
then the one or two things you need from them, each explained as if new,
leaving behind the vocabulary built while working; before reporting
progress, audit each claim against a tool result from the session and say
plainly what is verified and what is not. **Pause only where the work
needs the user:** a destructive or irreversible action, a real scope
change, or input only they hold; when the user is describing a problem or
thinking aloud, the deliverable is the assessment; otherwise act, and end
the turn only when the work is complete or blocked. Where ending the turn
waits for no one — a pipeline starts its next step — name the host's way
to pause, with the consequence under **Give the reason** as its reason.

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
- An error or a refusal names what stopped the call — the failing layer,
  or the rule and the state that failed it — what that implies, and the
  next action. It is written against the condition that fires it,
  prescribes only what that path can prove, and gives the cause in one
  line, never the log dump.
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
   judge returning a verdict, or a human. Human-facing text is ordinary
   writing and stays out. Test task instructions with a concrete input
   already in the executor's hands: what next action or judgment does each
   sentence change, and could the reader settle each question from that
   input alone? Translate requests to the artifact's author into the
   executing reader's goal or constraints. Mark templates — a hedge
   covering many instances is load-bearing, and "fixing" it to one
   instance breaks the others — and text quoted from a vendor guide, kept
   as tested rather than restyled.
2. **Sweep for stale text.** Diff the touched surfaces — pointed at files
   with no session diff, read their last commit instead. Grep the repo for
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
4. **Then the defect lens** on what remains — the failures worth a name,
   grouped as the rules are, so a finding is checkable; the remedy is the
   rule behind it, and a finding with no name here cites the rule it
   breaks:
   - **Before any prose**
     - *prose doing code's job* — a rule a hook, schema, or check could
       enforce, or a fact the system holds that the reader is told to go
       find.
   - **Layer one**
     - *hook before anchor* — opens on a mechanism, a trap, or a count of
       things, or has no first layer at all;
     - *builder's frame* — the situation or question is posed in the terms
       of the system you built, or asks what the reader's input cannot
       show;
     - *no checkable done* — steps with no done condition, or an output
       code reads with no exact contract.
   - **Layer two**
     - *bare rule* — a rule with no reason, or no skip condition.
   - **Layer three**
     - *volatile facts in a durable prompt* — derive at render time or
       point at a source.
   - **Formatting**
     - *flat hierarchy* — layers rendered as one paragraph, or bullets
       that run to paragraphs;
     - *a lookup rendered as a grid* — a table whose rows are independent
       entries the reader looks up one at a time; a sectioned list reads
       whole in source.
   - **Every sentence**
     - *familiar-term leak* — an internal name where the field has a word;
     - *negation as the lever* — the rule is carried by what not to do;
     - *rule–example conflict* — the example wins, so fix it first;
     - *stale cache* — restates a `--help`, a config, a listing;
     - *conflicting rules with no precedence* — state the rule once with
       its exception folded in;
     - *config-conditional prose* — a mode or flag branched in the text of
       an assembled prompt;
     - *unearned certainty* — a claim its layer could not observe, or one
       its source contradicts.
   - **Surfaces**
     - *buried outcome* — a report or final message that opens on process
       rather than the outcome and what the reader must decide;
     - *buried instruction* — move it to the end, or repeat it there on
       purpose;
     - *opaque returns and errors* — ids without meaning, failures without
       a next action.
5. **Verify and record.** Check each truth claim as **Prove what you
   prescribe** says, and say in the commit what you verified and how. Read every touched file once more as one
   whole, cold — a cold reader with a concrete scenario where a no-op or a
   route is in doubt. Name the deliberate keeps — a sanctioned echo, a
   load-bearing hedge, an earned `never` — with their reasons, in the
   commit or the surface's evidence log, so the next pass does not undo
   them.

Done when a cold reader would know from the first lines what each surface
is and what to do, the layers are visible on the page, every keep carries
its reason, every truth claim was verified, pinned, or marked unverified,
and the surface is usually shorter than before — longer only where a named
gap was filled.

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
- Writing a question a classifier or judge answers — a yes/no gate, a
  rubric grader, TypeSafe's Jev:
  `case-studies/classifier-judge-questions-jev-steward.md`. Case studies
  hold domain passes most sessions never need, each named here by its
  trigger.
- A project's own prompting guide, when its `CLAUDE.md` names one (planlab:
  `docs/loopy/prompting-guide.md`), answers that repo's calibrations: which
  terms pass the familiar-term test there, which emphasis is earned, where
  its surfaces live. General lessons graduate up into this file; the house
  layer keeps only what is specific to the project, as a rule with a
  pointer to the record that earned it.
