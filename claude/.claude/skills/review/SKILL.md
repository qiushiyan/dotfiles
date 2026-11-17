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
voice of another family (step 4):

```sh
envoy run review-r1 --with @consult-r1/codex-gpt-6.2-astra --with claude:claude-fable-5-2 --prompt-file <brief> \
  --instructions-file ~/.agents/skills/consult/VOICE.md --baseline <base-sha> --timeout-min 60
```

Any other model, effort or brief split: § More control.

## 1. Fix the range

The unit of review is commits. Find the baseline sha: one the conversation
already knows (a delegate baseline, the merge-base with the default branch)
or one the user names. Confirm the contents with `git log <base>..HEAD
--oneline`; every commit in the range belongs to the work under review. A
dirty tree escapes review: have the user commit, stash, or explicitly accept
reviewing the commits alone.

## 2. Pick the question, then the mode

| the request says | the question | mode |
|---|---|---|
| "goal", "high level", "step back", "from first principles", "one last look", "I'm confident in the internals, catch the obvious mistakes" | did we build the right thing? | **goal** |
| "full", "deep", or nothing about altitude | is it built right? | **full** |

A good ask carries the goal in the user's terms, what something outside this
session settled, and what the round should not be spent on; supply what a
one-word ask leaves out from the session. Say the pick back in one line
before writing anything, voices included: "this round buys *is it built
right*, full mode, @consult-r1 warm beside a cold fable". That line is the
user's one chance to redirect the round. Stop to ask only where the pick is
genuinely balanced.

**goal** ([GOAL-BRIEF.md](GOAL-BRIEF.md)) is the cheap read at altitude,
before any other round or as the closing one. It withholds the design: the
reviewer gets the goal, the facts outside the diff, the standards, and what
has already judged the range, and states its expectation before opening the
code. Assemble:

- **The facts block:** operational limits, scope boundaries, constraints the
  code cannot reveal. Facts about the world outside the diff, never
  justifications of choices inside it.
- **Already judged,** compiled from the session's record, never recalled:
  prior review rounds (`envoy collect review-r1` …), their reports, and the
  fix commits that carry their round coordinates (step 6); consult rounds,
  named by the question each judged, never by what it settled, since a
  consult's outcome is the design this brief withholds; bot reviewers; the
  suites and what they cover. Each with what it found, plus one line on what
  none of them reached. Where nothing has looked, write "nothing", so the
  reviewer does not assume defects were caught.

**full** ([BRIEF-TEMPLATE.md](BRIEF-TEMPLATE.md)) is the deep read. The
reviewer gets the implementation report and, where something outside this
session settled the direction, a fence of settled decisions. When nothing
outside the session has judged the design, delete the fence and say so:
everything is open, the design included. The report comes by provenance:

- A /delegate built it: its `result.md` report, verbatim.
- This session built it: write it now. What and why, the change map with the
  load-bearing files marked, key decisions, deviations from spec or plan,
  test coverage and its altitude, and where to look hardest, including where
  the build fought back (multi-attempt fixes, code re-read before it could be
  trusted), stated as struggle, not defended. It is a map pointing at risk,
  not a self-review.
- The user built it elsewhere: reconstruct only the what and why and the
  change map from the commits, and open with "reconstructed from commits,
  not implementer-authored".

Both modes carry **the standards the work was built to**: any rulebook this
session read before building, by path. A range that rests on a number this
session measured (a report, a spec, a threshold in the diff) keeps the
template's data section and method item, filled to
`~/.agents/skills/consult/DATA-BLOCK.md`, with the queries and raw outputs
saved beside the brief. Otherwise delete both.

## 3. Write the brief

Write one self-contained file in the session scratchpad, named for the round
(`review-r1.md`), from the mode's template. Done when a cold reader could
deliver the review without this conversation. Two slots leak, in opposite
directions:

- The **goal paragraph** says what the feature is for in the user's own
  terms, with none of the vocabulary this change invented. The ideas slot's
  person and moment follow the same rule.
- An **already judged** line says what was looked at and what came of it,
  never why a decision was made, which would hand back the design the round
  exists to judge.

`~/.agents/skills/consult/VOICE.md` rides beside the brief with every
voice's standing rules, so the brief carries only the review.

Each «slot» in a template says when its section stays and how to fill
it.

## 4. Dispatch

Run the mode's command (§ Voices) as one background Bash task, the job named
for the round (`review-r1`, then `review-r2`), and return. The task
completing is the signal; nothing the dispatch prints needs relaying.

**goal** is one cold voice, single turn, never a fan-out on its own. A warm
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
  two voices of one model mostly find the same things: fable beside a warm astra or
  carbon, astra beside a warm fable. A voice the user names is the cold
  voice as named.
- **Warm judges follow-through**: did the build integrate what was agreed
  and dodge the traps its rounds discussed. It is a poor judge of the design
  it committed to, and it takes only a full brief. When the user wants the
  design re-judged too, add a cold voice on a goal brief to the same job,
  each brief attached to its voice, so the cold voice never sees the full
  brief (§ More control).

Collapse to the single cold turn when the user asks for that voice alone,
when the consult weighed a different design than this range implements, or
when the user prefers the cheaper dispatch. Warm-only, the user asking the consult
voice itself to review, is a follow-through check rather than an independent
review: run it and call it that in the report. Add more cold voices only
when the user asks.

## 5. Judge every finding

`envoy collect review-r1` prints the findings; any other status prints a
`next:` line, so follow it. Verify every finding against the code before
accepting it: read the cited lines and retrace the claimed failure path.
Reviewers state hallucinated issues with the same confidence as real ones.
Weight by position, never by count: neither the warm voice endorsing its own
design nor agreement between reviewers earns anything.

