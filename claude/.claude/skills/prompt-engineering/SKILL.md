---
name: prompt-engineering
description: Rules for writing model-facing text. Use when writing or revising a prompt, a skill or its description, a CLAUDE.md, a snippet, or a tool's description or error.
requires:
  - user:writing-for-agents/SKILL-MECHANICS.md
  - lessons:agent-tooling/usage-lessons.md
---

# Writing for the model

This is the rulebook for text a model reads: a prompt, a skill, a `CLAUDE.md`,
a snippet, a tool's description, result, or error. Read it before writing one.
Two companions hold what only some text needs, so read the one that fits now:

- [AGENT-DOCS.md](AGENT-DOCS.md) for a skill and its description, a
  `CLAUDE.md` or `AGENTS.md`, or an agent that works over many steps.
- [TOOLS.md](TOOLS.md) for a tool's description, result, or error, a prompt
  around large material, or what fills the context window.

Before shipping, run [the revision pass](REVISION.md) over every model-facing
surface the session touched. The reader is a capable model. Brief it like a
senior colleague: the goal, the limits, and the few things it cannot know.

## The philosophy

A capable model does its best work from the goal, the constraints, and the
conventions of the place. A procedure costs attention every turn, fights the
model's own plan, and breaks on the case nobody foresaw. So say what done
looks like, give each constraint its reason, and leave the method to the
model.

Spend words where the model's default is wrong or its knowledge is missing:

- **Authority.** What it may do without asking, and where it must stop.
- **Facts it cannot find.** The unwritten convention, the trap, the reason
  behind a choice.
- **Judgment it gets wrong by default.** Growing scope, reading silence as
  approval, stopping before the work is done.

The rest is method the model already has. Leave it out.

Solve it in code before prose. An instruction is a lever paid for every
turn; a mechanism runs every time and costs nothing. **Eliminate** the
failure with a hook, schema, or check. Otherwise **inform**: put what the
system knows at the decision point. Only then **instruct**. Prose is for
judgment, and hard-blocking a real judgment call is the same mistake
inverted. When the mechanism lies outside your task, such as a global hook
for one skill, write the instruction and offer the mechanism.

## Write short

Short comes from keeping only what changes the reader's next action, never
from squeezing sentences.

- **One instruction per sentence.** Most sentences run under 20 words. A
  qualification that changes behavior gets its own sentence; one that does
  not gets cut. Dash asides and stacked clauses are where weak
  qualifications hide.
- **Terse, not encoded.** "Fix the case that happened, not every case that
  could." is short and whole. Arrow chains, slash lists, and strings of
  labels make the reader decode. Cut words, never grammar.
- **A reason fits in a clause.** "Every watcher on the account shares one
  rate limit." Where the model would mistake one thing for another, a
  reframe carries rule and reason together: "A timeout is not approval."
  A reason that needs a sentence gets one.
- **Plain words.** Use the field's own words. Coin a term only when the
  document uses it often, and define it in one line where it first appears.
- **A budget.** A skill body past 1,500 words has stopped being a brief, and
  most need far fewer. Disclose what only some runs need behind a pointer,
  or cut. In the dotfiles repo, `skill-sync --check` flags an owned skill
  that passes it. Past the line, an addition replaces something.

## Write in layers

Give a cold reader what it needs in the order it needs it. Most surfaces
settle into three layers; a snippet or an error line is one layer carrying
what it can of the three.

**1. What this is, and what done looks like.** Open on the task, the
situation it arrives in, the reader's role, and what marks the work complete.
A capable model generalizes from intent and cannot infer it.

<example type="avoid">
Two producers feed **#bug_reports**: `LoopyReport` rows (the row exists even when the Slack post failed) and `LoopyConversationAnalysis` rows. **Check `.source` before quoting `.problemStatement` as the user's words.** …
</example>

<example>
You are triaging a production incident of **Loopy**, planlab's multi-turn tool-use agent. A signal has arrived from one of two producers: a person pressed *report a bug* in a thread, or the judge that scores every settled run flagged one. You hold an id from either. The job is to say what happened and why, with receipts, and to leave one working dossier per root cause that the verify skill can reproduce from. It stops there.
</example>

The first opens on a mechanism, then a trap. The second names the task, the
input, and done.

- **The reader's world.** Describe the situation as the reader meets it:
  "the engineer who supervises this task reads your final message", not
  "your reply is stored as a `turn_reply` row". Pose each question so a
  careful person holding only the reader's input could settle it, and join
  the rest in code. A frame may simplify the system but never invents.
- **Done the reader can check.** "Every modified model accounted for", not
  "understanding reached". A vague bound invites stopping early. Output
  that code parses gets an exact contract: path, shape, allowed values.

**2. What shapes the judgment.** The constraints and the heuristics an expert
brings.

- **Give the reason.** A rule with its why is applied to cases it never
  named. The reason that lands best is a consequence in the reader's world.
- **Right altitude.** Give strong heuristics, not a decision tree. Number
  steps only where order matters. Ask for conclusions with their evidence;
  "show your thinking" can trigger a refusal.
- **Trigger and skip.** A rule says when it fires and when it does not. A
  required output section says "if none, say none", so nothing is invented.
- **Earned emphasis.** `CRITICAL`, `MUST`, and all-caps make current models
  over-trigger. Keep strong language for a hard boundary or a failure you
  can cite.

**3. What the environment will not confess.** The traps and the thing that
looks right and is wrong, each under the concept it belongs to.
Cross-cutting ones go at the end, where attention is strong again.

Let the formatting show the layers: a list for parallel items, a bold label
per entry for lookups, a table only for comparing across rows, and no more
structure than the content has. Prompt style shapes output style.

## Every sentence

- **Cold reader.** The reader has none of your conversation, and authoring
  skews you both ways. You leave out what is obvious to you, and you leak
  your own vocabulary. Each internal name must help the reader act; one that
  is there because you know it becomes the field's word (the
  **familiar-term test**).
- **Say what to do.** Negation drags the forbidden behavior into context.
  Keep `never` for a hard boundary, paired with what to do instead.
- **Shown beats said.** A model imitates examples more than it follows
  rules, so every example is an instruction. Hold each to the standard you
  want back, and fix it first when output ignores a rule. Use few: one where
  rules are not landing, and an avoid-case only where the model would
  otherwise reproduce the default.
- **One home per behavior.** Each rule lives in one place, and an echo names
  its home. Point at what the environment already says (a `--help`, a
  config, a listing) instead of restating it, since a copy goes stale. When
  a prompt is assembled from modes or flags, branch in the code that
  assembles it, not in the prose.
- **No-ops.** Delete a sentence the model would follow anyway. Settle doubt
  by running the document, since a terse line may be holding a behavior.
- **Prove what you prescribe.** Verify each claim about a mechanism at its
  source, and pin the load-bearing ones with a test where the surface has
  one. A claim you cannot check becomes a pointer to where the reader
  checks it.

## Pointers

- [REVISION.md](REVISION.md): the revision pass and its defect names.
- `~/.config/lessons/agent-tooling/usage-lessons.md`: lessons from how
  agents used past tools.
- `~/dotfiles/references/fable-prompting-guide.md`: the vendor's guide for
  current models, including which old instructions they no longer need.
- `case-studies/classifier-judge-questions-jev-steward.md`: a question a
  classifier or judge answers. `case-studies/README.md` says when to add
  one.
- A project's own prompting guide, when its `CLAUDE.md` names one, holds
  that repo's calibrations. General lessons graduate up into this file.
