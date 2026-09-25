## Pickup gate — design

**The problem is on trial, not just the approach.** This brief carries a
symptom, a framing, and a proposed approach that nobody outside the writing
session has judged. The first turn is an analysis pass that reasons from
the code as it is rather than from the brief's assumptions, and attacks all
three: the framing may be redefined.

The packet has two readers, in this order. First the user, who wrote or
accepted this brief days ago, has run other tracks since, and opens the
packet having lost the thread — it is their first look at this work since
then, and it has to re-ground them before it asks anything of them. Second
the `/consult` round that usually follows, which takes the packet as its
input and shapes its own brief from it. Write for the first reader; the
second reads through them.

**Read only; write nothing into the worktree.** Run existing commands,
tests, and queries freely; scratch files go to the scratchpad. A claim
that needs a test that does not exist yet stays `Unverified` and names the
test — the build turn writes it. After the project onboarding the pointer
names, run `brief drift <slug>` before any other read: a claim the drift
shows moved is checked against the moved code; a brief instruction the
drift makes moot is named as such rather than followed.

Return this shape, in about 1,000 words. Section 1 is prose; elsewhere the
`·` and `|` mark slots, and each slot is filled with a clause the user can
follow, never a label.

```markdown
## 1. Where we are
<the re-grounding: what this part of the product does and for whom · what is broken or wanted, and why it matters now · what has already landed toward it · what this session is for — plain sentences, as to a colleague back from two weeks away; a PR number or doc section only as a pointer after the plain sentence; a term the brief coined is re-introduced before it is used>
Framing: holds | redefined — <what the code and evidence say the problem is, and where the brief was off>

## 2. Premises checked
- <the one premise that, false, means the approach no longer solves the stated problem — one of the brief's load-bearing claims, or unlisted> · Held — <evidence> | Falsified — <what is true instead> | Unverified — <what would settle it>
- <each remaining `## At pickup` claim, at its named source> · …
- Cause on trial <only when the brief inferred its cause rather than traced it; this line records what your read did to each link>: observed — <what a user or a log saw, quoted; "nothing on record" when the brief argues from a class> · claimed chain — <X causes Y, which is why we see Z> · each link Held | Falsified | Unverified at its source · alternative cause the evidence leaves open — <cause> | none

## 3. Pressure test
- User: <strongest objection from what the user sees, waits for, or must understand> | None found
- Structure: <the change is absorbed by the current design | accreted onto it | blocked by it — and the preparatory reshape, if the foundation fights the change> · <strongest objection> | None found
- Proof: <the observation, available today, that would show the approach worked> | ran — <what it showed> | none named — not testable yet

## 4. Risk accounting
<for each of hot path · user-driven surface · core execution logic the change touches: what runs differently, what holds the risk down, why it is worth it — or one line saying it touches none>

## 5. End state
<where this part of the system is headed — quoted from the initiative's sequence doc, else implied by section 2's facts — in a sentence or two> · <one reshape away | a different system> · <what the recommendation does toward it> | the current structure is that shape | not established — <what is unverified>

## 6. Countershape, trade-off, recommendation
<one genuinely different shape that answers the strongest objection> | the proposal survived — <why> | the proposal is moot — <the premise that fell> | no countershape — section 2 fixed the shape at <seam>
<proposal vs countershape on the root problem and on user / structure / risk cost; a hybrid only where a changed shape removes the strongest objection>
Recommendation: <the shape> — accepts <the trade-off> · <"a judgment call" where it is one> · <one PR, or the sequence, under the project's milestone rule where one exists> | none — the brief closes: <what answered it, where the record goes>

## 7. Decisions and parked unknowns
Decision needed: <a product fork, in the form below> | none
Parked: <an unresolved technical fact that does not change the direction, with its working answer> | none

