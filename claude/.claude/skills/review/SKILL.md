---
name: review
description: "Code-review the branch's committed work through a cold AI session, at the altitude the round buys — quick (did anything break), full (is it built right), goal (did we build the right thing, once rounds have already run) — then judge and apply the findings."
---

# Review — independent review of committed work

The mirror of /delegate: there the host reviews a delegate's commits; here a fresh session ("the reviewer") reviews commits the host or the user wrote. The invariant both serve: **whoever wrote the code never gets to be its only reviewer.** Every review carries a cold read — a session with no stake in the design under review; reviewers report findings, and the host verifies each one against the code, fixes what survives, and answers to the user for every verdict. The review being bought is **strategic, not tactical**: findings that step back and reshape the design — a new module, a shared extraction, a call path collapsed, different wiring — not optimizations inside the implementation's frame. The brief's posture section is what demands this, and it holds for every dispatch that reaches that far — `quick` is the deliberate exception, buying correctness and routing anything structural out through a single escalation line. How far back the reviewer is *allowed* to step, and how wide it reaches, is the brief's other choice — the mode in step 2.

Dispatching, patterns, and house rules: [DISPATCH.md](../envoy/DISPATCH.md).

## Process

1. **Fix the range.** The unit of review is commits: find the baseline sha (one the conversation already knows — a delegate baseline, the merge-base with the default branch — or one the user names) and confirm the contents with `git log <base>..HEAD --oneline`. A dirty tree means uncommitted work escapes review: have the user commit, stash, or explicitly accept reviewing the commits alone. Done when the base sha is settled and every commit in the range belongs to the work under review.

2. **Pick the question this round buys, then the mode.** The first pick is **altitude, not depth**: `quick` and `goal` sit on opposite sides of `full` and drop opposite lenses, so a cheaper review here is **narrow, not shallow** — whatever a mode keeps runs to the same standard.

   | the request says | the question it's asking | mode |
   |---|---|---|
   | "quick", "just check nothing broke", "any bugs in this?", "small fix", 快速 / 小改 | does it break anything? | **quick** |
   | nothing about altitude — the ordinary case | is it built right? | **full** |
   | "high level", "goals and behaviors", "step back", "from first principles", "one last look before we merge" | did we build the right thing? | **goal** |

   No word either way, read where the branch stands and never how large the diff is: nothing outside the implementation has judged this work → **full**; the range decided nothing — a bug fix, a version bump, a copy or config change, a mechanical migration, a small addition inside a shape that already exists → **quick**; rounds have already run in this session and their findings are applied → **goal**. Inside `full` the second pick is whether the reviewer is told how the change decided to work: a consult round or a spec the user approved settled the direction → **spec-anchored**; nothing has judged the design, or the user handed over a goal and declined to explain the implementation → **fresh-eyes**. State the pick and its one-line reason and proceed; stop to ask only where the pick is genuinely balanced. A `quick` the user asked for on a range that decided structure still runs — say in one line that a correctness-only lens can't see that range's blast radius, and let the brief's escalation line carry the rest.

   **quick** ([QUICK-BRIEF.md](QUICK-BRIEF.md)) — one reading: what this breaks. Correctness, **blast radius** through every caller of what the diff touched, the edges the change created, and whether the suite's green light means anything here. Structure and design leave through a one-line **escalation** instead, which is also how the mode reports that it was the wrong mode.

   **full** — the review at every altitude, in one of two briefings. **Fresh-eyes** ([FRESH-EYES-BRIEF.md](FRESH-EYES-BRIEF.md)) carries the goal in the user's terms and nothing about the design — no spec, no settled decisions, no implementation report — so the reviewer derives what the feature should do and judges the code against that; the fence is what makes a review tactical, and around a design nobody has judged, it simply ships the design unjudged. **Spec-anchored** ([BRIEF-TEMPLATE.md](BRIEF-TEMPLATE.md)) hands over the spec, the settled items, and the implementation report: the fence holds the direction and the review hunts defects in its execution. It is the only brief a warm voice can take.

   **goal** ([GOAL-BRIEF.md](GOAL-BRIEF.md)) — the closing read. It withholds the design as fresh-eyes does, since first-principles judgment is impossible while holding the implementation's narrative, and adds the section no other brief has: **covered ground**. Skip that section and the round degrades into a late fresh-eyes review that spends its budget re-finding fixed defects.

   Then assemble what the mode's brief needs:

   - **quick** → the facts block, nothing more. Assembly costing near-nothing *is* the saving; the lenses that remain cost what they always cost.
   - **fresh-eyes** → the facts block, and nothing else: operational limits, scope boundaries, external constraints the code can't reveal — facts about the world outside the diff, never justifications of choices inside it. Writing no report is the mode's real cost: the reviewer spends budget orienting itself, which is the same thing that buys the independence.
   - **goal** → the facts block, plus **covered ground**, compiled and never recalled: the prior out-dirs in this session's scratchpad, the step-8 reports, and the fix commits, which carry their round coordinates for exactly this (step 6). Then the one line the compile can't produce — what those rounds did not reach.
   - **spec-anchored** → the implementation report, the map the brief hands the reviewer, sourced by provenance:
     - a /delegate built it → its handoff report from `result.md`, verbatim;
     - this session built it → write the report now: what & why, change map with the load-bearing files marked, key decisions, deviations from spec/plan, test coverage and its altitude, where to look hardest — including where building it fought back (multi-attempt fixes, code re-read before it could be trusted), stated as struggle, not defended. A guided map, **not a self-review** — point at risk and complexity; grading is the reviewer's job;
     - the user built it elsewhere → reconstruct the what & why and the change map from the commits and diffs, and open the report with "reconstructed from commits, not implementer-authored" so the reviewer weighs it accordingly.

   Every mode carries one more thing: **the standards the work was built to** — any rulebook this session read before building, by path. Not a design leak, which is why the design-withholding modes carry it too: a standard says what good looks like, never what this change did.

   Done when the mode's material passes its own test — a facts block whose every line is a fact about the world outside the diff, a report that maps the range for a cold reviewer pointing at risk and grading nothing, or covered ground sourced from the session's review record rather than from memory.