- **Wrong behavior, critical or moderate:** reading is not verification,
  because you retrace the code with the mental model that wrote the bug. Pin
  it with a test before thinking about a fix: a new case, or an existing one
  sharpened to reach the cited path. Red for the claimed reason confirms the
  finding and becomes the regression test. Green, where the test really
  exercises the path, is the strongest rebuttal there is.
- **Nothing executable to pin** (reshapes, doc claims, test-quality
  findings, paths no harness reaches) stays read-verified. Verify a
  composition finding by walking its trace: the hops it names exist and do
  what it says, then judge the join yourself. The code working is no
  rebuttal, nor is the reshape being
  larger than the patch. A hop that adds something the reviewer could not see
  is, and so is a second caller the reshape would have to invent. A range
  with nothing executable at all (a proposal, a docs pass, eval cases) is
  judged against its sources, at undiminished scrutiny.
- **Unpinned behaviour:** run the reviewer's revert test yourself. Revert
  the behaviour in a scratch copy and run the test it named, or write the one
  it could not. Red rebuts the finding; green over a reverted behaviour
  proves it, and the fix is the test, not the code. More coverage over a
  behaviour nobody would miss is not a finding.
- **A goal round** returns judgments, headed by the **did it land** verdict.
  For an expectation violation, confirm the code does what the reviewer
  says, then judge the expectation against the goal: one a reasonable user
  would hold is a real defect with every test green; one that contradicts
  the goal is rebutted on that ground. Confirm the verdict against the
  code and report your own, restated after the fixes. Each design objection
  is foundational: confirm its premise, form your own position, and put
  both to the user. A line-level defect the earlier
  rounds missed is still a real finding; take it, and note that already
  judged over-claimed.
- **Tenets** from a milestone round meet the bar in
  `~/.config/lessons/collaboration/tenets.md`; one that fails it is a tip,
  at whatever severity its content earns.
- **Ideas** get a take, not a verdict: confirm the friction or risk is
  real and unhandled, then decide whether you recommend it and why. An idea that is a defect (a
  reachable state with no handling, a case the goal implies) joins the
  findings at the severity it earns (in a goal round, among the obvious
  mistakes). With several voices, keep the best two or three.

You wrote this code, so the bias cuts both ways: adopting findings to be
agreeable and rebutting them to defend your work are equal failures. Meet a
structural reframing on its merits; a narrower local patch is not a
rebuttal. A finding that asks for a test gets the same scrutiny as one that
asks for code: locate the bug it would catch, and the absence of a test
already catching it. A test the reviewer wants deleted is verified the same
way.

Done when every finding is confirmed, rebutted with a first-principles
reason, or foundational for the user to decide; every critical or moderate
behavioral verdict names the test that decided it, or why none could; and
every idea has a take.

## 6. Fix, and account for the tests

You are the implementer here. Fix every confirmed finding, minors included
unless the ask says otherwise; an unpinned-behaviour finding is fixed by
writing its test. A goal round's confirmed obvious mistakes count as
moderate, pinned in step 5 and fixed here. Its design objections, and the
weight the reviewer would delete, wait for the user: applying one unasked
is the failure there.

- **Design the fix from the finding, not from the red test.** The cheapest
  change that greens it is usually the local patch the reviewer stepped past.
  A confirmed structural or compositional finding gets the actual reshape,
  not a shrunken local version or a deferral: a deferred composition finding
  ships the second mechanism.
- **Write for the next reader,** who never sees this review: comments and
  test titles state the behavior and its reason in the present tense. The
  round's coordinates go in the commit message: `(review r2)`, the finding
  id, in a full round its class tag, and the reviewer's member name, with
  the changelog voice (`previously`, `no longer`). A later goal round
  compiles its already judged from them.
- **A confirmed `model-facing` finding is a product fix** and lands now,
  whatever rule defers documentation to a later pass.
- **Every confirmed bug indicts the suite,** which was green over it.
  Decide whether the step-5 test filled a gap or must replace a weak test
  (wrong altitude, over-mocked, asserting internals). A test whose subject
  the fix removed is a tombstone: delete it rather than invert it.
- **Tenets go into the spec** on a milestone round, as `## Tenets` beside its
  phases: the first milestone creates the section, a later one revises it in
  place, keeping each struck tenet with its reason. They land in the fix
  commit, or their own. The build rereads the spec after every compaction,
  and a tenet left in this conversation is lost at the next one.
- **Build the ideas you recommend, without asking,** after the fixes, in
  a commit of their own the user can revert, with a test where an idea
  adds behaviour. Leave one
  unbuilt only when it is a product decision the user should make (a new
  mode, flag, command or option, or a change in what users can do), needs
  authority this session lacks, or the ask says ideas wait.

Done when the project's checks are green over the fixes and the ideas
built, the step-5 tests among them.

## 7. Round 2, when the fixes were substantive

A full round only; goal has none unless the user asks. Send a per-finding
summary of what changed, rebuttals included, into the same session (one
voice or the whole fan-out) with the `resume:` command collect printed, a
fresh name (`review-r2`) and the summary as its prompt file. The question is
narrow: was each point integrated or hand-waved, and did the fixes regress
anything? Converge; do not relitigate. Leave the ideas out. For light
fixes, the tests that pinned them are the cheap substitute.

## 8. Report

The user did not watch the round and decides from this message alone. Lead
with what needs them, each foundational objection or design decision in none
of the round's vocabulary; where nothing does, say so in the first line.

Then the question the round bought and its mode; the verdict per finding
(fixed, rebutted with the reason, or escalated); what the fixes changed and
the check results; on a milestone round the tenets as written and those
struck; and the job name, so the session stays continuable. Ideas come
last, after anything the caller's ask appends: one line for each idea
built, then one for each left unbuilt with your reason. They never count
as something that needs the user.

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
