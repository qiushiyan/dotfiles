---
name: prompt-engineering
description: House rules for model-facing text.
disable-model-invocation: true
requires:
  - user:writing-for-agents/SKILL-MECHANICS.md
  - lessons:agent-tooling/usage-lessons.md
---

# House rules for model-facing text

These are the rules every prompt, skill, brief, and tool text is held to.
If no procedure sent you here, read
[`../write-prompt/SKILL.md`](../write-prompt/SKILL.md) for new text or
[`../revise-prompt/SKILL.md`](../revise-prompt/SKILL.md) for a change to
existing text, and follow it; you have already read the rules it points to.

For a skill, a `CLAUDE.md`, or an agent that runs over many steps, also read
[AGENT-DOCS.md](AGENT-DOCS.md). For a tool or a prompt around large material,
read [TOOLS.md](TOOLS.md). For a tool's or a CLI's instruction layer, read the
lessons mined from agents' use of past tools,
`~/.config/lessons/agent-tooling/usage-lessons.md`. When the current model's
behavior is the question, read the vendor's guide,
`~/dotfiles/references/fable-prompting-guide.md`.

## What the words are for

You are writing for a capable model that has none of your context. Brief it
the way you would a senior colleague: open on what the work is for and what
done looks like, in the reader's terms, and leave the method to it.

Words go to three things. **Authority:** what the reader may do alone, and
where it stops. **Facts it cannot find:** the unwritten convention, the
trap, the reason behind a choice. **Judgment it gets wrong by default:**
growing scope, reading silence as approval, stopping early. A line earns its
place by naming what it prevents: a failure seen in use, or a default the
model gets wrong. A line that names nothing is a no-op, however sensible.

**Code before prose.** A hook, a schema, or a script runs every time; an
instruction works some of the time. Prose is for judgment, and a mode or
flag is branched in the code that assembles a prompt, never in its text.

**Write short.** One instruction per sentence. Plain words. A reason in a
clause, where the reader would otherwise misapply the rule: "a timeout is
not approval." Terse, not encoded: cut words, never grammar.

**Show what you want back.** The model copies examples more than it follows
rules, so every example is an instruction. Show one where the output is
style-bound, or where a rule alone loses to a habit. Leave examples out
where they would narrow a judgment the reader should make fresh each time.

**A mechanism becomes the fact it implies.** A reader acts on what a
mechanism means for it, not on the tour of how it works.

## The reader's world

Pose the task as the reader meets it: "the engineer who supervises this task
reads your final message", not "your reply is stored as a `turn_reply` row".
A name you coined while working helps you, not the reader; use the field's
word, and keep a name the reader will meet in its input. A stylised world is fine when the right answer survives in it. A
reader that acts on the real system gets a simplified world, never an
invented one, since an invented fact becomes a wrong action.

Ask a judge or classifier only what its input shows, and let code combine
its answer with the rest. Leave out what its verdict leads to, since a
stated stake skews the verdict (a worked rewrite:
`case-studies/classifier-judge-questions-jev-steward.md`).

## Calibrations from our sessions

- **Emphasis.** `CRITICAL`, `MUST`, and all-caps make current models
  over-trigger. Keep strong words for a hard boundary.
- **"Show your thinking"** can trigger a refusal, even when the person you
  write for asks for it. Ask for conclusions with their evidence; the
  evidence is what they debug from.
- **Size.** A skill body past 1,500 words has stopped being a brief. In the
  dotfiles repo `skill-sync --check` fails a skill's growth.
- **Claims about mechanisms** are checked at the source before they ship. A
  stale or invented one costs more than a missing one.
