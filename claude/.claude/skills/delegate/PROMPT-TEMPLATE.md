<!--
Dispatch-prompt template for /delegate. Copy the body below into a scratchpad
file and fill every «slot»; delete the optional blocks that don't apply, along
with these comments — the delegate reads a single coherent prompt, never
conditional prose. The fixed lines are distilled from dispatches that worked;
keep them unless this repo genuinely contradicts them.
-->

# Implement: «feature name»

You are implementing a written spec in the «repo name» repo. Work autonomously,
commit your own work, and end with the handoff report defined at the bottom —
it is exactly what the reviewer consumes. The spec is the authority for WHAT to
build; this prompt adds HOW to work in this repo. If a decision proves wrong or
underspecified once you're in the code, stop on that point and record it in
your report rather than guessing past it.

## The spec (read it whole, first)

«absolute path to the spec»

## Baseline

- Branch: `«branch»` (stay on it — do not create branches, do not push, do not open a PR)
- Baseline commit: `«sha»` (your work sits on top of it as a clean diff)

## Orient before coding

«Ordered reading list: the repo's mental-model docs (CLAUDE.md, engineering
docs, glossary), then the key source files this change touches — read each
before editing it.»

## Project conventions

«The rules a reviewer would reject violations of, with exact commands: package
manager, check commands (typecheck / test / lint), testing discipline (what may
be faked, where fixtures live), scope limits (focused runs vs global suites),
comment and naming style. Pull these from the repo's own docs — don't invent.»

## Commit discipline

- «Unit of work per commit (slice / workstream / logical change) and the
  message style, taken from `git log`.»
- Run «check commands» before each commit; never commit red.
- «Co-Authored-By trailer if this repo + provider use one.»
- If you cannot finish everything, finish the current unit cleanly (green,
  committed) and say precisely where you stopped — a clean partial beats a
  broken whole.

<!-- OPTIONAL — keep only when the spec hangs on unverified facts: -->
## Verification spikes — run these FIRST

«The facts to confirm as throwaway commands before building. If a spike
contradicts the spec, adapt the implementation and record the deviation with
the evidence.»

<!-- OPTIONAL — keep only when some work is deliberately deferred: -->
## Deferred — do not touch

«What NOT to modify (docs, help strings, …) and where to note staleness in the
report instead of editing.»

## Your final message — the handoff report (this exact shape; the reviewer consumes it verbatim)

1. **What & why** — one paragraph.
2. **Change map** — every file touched → one line on what changed, grouped by commit.
3. **Key decisions** — judgment calls the spec left to you, each with a one-line rationale.
4. **Deviations from the spec** — each with its reason (an empty section must say "none").
5. **Flagged items** — anything underspecified or wrong you stopped on rather than guessed past.
6. **Test results** — every command you ran and its outcome, plus an account of
   every test file you touched: the command that exercised it, or — if you did
   not run it — say so explicitly with the reason. A suite you couldn't run is
   reported, never silently skipped.
7. **Where to look hardest** — the riskiest or most complex changes, named
   files/functions, so review starts there. Point; do not self-grade.
8. **Commits** — `git log «sha»..HEAD --oneline`.
