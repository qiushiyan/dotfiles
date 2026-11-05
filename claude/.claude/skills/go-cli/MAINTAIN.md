# A maintenance pass over a personal Go CLI

The user runs this pass on their tools every few weeks, so the tool, not a
request, sets where to look. Find what would most improve it: answers it
gets wrong, paths that fail under real use, slowness its callers feel,
structure that makes every change cost more, and tests that guard nothing. Prove each
finding by running something. Then build what the proof supports.

You are done when every finding is either fixed and verified, or put to the
user as a decision with your recommendation, and the report is written.
Stop there. A review round comes next, so don't open a PR, install, or call
the work ready.

## Start from use, change and the last pass

Most past passes found their headline defects in how the tool is used, not
in its code. Before judging the code, gather:

- **Use.** Search past sessions with Obelisk (`~/.agents/skills/obelisk/SKILL.md`)
  for runs of the tool: the commands agents ran, the errors and retries,
  what they did after reading the output, and where they worked around it.
  Read the tool's own logs and state where it keeps them.
- **Change.** `git log` shows the hot spots and the fixes that keep coming
  back. Weight the structural lens toward what changes most.
- **The last pass.** `EVIDENCE.md`, `docs/` and earlier maintenance commits
  say what was measured, fixed or rejected. An idea rejected with a reason
  stays rejected unless you have new evidence.

A request the user adds, such as a feature or an area to look at, joins the
pass and is already approved. Design a feature after the structural
findings, on the shape you recommend, and say so where that shape still
waits on the user.

## Where to look

A lens that finds nothing gets one line in the report.

- **Wrong answers and robustness.** Reproduce each suspected defect before
  fixing it, using the design moment in `../spike/SKILL.md`.
- **Performance.** The traps are in `SKILL.md` § Performance traps, beside
  this file. Time the command the way its callers run it. Other passes may
  be loading the machine, so alternate runs of the old and new builds and
  report how far the repeats spread. For a Go benchmark, use `-count=10` and
  compare with `go run golang.org/x/perf/cmd/benchstat@latest`.
- **Structure.** `../thermo-nuclear-code-quality-review/SKILL.md` is written
  for a branch's diff; ask its questions of the whole tool. Its 1,000-line
  and type-cast rules prompt judgment here; they are not gates. Apply the
  deletion test from `../codebase-design/SKILL.md` to each module you
  suspect is shallow. Hold the result to `SKILL.md` § Module design.
- **Tests.** `../test-audit/SKILL.md`, at area scope for each package, or
  its `CAMPAIGN.md` when one reader cannot hold the whole suite.
- **Toolchain.** These need no install:

  ```
  go fix -diff ./...                                         # prints nothing on a current tree
  go run golang.org/x/tools/cmd/deadcode@latest ./...        # unreachable from main
  go run golang.org/x/tools/cmd/deadcode@latest -test ./...  # unreachable even from tests
  go run golang.org/x/vuln/cmd/govulncheck@latest ./...
  go list -m -u all                                          # a newer version shows in [brackets]
  ```

  A function in the first deadcode list but not the second is kept alive
  only by tests, so it is a candidate for the test audit. A module behind
  its latest version gets updated when its changelog gives a reason, such
  as a fix this tool needs or a vulnerability.

## Working

- Run spikes and mutations in a scratch clone or the session scratchpad,
  so a mutated line never reaches a commit or a build.
- Commit verified fixes the way the repository's `AGENTS.md` says: on a
  branch, or on `main` where it says so. Where a skill here would open a
  PR, the report takes its place.
- Fix and verify what needs no decision from the user. For a change that
  does need one, such as documented behaviour, output other repositories
  parse, a new command or a new dependency, build a prototype, so the user
  decides from a working patch.
- Other sessions run on this machine at the same time, often passes over
  other tools. Stop only processes you started, by PID. A `pkill -f`
  pattern once killed another session's mutation run.

## The report

Lead with what changes for the person using the tool: wrong answers fixed,
measured speedups, guards added. Give each its evidence: the command, and
the output or the before and after numbers.

Then list the decisions that are the user's. Give each what it means for
the person using the tool, the options, and your recommendation.

End with **For the next pass**: the baselines worth comparing (timings,
suite size and runtime, deadcode counts), the ideas you rejected with the
reason, and what you left and why.