3. **Write the brief** — one self-contained file in the session scratchpad, from the template step 2 chose. Spec-anchored fills orientation, where the authority on WHAT lives (spec/plan paths, or an inline goal statement when no spec exists), the settled decisions it must not relitigate, the commit range, the reading order, the deliberately-deferred work it must not flag, and the report last. Fresh-eyes and goal fill much less — the goal paragraph, the range, the facts block, the do-not-flag list — and quick least of all. Two slots leak, in opposite directions: the **goal paragraph** is what the feature is *for* in the user's own terms, carrying none of the vocabulary this change invented; and a **covered ground** line that explains *why* a decision was made hands back the design the round exists to judge, so each line says what was looked at and what came of it, never the reasoning behind it.

   The pointers go out with it. The review-lens pointer (`~/.config/lessons/collaboration/review-lens.md`) is the posture section and rides every dispatch. Under `full` its whole stance governs; `quick` and `goal` name the subset that governs them, which the lens itself sanctions — the dispatching prompt carries the run's contract. The codebase-design pointers are scoped by mode:

   - **full** → `deep-modules.md` and `deepening.md` whenever the range decides structure: new modules, reshaped interfaces, any real refactor. Trim both when the work is structurally inert — a version bump, a mechanical syntax migration — however large the diff. `composition.md` survives that trim on a **small contained fix**: a patch bolted onto an existing call path is exactly the shape it exists to catch, and exactly the range a reviewer waves through. Drop it only where the range adds no hop and rewires nothing.
   - **quick** → none, composition included. Choosing quick is choosing not to buy the structural read this round; the escalation line is what makes that tolerable rather than blind.
   - **goal** → none. The concept-count question its brief already carries is the altitude composition reaches here; the trace is a full-review instrument.

   Done when a cold reader could deliver the review without this conversation.