## Next move
<the consult you recommend — with the one question the round would buy (the cause, when it is still a belief; the shape, when the mechanism is traced) and, where a fork is open, the option the round should assume until the user answers it> | none — the brief closes, and the closing record is <where>
```

### How each section earns its place

**Read the code before writing section 1.** Trace the real data and
control flow, note the constraints that exist and why, and cite the files
and functions you read. Then write the re-grounding for the user, in their
register, before the technical restatement: the vocabulary you built while
reading is yours, not theirs. When the code and evidence contradict the
brief, the restatement follows the code and names where the brief was off —
that redefinition is what this gate exists to allow, and when the framing
moves, say so in the first line.

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
so rather than infer it. A spec's `Today:` lines, the sentences in its
Structure and Wiring that describe the code as it is, are premises for
this check: read each at the path it names before building on it.

**A cause still believed goes on trial; a cause read from the code is a
premise like any other.** When the brief's fix rests on a cause nobody has
traced to its lines — inferred from an incident, a log, a timeline —
separate what was observed from what was inferred, test each link of the
claimed chain at its source, and name the alternative cause the evidence
has not ruled out; the countershape in section 6 is then the fix at a
different link, and the consult's question is the cause. When the mechanism
is traced and you can point at it, the cause is checked in the ordinary
premise line and the consult's question is the shape of the fix.

**Structure: is this a local change the design absorbs, or is the design
in the way?** When the foundation fights the change, preparatory
refactoring — *make the change easy, then make the easy change* — beats
another patch; back a "structurally wrong" call with the code and name its
cost.

**Proof is the recipe's last step.** An approach with no observable
success available today — no predicate that is red now and would go green,
no measurement, no user-visible before/after — is not yet testable, and
that is itself the strongest objection for section 6 to answer.

**Risk is not lines changed** — an internal refactor can be large and
inert. What holds the risk down is coverage that already exists, a flag or
fallback, or a signal that would catch a regression. "Adds a branch that
only runs in the error path" is an answer; "overhead is minimal" is not.
This is an accounting, not a veto.

**The end state is usually already written.** A live initiative records
where it is headed in its sequence doc, reached through the brief's
`paths:`; quote it. Without one, section 2's facts may imply it; without
that, say "not established" — an end state invented to fill the slot is
worse than none. It orients the recommendation so a local fix is chosen
knowing what it defers. A fact that changes what the brief's problem *is*
redefines the framing in section 1; a fact that leaves the problem standing
and shows a larger one beside it goes here, and whether this session turns
to it is a section 7 fork.

<example>
## 5. End state
The capacity initiative's next milestone records it: the process that coordinates every run does no heavy work on its own thread. Today that thread still hashes and assembles each unpacked file on a cold claim, in slices of a few milliseconds · one reshape away · this brief's lever closes with nothing to build; the unpack share is that milestone's question, and section 7 asks whether this session takes it up.
</example>

<example>
## 5. End state
The current structure is that shape: one serializer behind one versioned header, every writer inside it. The change flips a default inside that structure.
</example>

**One countershape; the design space belongs to the consult.** The
proposal is the brief's `## At pickup` approach block. The countershape
makes a different bet on the *shape* — contained against structural, the
class against the instance, another seam, another owner of the state. A
smaller slice, a split or a reorder is sequencing: it goes on the
recommendation line under the project's milestone rule. When the proposal
wins, one clause says why the cheaper shape does not; that clause is what
shows a structural change earns its cost at the current scale. The
recommendation is the step the evidence supports, facing the end state,
and the consult is dispatched from it.

<example>
## 6. Countershape, trade-off, recommendation
Exclude the three server-to-server callback routes from the proxy matcher, as the event route already is, so no body cap and no clone applies to them. The proposal raises the cap for one route; the countershape closes the class in one matcher line and a raw-bytes rewrite would still pass through the clone. Hybrid: exclusion for all three, raw bytes only for the route that parses megabytes before it checks its secret.
Recommendation: the hybrid — accepts leaving two routes on base64 JSON · not a judgment call · one PR.
</example>

<example type="avoid">
Countershape: ship reconciliation first as its own thin PR, then the read in a second.
</example>

The avoid case is a sequence, not a shape; it belongs on the recommendation
line.

**Route every question you are tempted to ask into one of three lanes:**

- **Product or direction forks** — real decisions with live options that
  are the user's (intent, priorities, UX, scope). These are section 7's
  *Decision needed*. None is a fine answer, and an open fork does not
  block the consult: name the option the round should assume.
- **Implementation details** — yours. Decide, record the choice in the
  packet, continue.
- **Technical unknowns that do not change the direction** — section 7's
  *Parked*, each with your working answer; the consult or a review round
  resolves them. Omit the list when it is empty.

Write each fork as if briefing a CEO who decides from your words alone,
not from the code or the session behind them: why it matters now, what it
means in plain product terms, the options with what each implies for the
real user, and your recommendation. A term section 1 did not introduce is
introduced again where the user must act on it — a question, the
recommendation — since the vocabulary sections 2–6 built is yours, and a
line that leans on it comes back as "what does this mean?" instead of a
decision.

<example>
**Q2 — When a schedule import partially fails, do we save the good rows or reject the file?** This decides what a user sees after uploading a 500-task file with 3 bad rows. Save-partial gets them working immediately but they may not notice the 3 missing tasks; reject-whole is safe but turns one typo into a blocked afternoon. Recommendation: save-partial with a banner naming the failed rows — the blocked afternoon is the worse failure.
</example>

Done when section 1 would re-ground the user without the brief in front
of them, every slot in sections 2–7 carries its verdict or its `none`, and
the next move names a consult and its question, or the close. Stop after this
response — implementation begins once the direction is accepted.
