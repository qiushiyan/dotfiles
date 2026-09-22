---
name: review
description: "Code-review the branch's committed work through a cold AI session — goal (did we build the right thing: the cheap independent read, before or after any other round) or full (is it built right: the deep read with the implementation report) — then judge and apply the findings."
requires:
  - lessons:collaboration/review-lens.md
  - lessons:codebase-design/deep-modules.md
  - lessons:codebase-design/deepening.md
  - lessons:codebase-design/composition.md
  - lessons:collaboration/tenets.md
---

# Review — independent review of committed work

A fresh session ("the reviewer") reviews commits the host or the user wrote. The invariant: **whoever wrote the code never gets to be its only reviewer.** Every review carries a cold read — a session with no stake in the design under review; reviewers report findings, and the host verifies each one against the code, fixes what survives, and answers to the user for every verdict. The review being bought is **strategic, not tactical**: findings that step back and reshape the design — a new module, a shared extraction, a call path collapsed, different wiring — not optimizations inside the implementation's frame. The brief's posture section is what demands this. What the reviewer is *handed* — the goal alone, or the implementation's own map — is the brief's other choice, and that is the mode in step 2.

## Process

1. **Fix the range.** The unit of review is commits: find the baseline sha (one the conversation already knows — a delegate baseline, the merge-base with the default branch — or one the user names) and confirm the contents with `git log <base>..HEAD --oneline`. A dirty tree means uncommitted work escapes review: have the user commit, stash, or explicitly accept reviewing the commits alone. Done when the base sha is settled and every commit in the range belongs to the work under review.

2. **Pick the question this round buys, then the mode.** Two modes, named by what the reviewer is handed:

   | the request says | the question it's asking | mode |
   |---|---|---|
   | "goal", "high level", "step back", "from first principles", "one last look", "I'm confident in the internals, catch the obvious mistakes" | did we build the right thing? | **goal** |
   | "full", "deep", or nothing about altitude — the ordinary case | is it built right? | **full** |

   A good ask carries three things, and a one-word ask leaves the host to supply them from the session: the goal in the user's own terms, what is settled by something outside this session, and what the user does not want this round spent on. Say the pick back in one line before anything is written — "this round buys *did it land*, goal mode" — since that line is the user's one chance to redirect a round before it costs anything. Stop to ask only where the pick is genuinely balanced.

   **goal** ([GOAL-BRIEF.md](GOAL-BRIEF.md)) — the cheap independent read, at altitude, valid before any other round or as the closing read after them. It withholds the design: the reviewer gets the goal in the user's terms, the facts outside the diff, the standards, and what has already judged this range — and writes down what it expects before it opens the code, because first-principles judgment is impossible while holding the implementation's narrative. One cold voice. Its **structural lens** is a switch: keep the composition block in the brief when the range decides structure — a new module, a reshaped interface, a real refactor — and delete it when the range is structurally inert, however large the diff.

   **full** ([BRIEF-TEMPLATE.md](BRIEF-TEMPLATE.md)) — the deep read. The reviewer is handed the implementation report and, where something outside this session settled the direction, a fence of settled decisions; it hunts defects in the execution, traces composition, audits whether the suite's green means anything, and reports on a severity ladder. When nothing outside the session has judged the design, the fence is deleted and the brief says so: everything is open, the design included.

   Then assemble what the mode's brief needs:

   - **goal** → the facts block: operational limits, scope boundaries, external constraints the code can't reveal — facts about the world outside the diff, never justifications of choices inside it. Plus **already judged**, compiled and never recalled: the prior review rounds (`envoy collect review-r1`, `review-r2` …), their step-8 reports and the fix commits (which carry their round coordinates for exactly this, step 6), the consult rounds that shaped the design — named by the question each judged, never by what it settled, since a consult's outcome *is* the design this brief withholds — bot reviewers, the suites and what they cover — each with what it found, and one line the compile can't produce: what none of them reached. Where nothing has looked at the range, the section says "nothing" — an honest empty is what keeps the reviewer from assuming defects were already caught. The reviewer orienting itself unaided is what buys the independence.
   - **full** → the implementation report, the map the brief hands the reviewer, sourced by provenance:
     - a /delegate built it → its handoff report from `result.md`, verbatim;
     - this session built it → write the report now: what & why, change map with the load-bearing files marked, key decisions, deviations from spec/plan, test coverage and its altitude, where to look hardest — including where building it fought back (multi-attempt fixes, code re-read before it could be trusted), stated as struggle, not defended. A guided map, **not a self-review** — point at risk and complexity; grading is the reviewer's job;
     - the user built it elsewhere → reconstruct the what & why and the change map from the commits and diffs, and open the report with "reconstructed from commits, not implementer-authored" so the reviewer weighs it accordingly.

   Every mode carries one more thing: **the standards the work was built to** — any rulebook this session read before building, by path. Not a design leak, which is why goal carries it too: a standard says what good looks like, never what this change did.

   Every mode carries a second thing when it applies: **the data behind this change**. When the range rests on a measurement this session produced — a report or spec in the diff built from production queries, log runs, session-history queries, an eval or benchmark, a hand classification — the brief keeps its `## The data behind this change` section and the output's method item, filled to `~/.claude/skills/consult/DATA-BLOCK.md`, with the queries and raw outputs saved and cited by path. The reviewer then judges whether the right data was pulled and the approach is sound before it judges what the range concluded from it. A range with no such number deletes the section and the item; this is not a design leak either — a method says how a number was made, never whether the change is right.

   Done when the mode's material passes its own test — a facts block whose every line is a fact about the world outside the diff, an already-judged section sourced from the session's record rather than from memory, or a report that maps the range for a cold reviewer pointing at risk and grading nothing.

