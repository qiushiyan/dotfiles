---
name: review
description: Review committed work with a fresh model session, then apply what survives. Use when the user asks for a review round, or a goal or full review.
requires:
  - lessons:collaboration/review-lens.md
  - lessons:collaboration/finding-classes.md
  - lessons:codebase-design/deep-modules.md
  - lessons:codebase-design/deepening.md
  - lessons:codebase-design/composition.md
  - lessons:collaboration/tenets.md
---

# Review: an independent read of committed work

Whoever wrote the code is never its only reviewer. A fresh session, the
reviewer, reads the commits and reports findings; you verify each one
against the code, fix what survives, and answer to the user for every
verdict. Beside its findings it may suggest up to two ideas, small changes
that would make the work better to use or harder to break; you judge each
and build the ones you recommend. The review being bought is strategic:
findings that reshape the design (a new module, a shared extraction, a
collapsed call path), not tweaks inside the implementation's frame. The
round is done when every finding has a verdict, the fixes are green, and
the user has a report they can decide from alone.

## Voices

The user names the voice after the word: "review with fable", "astra full
review", "fable full review, then closeout".

| name | `--with` | member name |
|---|---|---|
| **astra**, "codex", or none named | `codex:gpt-6.2-astra:high` | `codex-gpt-6.2-astra` |
| **fable**, "claude" | `claude:claude-fable-5-2` | `claude-claude-fable-5-2` |
| **carbon**, "gemini" | `agy:gemini-4-carbon:high` | `agy-gemini-4-carbon` |

One cold voice is a goal round (45-minute cap) or a full round with no
consult this session (60):

```sh
envoy run review-r1 --with codex:gpt-6.2-astra:high --prompt-file <brief> \
  --instructions-file ~/.agents/skills/consult/VOICE.md --baseline <base-sha> --timeout-min 60
```

A full round after a consult seats the consult's voice warm beside a cold
voice of another family (step 3):

```sh
envoy run review-r1 --with @consult-r1/codex-gpt-6.2-astra --with claude:claude-fable-5-2 --prompt-file <brief> \
  --instructions-file ~/.agents/skills/consult/VOICE.md --baseline <base-sha> --timeout-min 60
```

Any other model, effort or brief split: § More control.

## 1. Fix the range

The unit of review is commits. Take the baseline sha the conversation knows
(a delegate baseline, the merge-base with the default branch) or the one the
user names, and confirm the range with `git log <base>..HEAD --oneline`. A
dirty tree escapes review: have the user commit, stash, or accept reviewing
the commits alone.

## 2. Pick the question and the mode, then write the brief

| the request says | the question | mode |
|---|---|---|
| "goal", "high level", "step back", "from first principles", "one last look", "I'm confident in the internals, catch the obvious mistakes" | did we build the right thing? | **goal** |
| "full", "deep", or nothing about altitude | is it built right? | **full** |

A good ask carries the goal in the user's terms, what something outside this
session settled, and what the round should not be spent on; supply what a
one-word ask leaves out from the session. Say the pick back in one line
before writing anything, voices included: "this round buys *is it built
right*, full mode, @consult-r1 warm beside a cold fable". That line is the
user's one chance to redirect the round; stop to ask only where the pick is
genuinely balanced.

**goal** ([GOAL-BRIEF.md](GOAL-BRIEF.md)) is the cheap read at altitude,
before any other round or as the closing one. It withholds the design: the
reviewer gets the goal, the facts outside the diff, the standards and what
has already judged the range, and states its expectation before opening the
code. Compile "already judged" from the session's record (earlier rounds
through `envoy collect review-r1`, the fix commits that carry their round
coordinates), never from memory.

**full** ([BRIEF-TEMPLATE.md](BRIEF-TEMPLATE.md)) is the deep read. The
reviewer gets the implementation report and, where something outside this
session settled the direction, a fence of settled decisions; with nothing
outside, delete the fence and say the design is open too. The report comes
by provenance:

- A /delegate built it: its `result.md` report, verbatim.
- This session built it: write it now. What and why, the change map with the
  load-bearing files marked, key decisions, deviations from spec or plan,
  test coverage and its altitude, and where to look hardest, including where
  the build fought back, stated as struggle, not defended.
