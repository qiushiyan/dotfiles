---
name: write-spec
description: Turn the settled direction into a committed, validated spec.
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

Turn the direction this session settled into the document the user
approves and this session builds from after compaction. The spec settles
the unknowns the design turns on by running them, so the build starts from
measured ground, and gives a model with no conversation the whole design in
a length it reads whole.

Everything below is a bar, not a form. Arguments override the defaults
and carry through the steps they touch:

- "don't commit": the spec, its index row and its revisions stay
  uncommitted, and step 4 still reads them.
- "let me read it first": the report comes after step 2, and step 4 waits
  for the user's word.
- "skip validation": step 4 keeps the cold read and drops the consult.
- "skip the checks": step 4 is skipped and the run ends at the report.

## Process

1. **Ground, then settle what the design turns on.** Reread the modules the
   change touches, so the problem and the approach rest on code, not
   memory, reusing this session's evidence where its revision and scope
   still hold. Then settle every unknown whose answer could change
   the scope, the ownership, the feasibility or the promised experience:
   a source read, an existing test, a production read, or a thin `/spike`,
   thirty minutes each at most so one question cannot eat the run. Record
   what ran, what it established, and what stays unknown. A failed access
   or an expired time box leaves the claim unresolved, never quietly
   deferred to the build. Continue with an evidenced fallback or a scope
   cut when either keeps the agreed goal.

   Ask the user only for a product choice or a blocker you cannot settle
   within those bounds: the independent questions in one batch, each with
   why it matters, what each option means for the real user, and your
   recommendation.

2. **Write the spec** to [SPEC-BAR.md](SPEC-BAR.md), read before writing.
   The project decides placement: the file's location, its status header,
   its index row, and any section a written project rule requires. Read the
   specs directory's README and the project's documentation entry point for
   those and for the project's own checks. The headings, their order and
   the prose are the bar's. Sibling specs show placement, not a convention;
   where they differ from the bar, the bar wins.

3. **Commit the spec** on the current branch with the index row that
   registers it, in its own commit with nothing else staged, so the
   build's departures and the checks' growth diff against it.

4. **Check it cold and validate it.** Dispatch both readers at once and fold
   what they return into one revision.

   - **Cold read.** A fresh subagent on the `opus` model, a different model
     from the writer's, gets the block in [COLD-READ.md](COLD-READ.md)
     filled in and nothing else. It reports what a model with no
     conversation could not reconstruct. Judge its reconstruction against
     the design you meant. Resolve each material ambiguity at the rule's
     home, and keep a term only when the spec or the project docs define
     it.
   - **Validation consult.** Continue a prior consult's latest job when it
     is in reach (this session's synthesis, or the handoff), by `/consult`
     step 6 with the spec as the updated proposal, so the voices judge
     follow-through. Otherwise open a fresh `/consult` on the spec. Judge
     the findings by `/consult`'s own process. A finding that opens a
     technical unknown returns to step 1. A disagreement that needs the
     user's call is flagged in the report, and the run stops there.

   Correct by the bar's closing rules. Checks add prose and rarely remove
   it, so a fold that adds words pays with a cut from what the build owns
   or what restates a decision. A finding's reason stays, stated without
   the round. When the revision changes what a cold reader would
   reconstruct, send it to a fresh reader with the block's re-read inputs
   filled in; the summary reconstruction stays blind. Hold the final
   revision to the bar's done condition, and commit a revision only when
   the spec changed.

5. **Report and stop.** This message is the user's first look at the run.
   Lead with the outcome and whether the spec is ready. Then each open
   decision, written so the user can decide from this message alone: what
   the person experiences under each option, the bet each relies on, the
   cost if it is wrong, your recommendation, and which build work waits on
   the answer. Then the identifiers: the spec path, the commit SHAs, the
   latest consult job, what settled, what the checks changed, and the
   spec's size with its growth since step 3's commit, when there is one
   (`scripts/spec-stats.py <spec> --against <sha>`). A spec over 6,000
   words names the decisions that earned it. Every status claim traces to a
   tool result from this session; unresolved checks are reported apart; if
   nothing is open, say so. The opening and one decision of such a report:

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
experiences. Skip a section on purpose, heading and all.

## Scope

One PR built in this session, however ambitious. Work too large for
that, or carrying operational risk, runs as phases on the same branch:
still one PR, a handoff between the sessions, two sessions at most without
a strong reason. A phase a later session will design from what the first
one teaches gets its goals, its boundary and the decisions that bind it,
not its design; a premise that gates the whole change still settles now.
Multiple PRs need every intermediate PR correct as a
merge state and a concrete constraint the seam serves
(`~/.config/lessons/collaboration/pr-boundaries.md` lists them). State the
boundary and the phases in § Delivery, so a voice or a build session does
not quietly re-split them.
