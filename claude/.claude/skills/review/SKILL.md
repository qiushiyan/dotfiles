---
name: review
description: Review committed work with a fresh codex or claude session, then apply what survives. Use when the user asks for a review round, or a goal or full review.
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
verdict. The review being bought is strategic: findings that reshape the
design (a new module, a shared extraction, a collapsed call path), not tweaks
inside the implementation's frame. The round is done when every finding has
a verdict, the fixes are green, and the user has a report they can decide
from alone.

## Resolving the voice

Name the model on every cold voice, and the effort on a codex one, so the
job records what ran. Resolve it from the user's words:

```sh
--with codex:gpt-6-astra:high    # the default: no voice named, "codex", or "astra"
--with codex:gpt-6.1-sol:xhigh   # "sol"
--with claude:claude-opus-5-5    # "claude", "opus"
--with claude:claude-fable-5-1   # "fable"
--with codex:gpt-6-astra:xhigh   # another effort only when the user asks: "astra on xhigh"
```

A model ID the user spells out goes through as written, a codex one on
`xhigh` unless they name an effort. A warm voice (`@<job>/<member>`) keeps
the model it started on.

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
right*, full mode, @consult-r1 warm beside a cold opus". That line is the
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
`~/.claude/skills/consult/DATA-BLOCK.md`, with the queries and raw outputs
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

