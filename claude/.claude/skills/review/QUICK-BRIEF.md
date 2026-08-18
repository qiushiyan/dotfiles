<!--
Brief template for /review in quick mode: the range decided nothing, and the
review is buying one reading — does this break anything. Copy the body below
into a scratchpad file, fill every «slot», delete these comments. A section
with nothing real to say gets deleted, not filled.

Quick is narrow, never shallow. What it drops is altitude, not rigour: no
design judgment, no structural findings, no reshapes — and in exchange the
lenses it keeps are run to the same standard as a full review. The saving is
this brief's assembly (no implementation report, no settled decisions, no
reading order) and the width of the read, not the care taken inside it.

When nothing outside the implementation has judged the design, this is the
wrong instrument — the range decided something, and a correctness-only lens
cannot see what. Use FRESH-EYES-BRIEF.md.
-->

# Quick review: «what the change does, one line, in the user's terms»

«Two or three sentences: what this change is for and what it claims to do.
Where a bug is being fixed, the wrong behaviour and the intended one. This is
the whole orientation — there is no spec and no design narrative behind it.»

## Posture — narrow, not shallow

Read `~/.config/lessons/collaboration/review-lens.md` before reviewing. Two of
its bars are **out of scope this round**: judging how the change joins the
design, and stepping back to propose a reshape. Everything else governs at full
strength — Chesterton's fence, the additive-bias bar on any test you request,
over-building as the likelier failure, evidence behind every finding, and
grading the code rather than the account of it.

If the range turns out to have decided something structural after all, do not
review it here: say so in one line under **Escalation** and keep going with the
lenses below. That line is the signal that this was the wrong instrument, and
it is worth more than a structural finding filed in the wrong round.

## The work under review

- Branch `«branch»`, commits `«base-sha»..HEAD` — start from
  `git log «base-sha»..HEAD --stat`.
- **Read the code, not only the diff.** Every lens below except the first
  requires reading files the diff does not touch; a review that stays inside
  the patch cannot answer them.
- Judge the code, not an account of it: commit messages say what was intended,
  only the code says what happens. Where they disagree the code wins, and the
  disagreement is a finding.
- Review only — do not change any code.

## Facts you can't get from the code

«Only what would make the review wrong if missing: operational limits, work
deliberately deferred, unrelated changes sharing the tree, an external
constraint the code can't reveal. Nothing to say? Delete the section.»

## Evaluate

- **Does it do what it says?** Against the intent above and the commit
  messages, for the person using it.
- **Blast radius — what it breaks that isn't in the diff.** For every signature,
  return shape, default, error mode, enum value, exported name, or config key
  the change touched: find the other callers and read them. This is the lens
  the author is worst placed to run and the one a small diff hides best.
- **Does green mean anything?** Run **the revert test** on each behaviour this
  change added or altered: name the test that goes red if the change is
  reverted. A behaviour with no such test is **unpinned** — the suite says
  nothing about it, and that is a finding whatever the coverage number says.
  Then run the same test on the tests the range itself touched, because three
  shapes stay green through anything: an assertion on a mock's return rather
  than the code's behaviour, an assertion on shape or call count rather than
  the value that actually changed, and — the common one — a test edited in the
  same commit so its expectation now matches the new output, which documents
  the change instead of pinning it. A test you request still owes the
  additive-bias bar.
- **The edges this change created or moved** — empty, absent, failed,
  duplicated, out-of-order, concurrent. Only the edges the diff is responsible
  for.
- **Silent behaviour changes** — a default flipped, a guard removed, an
  unrelated path altered, scope past what the intent above claims. Cheap to see
  now, expensive to find later.
- **Footguns** — unawaited promises, swallowed errors, leaked resources,
  off-by-one, mutation of shared or caller-owned state, a check that races the
  thing it checks.

## Do not flag

- «deliberately deferred work, known out-of-scope items, staleness on record»
- **Structure, composition, and design** — module shape, layering, how the
  change joins the existing call path, whether a reshape would have been
  better. These have one outlet here, the escalation line below: one line
  naming what you saw, and nothing on how to fix it.
- Test-suite quality beyond the green question above — naming, organisation,
  coverage philosophy, altitude debates.
- Style, naming, comments, and docs that follow this repo's own conventions.
- Theoretical risks behind unlikely preconditions; defense-in-depth where the
  primary defense is adequate; hardening nobody asked for.

## Output

1. **Findings** — **critical** (blocks merge) / **moderate** (fix before merge)
   / **minor**. For each: what, where (file/function), the code that proves it,
   a concrete fix. Say "none" for an empty tier.
2. **Unpinned behaviour** — every behaviour the revert test found no test for,
   and every range-touched test that pins nothing. "None" is a real answer.
3. **Escalation** — at most one line, only if the range decided something this
   round's lenses can't judge. Name what, not how to fix it. Otherwise omit.

Be specific and terse; no praise padding.