3. **Write the brief** — one self-contained file in the session scratchpad, named for the round (`review-r1.md`), from the template step 2 chose. Full fills orientation, where the authority on WHAT lives (spec/plan paths, or an inline goal statement when no spec exists), the settled decisions it must not relitigate (or the line that nothing is settled), the commit range, the reading order, the deliberately-deferred work it must not flag, the standards and data sections step 2 assembled, and the report last. Goal fills much less — the goal paragraph, the range, the facts block, already judged, the do-not-flag list. Two slots leak, in opposite directions: the **goal paragraph** is what the feature is *for* in the user's own terms, carrying none of the vocabulary this change invented; and an **already judged** line that explains *why* a decision was made hands back the design the round exists to judge, so each line says what was looked at and what came of it, never the reasoning behind it.

   The lesson pointers go out with it, copied from the template as written — they are for the reviewer. The posture section rides every dispatch: under `full` its whole stance governs; `goal` names the subset that governs it — the dispatching prompt carries the run's contract. The template's design-bar lines are scoped by what the range decided:

   - **full** → keep **Structural quality** whenever the range decides structure: new modules, reshaped interfaces, any real refactor. Trim it when the work is structurally inert — a version bump, a mechanical syntax migration — however large the diff. **Composition** survives that trim on a **small contained fix**: a patch bolted onto an existing call path is exactly the shape it exists to catch, and exactly the range a reviewer waves through. Drop it only where the range adds no hop and rewires nothing.
   - **goal** → the structural block follows the same rule; the concept-count question its brief always carries is the altitude composition reaches without it.
   - **full on a milestone** — "phase 1 is done", "the rest continues here", a spec whose phases are partly unbuilt → keep **The rest of the build**: it stops the reviewer flagging the unbuilt phases, and it returns the tenets those phases hold to, in the form `~/.config/lessons/collaboration/tenets.md` defines. Delete it when the range is the whole change.

   Done when a cold reader could deliver the review without this conversation.

