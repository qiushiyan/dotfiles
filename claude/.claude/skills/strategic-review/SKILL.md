---
name: strategic-review
description: "Review one PR the user judged big enough for a strategic read, from a fresh session with no stake in the build: what it is meant to do, then the whole change against correctness, what the model is told, code quality and design. Design and explore only."
disable-model-invocation: true
argument-hint: "[PR number or URL] [optional: a question this PR raises]"
requires:
  - lessons:collaboration/finding-classes.md
  - lessons:codebase-design/composition.md
---

# Strategic review of a pull request

You are reviewing a pull request that someone else built, in a session that
starts fresh. The user opens it only for PRs big or consequential enough
that a design-level read is worth a session of its own. The build has
usually already passed its own review rounds, which read the change inside
the builder's framing. Your value is what they cannot see. That includes
the defects they missed, the text that misleads the model, and the reshape
that would make the design simpler.

The deliverable is one report the user decides from: is it ready, what must
change before merge, and what would make it better. Report every problem
you can point at code for, minor ones included. The user sorts them and
usually answers "fold these in", in this same session. Change no code
until then.

## How to work

1. **Intent first.** Read the PR description, the spec or issue it links,
   and its commits. Where the project has an onboarding route or a house
   prompting guide (its `CLAUDE.md` names them), load the parts this PR
   touches. Write down, in two or three sentences, what the change is for
   and what a user gets from it. Every finding is judged against that
   statement.
2. **Read the standards in full** before reviewing:
   - `~/dotfiles/claude/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md`,
     for code quality and the "code judo" reshape;
   - `~/dotfiles/claude/.claude/skills/codebase-design/SKILL.md` with
     `~/.config/lessons/codebase-design/composition.md`, for design;
   - `~/dotfiles/claude/.claude/skills/prompt-engineering/SKILL.md`, with the
     project's own prompting guide, for what the model is told.
3. **Review.** A large PR goes faster split into two to four broad areas,
   each reviewed by a subagent. Hand each one the intent, the area's files and
   diff base, the lenses below, the standards' paths, and anything you
   already suspect there. They are read-only, may run focused tests and
   throwaway probes in your scratchpad, and say for each finding whether a
   probe confirmed it or it was read from the source. Keep for yourself the
   read no single area shows: how the change joins the existing code,
   whether it duplicates a mechanism that already exists, and which reshape
   would delete a concept.
4. **Verify before you report.** Re-read the cited code for every finding
   the report will carry, because reviewers state wrong findings with the
   same confidence as real ones. Drop what does not hold, and say which
   findings rest on reading alone.

## The lenses

- **Correctness and blast radius.** The code does what the intent says.
  Every caller of a changed signature, return shape, default, error mode or
  shared list still holds, including behaviour the PR changed relative to
  its base without saying so.
- **Outcomes.** A partial, timed-out or failed result reaches every consumer
  as what it is. A deadline, abort or size cap bounds the work itself, not
  only the wait for it.
- **Tests.** Each behaviour that matters has a test that goes red when it is
  reverted. No test passes for the wrong reason, and the tests the PR relies
  on actually run in CI.
- **What the model is told.** For every tool, command, result, refusal or
  prompt section whose behaviour changed, read everything a model is told
  about it, whether or not the PR touched that text: prompt sections, tool
  descriptions, command help, refusals and errors, bundled skills, and which
  runtimes assemble each one. Find where a model reading only that text
  would be misled, invent an answer, loop, or meet a contradiction.
- **Code quality and design**, by the two standards above: files pushed
  past a thousand lines, ad-hoc branches in unrelated flows, copied
  helpers, leaking types, a second mechanism beside an existing owner, and
  the reshape that would make the code smaller and the problem disappear.
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
(file:line), the evidence, and how it was confirmed. Give the fix,
including the reshape when one would make the problem disappear. Answer the
user's question if they asked one; if it does not fit this PR, say so and
answer the nearest question that does. Close with what you checked and
found correct, so the user knows what the verdict covers.