- The user built it elsewhere: reconstruct only the what and why and the
  change map from the commits, and open with "reconstructed from commits,
  not implementer-authored".

Write the brief from the mode's template into `review-r1.md`; its «slots»
say what each section holds, the data section included when the range rests
on a number this session measured. Done when a cold reader could deliver the
review without this conversation.

## 3. Dispatch

Run the mode's command (§ Voices) as one background Bash task named for the
round (`review-r1`, then `review-r2`), and return.

**goal** is one cold voice, single turn, never a fan-out on its own: a warm
voice holds the design, which is what goal must judge without.

**full** follows one question: did a consult in this session weigh the
design this range implements? With no consult, one cold voice. With one, the
consult session continued beside a cold voice:

- **Name the member** whose position the implementation followed, as the
  consult's synthesis recorded it: `@consult-r1` for a one-voice consult,
  `@consult-r1/<member name>` from a fan-out, where `@consult-r1` alone
  would continue every member and seat no cold voice. Name the latest round:
  after a round 2, `@consult-r2/…`. Seating every member warm is the user's
  call, one `--with` each.
- **The cold voice comes from another family than the warm one**, since
  two voices of one model mostly find the same things: fable beside a warm
  astra or carbon, astra beside a warm fable. A voice the user names is the
  cold voice as named.
- **Warm judges follow-through**: did the build integrate what was agreed
  and dodge the traps its rounds discussed. It is a poor judge of the design
  it committed to, and it takes only a full brief. When the user wants the
  design re-judged too, add a cold voice on a goal brief to the same job
  (§ More control).

Collapse to the single cold turn when the user asks for that voice alone,
when the consult weighed a different design than this range implements, or
when the user prefers the cheaper dispatch. Warm-only, the user asking the
consult voice itself to review, is a follow-through check rather than an
independent review: run it and call it that in the report.

## 4. Judge every finding

On the completion notice, `envoy collect review-r1` prints the findings.
Verify every finding against the code before accepting it: read the cited
lines and retrace the claimed failure path. Reviewers state hallucinated
issues with the same confidence as real ones. Weight by position, never by
count: neither the warm voice endorsing its own design nor agreement between
reviewers earns anything. You wrote this code, so adopting findings to be
agreeable and rebutting them to defend your work are equal failures; a
narrower local patch is no rebuttal of a structural reframing.

- **Wrong behavior, critical or moderate:** reading is not verification,
  because you retrace the code with the mental model that wrote the bug. Pin
  it with a test before thinking about a fix: a new case, or an existing one
  sharpened to reach the cited path. Red for the claimed reason confirms the
  finding and becomes the regression test; green, where the test really
  exercises the path, is the strongest rebuttal there is.
- **Nothing executable to pin** (reshapes, doc claims, test-quality
  findings, paths no harness reaches) stays read-verified. Verify a
  composition finding by walking its trace: the hops it names exist and do
  what it says, then judge the join yourself. The code working is no
  rebuttal, nor is the reshape being larger than the patch; a hop that adds
  something the reviewer could not see is, and so is a second caller the
  reshape would have to invent. A range with nothing executable at all (a
  proposal, a docs pass, eval cases) is judged against its sources, at
  undiminished scrutiny.
- **Unpinned behaviour:** run the reviewer's revert test yourself. Revert
  the behaviour in a scratch copy and run the test it named, or write the
  one it could not. Red rebuts the finding; green over a reverted behaviour
  proves it, and the fix is the test, not the code.
- **A goal round** returns judgments, headed by the **did it land** verdict.
  For an expectation violation, confirm the code does what the reviewer
  says, then judge the expectation against the goal: one a reasonable user
  would hold is a real defect with every test green; one that contradicts
  the goal is rebutted on that ground. Confirm the verdict against the code
  and report your own, restated after the fixes. Each design objection is
  foundational: confirm its premise, form your own position, and put both
  to the user. A line-level defect the earlier rounds missed is still a real
  finding; take it, and note that already judged over-claimed.
- **Tenets** from a milestone round meet the bar in
  `~/.config/lessons/collaboration/tenets.md`; one that fails it is a tip,
  at whatever severity its content earns.