4. **Dispatch**, anchored to the range, as one background Bash task, the job named for the round — `review-r1`, then `review-r2` — and return: the task completing is the completion signal, and nothing the dispatch prints needs relaying. `goal` is **one cold voice, single turn**, 45-minute cap, never a fan-out on its own. A warm voice there is not merely spare but wrong: it holds the design, which is the thing `goal` must judge without.

   ```sh
   envoy run review-r1 --with codex --prompt-file <brief> --baseline <base-sha> --timeout-min 45
   ```

   For `full`, the cap is 60 minutes and the shape follows one question: did a consult in this session weigh the design this range implements?

   No consult — one cold reviewer:

   ```sh
   envoy run review-r1 --with codex --prompt-file <brief> --baseline <base-sha> --timeout-min 60
   ```

   A consult exists — both voices as one fan-out, the consult session continued beside a cold one:

   ```sh
   envoy run review-r1 --with @consult-r1/codex --with codex --prompt-file <brief> --baseline <base-sha> --timeout-min 60
   ```

   `@consult-r1/codex` names the *member* whose position the implementation followed, as the consult's synthesis recorded it. A consult that ran as one voice is `@consult-r1` alone. A consult that ran as a fan-out holds one session per member, named `<provider>` or `<provider>-<model>` as its collect block prints them — the voice `codex` is member `codex`, the voice `claude:opus` is member `claude-opus` — and there `@consult-r1` alone would continue every member and seat no cold voice. Name the consult's latest round: after a round 2, `@consult-r2/codex`. Seating every member warm is the user's call, one `--with @<member>` each.

   Warm judges follow-through — did the implementation integrate what was agreed, did it dodge the traps its rounds discussed — and, having committed to the design in its own context, is a poor judge of the design itself; cold buys the unanchored, strategic read this skill exists for. Both get the complete brief; the warm voice re-reads cheaply what it already holds.

   A warm voice takes only a full brief — it already holds the design, so there is nothing left to withhold from it. When the user wants the design re-judged as well as its execution checked, the goal read joins the same fan-out as a cold voice on its own brief, each brief attached to its voice:

   ```sh
   envoy run review-r1 --with @consult-r1/codex=<full-brief> --with codex=<goal-brief> --baseline <base-sha> --timeout-min 60
   ```

   Two briefs, one job: the warm voice checks follow-through against the spec, the cold one derives what the feature should do with the design withheld, and one collect returns both. The withholding is what the separate file buys — a goal section inside the full brief would hand the cold voice the design on the next page.

   Collapse to the single cold turn when the user names one voice, when the consult weighed a different design than this range implements, or when the user prefers the cheaper dispatch. Warm-only — the user asking the consult voice itself to do the review — is a follow-through check, not an independent review: run it, and name it that in the report. More cold voices only when the user asks (`--with codex --with claude:opus`). `codex` alone inherits the model in the user's Codex config; a Claude voice runs only on a model the user names, spelled `claude:<model>` (`claude:opus`, `claude:claude-fable-5-1`).

   If the completion notification is lost to a compaction or a restart, `envoy pending` says what still needs attention.

5. **Judge pass on collection.** `envoy collect review-r1` prints the findings; any other status prints a `next:` line instead — follow it. Verify every finding against the actual code — read the cited lines, retrace the claimed failure path — before accepting it: reviewers state hallucinated issues with the same confidence as real ones. Weight by position, never by count: the warm voice endorsing the design it helped shape is expected and earns nothing, and agreement between reviewers earns nothing either.

   For a critical or moderate finding that alleges wrong behavior, reading alone is not verification — you retrace the code with the same mental model that wrote the bug. Pin it with a test before thinking about any fix: a new case, or an existing one sharpened to actually reach the cited path. **Red** — failing for the claimed reason — confirms the finding and becomes the regression test the fix must green; green, when the test genuinely exercises the cited path, is the strongest rebuttal evidence there is.

   Findings with nothing executable to pin — structural and compositional reshapes, doc claims, the test-quality findings themselves, paths no harness reaches — stay read-verified. A composition finding is verified by walking its trace: check the hops it names exist and do what it says they do, then judge the join yourself — the code working is not a rebuttal to it, and neither is the reshape being larger than the patch. What *is* a rebuttal: a hop that adds something the reviewer couldn't see, or a second caller the reshape would have to invent. A range can also carry nothing executable at all — a proposal, a docs pass, a batch of eval cases — where a finding like "these cases are outdated" is a judgment to verify against its sources, not a bug to reproduce; there the whole judge pass runs on reading, at undiminished scrutiny.

   **Unpinned behaviour** — a behaviour the reviewer's revert test found no test for — is verified by running that revert test yourself: revert the behaviour in a scratch copy and run the test the reviewer named, or write the one it couldn't. Red rebuts the finding; green over a reverted behaviour proves it, and the fix is the test, not the code. Hold the finding to its own scope: it names a behaviour whose regression would matter, and "more coverage" over a behaviour nobody would miss is not a finding.

   `goal` returns judgments rather than defects, and the headline is the **did it land** verdict itself: verify it the way you verify a design objection — confirm what the code actually does, form your own position, put both to the user. Two of its classes have no failure path to retrace. An **expectation violation**: confirm the code does what the reviewer says it does, then judge the expectation itself against the goal — one a reasonable user would hold, violated by the implementation, is a real defect with every test green, and one that contradicts the goal is rebutted on exactly that ground. A **design objection** is foundational by construction: verify its premise in the code, form your own position on it, and put both to the user — the reshape is theirs to authorize. A goal-round finding that turns out to be a line-level defect the earlier rounds missed is still a real finding: take it, and note that already judged over-claimed.

   Whatever the verification instrument, you wrote this code, so the bias cuts both ways — adopting findings to be agreeable and rebutting them to defend your own work are equal failures. Meet a structural reframing on its merits; a narrower local patch is not a rebuttal. A finding that asks for a new test earns the same scrutiny as one that asks for a code change — locate the bug it would catch, and the absence of a test already catching it; "more coverage" is not a defect, and a test the reviewer wants deleted is verified the same way.

   A milestone round's **tenets** are judged by the bar in `~/.config/lessons/collaboration/tenets.md`, not as findings: a line that fails it is a tip, and joins the findings at whatever severity its content earns.

   Done when every finding carries a verdict: confirmed, rebutted with a first-principles reason, or foundational — those the user decides — and every critical or moderate behavioral verdict names the test that decided it, or why none could.

