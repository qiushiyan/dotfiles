---
name: prompt-engineering
description: Rules for writing model-facing text. Use when writing or revising a prompt, a skill or its description, a CLAUDE.md, a snippet, or a tool's description or error.
requires:
  - user:writing-for-agents/SKILL-MECHANICS.md
  - lessons:agent-tooling/usage-lessons.md
---

# Writing for the model

You are writing for a capable model that has none of your context. Brief it
the way you would brief a senior colleague: what the work is for, what done
looks like, where it must stop, and the few things it cannot find out. Leave
the method to it. For a skill, a `CLAUDE.md`, or an agent that runs over
many steps, also read [AGENT-DOCS.md](AGENT-DOCS.md); for a tool or a prompt
around large material, [TOOLS.md](TOOLS.md).

## The stance

**Every line names what it prevents:** a failure seen in use, or a default
the model gets wrong. A line that names nothing is a no-op, however
sensible. Text piles up because adding feels safe and removing
feels risky, so a kept line meets the same proof as an added one.

Words go to three things. **Authority:** what the reader may do alone, and
where it stops. **Facts it cannot find:** the unwritten convention, the
trap, the reason behind a choice. **Judgment it gets wrong by default:**
growing scope, reading silence as approval, stopping early. The rest is
method it already has.

**Code before prose.** A hook, a schema, or a script runs every time; an
instruction works some of the time. Prose is for judgment, and a mode or
flag is branched in the code that assembles a prompt, never in its text.

**Open on the task and what done looks like,** in the reader's terms. A
capable model generalizes from intent and cannot infer it.

**Write short.** One instruction per sentence. Plain words. A reason in a
clause, where the reader would otherwise misapply the rule: "a timeout is
not approval." Terse, not encoded: cut words, never grammar.

**Show what you want back.** The model copies examples more than it follows
rules, so every example is an instruction. Use one where the output is
style-bound, or where a rule alone loses to a habit.

**Mechanism becomes the fact it implies.** A reader acts on what a mechanism
means for it, not on the tour. Cut the tour and keep the fact:

<example type="avoid">
The way this works: each worker runs in its own background session spawned over RPC, and results arrive as follow-up messages on the event bus, so don't block waiting on them. (A worker turn can take several minutes.)
</example>

<example>
A worker turn takes several minutes, so send one complete request rather than a stream of small ones, and keep working elsewhere while it runs.
</example>

## What our sessions taught

General advice a capable model already holds is not repeated here. These
are the calibrations our own work measured:

- **The reader's world.** Pose the task as the reader meets it: "the
  engineer who supervises this task reads your final message", not "your
  reply is stored as a `turn_reply` row". A judge or classifier answers only
  what its input shows, and code joins the rest. It is not told what its
  verdict leads to, since a stated stake skews the verdict
  (`case-studies/classifier-judge-questions-jev-steward.md`).
- **Familiar terms.** A name you coined while working helps you, not the
  reader. Use the field's word.
- **Emphasis.** `CRITICAL`, `MUST`, and all-caps make current models
  over-trigger. Keep strong words for a hard boundary.
- **"Show your thinking"** can trigger a refusal, even when the person you
  write for asks for it. Ask for conclusions with their evidence; the
  evidence is what they debug from.
- **Size.** A skill body past 1,500 words has stopped being a brief. In the
  dotfiles repo `skill-sync --check` fails a skill's growth.
- **Claims about mechanisms** are checked at the source before they ship. A
  stale or invented one costs more than a missing one.

More, from mining how agents used past tools:
`~/.config/lessons/agent-tooling/usage-lessons.md`. The vendor's guide for
current models: `~/dotfiles/references/fable-prompting-guide.md`.

## Before shipping: the revision pass

Read each model-facing surface the session touched, whole and cold, and ask:

1. Does it open on the task and what done looks like?
2. Does every line name what it prevents?
3. Is every claim true today, and does every pointer to it still resolve
   (grep for renamed names)?
4. Would the reader, holding only its input, know what to do?

Fold a finding in by rewriting the sentence it corrects, and keep its
reason as what goes wrong ("a hand-written merge step takes no hold"), not
its dated incident; receipts go in the evidence log. Other growth
pays with a cut. Where a question stays open, use a cold reader with a concrete
scenario, or an eval case when the behavior can be replayed
(`~/dev/skill-evals`).
