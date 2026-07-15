<!--
Brief template for /review. Copy the body below into a scratchpad file and
fill every «slot», deleting these comments — the reviewer reads a single
coherent brief. The fixed lines are distilled from review prompts that worked;
keep them unless this run genuinely contradicts them.
-->

# Review: «one-line description of the change»

«One paragraph anchoring identity for a cold reader: what the project is, in
plain terms, and what this change set out to accomplish. The reviewer has none
of the implementer's conversation — this paragraph and the reading list are
all the orientation it gets.»

## Posture — step back first

A reviewer's default failure is tactical: accept the implementation's framing
and optimize inside it, converging on a local optimum — the extra argument,
the patched conditional, the fix that works. Review strategically: before
endorsing any local fix, step back and ask whether reshaping the design
dissolves the problem instead — a new module or helper, a shared component
extracted, a function redesigned around a different contract, the pieces
wired together differently. Propose the reshape when you see one; the local
patch is the fallback, not the finding. This applies to the shape of the
code, never to the settled decisions fenced below.

The suite has its own version of that failure — call it additive bias — and it
runs the other way: asking for another test is cheap, always defensible, and
looks rigorous, so a reviewer drifts toward adding coverage instead of judging
what is already there. A missing test is visible today; a superfluous one bills
the future, and never to you. Hold a test you request to the same bar as any other finding — name
the bug it would catch, and confirm no existing test catches it. Coverage is
feedback, never the goal, which means a test worth deleting is a finding too.

## The work under review

- Branch `«branch»`, commits `«base-sha»..HEAD` — start from
  `git log «base-sha»..HEAD --stat`.
- Read the actual code, not just the diffs — a diff hides the surrounding
  context that decides whether a change is right.
- Where a change looks wrong, work out what the implementer was doing before
  judging it (Chesterton's fence) — odd-looking code often encodes a
  constraint you haven't hit yet.
- Review only — do not change any code.

## The foundation — decided, not up for relitigation

The direction is settled; your job is defects in the implementation of that
direction. If a settled item is fatally flawed and the flaw only shows in the
code, flag it with concrete evidence (code paths, failure scenarios) in the
foundational-objections section — never smuggled in as a "small fix". The
settled items:

1. «settled decision»
2. «settled decision»

## Read these, in this order

«Ordered reading list with absolute paths: the spec/plan first — it is the
authority on WHAT this change should do (no spec? state the goal here
instead) — then the repo's mental-model docs, then the load-bearing changed
files. The reviewer reads them itself — never restate their content.»

## Evaluate

- **Correctness** — bugs, edge cases, failure modes.
- **Solves the problem** — does the implementation solve the spec's problem, or just pass its own tests?
- **Silent deviations** — planned tests that never appeared, promised helpers that don't exist, scope creep past the spec.
- **Test quality** — right altitude (behavior, not internals); covers the planned cases plus the obvious additions; survives plausible refactors; follows project test patterns. Flag the tests that add churn without signal: tests of *shape* (signatures, data structures) that pass when behavior breaks, tests pinning wording or constants no caller depends on, a second test re-proving what an existing one already owns, and over-testing — every edge case or internals instead of the critical paths.
- **UX & performance** — user-facing impact, performance characteristics.
- **Structural quality — be ambitious, not just local.** Read `~/.config/lessons/codebase-design/deep-modules.md` before judging structure: its bar (depth, seams, the deletion test, illegal states) is the lens, and its vocabulary is the language structural findings are written in. When the change restructures an existing cluster, also read `~/.config/lessons/codebase-design/deepening.md` — whether a seam earns a port, and replace-don't-layer for the moved tests. The reshape that makes a concept disappear — a branch, a mode, a helper layer — outranks the one that tidies it. Two axes the lessons don't carry:
  - **Seam cleanliness:** casts, `any`/`unknown`, optionality papering over unclear invariants — push for an explicit contract.
  - **Preparatory refactoring** (when the range includes one): behavior-preserving and proportionate — sized to this change, not a rewrite smuggled in alongside it.
- **Right-sizing — over-building is the likelier failure** (the code's additive bias): defensive branches for states that can't occur, fallbacks the invariants already rule out, speculative features or config beyond the spec, abstractions pulled out before the pattern is real. Prefer making a bad state unrepresentable (a type, constructor, or enum) or validating at one boundary over more handling.

## Do not flag

- «deliberately deferred work, known out-of-scope items, staleness already on record»
- Theoretical risks behind unlikely preconditions; defense-in-depth where the primary defense is adequate.
- A missing test whose bug you can't name, or that an existing test already covers.
- Style that follows this repo's own conventions, even where you'd choose differently.

## Output

Findings ordered by severity — **critical** (blocks merge) / **moderate**
(fix before merge) / **minor** (nice-to-have) — and don't pass the review
because the code works: structural regressions and missed reshapes are
critical, not minor. For each finding: what, where (file/function), the
evidence (cite the code that proves it — a finding you can't point at code
for doesn't get reported), and a concrete fix. End with a **Foundational
objections** section, and state "none" explicitly for any empty severity
tier. Be specific and terse; no praise padding.

## Implementation report

The implementer's own map of the change, below. Treat it as a starting
point — pointers to cut your overhead, not the boundary of the review. Review
the whole change against its actual goal and actively look for what the
report leaves out; a review that only checks what the implementer surfaced
isn't independent.

---

«the report from step 2»
