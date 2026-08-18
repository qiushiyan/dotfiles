<!--
Brief template for /review in goal mode: the closing read. Rounds have already
run and their findings are applied; what is left to buy is altitude — did the
thing that shipped achieve what it was for. Copy the body below into a
scratchpad file, fill every «slot», delete these comments.

Two properties make this brief work, and both are easy to lose. It withholds
the design, exactly as FRESH-EYES-BRIEF.md does — a reviewer holding the
implementation's narrative cannot judge it from first principles. And it tells
the reviewer what earlier rounds already covered, which is what stops it
spending its whole budget re-finding line-level defects that are already fixed.
A goal brief without that section is just a late fresh-eyes review, and it will
report the details instead of the altitude.

Use this only where rounds have actually run. Where nothing has judged the work
yet, the closing read has nothing to close over — FRESH-EYES-BRIEF.md is the
instrument.
-->

# Goal review: «what this work was for, one line, in the user's terms»

«One paragraph: what the project is in plain terms, who this work is for, and
what they should be able to do now that it is done. Write it as though the
implementation did not exist — no mechanism, no file names, none of the
vocabulary this change invented. This paragraph is the standard the whole
review judges against, so it states the goal and never the solution.»

## Posture — the closing read, at altitude

Read `~/.config/lessons/collaboration/review-lens.md` before reviewing. The
bars that govern this round are its strategic ones: step back before judging
locally, over-building as the likelier failure, Chesterton's fence, and above
all **grade the artifact, not the account of it**. Seam-level and line-level
bars are not this round's work — earlier rounds owned them.

You were not told how this was built, deliberately. Several review rounds have
already gone through this work at the level of defects and structure; what none
of them could do is stand outside the whole thing and ask whether it achieved
what it was for. That is the only reading this round buys. A finding that a
careful line-by-line reader would have caught is not what you are here for —
and per the section below, it has probably already been caught.

**Before you open the implementation**, write down two or three sentences: what
this work should let someone do, and how you would know it succeeded. Keep
them — the gap between those and what shipped is what this round exists to
find, and it is unrecoverable once you have read the code.

## The work under review

- Branch `«branch»`, commits `«base-sha»..HEAD` — start from
  `git log «base-sha»..HEAD --stat`. «The user-facing entry points to read
  first.»
- Judge the code, not an account of it: comments, commit messages, and docs in
  the range say what was intended; only the code says what happens. Where they
  disagree the code wins, and the disagreement is a finding.
- Review only — do not change any code.

## Covered ground — what earlier rounds already went through

«Compiled from this session's review record, not from memory: the prior rounds
with their reviewers, the findings that were confirmed and fixed (one line
each, by what they were about rather than by id), the findings rebutted and on
what ground, and the structural decisions those rounds settled. Then one line
the compile can't produce: what those rounds did *not* reach, and why.»

Treat this as the floor, not the ceiling: those items are closed and
re-reporting them spends the one budget this round has, but the list records
what was *looked for* and never that the result is right. A defect can be
absent from every line above and the work still not do what it was for.

## Facts you can't get from the code

«Only what would make the review wrong if missing: operational limits, scope
deliberately deferred, external constraints. Never rationale for a choice
inside the diff. Nothing to say? Delete the section.»

## Evaluate

- **Did it land?** Against the goal above and the sentences you wrote before
  reading. Not "does it pass its tests" and not "is it well built" — can the
  person this was for actually do the thing, end to end, including the parts
  no single commit owns.
- **The obvious mistakes.** What a serious reader notices on a first honest
  pass: a case the goal plainly implies that nothing handles, a behaviour that
  contradicts what the feature claims, a surface that can't be reached. Not the
  defects that need a call chain traced to prove — those were earlier rounds'
  work.
- **Is it more complicated than the goal requires?** Count the concepts someone
  now has to learn to use or maintain this — modes, flags, paths, states,
  vocabularies. Compare that count to what the goal actually asks for. Name
  what could be deleted outright; do not trace call paths to justify it.
- **Did the rounds drift?** Several passes of fixes can each be right and the
  whole still end up somewhere other than the goal. Read the result as a
  stranger would, not as the sum of its corrections. This is the one question
  only the closing round can ask.

## Do not flag

- «deliberately deferred work, known out-of-scope items, staleness on record»
- Anything on the **covered ground** list — confirmed, rebutted, or settled.
- Line-level defects, seam hygiene, test mechanics, style, naming, docs.
- Theoretical risks behind unlikely preconditions; work the goal doesn't ask
  for.

## Output

1. **What I expected** — the sentences you wrote before reading, verbatim.
2. **Did it land** — achieved / partly / not, against the goal, with what a
   user can and can't do as the evidence. This is the verdict the round exists
   for; say it plainly before anything else.
3. **Obvious mistakes** — what, where, and why a reasonable person would expect
   otherwise. Unranked. "None" is a real answer.
4. **Weight it doesn't need** — the concepts that could be deleted without
   costing the goal anything, or "none".
5. **Design objections** — where you would have built this differently and what
   keeping it costs, or "none".

Be specific and terse; no praise padding, and no severity ladder — this round's
findings are either worth handling before merge or are decisions for the user.
