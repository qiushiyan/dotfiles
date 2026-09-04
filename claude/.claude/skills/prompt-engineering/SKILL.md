---
name: prompt-engineering
description: The one rulebook for model-facing text — prompts, skill and agent bodies, CLAUDE.md, snippets, tool descriptions and results, and the context window. Use when writing or revising any of them. Skill frontmatter and invocation are writing-for-agents' SKILL-MECHANICS.md.
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
creative violation; leave the method to the model, and write steps only
where order genuinely matters. A surface improved this way usually comes
out shorter — by keeping what changes the reader's next action and leaving
out the rest, never by compressing sentences into fragments, arrow chains,
or labels.

## The bar — rules that hold on every surface

- **Cold reader.** The artifact is read standalone by a model with none of
  your conversation. Anchor what the thing is and the system it belongs to
  in the first lines, then go specific. Your authoring context skews you
  both ways: you under-supply the basics because they are obvious to you,
  and you over-supply your own vocabulary. Run the **familiar-term test** on
  every internal name and product concept — does it help the model act, or
  is it here because you know what it means? A term that fails is replaced
  by the field's own word, or plain language when the field has none. The
  domain's standard terms stay: they are what the user says.
- **Give the reason.** The model performs better when it knows what the
  request is for and who it serves. "I'm working on X for Y; they need Z;
  with that in mind: the request" beats the request alone, and a rule with
  its why is applied to cases the rule never named.
- **Solve it in code first.** An instruction is a probabilistic lever paid
  for every turn; a mechanism executes every time and costs the window
  nothing. Before writing or strengthening a rule: **eliminate** the
  possibility (a hook, a schema, a formatter on save); failing that,
  **inform** — compute what the system already knows and place it at the
  decision point; only then **instruct**. Prose is for judgment. The
  boundary cuts both ways: hard-blocking a genuine judgment call is the
  same mistake inverted.
- **One home per behaviour.** Give each rule one authoritative place and
  echo it only on purpose, naming which home the echo serves — copies that
  accrete by accident drift apart and over-trigger. The environment is a
  home too: a `--help`, a config file, a directory listing; a document that
  restates it is a cache that goes stale, so cache only what the model
  cannot find by looking — the unwritten convention, the reason behind a
  choice, the trap no config confesses. When a prompt is assembled from
  modes or flags, branch in the composer, never in the prose: the model
  reads one world and cannot tell other modes exist.
- **Positive path; trigger, action, skip.** Say what to do. Negation
  drags the forbidden behaviour into context and half-reads as a
  suggestion; keep `never` for hard safety boundaries. A behavioural rule
  carries when it fires, what it does, and when not to — the skip
  condition is what stops over-triggering, and a mandated output section
  carries its skip ("if none, say none") so nothing gets invented to fill
  it.
- **Earned emphasis.** `CRITICAL`, `MUST`, all-caps, and "exactly once"
  make modern models over-trigger. Write plain imperatives; reserve strong
  language for a hard constraint behind an observed failure you can cite.
- **Shown beats said.** A model imitates what it is shown more strongly
  than it follows what it is told, so every example is an instruction and
  an unvetted one is an instruction you never meant. Wrap examples in
  `<example>` tags, hold them to the standard you want reproduced, and
  vet them first when output ignores a rule. Reasoning models need few or
  no examples for judgment; reach for one where rules are not landing or
  the output is style-bound, and add an avoid-case only where the model
  would otherwise reproduce the default you are displacing. What retrieval
  returns is an example too.
- **Prove what you prescribe.** A success line or an error may assert only
  what its layer observed — "accepted", "written", never "all inputs
  validated" from a layer that cannot see validation. An overclaim licenses
  the model to skip verification it still needs or to retry an operation
  that half-completed. A **truth claim** is any line asserting what a
  mechanism does — a command's behaviour, a path, a result's wording; pin
  it with a test that asserts the text says exactly that and no more.
- **Right altitude.** Encode the expert's strategy as strong heuristics,
  not a decision tree. Let the model reason: a clear goal, strong
  constraints, an explicit output contract, then room to work. Ask for
  conclusions with their evidence; a written intermediate the workflow
  needs — a blind read before the reveal, a plan before the build — is
  output and fine to ask for, while "show your thinking" or "reproduce
  your reasoning" is a refusal class on current models. Never ask for the
  latter.
- **Completion criteria.** End every step, and every body of rules, on a
  condition the model can tell done from not-done by — "every modified
  model accounted for", not "understanding reached". Clarity resists
  premature completion; demand drives the legwork.
- **Re-ground the human** (the Fable guide's rule, echoed here because
  every closing surface needs it). A final message, a packet, a report is
  the reader's first look at work they did not watch. Lead with the
  outcome, then the one or two things you need from them, each explained
  as if new; leave behind the vocabulary built while working. Before
  reporting progress, audit each claim against a tool result from the
  session and say plainly what is verified and what is not.
- **Pause only where the work needs the user.** A destructive or
  irreversible action, a real scope change, or input only they hold. When
  the user is describing a problem or thinking aloud, the deliverable is
  the assessment. Otherwise act, and end the turn only when the work is
  complete or blocked.
- **No-ops and sediment.** An instruction the model already obeys by
  default pays load to say nothing; delete the sentence rather than trim
  it. Stale layers settle because adding feels safe and removing feels
  risky — check every line for relevance to what the document does today.

## What differs by surface

