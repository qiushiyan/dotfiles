---
name: strategic-review
description: Strategic review of one PR from a fresh session.
disable-model-invocation: true
argument-hint: "[PR number or URL] [optional: a question this PR raises]"
requires:
  - lessons:collaboration/finding-classes.md
  - lessons:codebase-design/composition.md
  - lessons:testing/test-quality.md
---

# Strategic review of a pull request

You are reviewing a pull request that someone else built, in a session that
starts fresh. The user opens it only for PRs big or consequential enough
that a design-level read is worth a session of its own. The build has
usually already passed its own review rounds, which read the change inside
the builder's framing. Your value is what they cannot see. That includes
the defects they missed, the text that misleads the model, the handling
those rounds piled up without a case that needs it, and the reshape that
would make the design simpler.

The deliverable is one report the user decides from: is it ready, what must
change before merge, and what would make it better. Report every problem
you can point at code for, minor ones included. The user sorts them and
usually answers "fold these in", in this same session. Change no code
until then; [Folding the findings in](#folding-the-findings-in) says how
to build it once they do.

## How to work

1. **Intent first.** Read the PR description, the spec or issue it links,
   and its commits, and its CI status (`gh pr checks`): a red check is a
   finding, or a flake shown by a rerun or the same failure on the base.
   Then read the project's map of the area the PR touches.
   In PlanLab (`planlab-ai/main`), a PR touching Loopy or the steward has
   its map in `.agents/skills/pl-loopy-onboarding/`: read its `SKILL.md`,
   then the files under `routes/` that the PR's files and goal touch, and
   the docs those routes point to. Read it as a map rather than invoking
   it, because onboarding ends its turn on a first reply and this review
   has to carry on. Elsewhere, use the onboarding route the project's
   `CLAUDE.md` names, if any. Then write down, in two or three sentences,
   what the change is for and what a user gets from it. Every finding is
   judged against that statement.
2. **Read the standards in full** before reviewing:
   - `~/dotfiles/claude/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md`,
     for code quality and the "code judo" reshape;
   - `~/dotfiles/claude/.claude/skills/codebase-design/SKILL.md` with
     `~/.config/lessons/codebase-design/composition.md`, for design;
   - `~/.config/lessons/testing/test-quality.md`, for tests: what earns a
     place in a suite, the shapes of a test that cannot fail for a real
     reason, and why review drifts toward asking for more tests;
   - `~/dotfiles/claude/.claude/skills/prompt-engineering/SKILL.md`, when the
     PR description or the touched files show a model-facing change: a
     prompt section, tool description, tool result, command help, refusal or
     error a model reads, a skill an agent loads, or what one of the agent's
     tools does. Read it with the project's prompting guide (PlanLab:
     `docs/loopy/prompting-guide.md` and the onboarding's
     `routes/prompting.md`). A PR with no such change skips it, and the
     "What the model is told" lens with it.
3. **Review.** A PR too large to read whole in one pass splits into two to
   four broad areas, each read completely by a subagent. Hand each one the
   intent, the area's files and diff base, the lenses below, the standards'
   paths, and anything you already suspect there. They are read-only, may
   run focused tests and throwaway probes in your scratchpad, and say for
   each finding whether a probe confirmed it or it was read from the source.
   Keep for yourself the read no single area shows: how the change joins the
   existing code, whether it duplicates a mechanism that already exists,
   which reshape would delete a concept, and where earlier review rounds
   patched the same place twice. Start the report only once every
   area has returned, and wait on their completion notices rather than a
   scheduled wakeup: a wakeup prompted with `/strategic-review` fires later
   as a request for a second review.
4. **Verify before you report.** Re-read the cited code for every finding
   the report will carry, because reviewers state wrong findings with the
   same confidence as real ones. Every finding an area reported reaches the
   report or is dropped here with its reason, since past reports lost more
   findings this way than any other. Say which findings rest on reading
   alone.

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
- **Rounds that patched the same place.** Commit bodies name the round
  that asked for them ("review-r2 F10", "Codex P1 on #8860"), and the bot
  threads are on the PR. They show where review fixed one area more than
  once: a later fix repairs an earlier one, or each round adds machinery
  for one more case. Read that area's accumulated diff and ask what
  premise the fixes shared. When you can name it and test it, the pile is
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
- **What the model is told**, when step 2 found a model-facing change. For
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
- **Product scope.** Name any behaviour the PR changes outside what it
  describes, and who it reaches: another upload flow, another consumer of a
  shared type.
- **Claims.** Every claim in the PR body and spec about what the code does,
  checked against the code.

## The report

Open with the verdict, then the short list to fix before merge. Then the
findings grouped by lens. Give each one a severity (critical blocks merge,
moderate is fixed before merge, minor is optional) and its class tag from
`~/.config/lessons/collaboration/finding-classes.md`, then where it is
(file:line), the evidence, and how it was confirmed. A finding that asks
for handling carries its `reaches:` line. Give the fix, including the reshape when one
would make the problem disappear, and name the callers and invariants the
fix changes, since a right finding with a wrong fix still ships a defect.
Answer the user's question if they asked one; if it does not fit this PR,
say so and answer the nearest question that does.

Then two short lists, each omitted when empty. **Investigate:** serious
cases whose reachability you could not settle, each with the observation
that would settle it. **Known limits, not built:** cases nothing reaches
today or whose cost is minor, one line each with what would earn handling.

<example>
**Known limits, not built**
- An export started while the same workspace is mid-import reads a half-written
  sheet (`export_job.ts:142`). Imports and exports share one queue per
  workspace, so they never overlap today. Earns a lock when the queue splits.
- The client gives up on HTTP 429 without backing off (`client.ts:57`). Its
  one upstream is an internal service with no rate limit. Earns backoff when
  a rate-limited upstream joins.
</example>

Close with what you checked and found correct, so the user knows what the
verdict covers.

## Folding the findings in

When the user folds the findings in, build them as one change rather than
a patch per finding. Land the reshapes and the deletions first, since
they make some findings disappear, then fix each
remaining finding at the code that owns it, one commit per owner. "Fold
these in" and "fold all in" cover every finding, minors included, since a
problem fixed now is one no later session has to rediscover, and the
investigate list: run each item's observation first, build the ones it
shows are reached, and move the rest to the known limits. The known limits
stay unbuilt unless the user names one; that a fix is cheap does not earn
it a place.

Tests follow the Tests lens, not the finding list: pin the fragile
behaviours it named, and any fix that changes what a caller depends on, at
the owning boundary, extending an existing case where one fits. Break the
fixed line and watch each new test go red before trusting it. A fix to
text a model or user reads is pinned, if at all, by the token that
carries its contract rather than the sentence; a finding about naming or
structure gets no test of its own. Delete or rewrite the tests the lens
marked.

Your fixes meet the bar you held the PR to: handling a fix adds is earned by
what reaches it, and a probe you built is not a real caller. The fold is
code you wrote, and unread folds have shipped faults that CI and the bots
then found. With push rights and network, push to the PR branch, wait with
`gh pr checks --watch` rather than a wakeup, judge each bot finding by these
lenses, and fix what stands, in one round. Without them, say the fold is
unread and name its commits.
