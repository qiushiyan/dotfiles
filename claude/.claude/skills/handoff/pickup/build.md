## Pickup gate — build

**The direction is settled; the premises and the actions are on trial.**
This brief carries an approach something outside the writing session
already judged — an approved spec, a consult record, a PR to continue. The
first turn does not reopen the problem definition or the direction: it
verifies that the world still matches what the approach assumes, and
judges the *actions* — order, scope, the first cut — as sharply as a
design pass would. No code changes; the worktree stays as `brief start`
placed it.

The packet has two readers, in this order. First the user, who wrote or
accepted this brief days ago, has run other tracks since, and opens the
packet having lost the thread — it is their first look at this work since
then, and it has to re-ground them before it asks anything of them. Second
the `/consult` round that usually follows even a settled direction, asking
whether the implementation could be cleaner or more whole; it reads the
packet as its input. Write for the first reader; the second reads through
them.

Read `brief drift` first. A claim the drift shows moved is checked against
the moved code; a brief instruction the drift makes moot is named as such
rather than followed.

Return this shape, in about 600 words. Keep it short by leaving out what
would not change what the reader does next, never by compressing sentences
into fragments or arrow chains. When a falsified premise means the
reviewed approach no longer solves the stated problem, the packet opens
with one line above section 1 — `Reframe required — <what changed, and
the smallest consequence for the work>` — and the rest still follows;
otherwise the premise table is the verdict and no verdict line is written.

```markdown
## 1. Where we are
<the re-grounding: what this part of the product does and for whom · what is broken or wanted, and why it matters now · what has already landed toward it, and why the reviewed approach removes the failure · what this session is for — plain sentences, as to a colleague back from two weeks away; a PR number or doc section only as a pointer after the plain sentence; a term the brief coined is re-introduced before it is used>

## 2. Premises checked
- <the single premise that must be true for the approach to solve the stated problem, listed by the brief or not> · Held — <evidence> | Falsified — <what is true instead> | Unverified — <what would settle it>
- <each `## At pickup` claim, at its named source> · …
- <each `rests-on` and `blocked-by` entry, at its live state> · …

## 3. Scope test
<the next PR's boundary against the as-built: fold forward | unbundle | right as drawn — with the cost of the wrong boundary>
First cut: <the smallest change that makes the load-bearing premise observable — a red test, a probe, a spike>

## 4. Decisions needed
<a product fork that verification exposed, in the form below> | none

## Next move
<the consult you recommend — approach mode, with the one question about the implementation's shape the round would buy — or "go" when the scope test found nothing worth a second opinion>
```

### How each section earns its place

**Re-read what was settled, then the code it lands on, then write section
1 for the user.** The direction and target shape are decided — the spec,
consult record, or PR the brief's `rests-on` names — so the restatement
says why *that* approach removes the failure, not what you would have
chosen. Read the code the first cut will touch: trace the real data and
control flow and the existing patterns, and cite what you read, so the
actions you propose fit what is already there. Then write the
re-grounding in the user's register: the vocabulary you built while
reading is yours, not theirs.

<example type="avoid">
#5753, #5784 and #5872 fixed the mechanisms and landed the composed witnesses, but nothing has run them: the four twin cases, the fleet predicates the two 08-25 specs owe, and the closing-read lines in §M7 are all still open.
</example>

<example>
Loopy can edit wiki pages from inside a run. On pool-served workspaces three things went wrong in late August: an agent's edit saved but a person with the page open never saw it appear; an access grant approved mid-run never reached the running session; two writers could mint the same block id and corrupt the page. Three PRs fixed the mechanisms, each with a browser test that proves it (#5753, #5784, #5872). None of those tests has yet been run against the deployed system — this session runs them and records what they show, so the status ledger closes on evidence rather than on the specs' word.
</example>

When the code contradicts the brief's *facts*, that goes in section 2;
when it contradicts the brief's *direction*, that is the `Reframe
required` line — a build session never substitutes its own approach for
the reviewed one, quietly or otherwise, and a reframe routes to a design
pass in a later turn.

**Check premises at their source, in this order of strength:** run the
command or query · read the symbol · read the record · the brief's word.
Wherever your take rests on inference rather than something you actually
read, go read it. `Unverified` is a finding, not a failure: it names the
missing evidence and stays unverified until that evidence exists.
Production claims take production evidence; when getting it would be its
own investigation, say so rather than infer it. One premise is
load-bearing — the one that, false, makes the approach not solve the
stated problem — and it is tested with the cheapest decisive evidence
whether or not the brief listed it. A `blocked-by` gate that the drift
shows cleared is reported as cleared, and the instruction that waited on
it as moot.

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
*Decision needed*, depending on whether it changes the direction — it is
not resolved by picking the reading that lets the build continue. Write
each fork as if briefing a CEO who decides from your words alone, not
from the code or the session behind them: why it matters now, what it
means in plain product terms, the options with what each implies for the
real user, and your recommendation. Before sending, check each against:
could they decide from this text alone?

<example>
**Q2 — When a schedule import partially fails, do we save the good rows or reject the file?** This decides what a user sees after uploading a 500-task file with 3 bad rows. Save-partial gets them working immediately but they may not notice the 3 missing tasks; reject-whole is safe but turns one typo into a blocked afternoon. Recommendation: save-partial with a banner naming the failed rows — the blocked afternoon is the worse failure.
</example>

**The next move is usually a consult, named.** A settled direction still
leaves the implementation's shape open — a cleaner seam, a more whole cut
— and a second opinion before code is written is cheaper than one after.
End by recommending `/consult` in approach mode with the one question the
round would buy, typically the scope test's boundary; recommend "go" only
when the scope test found nothing worth a second opinion. The packet is
that consult's input; the consult skill shapes its own brief from it.

Done when section 1 would re-ground the user without the brief in front
of them, every premise carries one of the three verdicts, the scope test
names a boundary and a first cut, and the next move is named. Stop after
this response — implementation begins after the user's next message.
