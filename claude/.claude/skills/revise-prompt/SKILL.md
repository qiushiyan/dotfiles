---
name: revise-prompt
description: Revise model-facing text that exists. Use when a prompt, skill, CLAUDE.md or tool text misbehaves, needs tightening or a review, or a review finding needs folding in.
---

# Revise model-facing text

Change text a model already reads (a prompt, a skill, a brief, a tool's
description, result or error) so its reader does better, growing only by
what the fix needs. You are done when every surface in scope has had the
pass, each defect found is fixed in the layer that owns it and checked,
nothing that worked before breaks, and your report says what changed or
that nothing needed to. A review finding to fold in starts at step 2, with
the finding as the instance. Text that does not exist yet goes to
[`write-prompt`](../write-prompt/SKILL.md).

Read [`../prompt-engineering/SKILL.md`](../prompt-engineering/SKILL.md) first.
It holds the rules every fix and the pass are checked against, and the
guides for skills and tools.

## From a failure

1. **Get it as it happened:** the input, what the model did, and what it
   should have done, from a transcript or an output rather than a summary.
   With only a description, find or produce one real instance. When what it
   should have done is the user's choice and they have not said, ask.
2. **Find the first point where it went wrong, and the layer that owns
   it.** Look at what the model actually saw. Was the fact missing, buried,
   or contradicted? Did a frame, an example, or a stated stake pull it
   there? Do two instructions conflict, so it had to pick one? Or did the
   text never get a chance: the assembled context, a tool result, the code
   around it, the choice of model? Some failures are not text problems; say so
   and fix them where they live.
3. **Reproduce before you edit,** when one headless run can show the
   failure: record the commit and write the case first, so the current text
   fails it. A skill replays through
   [improve-tool's `EVALS.md`](../improve-tool/EVALS.md) where that skill is
   installed, and otherwise as one headless run of the skill on the recorded
   request; text that code sends to a model replays by running that model on
   the recorded input.
4. **Fix it in that layer.** Code owns what code can do. In text, rewrite
   the sentence that produced the behavior rather than adding a rule beside
   it: two rules that conflict become one that says which wins. When
   several findings share one cause in the structure, such as a file that
   opens on its mechanism, rewrite the structure instead of patching each
   sentence. A reason says what goes wrong, not when it went wrong; receipts
   go in the target's evidence log (`EVIDENCE.md` beside a skill) or the
   commit message. Growth beyond the fact the reader was missing is paid for
   with a cut.
5. **Run the pass** over every surface you touched, then rerun the failing
   case and whatever passed before: cases, tests, and callers that match a
   changed result or error.

## The pass

For a review, and after every fix. Read each surface in scope whole and
cold, with its callers and examples; where only part of a file is in scope,
pass that part and read the rest for contradictions. First write its task
in one plain sentence, as its reader meets it. Then ask:

1. Does it open on the task and what done looks like?
2. Is the task posed in the reader's world, without this session's names,
   and, for a judge, is every question answerable from its input?
3. Does every line name what it prevents? A line narrating how something
   works names nothing; keep the fact it implies for the reader (below).
4. Is every claim true today, and does every pointer still resolve (grep
   for renamed names)?
5. Would the reader, holding only its input, know what to do?
6. Is each meaning stated once, where the reader acts on it?

<example type="avoid">
The way this works: each worker runs in its own background session spawned over RPC, and results arrive as follow-up messages on the event bus, so don't block waiting on them. (A worker turn can take several minutes.)
</example>

<example>
A worker turn takes several minutes, so send one complete request rather than a stream of small ones, and keep working elsewhere while it runs.
</example>

Fix what the pass finds as in steps 3 to 5, settling each doubt by its kind:

- **A false claim, or a line that prevents nothing:** no case needed. Verify
  the fix by reading, or by running the command.
- **Unsure whether the model already does it without the line:** run its
  eval case against a copy without it; with no case, screen it with a
  baseline interview ([how to run one](../prompt-engineering/BASELINE.md)).
- **Any other open question:** ask a read-only cold reader with a concrete
  scenario ([how to brief one](../prompt-engineering/COLD-READER.md)).

## Report

Open with each surface's task sentence. Then each finding with its fix, each
deliberate keep with its reason, or plainly that nothing needed changing. Say what was verified by running (a case, a
replay) and what only by reading.
