---
name: spike
description: Settle a design question with throwaway code.
disable-model-invocation: true
---

# Spike — settle a question by running it

A spike is throwaway code whose output answers a question that reading cannot. It serves two moments. **Design:** before the build, the plan leans on a belief; a spike tests it and is allowed to kill the plan. **Verification:** around a change, the claim is that the change does what it is for; a spike proves it by running it instead of trusting the diff.

## Decide what would settle it

Write the claim so it could turn out false, and what you would have to observe to call it true or false, in program output. If reading the code settles it, read; if nothing you can run settles it, say so and stop.

- **Design:** test the assumptions the plan fails without, costliest first.
- **Verification:** a change's claims are its own description of itself; its defects sit where those claims meet the rest of the product. Work two fronts and report them apart, so a gap in one cannot hide behind a pass in the other:
  - **Target:** the scenarios the change exists for, driven end to end through the entry point a user or caller uses (the CLI, the API, the page, the running app), with the changed behaviors meeting the way they meet in use: a restart in the middle of a write, the page that renders the new field, the report that totals the changed rows.
  - **Risk:** beyond the target, where the change is fragile or would do the most damage if wrong: paths it shares with other features, the inputs each claim covers beyond the one that shows it working, the next consumer of what it produces, the existing flows through the changed code. Choose by how likely each is to break and how much would break.

## Keep the thing under test real

The code under test stays real: the actual module, library version and running app. Everything around it shrinks to what still exercises it. When the claim is about specific data, that data stays real too: the production row, the customer's file, the verbatim prompt. Name each fake and ask whether it could change the verdict; a fake that could is where the defect will hide, so make it real. A spike that reimplements what it tests proves only the reimplementation.

Reach the code the way the project already does (its test runner, an entry script, its dev stack), and put the spike where the project keeps throwaway work (a `scratch/` or `playgrounds/` dir, a gitignored `*.local` path), or the session scratchpad. A stray file still trips the next typecheck or lint, so leave the project's checks as clean as you found them.

## Run it against a baseline

Print the state at each step; the output is the evidence. A claim about timing or concurrency gets repeated runs; say how many, and treat a single green as unsettled.

When the change alters existing behavior, run the same command on a baseline: a worktree at the commit before the change. A fix must be red there and green here; anything else that differs is a finding. A reproduction built while the fix is still a hypothesis is the same instrument run early: red today is its verdict, and the fixed code reruns it. For a capability the baseline lacks, its red ("no such command") proves nothing; run the existing flows on both instead, which should agree. Remove the worktree once its output is captured.

## Report the verdict

VERIFIED or NOT VERIFIED per claim or target scenario, carrying the output that decides it; in verification, the risk probes follow apart, each with what it showed. Report what happened before what it means: the surprise is often worth more than the answer. VERIFIED covers only what the run drove; name what was not driven and what would settle it. A reader who never saw the run should reach your verdict from what you quote.

Fold the verdict into the plan: adopt it, or on NOT VERIFIED take it back to the user, plainly. Record claim, expected, actual and verdict where the plan lives, or in the report. Then delete the spike or leave it in its throwaway home. A verification claim worth guarding permanently becomes a real test, with the spike as its draft.
