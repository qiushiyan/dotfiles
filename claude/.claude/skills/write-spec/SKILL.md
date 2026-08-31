---
name: write-spec
description: Promote the settled direction into a committed spec and run a validation consult. Defaults — commit + validation consult; override by argument ("don't commit", "skip validation").
disable-model-invocation: true
---

# Write a spec

Turn the direction this session has settled into a spec: the design document
the user approves and later sessions implement. Write for the session that
holds none of this context — a good spec is reread by several future
sessions on the same branch.

Everything below is a bar, not a form: **adapt and simplify to the change at
hand**. Arguments to this skill override any default below, and an override
carries through the later steps it touches: "don't commit" leaves the spec —
and its revisions — as uncommitted files the validation still reads; a user
who wants to read the spec first gets the report after step 2, validation
waiting on their word; "skip validation" ends the run at the report.

## Process

1. **Ground, then interview if uncertain.** Reread the modules the change
   touches — the spec's problem and approach are grounded in actual code,
   not memory. Then, if product questions or design uncertainty remain,
   interview the user before writing — everything in one batch, clustered by
   topic (defer only a follow-up that a pending answer would decide or
   reshape), each question decidable from its text alone: why it matters,
   what it means in plain product terms, the options with their implications
   for the real user, and your recommendation. A **blocking technical
   unknown** that only running code can settle is not an interview question:
   name the spike that would settle it and stop — the user decides whether
   to run it before the spec is worth writing.

2. **Write the spec** to wherever this project conventionally keeps specs —
   follow the existing convention, and read the project's
   `documentation-standards.md` or specs-directory README first when one
   exists; ask only when no convention exists. The writing bar is
   [SPEC-BAR.md](SPEC-BAR.md) — the document's shape, the target shape, and
   the finish checks. Read it before writing; the spec is done when it holds
   to that bar, with Emphasis and Scope below deciding where the depth goes.

3. **Commit the spec** on the current branch — the spec file alone, its own
   commit, nothing else staged.

4. **Validation consult.** The spec goes before independent eyes:

   - A prior consult round's out-dir is in reach (this session's synthesis,
     or the handoff) → continue **that** consult as its round 2, the spec as
     the updated proposal under critique — the voices keep their context and
     judge follow-through. Mechanics live in `/consult` step 6; if the set
     cannot resume, fall through to the fresh branch.
   - Otherwise → invoke `/consult` in approach mode, fresh, with the spec as
     the artifact under review.

   Judge the findings by `/consult`'s own process; commit the revision only
   when the spec actually changed. A major disagreement that needs the
   user's call → flag it clearly and stop instead of pushing through.

5. **Report and stop.** The spec path, the commit SHAs (when committed), the
   consult out-dir, then: what settled, what validation changed, what stayed
   open. The user decides what happens next.

## Emphasis — where does the load-bearing novelty live?

Before writing, ask what this change actually turns on — the product
behavior, an interface or seam or vocabulary, compatibility and rollout
risk, how it will be verified — and give the spec its depth there. Two
worked examples:

- **A refactor or restructure** usually turns on the target shape: module
  structure and public-API wiring, written from the caller's perspective,
  steer every later session. Naming and domain vocabulary are load-bearing
  even when runtime behavior is unchanged — later sessions inherit the
  vocabulary this spec fixes.
- **A new feature** usually turns on the product sections: the insights,
  trade-offs, and user-facing concerns outweigh technical shape. A feature
  spec that is mostly module diagrams has its weight in the wrong place.

These are inspirations, not a taxonomy — a feature can be
interface-dominant, a deletion can turn on its verification story. Weight or
simplify sections by where the novelty lives; skipping a section is a
conscious call, not drift.

## Scope — one PR, one session, unless forced apart

Default the spec to **one PR built in this one session, however ambitious**.
Work genuinely too large for that, or carrying operational risk, runs as
phases **on the same branch** — still one PR, a handoff carrying the baton,
two sessions at most without a really strong reason. Multiple PRs only when
every intermediate PR is independently correct as a merge state *and* a
concrete constraint — repository or ownership boundary, release or rollback
mechanics, an operational step mid-way, evidence only a merged PR can
produce — benefits from the seam. State the PR boundary and the phases
explicitly in the spec, so a consult voice or an implementing session
doesn't quietly re-split it. The reasoning behind the default:
`~/.config/lessons/collaboration/pr-boundaries.md`.
