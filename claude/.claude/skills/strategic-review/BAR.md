# Review bar

During review, change no PR code; focused tests and scratchpad probes are
allowed. Mark each finding probe-confirmed or read from source.

## Standards

Read each applicable standard in full:

- `~/.config/lessons/collaboration/finding-classes.md`, for finding class tags;
- `~/dotfiles/claude/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md`,
  for code quality and the "code judo" reshape;
- `~/dotfiles/claude/.claude/skills/codebase-design/SKILL.md` with
  `~/.config/lessons/codebase-design/composition.md`, for design, and
  `steering.md` beside it when the PR sets a pattern later changes will
  copy: an entry point, a registry, a kind that keeps growing, a
  migration or a second way beside an old one, the fix for a fault that
  came back or sits in several places;
- `~/.config/lessons/testing/test-quality.md`, for tests;
- `~/dotfiles/claude/.claude/skills/revise-prompt/SKILL.md`, when the
  PR description or the touched files show a model-facing change: a
  prompt section, tool description, tool result, command help, refusal or
  error a model reads, a skill an agent loads, or what one of the agent's
  tools does. Read it with the project's prompting guide (Planlab:
  `docs/loopy/prompting-guide.md` and the onboarding's
  `routes/prompting.md`). A PR with no such change skips it, and the
  "What the model is told" lens with it;
- the emil design skills' review,
  `~/dev/aiforui-skills/emil-ui-review/SKILL.md`, when the PR makes a
  non-trivial UI or UX change, which the brief usually names, with that
  repository's README § Using them in a project with its own design
  system for this project's exceptions. The project's own design rules win over its values, and
  findings keep the report's severity and class tag.

## The lenses

- **Correctness and blast radius.** The code does what the intent says.
  Every caller of a changed signature, return shape, default, error mode or
  shared list still holds, including behaviour the PR changed relative to
  its base without saying so.
- **Outcomes.** A partial, timed-out or failed result reaches every consumer
  as what it is. A deadline, abort or size cap bounds the work itself, not
  only the wait for it.
- **Earned handling.** Handling is a guard, fallback, retry, validator,
  try/catch, clamp, new state or flag, or a test of one case. It earns its
  place when something real reaches the case: production data, a log, an
  external contract, or a reproduction from an input a real caller
  produces; or a path you traced reaches it and missing it means data loss,
  a permission breach, a customer-visible wrong or stuck result, or
  unbounded cost. A test or probe that builds a state nothing real
  produces shows the mechanism, not that the case occurs; a mocked
  timeout a contract allows is real. Read it both ways:
  - *What you ask for.* Each finding that asks for handling carries a
    `reaches:` line: `traced <caller and path>`, `evidence <what showed
    it>`, or `none`. A `none` case, or one whose cost is minor, is not a
    defect whatever its severity would be; it goes to the known limits
    with what would earn it. A serious case whose reachability you could
    not settle goes under investigate, with the observation that would
    settle it. A case something reaches is a finding even when the base
    already had it; say so in the finding.
  - *What the PR holds.* Handling the build or an earlier round added
    without that basis is a finding, and its fix is deletion once you name
    what already covers the case: the boundary that validates it, the
    type or invariant that rules it out, the single caller that never
    produces it. Typical: a check the types already rule out, a try/catch
    on a trusted path, a fallback that hides an invariant nobody stated,
    compatibility for a version that never shipped, a primitive guarding
    its own contract when no caller needs it. Where you cannot name the
    cover, say so and leave the code. If the state should never exist,
    the fix is where it is produced, not a guard where it surfaced.

  <example>
  ```ts
  // The PR adds, in a helper whose only caller is parseRunArgs():
  if (!Number.isFinite(limit) || limit < 1) limit = DEFAULT_LIMIT;
  ```
  **minor · unearned-handling** — `run_args.ts:88`, added in review-r2.
  reaches: none — `parseRunArgs` (`cli.ts:41`) already rejects a
  non-positive limit, and nothing else calls the helper. Fix: delete the
  clamp; the boundary owns it.
  </example>
- **Rounds that patched the same place.** Commit messages, in the context
  file, name the round that asked for them ("review-r2 F10", "Codex P1 on
  #8860"), and the bot threads are on the PR. They show where review fixed
  one area more than once: a later fix repairs an earlier one, or each round
  adds machinery for one more case. Read that area's accumulated diff and
  ask what premise the fixes shared. When you can name it and test it, the pile is
  one finding whose fix is the reshape that removes the condition, and the
  machinery with it; fixes that guard different obligations stay separate
  findings.
- **Tests**, by `test-quality.md`. Start from the risk, not the test
  files: name the few behaviours in this PR most likely to break and
  costliest when they do, such as an ordering rule, a bound, an outcome
  that can collapse, a permission check, or wiring between processes or
  packages. Each needs a test at the boundary that owns it, one that goes
  red when the behaviour breaks and that runs in CI. Where you can, break
  the guarded line and run the test: wiring you can remove with the suite
  still green is a finding even when every line is covered. Probe in a
  copy under your scratchpad, by the project's rules for worktrees and
  installs; where a test cannot run that way, read it and say so. Then
  weigh the tests the PR added, since each costs upkeep like code. A test
  that pins whole sentences a model or user reads, restates the
  implementation, checks only a mock's arguments, or asserts a value its
  own fixture supplied is a finding, fixed by asserting the token or
  relation a caller depends on, or by deleting it. A test you ask for names
  the bug it would catch and why no existing test catches it.
- **What the model is told**, when the PR shows a model-facing change. For
  every tool, command, result, refusal or prompt section whose behaviour
  changed, read everything a model is told about it, whether or not the PR
  touched that text: prompt sections, tool descriptions, command help,
  refusals and errors, bundled skills, and which runtimes assemble each one.
  Find where a model reading only that text would be misled, invent an
  answer, loop, or meet a contradiction.
- **Code quality and design**, by the thermo-nuclear and codebase-design
  standards: files pushed past a thousand lines, ad-hoc branches in
  unrelated flows, copied helpers, leaking types, a second mechanism beside
  an existing owner, and the reshape that would make the code smaller and
  the problem disappear.
- **What the next change copies**, when you read `steering.md`. Name
  the next change of that kind and walk it as a session that read none of
  the design: what its search finds, what it copies, what fails when it
  skips a step. Where you can, take the easy wrong path
  in your scratch copy and read the failure. A second live shape is the
  design lens's finding; say here which one a search finds first. A fix
  asked for here is earned by the next change, not a runtime case, so its
  `reaches:` line cites what shows the kind growing. It names its
  mechanism and why a stronger one could not hold. A registry or guard for
  a kind nothing shows growing is speculative generality, fixed by leaving
  the code direct.

  <example>
  **moderate · other (unforced step)** — `routes/index.ts:12`. A route file
  missing from `ROUTES` compiles and every suite stays green (probe).
  reaches: evidence — six routes added by four authors since October.
  Fix: a check that lists the directory, since no type sees a file nothing
  imports.
  </example>
- **Product scope.** Name any behaviour the PR changes outside what it
  describes, and who it reaches: another upload flow, another consumer of a
  shared type.
- **Claims.** Every claim in the PR body and spec about what the code does,
  checked against the code.
