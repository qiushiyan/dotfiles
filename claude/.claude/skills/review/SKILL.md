---
name: review
description: "Get an independent code review of the branch's committed work from a fresh AI session (codex or claude), then judge and apply the findings."
disable-model-invocation: true
---

# Review — independent review of committed work

The mirror of /delegate: there the host reviews a delegate's commits; here a fresh session ("the reviewer") reviews commits the host or the user wrote. The invariant both serve: **whoever wrote the code never gets to be its only reviewer.** The reviewer reads cold and reports findings; the host verifies each one against the code, fixes what survives, and answers to the user for every verdict. The review being bought is **strategic, not tactical**: findings that step back and reshape the design — a new module, a shared extraction, different wiring — not optimizations inside the implementation's frame. The brief's posture section is what demands this; it holds for every dispatch.

Engine: `node ~/.claude/skills/sidekick-runtime/turn.mjs`. Read [ENGINE.md](../sidekick-runtime/ENGINE.md) before passing a user-supplied `--model`/`--effort` value (the valid values differ per provider) and whenever a turn ends with a status other than `ok` (it maps each status to the recovery move).

## Process

1. **Fix the range.** The unit of review is commits: find the baseline sha (one the conversation already knows — a delegate baseline, the merge-base with the default branch — or one the user names) and confirm the contents with `git log <base>..HEAD --oneline`. A dirty tree means uncommitted work escapes review: have the user commit, stash, or explicitly accept reviewing the commits alone. Done when the base sha is settled and every commit in the range belongs to the work under review.

2. **Assemble the implementation report** — the map the brief hands the reviewer. Source it by provenance:
   - a /delegate built it → its handoff report from `result.md`, verbatim;
   - this session built it → write the report now: what & why, change map with the load-bearing files marked, key decisions, deviations from spec/plan, test coverage and its altitude, where to look hardest. A guided map, **not a self-review** — point at risk and complexity, never grade your own quality; grading is the reviewer's job;
   - the user built it elsewhere → reconstruct the what & why and the change map from the commits and diffs, and open the report with "reconstructed from commits, not implementer-authored" so the reviewer weighs it accordingly.

3. **Write the brief** — one self-contained file in the session scratchpad, started from [BRIEF-TEMPLATE.md](BRIEF-TEMPLATE.md). The reviewer starts cold, with none of this conversation: orientation, where the authority on WHAT lives (spec/plan paths, or an inline goal statement when no spec exists), the settled decisions it must not relitigate, the commit range, the reading order, the deliberately-deferred work it must not flag, and the report from step 2 last. Done when a cold reader could deliver the review without this conversation.

4. **Dispatch** one background turn via Bash `run_in_background` (a reviewer that reads seriously can exceed the 10-minute foreground cap):

   ```
   node ~/.claude/skills/sidekick-runtime/turn.mjs \
     --provider codex --prompt-file <brief> --baseline <base-sha> \
     --timeout-min 30 --label review
   ```

   Default is exactly that: one codex reviewer, no `--model`/`--effort` flags — the user's codex config governs, and cross-family review (codex on code a claude host wrote) is part of the independence, not just the economics. `--baseline` makes `collect.mjs` print the reviewed range alongside the findings. More reviewers only when asked; each gets the same brief and never another's output. A claude reviewer needs an explicit strong model (e.g. `--model opus`) — never your own session's default by accident. After dispatching, echo provider, effective model/effort, and the engine's `watch:` / `takeover:` lines (a takeover is for after the turn finishes).

5. **Judge pass on collection.** On the task notification, `node ~/.claude/skills/sidekick-runtime/collect.mjs <out-dir>` prints the findings; a status other than `ok` → ENGINE.md's status table. Verify every finding against the actual code — read the cited lines, retrace the claimed failure path — before accepting it: reviewers state hallucinated issues with the same confidence as real ones. And you wrote this code, so the bias cuts both ways — adopting findings to be agreeable and rebutting them to defend your own work are equal failures. Meet a structural reframing on its merits; a narrower local patch is not a rebuttal. A finding that asks for a new test earns the same scrutiny as one that asks for a code change — locate the bug it would catch, and the absence of a test already catching it; "more coverage" is not a defect, and a test the reviewer wants deleted is verified the same way. Done when every finding carries a verdict: confirmed, rebutted with a first-principles reason, or foundational — those the user decides.

6. **Fix, and account for the tests.** Apply the confirmed criticals and moderates yourself — in this skill the host is the implementer; minors go by user preference. A confirmed structural finding gets the actual reshape, not a shrunken local version of it and not a deferral to "future work". Every confirmed bug also indicts the suite: decide whether a test was missing (coverage gap) or present but weak (wrong altitude, over-mocked, asserting internals), and add / strengthen / delete accordingly. Done when the project's checks are green over the fixes.

7. **Round 2, when the fixes were substantive:** send a per-finding summary of what changed — rebuttals included — into the **same session** (`--resume <sessionId from meta.json>`). The question is narrow: was each point actually integrated or hand-waved, and did the fixes regress anything? Converging, not relitigating. For light fixes, handing the user the takeover command is the cheap substitute.

8. **Report** to the user: the verdict finding by finding (fixed / rebutted with the reason / escalated as foundational), what the fixes changed, the check results, and the resume + takeover commands.
