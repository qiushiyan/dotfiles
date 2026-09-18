---
name: write-spec
description: Promote the settled direction into a committed spec and run a validation consult. Defaults — commit + validation consult; override by argument ("don't commit", "skip validation").
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

Turn the direction this session has settled into a spec: the design document
the user approves and this session, after compaction, implements. Writing a
spec is a procedure, not only a document. It settles the unknowns the design
turns on by running them, so the build starts from measured ground, and it
produces a document a model can rebuild its whole mental model from.

Everything below is a bar, not a form: **adapt and simplify to the change at
hand**. Arguments to this skill override any default below, and an override
carries through the later steps it touches: "don't commit" leaves the spec
and its revisions as uncommitted files the checks still read; a user who
wants to read the spec first gets the report after step 2, the checks
waiting on their word; "skip validation" skips the validation consult and
keeps the cold read; "skip the checks" skips both and ends at the report.

## Process

1. **Ground, then settle what the design turns on.** Reread the modules the
   change touches, so the problem and the approach are grounded in code, not
   memory. Reuse evidence this session already gathered when its revision,
   inputs and scope still support the decision; fill the material gaps
   rather than repeat a sound measurement.

   Then settle every unknown whose answer could change the scope, the
   ownership, the feasibility, or the promised experience, before the design
   is written as ready. Use whatever the question needs: a source read, an
   existing test, a production read, or a thin `/spike`. Give each question
   at most thirty minutes. Record what ran, what it established, and what
   stays unknown; an access failure or an expired time box leaves the claim
   unresolved, never quietly deferred to the build. Continue with an
   evidenced fallback or an explicit scope cut when either preserves the
   agreed goal.

   Ask the user only for a product choice, or for a blocker you cannot settle
   within those bounds. Ask the independent questions in one batch, a
   question whose answer decides whether another applies first, each
   carrying why it matters, the options with what each means for the real
   user, and your recommendation.

2. **Write the spec** where the project keeps specs, following its
   convention. Read the specs directory's README and the project's
   documentation bindings; they govern names, order, format and local
   checks. Where no convention exists, follow the existing specs, and ask
   only if placement stays ambiguous. Read [SPEC-BAR.md](SPEC-BAR.md)
   before writing: it carries the shared spec-writing rules, decides what
   the spec must settle, and says when it is done. Where the two meet, the
   project's convention governs names, order and format; SPEC-BAR's shape is
   the fallback.

3. **Commit the spec** on the current branch: the spec file alone, its own
   commit, nothing else staged.

4. **Check it cold, then validate it.** A fresh comprehension reader, then
   the independent validation route, in this order:

   - **Cold read.** Dispatch a fresh subagent on the `opus` model with the
     prompt in [COLD-READ.md](COLD-READ.md) and only the spec path, the
     project docs root, and the glossary path. Judge its reconstruction
     against the design you meant. Resolve each material ambiguity at the
     rule's home; keep a term only when its meaning is recoverable from the
     spec or the project docs. When a correction changes what a cold reader
     would reconstruct, send the corrected spec to a fresh reader.
   - **Validation consult.** A prior consult's latest job name in reach (this
     session's synthesis, or the handoff) → continue **that** job with the
     spec as the updated proposal under critique; the voices keep their
     context and judge follow-through. Mechanics live in `/consult` step 6;
     if the job cannot continue, fall through. Otherwise → invoke `/consult`
     in approach mode, fresh, with the spec as the artifact under review.
     Judge the findings by `/consult`'s own process; the revisions keep
     SPEC-BAR's section ownership. A finding that opens a new technical
     unknown goes back to step 1. A major disagreement that needs the user's
     call → flag it and stop.

   Before reporting, hold the final revision to SPEC-BAR's readiness, and
   send it to a fresh cold reader when validation changed what a cold reader
   would reconstruct. Commit a revision only when the spec actually changed.

5. **Report and stop.** The user did not watch the run; this message is
   their first look at it. Lead with the outcome and whether the spec is
   ready, then each open decision, then the identifiers: the spec path, the
   commit SHAs, the latest consult job name, what settled, and what the cold
   read and the validation changed. Every status claim traces to a tool
   result from this session. Write each open decision so the user can decide
   from this message alone: what the person experiences under each option,
   the bet each relies on, the cost if it is wrong, your recommendation, and
   which build work waits on the answer. When a retry is one of the options,
   say what happens after the retry. Report unresolved checks separately. If
   nothing is open, say so. The user decides what happens next.

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

Give depth to the decisions this change turns on, and omit the views that
settle nothing. A refactor usually turns on the target shape and the
vocabulary later sessions inherit; a feature usually turns on what the
person experiences. These are inspirations, not a taxonomy: skipping a
section is a conscious call, not drift.

## Scope — one PR, one session, unless forced apart

Default the spec to **one PR built in this one session, however ambitious**.
Work genuinely too large for that, or carrying operational risk, runs as
phases **on the same branch**: still one PR, a handoff carrying the baton,
two sessions at most without a really strong reason. Multiple PRs only when
every intermediate PR is independently correct as a merge state *and* a
concrete constraint (a repository or ownership boundary, release or rollback
mechanics, an operational step mid-way, evidence only a merged PR can
produce) benefits from the seam. State the PR boundary and the phases
explicitly in the spec, so a consult voice or an implementing session does
not quietly re-split it. The reasoning behind the default:
`~/.config/lessons/collaboration/pr-boundaries.md`.
