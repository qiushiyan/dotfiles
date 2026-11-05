# A maintenance pass over a personal Go CLI

Run open-ended explorations and evaluations of this tool, looking for the
improvements with the most leverage. Areas include, and are not limited
to:

- **Bugs and robustness:** answers the tool gets wrong, and paths that fail
  under real use.
- **Performance:** slowness its callers feel, at start-up and per call.
- **Codebase organisation:** modules to untangle, layers to delete, logic in
  the wrong package.
- **Wiring and public interfaces:** commands, flags, help, `--json` output
  and package interfaces that a caller or a new reader should find easy to
  understand and hard to misuse.
- **Code review:** the existing code held to the standards below.
- **Tests:** guards missing where breakage is likely, and tests that guard
  nothing.

Run spikes as you go. A hypothesis about speed, a suspected bug or a
refactor's payoff is settled by real numbers and real behaviour, not by
reading. Report what the run showed, including when it kills the idea.

You are done when every finding is either fixed and verified, or put to the
user as a decision with your recommendation, and the report is written.
Stop there. A review round comes next, so don't open a PR, install, or call
the work ready.

## Skills to draw on

- **Code review:** `../thermo-nuclear-code-quality-review/SKILL.md`, a strict
  review for structural simplification. It is written for a branch's diff,
  so ask its questions of the whole tool. Its 1,000-line and type-cast rules
  prompt judgment here; they are not gates.
- **Codebase design:** `../codebase-design/SKILL.md`, the vocabulary of deep
  modules, seams and the deletion test. Apply the deletion test to each
  module you suspect is shallow.
- **Test audit:** `../test-audit/SKILL.md`, which finds the tests to add,
  repair and delete. Use area scope for each package, or its `CAMPAIGN.md`
  when one reader cannot hold the whole suite.
- **Spikes:** `../spike/SKILL.md`. Use its design moment to test a
  hypothesis, and its verification moment to prove a fix.
- **Go conventions:** `SKILL.md` beside this file. Its sections "Module
  design" and "Help and output are the interface" set the bar for
  structure and interfaces, and "Performance traps" lists where these
  tools lose time.
- **Past usage:** `~/.agents/skills/obelisk/SKILL.md`, for searching past
  sessions.

## Start from use, change and the last pass

Most past passes found their headline defects in how the tool is used, not
in its code. Before judging the code, gather:

- **Use.** Search past sessions with Obelisk for runs of the tool: the
  commands agents ran, the errors and retries, what they did after reading
  the output, and where they worked around it. Read the tool's own logs and
  state where it keeps them.
- **Change.** `git log` shows the hot spots and the fixes that keep coming
  back. Weight structural work toward what changes most.
- **The last pass.** `EVIDENCE.md` and `docs/`, where the tool has them,
  say what was measured, fixed or rejected. An idea rejected with a reason
  stays rejected unless you have new evidence.

A request the user adds, such as a feature or an area to look at, joins the
pass and is already approved. Design a feature after the structural
findings, on the shape you recommend, and say so where that shape still
waits on the user.

## Go tools

None of these needs an install:

```
go fix -diff ./...                                         # prints nothing on a current tree
go run golang.org/x/tools/cmd/deadcode@latest ./...        # unreachable from main
go run golang.org/x/tools/cmd/deadcode@latest -test ./...  # unreachable even from tests
go run golang.org/x/vuln/cmd/govulncheck@latest ./...
go list -m -u all                                          # a newer version shows in [brackets]
GOFLAGS=-count=1 go run github.com/go-gremlins/gremlins/cmd/gremlins@latest \
  unleash --integration --coverpkg ./... --timeout-coefficient 20 --workers 4
```

- A function in the first deadcode list but not the second is kept alive
  only by tests, so it is a candidate for the test audit.
- Update a module that is behind its latest version when its changelog
  gives a reason, such as a fix this tool needs or a vulnerability.
- Gremlins mutates the code and reports each mutant the suite let live.
  Each flag above prevents a false count:
  - Without `--integration` and `--coverpkg`, it runs only the mutated
    package's tests, so code guarded through `cmd/` tests looks unguarded.
  - With cached tests, its timeout is set from a near-zero baseline, and
    mutants time out instead of being judged.

  On gopen (about 700 lines) the run takes 3 minutes. On a larger tool,
  pass the package you are auditing as its path argument.
  A lived mutant is a candidate gap; the test audit decides whether it
  matters.
- For a Go benchmark, use `-count=10` and compare runs with
  `go run golang.org/x/perf/cmd/benchstat@latest`.

## Working

- Run spikes and mutations in a scratch clone or the session scratchpad,
  so a mutated line never reaches a commit or a build.
- Commit verified fixes on `main` where the repository's `AGENTS.md` says
  to commit there. Otherwise commit them to one branch for the pass, and
  leave it unmerged: the closeout after the review merges it. Where a skill
  here, such as the test audit's campaign, would open a PR, the report
  takes its place.
- Fix and verify what needs no decision from the user. For a change that
  does need one, such as documented behaviour, output other repositories
  parse, a new command or a new dependency, build a prototype on a branch
  of its own, named in the report, so the user decides from a working
  patch.
- Time a command the way its callers run it. Other passes may be loading
  the machine, so alternate runs of the old and new builds and report how
  far the repeats spread.
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
suite size and runtime, deadcode and lived-mutant counts), the ideas you
rejected with the reason, and what you left and why.
