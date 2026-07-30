---
name: review
description: "Get a code review of the branch's committed work — a cold AI session, plus the consult voice warm when one shaped the design — then judge and apply the findings."
disable-model-invocation: true
---

# Review — independent review of committed work

The mirror of /delegate: there the host reviews a delegate's commits; here a fresh session ("the reviewer") reviews commits the host or the user wrote. The invariant both serve: **whoever wrote the code never gets to be its only reviewer.** Every review carries a cold read — a session with no stake in the design under review; reviewers report findings, and the host verifies each one against the code, fixes what survives, and answers to the user for every verdict. The review being bought is **strategic, not tactical**: findings that step back and reshape the design — a new module, a shared extraction, different wiring — not optimizations inside the implementation's frame. The brief's posture section is what demands this; it holds for every dispatch.

Dispatching, patterns, and house rules: [DISPATCH.md](../envoy/DISPATCH.md).

## Process

1. **Fix the range.** The unit of review is commits: find the baseline sha (one the conversation already knows — a delegate baseline, the merge-base with the default branch — or one the user names) and confirm the contents with `git log <base>..HEAD --oneline`. A dirty tree means uncommitted work escapes review: have the user commit, stash, or explicitly accept reviewing the commits alone. Done when the base sha is settled and every commit in the range belongs to the work under review.

2. **Assemble the implementation report** — the map the brief hands the reviewer. Source it by provenance:

   - a /delegate built it → its handoff report from `result.md`, verbatim;
   - this session built it → write the report now: what & why, change map with the load-bearing files marked, key decisions, deviations from spec/plan, test coverage and its altitude, where to look hardest. A guided map, **not a self-review** — point at risk and complexity; grading is the reviewer's job;
   - the user built it elsewhere → reconstruct the what & why and the change map from the commits and diffs, and open the report with "reconstructed from commits, not implementer-authored" so the reviewer weighs it accordingly.

   Done when the report maps the range for a cold reviewer — pointing at risk, grading nothing.

3. **Write the brief** — one self-contained file in the session scratchpad, from [BRIEF-TEMPLATE.md](BRIEF-TEMPLATE.md): orientation, where the authority on WHAT lives (spec/plan paths, or an inline goal statement when no spec exists), the settled decisions it must not relitigate, the commit range, the reading order, the deliberately-deferred work it must not flag, and the report from step 2 last. The template's review-lens pointer (`~/.config/lessons/collaboration/review-lens.md`) goes out with every dispatch — it is the posture section. The codebase-design pointers go out as written whenever the range decides structure: new modules, reshaped interfaces, any real refactor; trim them when the work is structurally inert — a version bump, a mechanical syntax migration, a small contained fix — however large the diff. Done when a cold reader could deliver the review without this conversation.

4. **Dispatch**, 60-minute cap, anchored to the range. The shape follows one question: did a consult in this session weigh the design this range implements?

   No consult — one cold reviewer:

   ```sh
   envoy turn --provider codex --prompt-file <brief> --baseline <base-sha> \
     --timeout-min 60 --label review
   ```

   A consult exists — both voices as one fan-out, the consult session continued beside a cold one:

   ```sh
   envoy fan --prompt-file <brief> --baseline <base-sha> \
     --with-from <consult-out-dir> --with codex --timeout-min 60 --label review
   ```

   Warm and cold buy different findings, which is why the pair is the default rather than either alone. The warm voice holds the consult's full context: it is the best judge of follow-through — did the implementation integrate what was agreed, did it dodge the traps its rounds discussed — and, having committed to the design in its own context, a poor judge of the design itself (anchoring to prior positions is measured model behavior, not a hypothetical). The cold voice is the reverse: the unanchored, strategic read this skill exists to buy. The brief stays the complete cold brief; the warm voice re-reads cheaply what it already holds. In the judge pass, weight them by position — the warm voice endorsing the design it helped shape is expected and earns no weight — and agreement between any reviewers earns none either: you verify every finding against the code regardless.

   Collapse to the single cold turn when the user names one voice, when the consult weighed a different design than this range implements, or when the user prefers the cheaper dispatch. Warm-only — the user asking the consult voice itself to do the review — is a follow-through check, not an independent review: run it, and name it that in the report. More cold voices only when the user asks (`--with codex --with claude:opus`).

   `--baseline` makes collection print the reviewed range alongside the findings. Relay the coordinate block, then return — a small, self-contained task while it runs is fair game, as long as it stays clear of the code under review.

5. **Judge pass on collection.** `envoy collect <out-dir>` prints the findings. Verify every finding against the actual code — read the cited lines, retrace the claimed failure path — before accepting it: reviewers state hallucinated issues with the same confidence as real ones.

   For a critical or moderate finding that alleges wrong behavior, reading alone is not verification — you retrace the code with the same mental model that wrote the bug. Pin it with a test before thinking about any fix: a new case, or an existing one sharpened to actually reach the cited path. **Red** — failing for the claimed reason — confirms the finding and becomes the regression test the fix must green; green, when the test genuinely exercises the cited path, is the strongest rebuttal evidence there is.

   Findings with nothing executable to pin — structural reshapes, doc claims, the test-quality findings themselves, paths no harness reaches — stay read-verified. A range can also carry nothing executable at all — a proposal, a docs pass, a batch of eval cases — where a finding like "these cases are outdated" is a judgment to verify against its sources, not a bug to reproduce; there the whole judge pass runs on reading, at undiminished scrutiny.

   Whatever the verification instrument, you wrote this code, so the bias cuts both ways — adopting findings to be agreeable and rebutting them to defend your own work are equal failures. Meet a structural reframing on its merits; a narrower local patch is not a rebuttal. A finding that asks for a new test earns the same scrutiny as one that asks for a code change — locate the bug it would catch, and the absence of a test already catching it; "more coverage" is not a defect, and a test the reviewer wants deleted is verified the same way.

   Done when every finding carries a verdict: confirmed, rebutted with a first-principles reason, or foundational — those the user decides — and every critical or moderate behavioral verdict names the test that decided it, or why none could.

6. **Fix, and account for the tests.** Apply the confirmed criticals and moderates yourself — in this skill the host is the implementer; minors go by user preference. Design the fix from the finding, not from the red test: the cheapest change that greens it is usually the local patch the reviewer stepped past. A confirmed structural finding gets the actual reshape, not a shrunken local version of it and not a deferral to "future work". Every confirmed bug also indicts the suite — it was green over the bug: decide whether the step-5 test filled a coverage gap or must replace a weak test (wrong altitude, over-mocked, asserting internals), and add / strengthen / delete accordingly. Done when the project's checks are green over the fixes, the step-5 tests among them.

7. **Round 2, when the fixes were substantive:** send a per-finding summary of what changed — rebuttals included — into the same session (`envoy collect` prints the resume command; a fan-out of reviewers continues whole: `envoy fan --resume-from <out-dir> --prompt-file round2.md`). The question is narrow: was each point actually integrated or hand-waved, and did the fixes regress anything? Converging, not relitigating. For light fixes, handing the user the takeover command is the cheap substitute.

8. **Report** to the user: the verdict finding by finding (fixed / rebutted with the reason / escalated as foundational), what the fixes changed, the check results, and the resume + takeover commands from collection.