4. **Dispatch**, anchored to the range. `quick` and `goal` are always **one cold voice, single turn** — 30-minute cap for quick, 45 for goal, never a fan-out. A warm voice there is not merely spare but wrong: it holds the design, which is the thing `goal` must judge without.

   ```sh
   envoy turn --provider codex --prompt-file <brief> --baseline <base-sha> \
     --timeout-min 30 --label review --coordinate-file <scratchpad>/review.coords
   ```

   For `full`, the cap is 60 minutes and the shape follows one question: did a consult in this session weigh the design this range implements?

   No consult — one cold reviewer:

   ```sh
   envoy turn --provider codex --prompt-file <brief> --baseline <base-sha> \
     --timeout-min 60 --label review --coordinate-file <scratchpad>/review.coords
   ```

   A consult exists — both voices as one fan-out, the consult session continued beside a cold one:

   ```sh
   envoy fan --prompt-file <brief> --baseline <base-sha> \
     --with-from <consult-job-dir> --with codex --timeout-min 60 --label review --coordinate-file <scratchpad>/review.coords
   ```

   `<consult-job-dir>` is a *turn's* directory. A consult that ran as a fan-out holds one session per member, so seat exactly one of them warm — the voice whose position the implementation followed, named in the consult's synthesis — by its member directory (`<consult-out-dir>/codex`). Seating every member warm is the user's call, one `--with-from` per member.

   Warm and cold buy different findings, which is why the pair is the default rather than either alone. The warm voice holds the consult's full context: it is the best judge of follow-through — did the implementation integrate what was agreed, did it dodge the traps its rounds discussed — and, having committed to the design in its own context, a poor judge of the design itself (anchoring to prior positions is measured model behavior, not a hypothetical). The cold voice is the reverse: the unanchored, strategic read this skill exists to buy. The brief stays the complete cold brief; the warm voice re-reads cheaply what it already holds.

   A warm voice takes only a spec-anchored brief — it already holds the design, so there is nothing left to withhold from it. Fresh eyes on a design a consult shaped is therefore a *separate* cold turn with its own brief, never a member of that fan-out (one `envoy fan` carries one brief); run it when the user wants the design itself re-judged rather than its execution checked.

   Collapse to the single cold turn when the user names one voice, when the consult weighed a different design than this range implements, or when the user prefers the cheaper dispatch. Warm-only — the user asking the consult voice itself to do the review — is a follow-through check, not an independent review: run it, and name it that in the report. More cold voices only when the user asks (`--with codex --with claude:opus`).

   `--baseline` makes collection print the reviewed range alongside the findings. Read the coordinate file once, relay out-dir and watch, then return.

5. **Judge pass on collection.** `envoy collect <out-dir>` prints the findings (once — a persisted output is read afterwards). Verify every finding against the actual code — read the cited lines, retrace the claimed failure path — before accepting it: reviewers state hallucinated issues with the same confidence as real ones. Weight by position, never by count: the warm voice endorsing the design it helped shape is expected and earns nothing, and agreement between reviewers earns nothing either.

   For a critical or moderate finding that alleges wrong behavior, reading alone is not verification — you retrace the code with the same mental model that wrote the bug. Pin it with a test before thinking about any fix: a new case, or an existing one sharpened to actually reach the cited path. **Red** — failing for the claimed reason — confirms the finding and becomes the regression test the fix must green; green, when the test genuinely exercises the cited path, is the strongest rebuttal evidence there is.

   Findings with nothing executable to pin — structural and compositional reshapes, doc claims, the test-quality findings themselves, paths no harness reaches — stay read-verified. A composition finding is verified by walking its trace: check the hops it names exist and do what it says they do, then judge the join yourself — the code working is not a rebuttal to it, and neither is the reshape being larger than the patch. What *is* a rebuttal: a hop that adds something the reviewer couldn't see, or a second caller the reshape would have to invent. A range can also carry nothing executable at all — a proposal, a docs pass, a batch of eval cases — where a finding like "these cases are outdated" is a judgment to verify against its sources, not a bug to reproduce; there the whole judge pass runs on reading, at undiminished scrutiny.

   `quick` returns one class of its own: **unpinned behaviour**, where the reviewer's revert test found no test to name. Verify by running that revert test yourself — revert the behaviour in a scratch copy and run the test the reviewer named, or write the one it couldn't. Red rebuts the finding; green over a reverted behaviour proves it, and the fix is the test, not the code. This is why quick keeps the pin-it-first rule at full strength: it is the mode's whole defence against a green suite that means nothing. The **escalation line** gets a verdict too — re-run the range under `full`, or record in the step-8 report why the structural read was declined.

   `goal` returns judgments rather than defects, and the headline is the **did it land** verdict itself: verify it the way you verify a design objection — confirm what the code actually does, form your own position, put both to the user. A goal-round finding that turns out to be a line-level defect the earlier rounds missed is still a real finding: take it, and note that covered ground over-claimed.

   A fresh-eyes review returns two classes the spec-anchored one can't. An **expectation violation** has no failure path to retrace: confirm the code does what the reviewer says it does, then judge the expectation itself against the goal — one a reasonable user would hold, violated by the implementation, is a real defect with every test green, and one that contradicts the goal is rebutted on exactly that ground. A **design objection** is foundational by construction: verify its premise in the code, form your own position on it, and put both to the user — the reshape is theirs to authorize.

   Whatever the verification instrument, you wrote this code, so the bias cuts both ways — adopting findings to be agreeable and rebutting them to defend your own work are equal failures. Meet a structural reframing on its merits; a narrower local patch is not a rebuttal. A finding that asks for a new test earns the same scrutiny as one that asks for a code change — locate the bug it would catch, and the absence of a test already catching it; "more coverage" is not a defect, and a test the reviewer wants deleted is verified the same way.

   Done when every finding carries a verdict: confirmed, rebutted with a first-principles reason, or foundational — those the user decides — and every critical or moderate behavioral verdict names the test that decided it, or why none could.

