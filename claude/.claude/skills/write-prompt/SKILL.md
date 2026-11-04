---
name: write-prompt
description: Write new model-facing text. Use when drafting a prompt, snippet, skill, CLAUDE.md, brief for another session, judge question, or tool text.
---

# Write model-facing text

Write text a model will read that does not exist yet: a prompt, a system
prompt, a skill, a brief for another session, a judge's questions, a tool's
description, result or error. You are done when the text poses the reader's
task in the reader's own terms, says what done looks like and where the
reader stops, and has had the check in step 4. Improving your draft before
you hand it over stays here. A change to text that already exists goes to
[`revise-prompt`](../revise-prompt/SKILL.md), an addition included, and so
does a later review of what you wrote, such as an end-of-session review.

Read [`../prompt-engineering/SKILL.md`](../prompt-engineering/SKILL.md) first.
It holds the house rules these steps apply, and the guides for skills and
tools.

## 1. Pose the task as the reader meets it

Set this session aside. Ask what the reader holds when the text reaches it,
who reads what it produces, and what it has to produce. Write that in plain
words, as if to someone who never saw the code: the job, not the system
around it. Names this session coined (for tables, events, stages, the
ticket's words) stay out; keep a name the reader will meet in its input or
in the code and tools it works in. What code enforces stays in code; tell
the reader only what it acts on.

<example type="avoid">
Pick up QIU-372 on `m9/one-home`: r2 converged on folding `hostWaits` into the verdict join, so wire it before the `blocks_next` flip and re-run the jev lane.
</example>

<example>
A check judges whether a reply leaves its reader something to decide. Today it guesses whether the work is waiting; after this change, code tells it. This branch is half of that change. Finish it from the spec in `docs/specs/`. You are done when the spec's test plan passes. Stop at your report, since a review comes next.
</example>

## 2. Say what done looks like, and the limits

Make done something the reader can check. Then spend words where the house
rules say: authority, facts it cannot find, and judgment it gets wrong by
default. Before writing a mode, a reply format that code parses, or a branch
as prose, decide whether code should hold it. Ask the user for authority or a
fact you do not hold, such as whether the reader may commit.

For a judge, check every question against its input, leave out what its
verdict leads to, and ask for its conclusion with the evidence for it, never
its reasoning written out, even when you are asked to include it: a request
to show reasoning can be refused.

## 3. Decide what to show

Give an exact reply format when code parses the reply. Otherwise apply the
house rule **Show what you want back**, and when you cannot tell whether an
example helps, try both in step 4.

## 4. Check it before it ships

- **Text code sends to a model** (a system prompt, a tool's description,
  result or error): write three to five realistic inputs,
  the hard one included, run the text on them with the model that will read
  it (`claude -p` stands in for a Claude model), and read the outputs. When
  a choice stays open, such as the framing or an example, run both versions
  on the same inputs and keep the better one.
- **A brief or a snippet:** read it as its reader would, holding only it,
  and ask it the questions of
  [`revise-prompt`'s pass](../revise-prompt/SKILL.md#the-pass).
- **A skill or a CLAUDE.md:** have a read-only cold reader with a concrete
  scenario report the first point where it would guess
  ([how to brief one](../improve-tool/COLD-READER.md)). When its behavior can
  be replayed, a case shows what agents do with it
  ([`EVALS.md`](../improve-tool/EVALS.md)).

This is a smoke check, not an eval suite. Confirm every pointer the text
names resolves. Fix what the check shows by rewriting the sentence at
fault. Your report says which check ran and what it showed.
