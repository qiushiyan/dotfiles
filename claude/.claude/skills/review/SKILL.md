---
name: review
description: "Get a code review of the branch's committed work — a cold AI session, briefed fresh-eyes or spec-anchored, plus the consult voice warm when one shaped the design — then judge and apply the findings."
---

# Review — independent review of committed work

The mirror of /delegate: there the host reviews a delegate's commits; here a fresh session ("the reviewer") reviews commits the host or the user wrote. The invariant both serve: **whoever wrote the code never gets to be its only reviewer.** Every review carries a cold read — a session with no stake in the design under review; reviewers report findings, and the host verifies each one against the code, fixes what survives, and answers to the user for every verdict. The review being bought is **strategic, not tactical**: findings that step back and reshape the design — a new module, a shared extraction, different wiring — not optimizations inside the implementation's frame. The brief's posture section is what demands this; it holds for every dispatch. How far back the reviewer is *allowed* to step is the brief's other choice — the mode in step 2.

Dispatching, patterns, and house rules: [DISPATCH.md](../envoy/DISPATCH.md).

## Process

1. **Fix the range.** The unit of review is commits: find the baseline sha (one the conversation already knows — a delegate baseline, the merge-base with the default branch — or one the user names) and confirm the contents with `git log <base>..HEAD --oneline`. A dirty tree means uncommitted work escapes review: have the user commit, stash, or explicitly accept reviewing the commits alone. Done when the base sha is settled and every commit in the range belongs to the work under review.

2. **Pick the mode, and assemble what it carries.** Both briefs go to a session with no stake in the design; they differ in one thing — whether the reviewer is told how the change decided to work.

   **Fresh-eyes** ([FRESH-EYES-BRIEF.md](FRESH-EYES-BRIEF.md)) — the brief carries the goal in the user's terms and nothing about the design: no spec, no settled decisions, no implementation report. The reviewer derives what the feature should do, reads the code, and judges one against the other. **The default when nothing outside the implementation has ever judged this design** — no consult round, no spec the user approved: the fence is what makes a review tactical, and around a design no one has judged it simply ships the design unjudged. Also what the user means by "fresh eyes", and what they are asking for when they hand over a goal and decline to explain the implementation. The twin of /consult's blind design mode, one phase later.

   **Spec-anchored** ([BRIEF-TEMPLATE.md](BRIEF-TEMPLATE.md)) — the direction was settled by a consult round or a spec the user approved; the fence holds it and the review hunts defects in the execution. The reviewer gets the spec, the settled items, and the implementation report. The right instrument for a range built against a plan, and the only brief a warm voice can take.

   Then assemble what that brief's last section needs:

   - **fresh-eyes** → the facts block, and nothing else: operational limits, scope boundaries, external constraints the code can't reveal — facts about the world outside the diff, never justifications of choices inside it. Writing no report is the mode's real cost: the reviewer spends budget orienting itself, which is the same thing that buys the independence.
   - **spec-anchored** → the implementation report, the map the brief hands the reviewer, sourced by provenance:
     - a /delegate built it → its handoff report from `result.md`, verbatim;
     - this session built it → write the report now: what & why, change map with the load-bearing files marked, key decisions, deviations from spec/plan, test coverage and its altitude, where to look hardest — including where building it fought back (multi-attempt fixes, code re-read before it could be trusted), stated as struggle, not defended. A guided map, **not a self-review** — point at risk and complexity; grading is the reviewer's job;
     - the user built it elsewhere → reconstruct the what & why and the change map from the commits and diffs, and open the report with "reconstructed from commits, not implementer-authored" so the reviewer weighs it accordingly.

   Both modes carry one more thing: **the standards the work was built to** — any rulebook this session read before building, by path. Not a design leak, which is why fresh-eyes carries it too: a standard says what good looks like, never what this change did.

   Done when the mode's material passes its own test — a facts block whose every line is a fact about the world outside the diff, or a report that maps the range for a cold reviewer, pointing at risk and grading nothing.

