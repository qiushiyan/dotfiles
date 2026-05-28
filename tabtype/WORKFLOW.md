# Daily Workflow

This is the list of prompts I use daily when developing with two AI coding agents — one acting as **implementer** (drafts specs, plans, code) and one as **reviewer** (critiques each artifact). I paste responses between them using snippets defined in `.config/tabtype/config.json`.

The full arc covers a single feature from problem framing through PR. Most steps can be skipped or repeated depending on the task; the helpers at the end fit anywhere.

## Spec stage

1. **`think-holistic`** → **both** agents in parallel. Frames the problem and proposes 2–3 approaches grounded in the actual code, before committing to a direction. Usually the first prompt of a session.

2. **`compare-notes`** → implementer. After both agents respond to `think-holistic`, paste the reviewer's analysis at the end of `compare-notes` and send to the implementer to synthesize the two views before committing to a direction.

3. **`write-spec`** → implementer. With a direction settled, the implementer writes the spec to `docs/superpowers/specs/`. The spec stays moderately technical but defers line-level details, test design, doc plans, and precise commit order.

4. **`review-spec`** → reviewer. Critiques the spec using the three-part altitude lens. Output is structured feedback.

5. **`update-spec`** → implementer. Paste the reviewer's feedback at `$0`. The implementer assesses each point (validity → update or pushback) and revises the spec.

6. *(common for nontrivial specs)* **`review-spec-again`** → reviewer. Re-checks whether the round-1 feedback was actually integrated, or hand-waved.

7. *(common for nontrivial specs)* **`update-spec-again`** → implementer. Round-2 feedback applied inline, no formal validity gate. Focus is converging.

## Plan stage

8. **`tdd-plan`** (or `tdd-plan-strict` / `start-plan` for non-TDD work) → implementer. With the spec settled, the implementer writes a detailed plan: vertical slices, specific test cases, helper sketches, fixture shape, line-level references for existing code. Stops short of full code bodies.

9. **`review-plan`** → reviewer. Critiques the plan against the TDD and architecture skills, applies the altitude lens.

10. **`update-plan`** → implementer. Paste feedback at `$0`. The plan gets revised.

11. *(rare)* **`review-plan-again`** / **`update-plan-again`** → round-2 for plans. Usually one iteration suffices.

## Implementation stage

12. *(no snippet)* Implementation. The implementer writes code per the approved plan, doing the actual red-green-refactor cycles.

13. **`commits-summary`** + **`review-implementation`** → reviewer. Round-1 code review. The `commits-summary` block gets pasted in first for high-level context. The reviewer evaluates correctness, test quality, plan deviation, and whether the implementation actually solves the spec's problem.

14. **`respond-review`** → implementer. Paste reviewer feedback at `$0`. The implementer analyzes each point first — **no code changes yet**. The analysis-first gate matters here because code changes are expensive.

15. *(no snippet — manual prompt)* "Go ahead and apply." After reviewing the analysis, I tell the implementer to make the agreed changes.

16. **`review-implementation-again`** → reviewer. Round-2 code review on the updated implementation. Focus shifts to "was the previous feedback actually addressed?"

17. **`respond-review-again`** → implementer. Paste round-2 feedback at `$0`. The implementer applies fixes inline, no analysis gate — this round is about converging.

## Wrap-up

18. **`pr-description`** → implementer. Drafts the PR description aimed at a technical colleague who won't read the diff.

19. *(optional)* **`find-similar-bugs`** → implementer. Before committing, sweeps the codebase for other places likely to have the same bug pattern.

## Helpers that fit anywhere

- **`list-assumptions`** — when you suspect the agent is guessing about data, intent, or system state. Forces categorization into verified / likely / speculative.

- **`trace-execution`** — when you need to understand an existing code path step-by-step. Useful before refactors or when debugging unfamiliar territory.

- **`commits-summary`** — standalone context block to bring any agent up to speed on a series of commits without making them review commit-by-commit.

- **`smart-adapt-skills`** — meta reminder when an agent is using skill files: adapt the principles, don't apply pedantically.

- **`technical-difficulty`** — reframes what "hard" means when discussing scope or complexity (impact and uncertainty, not lines changed).
