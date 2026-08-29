## Pickup gate — build

**The direction is settled; the premises are on trial.** This brief carries
an approach something outside the writing session already judged — an
approved spec, a consult record, a PR to continue. The first turn does not
reopen the problem definition or the direction: it verifies that the world
still matches what the approach assumes, and judges the *actions* — order,
scope, the first cut — as sharply as a design pass would. No code changes;
the worktree stays as `brief start` placed it, and the turn ends on the
verdict.

Read `brief drift` first. A claim the drift shows moved is checked against
the moved code; a brief instruction the drift makes moot is named as such
rather than followed.

Return exactly this shape (~40 lines):

```markdown
## 1. Problem in plain terms
<who is affected · what fails · why the reviewed approach removes that failure — in your own words, from what you read>

## 2. Premises checked
- <the single premise that must be true for the approach to solve the stated problem, listed by the brief or not> · Held — <evidence> | Falsified — <what is true instead> | Unverified — <what would settle it>
- <each `## At pickup` claim, at its named source> · …

## 3. Scope test
<the next PR's boundary against the as-built: fold forward | unbundle | right as drawn — with the cost of the wrong boundary>
First cut: <the smallest change that makes the load-bearing premise observable — a red test, a probe, a spike>

## 4. Verdict
Build framing holds — <why> | Reframe required — <what changed, failed, or remains unverified, and the smallest consequence for the work>
Decision needed: <only a product fork that verification exposed — options, consequences, a recommendation> | none
```

### How each section earns its place

**Re-read what was settled, then re-read the code it lands on.** The
direction and target shape are decided — the spec, consult record, or PR
the brief's `rests-on` names — so the restatement in section 1 says why
*that* approach removes the failure, not what you would have chosen. Then
read the code the first cut will touch: trace the real data and control
flow and the existing patterns, and cite what you read, so the actions you
propose fit what is already there. When the code contradicts the brief's
*facts*, that goes in section 2; when it contradicts the brief's
*direction*, that is a `Reframe required` — a build session never
substitutes its own approach for the reviewed one, quietly or otherwise.

**Check premises at their source, in this order of strength:** run the
command or query · read the symbol · read the record · the brief's word.
Wherever your take rests on inference rather than something you actually
read, go read it. `Unverified` is a finding, not a failure: it names the
missing evidence and stays unverified until that evidence exists.
Production claims take production evidence; when getting it would be its
own investigation, say so rather than infer it. One premise is load-bearing
— the one that, false, makes the approach not solve the stated problem —
and it is tested with the cheapest decisive evidence whether or not the
brief listed it.

**The scope test is where a build session's judgement lives.** The
sequence was drawn with less knowledge than you now hold. A shared seam, a
contract to de-risk before its consumers land, or a correctness coupling
argue for folding the next step forward into this one; a different
evolution axis, a different risk boundary, or a parallel tail argue for
unbundling. Either is a recommendation to the human with the cost of the
wrong boundary stated; the direction itself stays. The first cut is the
build equivalent of a red test: the smallest change that turns the
load-bearing premise into something observable, so the session that
implements starts from evidence rather than from the plan's word.

**Stop and flag, never guess past.** A decision that turns out wrong or
underspecified once you are in the code is a `Reframe required` or a
`Decision needed`, depending on whether it changes the direction — it is
not resolved by picking the reading that lets the build continue.

**The verdict is one line and binary.** `Reframe required` routes to a
design pass in a later turn, with the smallest consequence for the work
stated; it is not softened into "holds, mostly". A *Decision needed* is
appended only when verification exposed a product fork that changes the
direction — written so the user can decide from the text alone: why it
matters now, the user-visible options, your recommendation.

Done when every premise carries one of the three verdicts, the scope test
names a boundary and a first cut, and section 4 is one of the two lines.
Stop after this response — implementation begins after the user's next
message.
