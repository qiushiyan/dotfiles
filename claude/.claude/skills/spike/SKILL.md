---
name: spike
description: "Settle a design question by building throwaway code on a simplified foundation, before the implementation commits to the answer."
disable-model-invocation: true
---

# Spike — settle a question by running it

A spike is **throwaway code that answers one question**. What it returns is a verdict; the code is scaffolding, and it burns. Its place is between a settled plan and the build — the plan rests on a belief that reading could not settle, and the real implementation is an expensive place to discover it was wrong. A spike is allowed to kill the plan; one that could only ever confirm was never an experiment.

## Process

1. **Name the question, and both verdicts.** It comes from the plan — the assumption the design leans hardest on and has the least evidence for, which a consult synthesis usually already names as an open question or a point the voices split on. Several candidates means taking the one whose being wrong would cost the most to discover mid-build. State it as a claim that could turn out false, then write what you must *observe* to call it true, and what observation would send the design back — in program output, not impressions. If reading the code answers it, read the code; if a test in the real project answers it, write that test; if nothing the plan rests on can be settled by running something, say so and skip the spike. Done when the claim and both observable outcomes are written down and no code exists yet.

2. **Draw the line between real and faked.** The thing under test stays **real** — the actual module, the actual primitive, the actual library version — and everything it stands on shrinks to the smallest shape that still exercises it. A spike that reimplements the thing it is testing proves the reimplementation works and nothing else. The fakes are where a spike lies to you, so test each one: would the verdict change if this fake were the real thing? If it could, that fake is load-bearing and has to become real. Done when you can name in a line each what is real and what is faked, and why no fake can flip the verdict.

3. **Build it thin.** Reach the real code the way the project already reaches it — its test runner, an existing entry script, its dev server. A fresh standalone entry point is the classic way to lose a day in a workspace repo to module resolution the test runner had already solved: the product's overhead is what you are escaping, not the toolchain's. One command to run it, and nothing in it that outlives the question — no tests, no abstractions, no error handling past what keeps it running. What it persists or mocks follows the line you drew above, never a blanket rule: persistence is sometimes the very thing under test. Print the full relevant state at each step — the output is the evidence, and a bare pass/fail cannot be re-read tomorrow. Set a time box before you start; blowing through it is itself a finding, that the shape is harder to stand up than the plan assumed, and it is worth more said out loud than pushed through.

   Give it a home the project already reserves for throwaway work — a `playgrounds/` tree, a `scratch/` dir, a gitignored `*.local` path — and the session scratchpad when it reserves none. Gitignored is not out of the way: a stray scratch file still surfaces in the next typecheck or lint run and reads there as a real failure. Done when one command runs it and the project's own checks are as clean as they were before.

4. **Run it and return a verdict.** VERIFIED or NOT VERIFIED, carrying the output that decides it rather than your summary of the output. Report what happened before what you take it to mean — the surprise a spike turns up is usually worth more than the answer it was sent for, and it only survives if the run is reported straight. Half a verdict is not one: name the part that stayed unsettled and what would settle it. Done when a reader who never saw the run could reach your verdict from the evidence you quote.

5. **Fold it in, then burn it.** The verdict amends the plan — adopted into the design, or, on NOT VERIFIED, carried back to the user and to /consult when the shape itself is now in question, plainly rather than patched around. The question, the verdict, and its evidence go where the plan lives, durable; the code does not follow them. Delete it, or leave it in the throwaway home it was built in. Done when the plan carries the verdict and the working tree carries nothing the implementation didn't ask for.
