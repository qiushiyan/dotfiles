---
name: revise-prompt
description: Revise model-facing text that exists. Use when a prompt, skill or tool text misbehaves or needs tightening, a review finding needs folding in, or a revision pass is due.
---

# Revise model-facing text

Change text a model already reads (a prompt, a skill, a brief, a tool's
description, result or error) so its reader does better, without the text
growing. You come in from a failure, where the model did something wrong on
an input, or for a review, a pass with nothing reported wrong. You are done
when every surface in scope has had the pass, each defect found is fixed in
the layer that owns it and checked, nothing that worked before breaks, and
your report says what changed or that nothing needed to. Text that does not
exist yet goes to [`write-prompt`](../write-prompt/SKILL.md).

Read [`../prompt-engineering/SKILL.md`](../prompt-engineering/SKILL.md) first.
It holds the house rules the pass checks against, and the guides for skills
and tools.

## From a failure

1. **Get it as it happened:** the input, what the model did, and what it
   should have done, from a transcript or an output rather than a summary.
   With only a description, find or produce one real instance.
2. **Find the first point where it went wrong, and the layer that owns
   it.** Look at what the model actually saw. Was the fact missing, buried,
   or contradicted? Did a frame, an example, or a stated stake pull it
   there? Do two instructions conflict, so it had to pick one? Or did the
   text never get a chance: the assembled context, a tool result, the
   engine, the choice of model? Some failures are not text problems; say so
   and fix them where they live. Check each claim at its source.
3. **Reproduce before you edit,** when one headless run can show the
   failure: record the commit and write the case first (improve-tool's
   `EVALS.md`), so the current text fails it.
4. **Fix it in that layer.** Code owns what code can do. In text, rewrite
   the sentence that produced the behavior rather than adding a rule beside
   it: two rules that conflict become one that says which wins. Capitals
   and MUST do not fix a miss. A reason says what goes wrong, not when it
   went wrong; receipts go in the evidence log. Any growth is paid for with
   a cut.
5. **Run the pass** over every surface you touched, then rerun the failing
   case and the ones that passed before.

## The pass

For a review, and after every fix. Read each surface in scope whole and
cold, with its callers and examples. First write its task in one plain
sentence, as its reader meets it; your report opens with these. Then ask:

1. Does it open on the task and what done looks like?
2. Is the task posed in the reader's world, without this session's names,
   and can the reader answer every question from what it is given?
3. Does every line name what it prevents?
4. Is every claim true today, and does every pointer still resolve (grep
   for renamed names)?
5. Would the reader, holding only its input, know what to do?

A mechanism tour becomes the fact the reader acts on:

<example type="avoid">
The way this works: each worker runs in its own background session spawned over RPC, and results arrive as follow-up messages on the event bus, so don't block waiting on them. (A worker turn can take several minutes.)
</example>

<example>
A worker turn takes several minutes, so send one complete request rather than a stream of small ones, and keep working elsewhere while it runs.
</example>

A defect the pass finds goes through steps 2 to 4, with a case first when
one run can show it. Fold a finding in by rewriting the sentence it
corrects. Where a question stays open, use a cold reader with a concrete
scenario.

## Report

Each finding with its fix, each deliberate keep with its reason, or plainly
that nothing needed changing. Say what was verified by running (a case, a
replay) and what only by reading.
