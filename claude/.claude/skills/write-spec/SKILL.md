---
name: write-spec
description: Promote the settled direction into a committed spec — unknowns run down, the spec committed, read cold by a fresh model, validated by consult. Defaults — commit + cold read + validation consult; override by argument ("don't commit", "skip validation", "skip the checks").
disable-model-invocation: true
requires:
  - user:consult
  - user:spike
  - lessons:codebase-design/deep-modules.md
  - lessons:codebase-design/design-it-twice.md
  - lessons:codebase-design/deepening.md
  - lessons:codebase-design/composition.md
  - lessons:testing/tdd-loop.md
  - lessons:testing/mocking-and-fixtures.md
  - lessons:collaboration/pr-boundaries.md
  - lessons:collaboration/tenets.md
---

# Write a spec

Turn the direction this session has settled into the document the user
approves and this session, after compaction, builds from. A spec is a
procedure as much as a document: it settles the unknowns the design turns
on by running them, so the build starts from measured ground, and it gives
a model with no conversation everything it needs to rebuild the whole
mental model.

Everything below is a bar, not a form; adapt it to the change at hand.
Arguments override the defaults and carry through the steps they touch:

- "don't commit": the spec, its index row and its revisions stay
  uncommitted files, and step 4 still reads them.
- "let me read it first": the report comes after step 2, and step 4 waits
  on the user's word.
- "skip validation": step 4 keeps the cold read and drops the consult.
- "skip the checks": step 4 is skipped and the run ends at the report.

## Process

1. **Ground, then settle what the design turns on.** Reread the modules the
   change touches, so the problem and the approach rest on code rather
   than memory; reuse evidence this session already gathered where its
   revision and scope still support the decision. Then settle every
   unknown whose answer could change the scope, the ownership, the
   feasibility or the promised experience: a source read, an existing
   test, a production read, or a thin `/spike`, thirty minutes each at
   most so one question cannot eat the run. Record what ran, what it
   established, and what stays unknown. A failed access or an expired time
   box leaves the claim unresolved, never quietly deferred to the build;
   continue with an evidenced fallback or a scope cut when either keeps the
   agreed goal.

   Ask the user only for a product choice or a blocker you cannot settle
   within those bounds: the independent questions in one batch, each with
   why it matters, what each option means for the real user, and your
   recommendation.

2. **Write the spec** to [SPEC-BAR.md](SPEC-BAR.md), read before writing.
   The project decides placement: where the file goes, its status header,
   its index row, any section a written project rule requires; read the
   specs directory's README and the project's documentation entry point
   for those and for the project's own checks. The headings, their order
   and the prose are the bar's. Sibling specs show placement, not a
   convention; where they differ from the bar, the bar wins.

3. **Commit the spec** on the current branch with the index row that
   registers it, in its own commit with nothing else staged, so the build's
   departures diff against it.

4. **Check it cold and validate it.** Two readers judge the spec as it
   stands; dispatch both at once and fold what they return into one
   revision.

   - **Cold read.** A fresh subagent on the `opus` model, a different
     model from the writer's, given the block in [COLD-READ.md](COLD-READ.md)
     filled in and nothing else, reports what a model with no conversation
     could not reconstruct. Judge its reconstruction against the design
     you meant; resolve each material ambiguity at the rule's home, and
     keep a term only when its meaning is recoverable from the spec or the
     project docs.
   - **Validation consult.** When a prior consult's latest job is in reach
     (this session's synthesis, or the handoff), continue it with the spec
     as the updated proposal under critique, by `/consult` step 6: the
     voices keep their context and judge follow-through. Otherwise open a
     fresh `/consult` with the spec as the proposal under
     review. Judge the findings by `/consult`'s own process. A finding that
     opens a technical unknown returns to step 1; a disagreement that needs
     the user's call is flagged in the report, and the run stops there.

   Corrections follow the bar's closing rules: rewrite at the rule's home,
   add at the section that owns it. When the revision changes what a cold
   reader would reconstruct, send it to a fresh reader with the previous
   reader's resolved-term list and the changed sections as the block's
   re-read inputs; the summary reconstruction stays blind. Hold the final
   revision to the bar's done condition, measurements included, and commit
   a revision only when the spec changed.

5. **Report and stop.** This message is the user's first look at the run.
   Lead with the outcome and whether the spec is ready. Then each open
   decision, written so the user can decide from this message alone: what
   the person experiences under each option, the bet each relies on, the
   cost if it is wrong, your recommendation, and which build work waits on
   the answer. Then the identifiers: the spec path, the commit SHAs, the
   latest consult job, what settled, and what the cold read and the
   validation changed. Every status claim traces to a tool result from this
   session; unresolved checks are reported apart; if nothing is open, say
   so. The opening and one decision of such a report:

   <example>
   The spec for the worker deaths on oversized script output is written,
   validated, and committed. A planner's script overran a worker's memory
   and the run kept retrying; the spec repairs the output conversion, bounds
   the output, and tells the model what failed. It is ready to build once
   you settle one product decision; nothing else is open.

   Decision: which repeated failures should end a run early?

   A — stop only with proof that the worker ran out of memory. The bet is
   that an unexplained loss is usually temporary, so another attempt can
   succeed. The cost is that some memory deaths leave no report, and those
   runs keep freezing and retrying until the normal budget runs out.

   B — stop after two unexpected losses on the same step, once the model has
   been warned. The bet is that two losses on the same work mean a third
   blind try is waste. The cost is the occasional run that a third attempt
   would have finished.

   Recommend B. The planner sees an interruption card pointing at the work
   already produced, with one click to resend. A resend gives the model a
   chance to take a different path; it does not fix the cause, and it can
   fail again.

   Your answer sets the run-ending policy. The output-conversion repair is
   independent and can start now.
   </example>

## Emphasis

Give depth to the decisions the change turns on and omit the views that
settle nothing. A refactor usually turns on the target shape and the
vocabulary later sessions inherit; a feature on what the person
experiences. Skipping a section is a conscious call, not drift; the
heading is left out.

## Scope

One PR built in this one session, however ambitious. Work too large for
that, or carrying operational risk, runs as phases on the same branch:
still one PR, a handoff between the sessions, two sessions at most without
a strong reason. Multiple PRs need two things: every intermediate PR is
independently correct as a merge state, and a concrete constraint benefits
from the seam, such as a repository or ownership boundary, release or
rollback mechanics, an operational step mid-way, or evidence only a merged
PR can produce. State the boundary and the phases in § Delivery, so a voice
or a build session does not quietly re-split them; the reasoning is
`~/.config/lessons/collaboration/pr-boundaries.md`.