3. **Write the brief** — one self-contained file in the session scratchpad, from the template step 2 chose. Spec-anchored fills orientation, where the authority on WHAT lives (spec/plan paths, or an inline goal statement when no spec exists), the settled decisions it must not relitigate, the commit range, the reading order, the deliberately-deferred work it must not flag, and the report last. Fresh-eyes fills much less — the goal paragraph, the range, the facts block, the do-not-flag list — and the slot that leaks is the goal paragraph: what the feature is *for*, in the user's own terms, carrying none of the vocabulary this change invented. Both carry the review-lens pointer (`~/.config/lessons/collaboration/review-lens.md`) — it is the posture section, and it goes out with every dispatch. The codebase-design pointers go out as written whenever the range decides structure: new modules, reshaped interfaces, any real refactor; trim them when the work is structurally inert — a version bump, a mechanical syntax migration, a small contained fix — however large the diff. Done when a cold reader could deliver the review without this conversation.

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

   Warm and cold buy different findings, which is why the pair is the default rather than either alone. The warm voice holds the consult's full context: it is the best judge of follow-through — did the implementation integrate what was agreed, did it dodge the traps its rounds discussed — and, having committed to the design in its own context, a poor judge of the design itself (anchoring to prior positions is measured model behavior, not a hypothetical). The cold voice is the reverse: the unanchored, strategic read this skill exists to buy. The brief stays the complete cold brief; the warm voice re-reads cheaply what it already holds.

   A warm voice takes only a spec-anchored brief — it already holds the design, so there is nothing left to withhold from it. Fresh eyes on a design a consult shaped is therefore a *separate* cold turn with its own brief, never a member of that fan-out (one `envoy fan` carries one brief); run it when the user wants the design itself re-judged rather than its execution checked.

   Collapse to the single cold turn when the user names one voice, when the consult weighed a different design than this range implements, or when the user prefers the cheaper dispatch. Warm-only — the user asking the consult voice itself to do the review — is a follow-through check, not an independent review: run it, and name it that in the report. More cold voices only when the user asks (`--with codex --with claude:opus`).

   `--baseline` makes collection print the reviewed range alongside the findings. Relay the coordinate block, then return.

5. **Judge pass on collection.** `envoy collect <out-dir>` prints the findings. Verify every finding against the actual code — read the cited lines, retrace the claimed failure path — before accepting it: reviewers state hallucinated issues with the same confidence as real ones. Weight by position, never by count: the warm voice endorsing the design it helped shape is expected and earns nothing, and agreement between reviewers earns nothing either.

   For a critical or moderate finding that alleges wrong behavior, reading alone is not verification — you retrace the code with the same mental model that wrote the bug. Pin it with a test before thinking about any fix: a new case, or an existing one sharpened to actually reach the cited path. **Red** — failing for the claimed reason — confirms the finding and becomes the regression test the fix must green; green, when the test genuinely exercises the cited path, is the strongest rebuttal evidence there is.

   Findings with nothing executable to pin — structural reshapes, doc claims, the test-quality findings themselves, paths no harness reaches — stay read-verified. A range can also carry nothing executable at all — a proposal, a docs pass, a batch of eval cases — where a finding like "these cases are outdated" is a judgment to verify against its sources, not a bug to reproduce; there the whole judge pass runs on reading, at undiminished scrutiny.

   A fresh-eyes review returns two classes the spec-anchored one can't. An **expectation violation** has no failure path to retrace: confirm the code does what the reviewer says it does, then judge the expectation itself against the goal — one a reasonable user would hold, violated by the implementation, is a real defect with every test green, and one that contradicts the goal is rebutted on exactly that ground. A **design objection** is foundational by construction: verify its premise in the code, form your own position on it, and put both to the user — the reshape is theirs to authorize.

   Whatever the verification instrument, you wrote this code, so the bias cuts both ways — adopting findings to be agreeable and rebutting them to defend your own work are equal failures. Meet a structural reframing on its merits; a narrower local patch is not a rebuttal. A finding that asks for a new test earns the same scrutiny as one that asks for a code change — locate the bug it would catch, and the absence of a test already catching it; "more coverage" is not a defect, and a test the reviewer wants deleted is verified the same way.

   Done when every finding carries a verdict: confirmed, rebutted with a first-principles reason, or foundational — those the user decides — and every critical or moderate behavioral verdict names the test that decided it, or why none could.

6. **Fix, and account for the tests.** Apply the confirmed criticals and moderates yourself — in this skill the host is the implementer; minors go by user preference. Design the fix from the finding, not from the red test: the cheapest change that greens it is usually the local patch the reviewer stepped past. A confirmed structural finding gets the actual reshape, not a shrunken local version of it and not a deferral to "future work". Write the fix for the **next reader**, who will never see this review: comments and test titles carry the behavior and its reason in the present tense, while the round's coordinates (`(review r2)`, the finding id, the reviewer's name) and the changelog voice (`previously`, `used to`, `no longer`) go in the commit message and the step-7 summary. Every confirmed bug also indicts the suite — it was green over the bug: decide whether the step-5 test filled a coverage gap or must replace a weak test (wrong altitude, over-mocked, asserting internals), and add / strengthen / delete accordingly — a test whose subject the fix removed is a **tombstone**, deleted rather than inverted, since what earns the keep is the subject, not the polarity. Done when the project's checks are green over the fixes, the step-5 tests among them.

7. **Round 2, when the fixes were substantive:** send a per-finding summary of what changed — rebuttals included — into the same session (`envoy collect` prints the resume command; a fan-out of reviewers continues whole: `envoy fan --resume-from <out-dir> --prompt-file round2.md`). The question is narrow: was each point actually integrated or hand-waved, and did the fixes regress anything? Converging, not relitigating. For light fixes, handing the user the takeover command is the cheap substitute.

8. **Report** to the user: the mode the review ran in, the verdict finding by finding (fixed / rebutted with the reason / escalated as foundational), what the fixes changed, the check results, and the resume + takeover commands from collection.