6. **Fix, and account for the tests.** Apply the confirmed criticals and moderates yourself — in this skill the host is the implementer; minors go by user preference. A `goal` round has no severity ladder: its output is a verdict plus decisions, so it reports first (step 8), builds what the user authorizes, and reports again; applying a design objection unasked is the failure mode there. Unpinned-behaviour findings are fixed by writing the test, which lands in this step like any other.

   - **Design the fix from the finding, not from the red test**: the cheapest change that greens it is usually the local patch the reviewer stepped past. A confirmed structural or compositional finding gets the actual reshape — not a shrunken local version, not a deferral to "future work": a deferred composition finding ships the second mechanism, and the migration is never cheaper than while the branch is open.
   - **Write the fix for the next reader**, who will never see this review: comments and test titles carry the behavior and its reason in the present tense. The round's coordinates (`(review r2)`, the finding id, the reviewer) and the changelog voice (`previously`, `no longer`) go in the commit message, where a later `goal` round compiles its **already judged** from them.
   - **Every confirmed bug indicts the suite** — it was green over the bug. Decide whether the step-5 test filled a coverage gap or must replace a weak test (wrong altitude, over-mocked, asserting internals), and add, strengthen, or delete accordingly. A test whose subject the fix removed is a **tombstone**: deleted rather than inverted, since the subject earns the keep, not the polarity.

   - **Tenets go into the spec.** On a milestone round, the surviving tenets are written into the spec as `## Tenets`, beside its phases — the first milestone creates the section, a later one revises it, with each struck tenet and its reason kept — and they land in the fix commit, or in their own when there is nothing to fix. The build rereads the spec after every compaction; a tenet left in this conversation is dropped at the next one.

   Done when the project's checks are green over the fixes, the step-5 tests among them.

7. **Round 2, when the fixes were substantive** — a `full` instrument. `goal` defaults to no second round: its findings are either decisions for the user or a reason to run `full`, neither of which a follow-up to the same voice settles. Run one anyway only when the user asks. For `full`: send a per-finding summary of what changed — rebuttals included — into the same session, one voice or a whole fan-out alike, with the `resume:` command collection printed — a fresh name (`review-r2`) and the follow-up as its prompt file. The question is narrow: was each point actually integrated or hand-waved, and did the fixes regress anything? Converging, not relitigating. For light fixes, the tests that pinned them are the cheap substitute.

8. **Report** to the user, who did not watch the round and decides from this message alone. Lead with what needs them: each foundational objection or design decision as its own standalone question — why it matters now, what it means in plain product terms, the options with what each implies for the person using the product, and your recommendation — with none of the vocabulary the round built. Then the question this round bought and the mode that bought it, the verdict finding by finding (fixed / rebutted with the reason / escalated as foundational), what the fixes changed, the check results, on a milestone round the tenets as written into the spec and what was struck, and the job name, so the session stays continuable. Where nothing needs the user, say so in the first line and let the verdicts be the report.
