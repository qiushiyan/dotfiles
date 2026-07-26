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

## Posture — the review lens

Read `~/.config/lessons/collaboration/review-lens.md` before reviewing — its
stance governs every finding: step back before endorsing any local fix, hold a
test you request to its additive-bias bar, treat over-building as the likelier
failure. The stance applies to the shape of the code, never to the settled
decisions fenced below.

## The work under review

- Branch `«branch»`, commits `«base-sha»..HEAD` — start from
  `git log «base-sha»..HEAD --stat`.
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
- **Test quality** — right altitude (behavior, not internals); covers the planned cases plus the obvious additions; survives plausible refactors; follows project test patterns. Weigh what the change did to the tests already there: a behavior it removed or reshaped can leave an existing test asserting something gone, now redundant, or pinned to internals that moved — flag those for deletion or rewrite, not silent survival.
- **UX & performance** — user-facing impact, performance characteristics.
- **Structural quality.** Read `~/.config/lessons/codebase-design/deep-modules.md` before judging structure: its bar (depth, seams, the deletion test, illegal states) is the lens, and its vocabulary is the language structural findings are written in. When the change restructures an existing cluster, also read `~/.config/lessons/codebase-design/deepening.md` — whether a seam earns a port, and replace-don't-layer for the moved tests.

## Do not flag

- «deliberately deferred work, known out-of-scope items, staleness already on record»
- Theoretical risks behind unlikely preconditions; defense-in-depth where the primary defense is adequate.
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