- **Ideas** get a take, not a verdict: confirm the friction or risk is real
  and unhandled, then decide whether you recommend it and why. An idea that
  is a defect (a reachable state with no handling, a case the goal implies)
  joins the findings at the severity it earns (in a goal round, among the
  obvious mistakes). With several voices, keep the best two or three.

Done when every finding is confirmed, rebutted with a first-principles
reason, or foundational for the user to decide; every critical or moderate
behavioral verdict names the test that decided it, or why none could; and
every idea has a take.

## 5. Fix, and account for the tests

Fix every confirmed finding, minors included unless the ask says otherwise;
an unpinned-behaviour finding is fixed by writing its test. A goal round's
confirmed obvious mistakes count as moderate, pinned in step 4 and fixed
here. Its design objections, and the weight the reviewer would delete, wait
for the user: applying one unasked is the failure there.

- **Design the fix from the finding, not from the red test.** The cheapest
  change that greens it is usually the local patch the reviewer stepped past.
  A confirmed structural or compositional finding gets the actual reshape,
  not a shrunken local version or a deferral: a deferred composition finding
  ships the second mechanism.
- **Write for the next reader,** who never sees this review: comments and
  test titles state the behavior and its reason in the present tense. The
  round's coordinates go in the commit message: `(review r2)`, the finding
  id, in a full round its class tag, and the reviewer's member name.
- **A confirmed `model-facing` finding is a product fix** and lands now,
  whatever rule defers documentation to a later pass.
- **Every confirmed bug indicts the suite,** which was green over it:
  decide whether the step-4 test filled a gap or must replace a weak test,
  and delete a test whose subject the fix removed rather than invert it.
- **Tenets go into the spec** on a milestone round, as `## Tenets` beside its
  phases, revised in place by later milestones with each struck tenet kept
  with its reason; the build rereads the spec after every compaction, and a
  tenet left in this conversation is lost at the next one.
- **Build the ideas you recommend, without asking,** after the fixes, in a
  commit of their own the user can revert, with a test where an idea adds
  behaviour. Leave one unbuilt only when it is a product decision the user
  should make (a new mode, flag, command or option, or a change in what
  users can do), needs authority this session lacks, or the ask says ideas
  wait.

Done when the project's checks are green over the fixes and the ideas built.

## 6. Round 2, when the fixes were substantive

A full round only; goal has none unless the user asks. Send a per-finding
summary of what changed, rebuttals included, into the same session (one
voice or the whole fan-out) with the `resume:` command collect printed,
named `review-r2`. The question is narrow: was each point integrated or
hand-waved, and did the fixes regress anything? Converge; do not relitigate.
Leave the ideas out. For light fixes, the tests that pinned them are the
cheap substitute.

## 7. Report

Lead with what needs the user, each foundational objection or design
decision in none of the round's vocabulary; where nothing does, say so in
the first line. Then the question the round bought and its mode; the verdict
per finding (fixed, rebutted with the reason, or escalated); what the fixes
changed and the check results; on a milestone round the tenets as written
and those struck; and the job name, so the session stays continuable. Ideas
come last, after anything the caller's ask appends: one line for each idea
built, then one for each left unbuilt with your reason. They never count as
something that needs the user.

## More control

| the user asks for | what to pass |
|---|---|
| opus | `--with claude:claude-opus-5-5` |
| sol | `--with codex:gpt-6.2-sol:xhigh` |
| an effort ("astra on xhigh") | that effort in the voice: `codex:gpt-6.2-astra:xhigh` |
| a model id spelled out | as written, on `high` for Astra or Carbon and `xhigh` for another codex model (Carbon given no effort runs Medium) |

A warm voice beside a cold one on a goal brief takes each brief as
`<voice>=<brief>`, still one job:

```sh
envoy run review-r1 --with @consult-r1/codex-gpt-6.2-astra=<full-brief> --with claude:claude-fable-5-2=<goal-brief> \
  --instructions-file ~/.agents/skills/consult/VOICE.md --baseline <base-sha> --timeout-min 60
```

If envoy refuses `--instructions-file` beside a warm voice, VOICE.md changed
since that consult: leave the flag off as envoy says, and open the brief
with VOICE.md's path so the cold voice still reads the rules.
