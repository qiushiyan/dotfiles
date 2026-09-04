## Pickup gate — build

**The direction is settled; the premises and the actions are on trial.**
Something outside the writing session already judged the approach this
brief carries. The first turn does not reopen the problem definition or
the direction: it verifies that the world still matches what the approach
assumes, and judges the *actions* — order, scope, the first cut — as
sharply as a design pass would.

The packet has two readers, in this order. First the user, who wrote or
accepted this brief days ago, has run other tracks since, and opens the
packet having lost the thread — it is their first look at this work since
then, and it has to re-ground them before it asks anything of them. Second
the `/consult` round that usually follows even a settled direction, asking
whether the implementation could be cleaner or more whole; it takes the
packet as its input and shapes its own brief from it. Write for the first
reader; the second reads through them.

**Read only; write nothing into the worktree.** Run existing commands,
tests, and queries freely; scratch files go to the scratchpad. A claim
that needs a test that does not exist yet stays `Unverified` and names the
test — the build turn writes it. After the project onboarding the pointer
names, run `brief drift <slug>` before any other read: a claim the drift
shows moved is checked against the moved code; a brief instruction the
drift makes moot is named as such rather than followed, and a `blocked-by`
gate the drift shows cleared is reported as cleared.

Return this shape, in about 600 words. Section 1 is prose; elsewhere the
`·` and `|` mark slots, and each slot is filled with a clause the user can
follow, never a label. **`Reframe required`** is the one line that goes
above section 1, and only when a falsified premise, or a decision that
turns out wrong once you are in the code, means the reviewed approach no
longer solves the stated problem: `Reframe required — <what changed, and
the smallest consequence for the work>`, after which the packet still
follows and a design pass runs in a later turn. A finding that leaves the
direction standing is a section 4 fork or a section 2 line instead — a
build session never substitutes its own approach for the reviewed one,
and never resolves an underspecified decision by picking the reading that
lets the build continue. When nothing reframes, the premise list is the
verdict and no verdict line is written.

```markdown
## 1. Where we are
<the re-grounding: what this part of the product does and for whom · what is broken or wanted, and why it matters now · what has already landed toward it, and why the reviewed approach removes the failure · what this session is for — plain sentences, as to a colleague back from two weeks away; a PR number or doc section only as a pointer after the plain sentence; a term the brief coined is re-introduced before it is used>

## 2. Premises checked
- <the one premise that, false, means the approach no longer solves the stated problem — one of the brief's load-bearing claims, or unlisted; tested with the cheapest decisive evidence> · Held — <evidence> | Falsified — <what is true instead> | Unverified — <what would settle it>
- <each remaining `## At pickup` claim, at its named source> · …
- <each `rests-on` and `blocked-by` entry, at its live state> · …

## 3. Scope test
<the next PR's boundary as the spec or PR the brief points at draws it, against what the code already holds: fold forward | unbundle | right as drawn — with the cost of the wrong boundary>
First cut: <the smallest change that makes the load-bearing premise observable — a red test, a probe, a spike>

## 4. Decisions needed
<a product fork that verification exposed, or a parked fork whose case the drift shows has now landed, in the form below> | none

## Next move
<the consult you recommend — approach mode, with the one question about the implementation's shape the round would buy, typically the scope test's boundary, and where a fork is open the option the round should assume — or "go" when the scope test found nothing worth a second opinion>
```

### How each section earns its place

**Re-read what was settled, then the code it lands on, then write section
1 for the user.** The direction and target shape are decided — the spec,
consult record, or PR the brief points at through its paths and its body —
so the restatement says why *that* approach removes the failure, not what
you would have chosen. Read the code the first cut will touch: trace the
real data and control flow and the existing patterns, and cite what you
read, so the actions you propose fit what is already there. Then write the
re-grounding in the user's register: the vocabulary you built while
reading is yours, not theirs.

<example type="avoid">
#5753, #5784 and #5872 fixed the mechanisms and landed the composed witnesses, but nothing has run them: the four twin cases, the fleet predicates the two 08-25 specs owe, and the closing-read lines in §M7 are all still open.
</example>

<example>
Loopy can edit wiki pages from inside a run. On pool-served workspaces three things went wrong in late August: an agent's edit saved but a person with the page open never saw it appear; an access grant approved mid-run never reached the running session; two writers could mint the same block id and corrupt the page. Three PRs fixed the mechanisms, each with a browser test that proves it (#5753, #5784, #5872). None of those tests has yet been run against the deployed system — this session runs them and records what they show, so the status ledger closes on evidence rather than on the specs' word.
</example>

**Check premises at their source, in this order of strength:** run the
command or query · read the symbol · read the record · the brief's word.
`Unverified` is a finding, not a failure: it names the missing evidence and
stays unverified until that evidence exists. Production claims take
production evidence; when getting it would be its own investigation, say
so rather than infer it.

**The scope test is where a build session's judgement lives.** A shared
seam, a contract to de-risk before its consumers land, or a correctness
coupling argue for folding the next step forward into this one; a
different evolution axis, a different risk boundary, or a parallel tail
argue for unbundling. Either is a recommendation to the human with the
cost of the wrong boundary stated; the direction itself stays. The first
cut is the build equivalent of a red test: the smallest change that turns
the load-bearing premise into something observable, so the session that
implements starts from evidence rather than from the plan's word.

**Write each fork as if briefing a CEO** who decides from your words
alone, not from the code or the session behind them: why it matters now,
what it means in plain product terms, the options with what each implies
for the real user, and your recommendation.

<example>
**Q2 — When a schedule import partially fails, do we save the good rows or reject the file?** This decides what a user sees after uploading a 500-task file with 3 bad rows. Save-partial gets them working immediately but they may not notice the 3 missing tasks; reject-whole is safe but turns one typo into a blocked afternoon. Recommendation: save-partial with a banner naming the failed rows — the blocked afternoon is the worse failure.
</example>

**The next move is usually a consult.** A settled direction still leaves
the implementation's shape open — a cleaner seam, a more whole cut — and a
second opinion before code is written is cheaper than one after.

Done when section 1 would re-ground the user without the brief in front
of them, every premise carries one of the three verdicts, the scope test
names a boundary and a first cut, and the next move is named. Stop after
this response — implementation begins after the user's next message.