6. **Fix, and account for the tests.** Apply the confirmed criticals and moderates yourself — in this skill the host is the implementer; minors go by user preference. A `goal` round has no severity ladder to apply: its output is a verdict plus decisions, so what gets built is what the user authorizes, and applying a design objection unasked is the failure mode there. A `quick` round's unpinned-behaviour findings are fixed by writing the test, and that test lands in this step like any other. Design the fix from the finding, not from the red test: the cheapest change that greens it is usually the local patch the reviewer stepped past. A confirmed structural or compositional finding gets the actual reshape, not a shrunken local version of it and not a deferral to "future work" — a deferred composition finding ships the second mechanism, and the migration is never cheaper again than while the branch is open. Write the fix for the **next reader**, who will never see this review: comments and test titles carry the behavior and its reason in the present tense, while the round's coordinates (`(review r2)`, the finding id, the reviewer's name) and the changelog voice (`previously`, `used to`, `no longer`) go in the commit message and the step-7 summary. Those coordinates now have a second consumer: they are what a later `goal` round compiles its **covered ground** from, so a fix commit that drops them costs the closing read its floor. Every confirmed bug also indicts the suite — it was green over the bug: decide whether the step-5 test filled a coverage gap or must replace a weak test (wrong altitude, over-mocked, asserting internals), and add / strengthen / delete accordingly — a test whose subject the fix removed is a **tombstone**, deleted rather than inverted, since what earns the keep is the subject, not the polarity. Done when the project's checks are green over the fixes, the step-5 tests among them.

7. **Round 2, when the fixes were substantive** — a `full` instrument. `quick` and `goal` default to no second round: quick's fixes are verified by the tests that pinned them, and goal's findings are either decisions for the user or a reason to run a different mode, neither of which a follow-up to the same voice settles. Run one anyway only when the user asks. For `full`: send a per-finding summary of what changed — rebuttals included — into the same session (`envoy collect` prints the resume command — add a fresh `--coordinate-file`; a fan-out of reviewers continues whole: `envoy fan --resume-from <out-dir> --prompt-file round2.md --coordinate-file <fresh>`). The question is narrow: was each point actually integrated or hand-waved, and did the fixes regress anything? Converging, not relitigating. For light fixes, handing the user the takeover command is the cheap substitute.

8. **Report** to the user: the question this round bought and the mode that bought it, the verdict finding by finding (fixed / rebutted with the reason / escalated as foundational), what the fixes changed, the check results, and the resume + takeover commands from collection.
