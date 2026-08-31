# Research — goal-driven prompting vs. procedural instruction (Claude 5 generation)

2026-09-01. Question: did Anthropic really say they cut ~80% of their own system
prompt for the Claude 5 generation, what do first-party prompting docs say about
goals/constraints vs. step-scripting, and what would that mean for SPEC-BAR's
"outcome rubric" escalation (EVIDENCE.md, goal-review section)? Primary sources
only; each section separates *what the source says* from *what we infer*.

## 1. The ~80% claim — verified in a primary source

**What the source says.** The claim is real and first-party, but it is about
**Claude Code's** system prompt, not claude.ai's, and it does not appear in the
model announcement. The announcement
(<https://www.anthropic.com/news/claude-fable-5-mythos-5>, 2026-06-09) covers
capabilities, safety classifiers, pricing — no prompting guidance at all.

The primary source is Anthropic's own blog: Thariq Shihipar (Member of Technical
Staff, Claude Code team), *"The new rules of context engineering for Claude 5
generation models"*, 2026-07-24,
<https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models>:

> "We removed over 80% of Claude Code's system prompt for models like Claude
> Opus 5 and Claude Fable 5 with no measurable loss on our coding evaluations."

Its shifts, verbatim headings: *give Claude rules → let Claude use judgement*
(the "no comments" rule became "write code that reads like the surrounding
code: match its comment density, naming, and idiom"); *give Claude examples →
design interfaces* ("giving examples actually constrains them to a certain
exploration space"); *put it all upfront → use progressive disclosure*; simple
tool descriptions; auto-memory over CLAUDE.md. CLAUDE.md advice: keep it
"lightweight," spend tokens on repo-specific gotchas. Author announced it as
"what we've learned about writing system prompts, skills and Claude.MDs"
(<https://x.com/trq212/status/2080710971228918066>).

**What we infer.** The ~80% figure is citable, with two caveats: it is scoped to
Claude Code's prompt and its evidence is "no measurable loss on coding evals" —
a *safe-to-delete* result, not a *deletion-improves-output* result. The blog is
on claude.com, not the docs site, so it is positioning + field notes, while the
platform docs below are the maintained guidance.

## 2. First-party prompting docs — goals over scripts

**Anthropic**, *Prompting best practices*
(<https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices>):

> "**Prefer general instructions over prescriptive steps.** A prompt like
> 'think thoroughly' often produces better reasoning than a hand-written
> step-by-step plan. Claude's reasoning frequently exceeds what a human would
> prescribe."

Also: self-check instructions carried over from older prompts "can cause
over-verification" on Opus 5 — "remove these instructions rather than rewriting
them"; and "dial back" anti-laziness prompting when migrating. But the same page
still opens with the *opposite-direction* baseline: "Provide instructions as
sequential steps using numbered lists or bullet points when the order or
completeness of steps matters," and "Be specific about the desired output
format and constraints."

*Prompting Claude Fable 5*
(<https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5>):
"you can steer most behaviors with a brief instruction rather than enumerating
each behavior by name"; "Skills developed for prior models are often too
prescriptive for Claude Fable 5 and can degrade output quality"; "Give the
reason, not only the request." Note what the page does *not* drop: it supplies
paragraph-length instruction blocks for boundaries, verification ("audit each
claim against a tool result"), scope, and communication style.

**OpenAI**, *Reasoning best practices*
(<https://developers.openai.com/api/docs/guides/reasoning-best-practices>):
"prompting them to 'think step by step' … is unnecessary"; "give very specific
parameters for a successful response, and encourage the model to keep reasoning
and iterating until it matches your success criteria." **Google**, *Prompting
strategies* (<https://ai.google.dev/gemini-api/docs/prompting-strategies>):
"it's generally not necessary to have the model outline, plan, or detail
reasoning steps." All three vendors converge.

**What we infer.** The doctrine is narrower than "delete structure": what dies
is scripting the model's *reasoning procedure* and enumerating behaviors it
already has. What survives, in every one of these documents, is stating goals,
success criteria, constraints, and boundaries — often at length. OpenAI's
version even names the rubric shape: parameters for a successful response.

## 3. Implications for write-spec / SPEC-BAR

The escalation on record (EVIDENCE.md, 2026-08-31 goal review): rebuild SPEC-BAR
"as an outcome rubric instead of a document anatomy … revisit only if specs come
back formally complete but over-sectioned."

**Sketch of the outcome-rubric variant** (grounded in §2's pattern — success
criteria, not procedure): replace the tiered anatomy (summary → product →
technical → target shape) with what a done spec must have *decided*, letting the
model choose the document's form:

- **Goals** — the product outcome, the boundary after landing, non-goals with
  one-line whys; legible to a reader with no session context.
- **Decisions** — the interface/structure/wiring choices actually made (no
  vague-direction verbs), each chosen over a named alternative for a stated
  reason (design-it-twice survives as a criterion, not a procedure).
- **Constraints** — scope (one PR/one session), what's left to the build, what
  the spec may not pin (estimates, per-call-site mechanics).
- **Verification** — which behaviors must be tested through which interfaces,
  and the named-or-killed status of every rabbit hole.

The reading list, Emphasis, and Scope survive unchanged — they are already
constraints, not steps. The deletion candidates are the section inventory and
the three-view target-shape template (offerable as an example, per the blog's
examples-constrain finding).

**Evidence that would justify switching** — the escalation's own trigger plus
§1's method: specs coming back formally complete but over-sectioned (Emphasis
weighting ignored); riders like "skip the summary tier" recurring the way F1's
preamble did; or an A/B on real spec sessions showing no satisfaction loss —
Anthropic cut 80% only after evals showed no regression, not on doctrine.

**Risks.** (a) SPEC-BAR is not a reasoning script — it specifies an *artifact*
read by 3–7 later sessions; the anatomy is a stable interface for readers, which
"design interfaces, not examples" arguably supports keeping. (b) 33 sessions /
29 with measured satisfaction back the current formula; the rubric variant has
zero. (c) The goal review itself said "the anatomy is the user's measured
formula" and gated the change on a signal not yet observed. Verdict: hold until
the trigger fires; if it does, migrate by deletion-with-evals, not rewrite.
