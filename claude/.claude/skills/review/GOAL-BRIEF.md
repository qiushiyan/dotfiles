<!--
Brief template for /review in goal mode: the cheap independent read, at
altitude. It runs before any other round or as the closing read after them;
what it buys is the same either way — did the thing that shipped achieve what
it was for. Copy the body below into a scratchpad file, fill every «slot»,
delete these comments. A section with nothing real to say gets deleted, not
filled: an empty heading invites invented content.

Two properties make this brief work, and both are easy to lose. It withholds
the design — a reviewer holding the implementation's narrative cannot judge it
from first principles. And it tells the reviewer honestly what has already
looked at this range, including "nothing": that is what stops it either
re-finding fixed defects or assuming defects were already caught.

The structural block under Evaluate is a switch: keep it when the range
decides structure — a new module, a reshaped interface, a real refactor — and
delete it when the range is structurally inert, however large the diff.
-->

# Goal review: «what this work was for, one line, in the user's terms»

«One paragraph: what the project is in plain terms, who this work is for, and
what they should be able to do now that it is done. Write it as though the
implementation did not exist — no mechanism, no file names, none of the
vocabulary this change invented. This paragraph is the standard the whole
review judges against, so it states the goal and never the solution.»

## Posture — the read at altitude

Read `~/.config/lessons/collaboration/review-lens.md` before reviewing. The
bars that govern this round are its strategic ones: step back before judging
locally, over-building as the likelier failure, Chesterton's fence, and above
all **grade the artifact, not the account of it**. Seam-level and line-level
bars are the full review's work, not this round's — except where the
structural block below is present.

You were not told how this was built, deliberately: you are the read the next
maintainer will get, and what you have to work out for yourself is what the
implementer can no longer see. Stand outside the whole thing and ask whether
it achieved what it was for; that is the reading this round buys.

**Before you open the implementation**, write down two or three sentences: what
this work should let someone do, and how you would know it succeeded. Keep
them — the gap between those and what shipped is what this round exists to
find, and it is unrecoverable once you have read the code.

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
- Judge the code, not an account of it: comments, commit messages, and docs in
  the range say what was intended; only the code says what happens. Where they
  disagree the code wins, and the disagreement is a finding.
- Review only — do not change any code.

## Already judged — what has looked at this range, and what it found

«Compiled from this session's record, not from memory: the prior review
rounds with their reviewers and what was confirmed, fixed, or rebutted (one
line each, by what it was about, never the reasoning behind it); the consult
rounds that shaped the design — the question each judged and that the range
implements its result, never the result itself, which is the design this
brief withholds; bot reviewers and what they reported; the suites that are
green and what they cover. Then one line
the compile can't produce: what none of them reached, and why. Where nothing
has looked at this range yet, write exactly that — "Nothing has reviewed this
range" is a complete section, and a check result joins it only from a run on
record.»

This is a record of what was *examined*, never a claim that the result is
right and never immunity: re-reporting an item as it stands spends the one
budget this round has, but a materially different counterexample — a path
those rounds did not trace, a user those rounds did not consider — reopens it,
and you should say so.

## Facts you can't get from the code

«Only what would make the review wrong if missing: operational limits, scope
deliberately deferred, external constraints. Never rationale for a choice
inside the diff. Nothing to say? Delete the section.»

## The data behind this change

«Only when the range rests on a measurement this session produced — a
report, a spec or a threshold in the diff built from its own queries, logs,
eval or classification; else delete this section and the output's method
item. Fill it to `~/.claude/skills/consult/DATA-BLOCK.md`: observed only,
the queries and raw outputs by absolute path, what the reviewer can run.»

## The standards this work was built to

«The rulebooks the implementer worked under, by absolute path — the guidance
documents this session read before building — plus, where one exists, a sibling
module or test in this repo that solves an analogous problem well. Nothing here
may reveal how the change works; a document that would belongs in neither list.
Nothing to name? Delete the section.»

