# Daily Workflow

This is the list of prompts I use daily when developing with two AI coding agents — one acting as **implementer** (drafts specs, plans, code) and one as **reviewer** (critiques each artifact). I paste responses between them using snippets defined in `.config/tabtype/config.toml`.

The full arc covers a single feature from problem framing through PR. Most steps can be skipped or repeated depending on the task; the helpers at the end fit anywhere.

## Spec stage

1. **`think-holistic`** → **both** agents in parallel. Frames the problem and proposes 2–3 approaches grounded in the actual code, before committing to a direction. Usually the first prompt of a session.

2. **`compare-notes`** → implementer. After both agents respond to `think-holistic`, paste the reviewer's analysis at the end of `compare-notes` and send to the implementer to synthesize the two views before committing to a direction.

3. **`write-spec`** → implementer. With a direction settled, the implementer writes the spec to `docs/superpowers/specs/`. The spec stays moderately technical but defers line-level details, test design, doc plans, and precise commit order.

4. **`review-spec`** → reviewer. Critiques the spec using the three-part altitude lens. Output is structured feedback.

5. **`update-spec`** → implementer. Paste the reviewer's feedback at `$0`. The implementer assesses each point (validity → update or pushback) and revises the spec.

6. *(common for nontrivial specs)* **`review-spec-again`** → reviewer. Re-checks whether the round-1 feedback was actually integrated, or hand-waved.

7. *(common for nontrivial specs)* **`update-spec-again`** → implementer. Round-2 feedback applied inline, no formal validity gate. Focus is converging.

## Stage transition

8. **`compact-for-plan`** → implementer. Just before the plan stage. Invokes `/compact` with a structured prompt that preserves the settled spec, architectural direction, and rationale while dropping brainstorming alternatives, cross-agent synthesis, and round-1 critiques. Shifts the implementer from creative-divergent mode to focused-execution mode.

## Plan stage

9. **`tdd-plan`** (or `tdd-plan-strict` / `start-plan` for non-TDD work) → implementer. With the spec settled, the implementer writes a detailed plan: vertical slices, specific test cases, helper sketches, fixture shape, line-level references for existing code. Stops short of full code bodies.

10. **`review-plan`** → reviewer. Critiques the plan against the TDD and architecture skills, applies the altitude lens.

11. **`update-plan`** → implementer. Paste feedback at `$0`. The plan gets revised.

12. *(rare)* **`review-plan-again`** / **`update-plan-again`** → round-2 for plans. Usually one iteration suffices.

## Implementation stage

13. *(no snippet)* Implementation. The implementer writes code per the approved plan, doing the actual red-green-refactor cycles.

### Mid-point checkpoint *(optional — for large implementations, e.g. 10+ slices)*

When the work is large, I manually pause the implementer at a commit partway through (say slice 4 or 5) and run a checkpoint review before it continues. Catching a structural problem here is far cheaper than at the final review, and it compounds across every remaining slice.

14. **`midpoint-status`** → implementer. The paused implementer reports where it is: slices done, slices left, and — most usefully — deviations and surprises against the plan. A status snapshot, not a self-review.

15. **`review-midpoint`** → reviewer. Paste the status at `$0`. The reviewer does two jobs: reviews the completed slices (weighting foundational issues that will compound) and guides the rest (gotchas, plan course-corrections, reuse tips). Unreached slices are intentionally undone, not defects.

16. **`respond-midpoint`** → implementer. Paste the review at `$0`. The implementer triages each point into fix-now / fold-into-remaining-slices / disagree — **no code changes yet** — then summarizes the updated plan and waits for my go-ahead. After I greenlight, it fixes the now-problems first, then resumes the remaining slices.

17. *(optional — after a long implementation, when context is heavy)* **`compact-for-review`** → implementer. Before the review cycle, `/compact` to a focused window: keep the implementation status, the load-bearing mental model and critical files, and the key decisions + why — drop the step-by-step build process. Readies the implementer to write a sharp handoff and respond to review from first principles. Usually the review that follows is `review-implementation`, but not always.

18. **`implementation-handoff`** → implementer. With the work finished, the implementer writes a structured handoff: what changed and why, a change map with the load-bearing files marked, key decisions and tradeoffs, deviations from the plan, test coverage, and — critically — where the reviewer should look hardest. It orients the review and shifts the framing to the person who knows the code best. Supersedes the bare `commits-summary` as the review's context block.

19. **`review-implementation`** → reviewer. Round-1 code review. Paste the handoff at `$0` for context. The reviewer evaluates correctness, test quality, plan deviation, structural quality, and whether the implementation actually solves the spec's problem.

20. **`respond-review`** → implementer. Paste reviewer feedback at `$0`. The implementer analyzes each point first — **no code changes yet**. The analysis-first gate matters here because code changes are expensive.

21. *(no snippet — manual prompt)* "Go ahead and apply." After reviewing the analysis, I tell the implementer to make the agreed changes.

22. **`review-implementation-again`** → reviewer. Round-2 code review on the updated implementation. Focus shifts to "was the previous feedback actually addressed?"

23. **`respond-review-again`** → implementer. Paste round-2 feedback at `$0`. The implementer applies fixes inline, no analysis gate — this round is about converging.

## Wrap-up

24. *(optional — when the session is running long)* **`compact-for-cleanup`** → implementer. When implementation is essentially done and polished but small non-blocking tasks remain (docs, minor fixes, cleanup), `/compact` to a focused window on the finished code: preserves what was built and the leftover task list, drops the whole spec → plan → review journey. Unlike `compact-for-plan`, nothing about planning follows — you just work the remaining tasks.

25. **`pr-description`** → implementer. Drafts the PR description aimed at a technical colleague who won't read the diff.

26. *(optional)* **`find-similar-bugs`** → implementer. Before committing, sweeps the codebase for other places likely to have the same bug pattern.

## Helpers that fit anywhere

- **`list-assumptions`** — when you suspect the agent is guessing about data, intent, or system state. Forces categorization into verified / likely / speculative.

- **`trace-execution`** — when you need to understand an existing code path step-by-step. Useful before refactors or when debugging unfamiliar territory.

- **`commits-summary`** — standalone context block to bring any agent up to speed on a series of commits without making them review commit-by-commit.

- **`smart-adapt-skills`** — meta reminder when an agent is using skill files: adapt the principles, don't apply pedantically.

- **`technical-difficulty`** — reframes what "hard" means when discussing scope or complexity (impact and uncertainty, not lines changed).
