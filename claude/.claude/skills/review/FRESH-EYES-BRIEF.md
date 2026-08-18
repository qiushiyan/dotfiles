<!--
Brief template for /review in fresh-eyes mode. Copy the body below into a
scratchpad file, fill every «slot», delete these comments. A section with
nothing real to say gets deleted, not filled — an empty heading invites
invented content, and the skeleton is a checklist for you, not a shape the
brief owes the reviewer.

What this template is for is what it leaves out: the reviewer gets the goal and
nothing about how the implementation chose to reach it — no spec, no settled
decisions, no design narrative, no implementation report. Every sentence of
rationale added back buys a cheaper review and a narrower one. When the design
is genuinely settled and the question is faithful execution of it,
BRIEF-TEMPLATE.md is the instrument; the two don't blend.
-->

# Fresh-eyes review: «the goal, one line, in the user's terms»

«One paragraph: what the project is in plain terms, who this feature is for,
and what they should be able to do once it works. Write it as though the
implementation did not exist — no mechanism, no file names, none of the
vocabulary this change invented.»

## Posture — a cold read

Read `~/.config/lessons/collaboration/review-lens.md` before reviewing — its
stance governs every finding.

You were not told how this was built, deliberately: you are the read its next
maintainer will get, and what you have to work out for yourself is what the
implementer can no longer see. Derive from the goal above what this should do
for the person using it, then read the code and judge what is there against
that.

**Before you open the implementation**, write down two or three sentences: what
you expect this feature to do, and how you expect it to behave when things go
wrong. Keep them — the gap between those and what you find is the most valuable
thing this review produces, and it is unrecoverable once you have read the code.

Because you have no design document to check against:

- **Report what surprises you.** An expectation a reasonable person would hold,
  violated by the implementation, is a finding: state the expectation and what
  you observed. It needs no proven bug behind it. "I might be missing context"
  is a caveat to write down, not a reason to stay quiet.
- **The design is in scope.** Nothing here is fenced off from you. Keep design
  objections in their own section: a defect is the code failing its own intent,
  a design objection says the intent is wrong.

## The work under review

- Branch `«branch»`, commits `«base-sha»..HEAD` — start from
  `git log «base-sha»..HEAD --stat`. «The user-facing entry points to read
  first.»
- Judge the code, not an account of it: comments, commit messages, and any docs
  in the range say what was intended; only the code says what happens. Where
  they disagree the code wins, and the disagreement is a finding.
- Review only — do not change any code.

## Facts you can't get from the code

«Only what would make the review wrong if missing, never rationale — the test
for each line is whether it states a fact about the world outside this diff or
justifies a choice inside it. Three kinds qualify: operational limits (what
must not be run, what is unreachable from here), scope (work deliberately
deferred, unrelated changes sharing the tree), and external constraints the
code cannot reveal (a deploy fact, a compatibility requirement, a consumer that
can't change).»

## The standards this work was built to

«The rulebooks the implementer worked under, by absolute path — the guidance
documents this session read before building — plus, where one exists, a sibling
module or test in this repo that solves an analogous problem well. Nothing here
may reveal how the change works; a document that would belongs in neither list.
Nothing to name? Delete the section.»

## Evaluate

- **Does it do the job?** Against the goal above and the expectation you wrote
  down — for the person using it, not for the tests.
- **The edges a user actually meets** — empty, slow, failed, retried,
  interrupted, concurrent, first-run. What happens then, and is it what a
  reasonable person would expect?
- **Test quality** — behavior, not internals; survives a plausible refactor;
  follows this repo's test patterns. A test this change made obsolete —
  asserting behavior that's gone, or pinned to internals that moved — is a
  finding too.
- **Structural quality** — read `~/.config/lessons/codebase-design/deep-modules.md`
  for the bar, and write structural findings in its vocabulary. When the change
  restructures an existing cluster, `~/.config/lessons/codebase-design/deepening.md`
  decides whether a seam earns a port, and replace-don't-layer for the moved
  tests.
- **Composition — how this joins what was already there** — read
  `~/.config/lessons/codebase-design/composition.md` and run **the trace** it
  defines, then judge the join: did the concepts already in the codebase absorb
  the new case, or did it get its own route beside them? You are the right
  reader for this — you were told nothing about how it was built, so a hop that
  only makes sense from inside the implementation's history will not make sense
  to you either. Name the reshape and the concept it deletes, and only where a
  caller that exists today pays for it.

## Do not flag

- «deliberately deferred work, known out-of-scope items, staleness on record»
- Theoretical risks behind unlikely preconditions; defense-in-depth where the
  primary defense is adequate.
- Style that follows this repo's own conventions, even where you'd choose
  differently.
- The absence of anything the goal above doesn't ask for.

## Output

1. **What I expected** — the sentences you wrote before reading, verbatim.
2. **The trace** — the hops of the one path you followed, entry to effect, one
   line each for what that hop adds, and "adds nothing" where that is the
   answer. Findings can cite it by hop instead of re-describing the path.
3. **Expectation violations** — what you expected, what it does, where in the
   code. Unranked, and the section this review exists for; "none" is a real
   answer, said explicitly.
4. **Defects** — **critical** (blocks merge) / **moderate** (fix before merge) /
   **minor**. Structural and compositional regressions are critical, not minor —
   a path that works and accreted has still failed. For each: what,
   where (file/function), the code that proves it, a concrete fix. Say "none"
   for an empty tier.
5. **Design objections** — where you would have built this differently and what
   keeping it costs, or "none".

Be specific and terse; no praise padding.