Every voice's standing rules ride beside the brief as `--instructions-file
~/.agents/skills/consult/VOICE.md`. If envoy refuses it beside a warm voice
that started without it, drop the flag and open the brief with that path.

Each «keep when» slot in a template states its own condition. The full
brief's Structural quality and Composition lines are fixed text, so their
condition lives here:

- **Structural quality** stays whenever the range decides structure: new
  modules, reshaped interfaces, a real refactor, a schema or data migration.
  Trim it only when the work is structurally inert, such as a version bump
  or a mechanical syntax migration, however large the diff.
- **Composition** survives that trim on a small contained fix, because a
  patch bolted onto an existing call path is the shape it exists to catch.
  Drop it only where the range adds no hop and rewires nothing.

In goal mode the structural block is one slot with its own condition; the
concept-count question the goal brief always carries is the altitude
composition reaches without it.

A range is a milestone when the user says "phase 1 is done" or "the rest
continues here", or the spec's phases are partly unbuilt; keep **The rest of
the build** then. When the range changes an agent's prompts, tools or
skills, or alters what one of its tools does, keep **What the model is
told**, and write any do-not-flag line about docs so it excludes
those surfaces: a fresh read has found misleading model-facing text on
ranges that passed full rounds without it.

Keep **Where this can be better** in both modes unless the ask says no ideas
or the range is mechanical. Fill in who uses the work and when, and pick the
kind of better by what a failure costs: harder to break wherever a failure
loses work or misleads someone, smoother to use otherwise, both where both
apply.

## 4. Dispatch

Run one background Bash task, the job named for the round (`review-r1`, then
`review-r2`), and return. The task completing is the signal; nothing the
dispatch prints needs relaying. If the notification is lost to a compaction
or a restart, `envoy pending` says what still needs attention.

**goal** is one cold voice, single turn, 45-minute cap, never a fan-out on
its own. A warm voice holds the design, which is what goal must judge
without.

```sh
envoy run review-r1 --with codex:gpt-6-astra:high --prompt-file <brief> --instructions-file ~/.agents/skills/consult/VOICE.md --baseline <base-sha> --timeout-min 45
```

**full** has a 60-minute cap, and its shape follows one question: did a
consult in this session weigh the design this range implements? With no
consult, one cold reviewer:

```sh
envoy run review-r1 --with codex:gpt-6-astra:high --prompt-file <brief> --instructions-file ~/.agents/skills/consult/VOICE.md --baseline <base-sha> --timeout-min 60
```

With a consult, one fan-out: the consult session continued beside a cold
voice.

```sh
envoy run review-r1 --with @consult-r1/codex-gpt-6-astra --with claude:claude-opus-5-5 --prompt-file <brief> --instructions-file ~/.agents/skills/consult/VOICE.md --baseline <base-sha> --timeout-min 60
```

- **Name the member** whose position the implementation followed, as the
  consult's synthesis recorded it. A one-voice consult is `@consult-r1`
  alone. A fan-out consult holds one session per member, named `<provider>`
  or `<provider>-<model>` as its collect block prints them
  (`codex:gpt-6-astra:high` is member `codex-gpt-6-astra`), and
  `@consult-r1` alone there would continue every member and seat no cold
  voice. Name the latest round: after a round 2, `@consult-r2/…`. Seating
  every member warm is the user's call, one `--with @<member>` each.
- **The cold voice is the warm voice's other family.** Two voices of one
  model mostly find the same things. A warm codex voice, whether a one-voice
  consult or a member, takes `claude:claude-opus-5-5` cold; a warm Claude
  one (member `claude-claude-opus-5-5`) takes `codex:gpt-6-astra:high`. This outranks the stock
  words "codex" and "astra"; a voice the user picks beyond them is the cold
  voice as typed.
- **Warm judges follow-through**: did the build integrate what was agreed
  and dodge the traps its rounds discussed. It is a poor judge of the design
  it committed to, and it takes only a full brief. When the user wants the
  design re-judged too, add a cold voice on a goal brief to the same job,
  each brief attached to its voice, so the cold voice never sees the full
  brief:

  ```sh
  envoy run review-r1 --with @consult-r1/codex-gpt-6-astra=<full-brief> --with claude:claude-opus-5-5=<goal-brief> --instructions-file ~/.agents/skills/consult/VOICE.md --baseline <base-sha> --timeout-min 60
  ```

Collapse to the single cold turn when the user asks for one voice, when the
consult weighed a different design than this range implements, or when the
user prefers the cheaper dispatch. Warm-only, the user asking the consult
voice itself to review, is a follow-through check rather than an independent
review: run it and call it that in the report. Add more cold voices only
when the user asks, each resolved as in **Resolving the voice**.

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
  Verify it like a design objection: confirm what the code does, form your
  own position, and put both to the user. For an expectation violation, confirm the code does what the reviewer says,
  then judge the expectation against the goal: one a reasonable user would
  hold is a real defect with every test green; one that contradicts the goal
  is rebutted on that ground. A design objection is foundational: verify its
  premise, form your own position, and put both to the user. A line-level
  defect the earlier rounds missed is still a real finding; take it, and
  note that already judged over-claimed.
- **Tenets** from a milestone round meet the bar in
  `~/.config/lessons/collaboration/tenets.md`; one that fails it is a tip,
  at whatever severity its content earns.
- **Ideas** get a take, not a verdict: the friction or risk is real, the
  code does not already handle it, and the idea is as small as asked; then
  say whether you would take it and why. An idea that is a defect (a
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

You are the implementer here. Apply the confirmed criticals and moderates;
minors go by the user's preference. Ideas wait for the user, whatever the
ask says about minors. An unpinned-behaviour finding is fixed by writing its
test, here. A goal round has no severity ladder: report first
(step 8), build what the user authorizes, and report again. Applying a
design objection unasked is the failure there.

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

Done when the project's checks are green over the fixes, the step-5 tests
among them.

## 7. Round 2, when the fixes were substantive

A full round only; goal has none unless the user asks, since its findings
are decisions for the user or a reason to run full. Send a per-finding
summary of what changed, rebuttals included, into the same session (one
voice or the whole fan-out) with the `resume:` command collect printed, a
fresh name (`review-r2`) and the summary as its prompt file. The question is
narrow: was each point integrated or hand-waved, and did the fixes regress
anything? Converge; do not relitigate. Leave the ideas out. For light fixes, the tests that pinned them
are the cheap substitute.

## 8. Report

The user did not watch the round and decides from this message alone. Lead
with what needs them: each foundational objection or design decision as its
own question, with why it matters now, what it means in plain product
terms, the options and what each means for the person using the product,
and your recommendation, in none of the round's vocabulary. Where nothing
needs them, say so in the first line.

Then the question the round bought and its mode; the verdict per finding
(fixed, rebutted with the reason, or escalated); what the fixes changed and
the check results; on a milestone round the tenets as written and those
struck; and the job name, so the session stays continuable. Ideas come
last, one line each with your take, after anything the caller's ask
appends. They never count as something that needs the user.