## Evaluate

- **Did it land?** Against the goal above and the sentences you wrote before
  reading. Not "does it pass its tests" and not "is it well built" — can the
  person this was for actually do the thing, end to end, including the parts
  no single commit owns.
- **The obvious mistakes.** What a serious reader notices on a first honest
  pass: a case the goal plainly implies that nothing handles, a behaviour that
  contradicts what the feature claims, a surface that can't be reached, an
  edge the user actually meets — empty, slow, failed, retried, interrupted,
  first-run. Not the defects that need a call chain traced to prove — those
  are the full review's work.
- **Does green mean anything?** For each behaviour the goal plainly implies
  and whose regression would matter, name the test that goes red if it is
  reverted. A behaviour with no such test is **unpinned**, and that is a
  finding whatever the coverage number says. Skip behaviours whose regression
  would cost nothing; this is not a request for coverage.
- **Is it more complicated than the goal requires?** Count the concepts someone
  now has to learn to use or maintain this — modes, flags, paths, states,
  vocabularies. Compare that count to what the goal actually asks for. Name
  what could be deleted outright.
- **Did the rounds drift?** «keep only when earlier rounds ran; otherwise
  delete this bullet» Several passes of fixes can each be right and the whole
  still end up somewhere other than the goal. Read the result as a stranger
  would, not as the sum of its corrections.
- **Structural quality and composition** «keep only when the range decides
  structure; otherwise delete this bullet» — read
  `~/.config/lessons/codebase-design/deep-modules.md` for the bar and write
  structural findings in its vocabulary; when the change restructures an
  existing cluster, `~/.config/lessons/codebase-design/deepening.md` decides
  whether a seam earns a port. Then read
  `~/.config/lessons/codebase-design/composition.md`, run **the trace** it
  defines, and judge the join: did the concepts already in the codebase absorb
  the new case, or did it get its own route beside them? You are the right
  reader for this — you were told nothing about how it was built, so a hop
  that only makes sense from inside the implementation's history will not
  make sense to you either. Name the reshape and the concept it deletes, and
  only where a caller that exists today pays for it.

## Do not flag

- «deliberately deferred work, known out-of-scope items, staleness on record»
- Anything under **already judged** as it stands there — confirmed, rebutted,
  or settled — unless you hold a counterexample those rounds did not.
- Seam hygiene, test mechanics, style, naming, docs — unless the structural
  block above is present, and then only structural findings.
- Theoretical risks behind unlikely preconditions; work the goal doesn't ask
  for; the absence of anything the goal above doesn't ask for.

## Output

1. **What I expected** — the sentences you wrote before reading, verbatim.
2. **The method** «only when the data section is kept» — before the verdict:
   is the right data pulled for the question, is data missing that would
   change the answer, is the approach sound, and which measured claims it
   cannot support as stated. Doubt a count: re-run or vary it if the brief
   says you can, else say what you would run and what a different result
   would change. "Sound, with these limits" is a real answer.
3. **Did it land** — achieved / partly / not, against the goal, with what a
   user can and can't do as the evidence. This is the verdict the round exists
   for; say it plainly before anything else.
4. **Obvious mistakes** — what, where, and why a reasonable person would expect
   otherwise. Unranked. "None" is a real answer.
5. **Unpinned behaviour** — each behaviour the revert test found no test for,
   or "none".
6. **Weight it doesn't need** — the concepts that could be deleted without
   costing the goal anything, or "none".
7. **Structural findings** «only when the structural block was kept» — open
   with the trace, one line per hop for what it adds and "adds nothing" where
   that is the answer; then each finding with the code that proves it and the
   reshape it names.
8. **Design objections** — where you would have built this differently and what
   keeping it costs, or "none".

Be specific and terse; no praise padding, and no severity ladder — this round's
findings are either worth handling before merge or are decisions for the user.