**Instructions — a prompt, a skill body, a doc.** A skill or doc opens on
what it is and the system it serves, then its rules, then the output
contract; a prompt that carries data puts the data before the instructions
and the question last, since attention is strongest at the edges of context
and weakest in the middle. Delimit content types so data is never mistaken
for instruction. State the output contract: format, length, what done looks
like. A role line sets voice and audience, not competence. Sort every piece
as a **step** (an ordered action) or **reference** (consulted on demand):
inline what every run needs, push what only some runs reach behind a
pointer, and keep a concept's definition, rules, and caveats under one
heading. Every document spends one of two budgets — **context load** when
it is always in the window, **cognitive load** on the human who must
remember it exists — so a **context pointer** (a skill description, a line
in `CLAUDE.md` naming a doc) is front-loaded on its trigger word, carries
one trigger per genuinely distinct branch, and stops there. Repeat a
**leading word** — a compact concept the model already holds (*lesson*,
*tight*, *red*) — as a token, never as a sentence, so it anchors the
behaviour cheaply; a coined word buys no prior. Split a document only when
the cut earns it: by sequence when later steps tempt the model to rush the
current one, and only across a real context boundary.

**Context — what the model holds this turn.** The window is a finite budget
and quality degrades as it fills, well before the advertised limit; the
most common agent failure is the right information missing or buried, not
clumsy wording. Hold lightweight references — paths, ids, queries — and
load full content just in time; disclose in tiers, an index first and the
detail when the task matches. Keep the prefix stable so the cache hits the
static portion, and let per-request content ride at the end. For work that
outlives a window, keep state in durable artifacts outside it and tell the
agent its context is managed, so it does not wrap up early to save budget.

**Tools — what the model acts through.** Everything the agent sees through
a tool is prompt: name, parameters, description, result, error. Build a
few tools around whole workflows rather than wrapping an API; if an
engineer cannot say which tool applies, the model cannot either. The
description onboards a new teammate — query formats, terminology, how
resources relate — and *when* to call it lives in the system prompt.
Unambiguous parameter names; enums that teach the usage patterns through
the schema. Return semantic, human-legible fields over opaque ids, meet the
model's vocabulary in retrieval, and route bulky data the model need not
read around it. An error names the failure layer, says what it implies, and
prescribes the next action — written against the condition that fires it,
prescribing only what that path can prove, with the reason line and never
the dump. The result surface is read at the exact moment the model decides
its next action, so when a result changes what should happen next it says
so with the reason; an action that is usually but not always wrong gets
warn-once-then-allow rather than a hard block; a threshold nudge fires
once, with why the threshold matters. Tool ergonomics are settled by
running realistic multi-call scenarios and reading what the agent fumbles.

## The revision pass

The standing pass over the model-facing surfaces a session touched, run
before shipping. In order:

1. **Inventory by reader.** Tag every touched surface: the model acting, a
   model grading output against a rubric, or a human. Human-facing text is
   ordinary writing and stays out. Mark templates — a hedge that covers
   many instances is load-bearing, and "fixing" it into one instance's
   specifics breaks the others — and text quoted from a vendor guide,
   which is kept as tested rather than restyled.
2. **Sweep for stale text.** Diff the touched surfaces. Grep the repo for
   every name the diff removed or renamed and for every file that points
   at a touched surface; read each hit for text describing the old
   behaviour. After a behaviour change that is where the highest-yield
   defect usually is, not in the text you were pointed at.
3. **Cut before you add.** Remove plumbing and mechanism narration ("this
   works by…"), incident narration (the ticket, the session, the user who
   hit it — the model needs the general reason), procedure the model would
   derive from the goal, no-ops, accidental duplicates, generic directives,
   rules guarding failures never seen, and unearned emphasis. Then
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
4. **Then the defect lens** on what remains — each bar rule seen from its
   failure side, named so a finding is checkable: *assumed conversational
   context* (opens mid-stream — add the identity anchor); *familiar-term
   leak* (replace with the field's term); *negation as the lever* (reframe
   to the positive path); *rule–example conflict* (shown beats said — fix
   the example first); *conflicting rules with no precedence* (state the
   rule once with its exception folded in); *config-conditional prose*
   (branch in the composer); *unearned certainty* (assert what this layer
   observed); *volatile facts in a durable prompt* (derive at render time
   or point at a source); *buried instruction* (move to the end, or repeat
   it there on purpose); *opaque returns and errors* (semantic fields,
   prescriptive recovery).
5. **Verify and record.** Check each truth claim against its source now.
   Where the surface already has a harness, pin the claim with a test;
   where none exists, say in the commit what you verified and how. Read
   every touched file once more as one whole, cold. Name the deliberate
   keeps — a sanctioned echo, a load-bearing hedge, an earned `never` —
   with their reasons, so the next pass does not undo them.

Done when a cold reader would know from the first lines what each surface
is and what to do, every keep carries its reason, every truth claim was
verified or pinned, and the surface is usually shorter than before —
longer only where a named gap was filled.

## Pointers

- A skill's frontmatter: `disable-model-invocation` and the description's
  two shapes are `../writing-for-agents/SKILL-MECHANICS.md`, with router
  skills; `argument-hint` names the argument shape in one bracketed line;
  `allowed-tools` is left out (why: the usage lessons below). The house
  shape of a skill in this repo, `skillOverrides`, and the install recipe:
  `docs/agent-skills.md` in the dotfiles repo — read one sibling skill
  before writing a new one.
- Tools whose instructions are shaped by usage history — what to teach,
  what to move into the engine, cold readers:
  `~/.config/lessons/agent-tooling/usage-lessons.md`.
- Model-specific behaviours of the current Claude generation — long turns,
  effort, refusal classes, memory scaffolding:
  `/Users/qiushi/dotfiles/references/fable-prompting-guide.md`.
- A project's own prompting guide, when its `CLAUDE.md` names one (planlab:
  `docs/loopy/prompting-guide.md`), answers the calibrations for that
  repo: which terms pass the familiar-term test there, which emphasis is
  earned, where its surfaces live. General lessons graduate up into this
  file; the house layer keeps the instance and its evidence.
